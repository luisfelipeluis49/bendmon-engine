"""Secure, bounded filesystem and JSON intake for Content-0."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
from typing import Any, Callable, Iterable

from .models import (Asset, AssetId, Catalog, CatalogId, Encounter,
                     EncounterEntry, EncounterId, LoadedProject, MapId,
                     MapRecord, MixRecipe, MixResultDescriptor, MoveId,
                     MoveRecord, Project, ProjectId, RecipeId, ResultId, TypeId,
                     Species, SpeciesId)

SCHEMA = "content-0"
MAX_JSON_BYTES = 1 << 20
MAX_TOTAL_BYTES = 8 << 20
MAX_FILES = 64
MAX_ENTITIES = 256
MAX_PER_RECORD = 256
MAX_TOTAL_REFS = 4096
MAX_DEPTH = 16
MAX_PATH = 240
MAX_WIRE_TOKENS = 140_000
MAX_WIRE_BYTES = 2 << 20
ID_RE = re.compile(r"[a-z][a-z0-9_-]{0,31}:[a-z][a-z0-9_-]{0,31}\Z")
PATH_COMPONENT_RE = re.compile(r"[A-Za-z0-9_.-]+\Z")
SHA_RE = re.compile(r"[0-9a-f]{64}\Z")


@dataclass(frozen=True, order=True, slots=True)
class Diagnostic:
    code: str
    file: str
    pointer: str
    entity_id: str | None
    message: str

    def as_dict(self) -> dict[str, Any]:
        return {"code": self.code, "file": self.file, "pointer": self.pointer,
                "entityId": self.entity_id, "message": self.message}


class ContentError(Exception):
    def __init__(self, diagnostics: Iterable[Diagnostic]):
        self.diagnostics = tuple(sorted(diagnostics))
        super().__init__(self.diagnostics[0].message if self.diagnostics else "invalid content")


class InfrastructureError(RuntimeError):
    """The trusted native validation boundary is absent or broken."""


def _fail(code: str, file: str, pointer: str, message: str,
          entity_id: str | None = None) -> None:
    raise ContentError([Diagnostic(code, file, pointer, entity_id, message)])


def _valid_path(value: Any, suffix: str, file: str, pointer: str) -> str:
    if not isinstance(value, str) or not value.isascii() or len(value) > MAX_PATH:
        _fail("path", file, pointer, "path must be ASCII and at most 240 characters")
    parts = value.split("/")
    if (not value or value.startswith("/") or any(not PATH_COMPONENT_RE.fullmatch(p) or p in {".", ".."} for p in parts)
            or "\\" in value or ":" in value or "\0" in value or not value.endswith(suffix)):
        _fail("path", file, pointer, f"path must be normalized and end in {suffix}")
    return value


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise ValueError(f"duplicate key {key!r}")
        out[key] = value
    return out


def _bad_number(value: str) -> Any:
    raise ValueError(f"unsupported number {value!r}")


def _decode(raw: bytes, file: str) -> Any:
    try:
        text = raw.decode("utf-8", "strict")
        if any(0xD800 <= ord(c) <= 0xDFFF for c in text):
            raise ValueError("Unicode surrogate is forbidden")
        # Bound nesting lexically before json.loads can recurse. Brackets inside
        # strings (including escaped quotes/backslashes) do not affect depth.
        depth = 0
        in_string = escaped = False
        for char in text:
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            elif char == '"':
                in_string = True
            elif char in "[{":
                depth += 1
                if depth > MAX_DEPTH:
                    raise ValueError("JSON nesting exceeds 16")
            elif char in "]}":
                depth -= 1
        value = json.loads(text, object_pairs_hook=_pairs, parse_float=_bad_number,
                           parse_constant=_bad_number)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        _fail("json", file, "", f"invalid strict UTF-8 JSON: {exc}")
    stack = [(value, 1)]
    while stack:
        node, depth = stack.pop()
        if depth > MAX_DEPTH:
            _fail("json-depth", file, "", "JSON nesting exceeds 16")
        if isinstance(node, dict):
            for key, child in node.items():
                if any(0xD800 <= ord(c) <= 0xDFFF for c in key):
                    _fail("json", file, "", "Unicode surrogate is forbidden")
                if isinstance(child, str) and any(0xD800 <= ord(c) <= 0xDFFF for c in child):
                    _fail("json", file, "", "Unicode surrogate is forbidden")
                if isinstance(child, (dict, list)):
                    stack.append((child, depth + 1))
        elif isinstance(node, list):
            for child in node:
                if isinstance(child, str) and any(0xD800 <= ord(c) <= 0xDFFF for c in child):
                    _fail("json", file, "", "Unicode surrogate is forbidden")
                if isinstance(child, (dict, list)):
                    stack.append((child, depth + 1))
    if not isinstance(value, dict):
        _fail("shape", file, "", "document must be a JSON object")
    return value


def _pointer_token(value: str) -> str:
    return value.replace("~", "~0").replace("/", "~1")


def _object(value: Any, required: set[str], file: str, pointer: str,
            optional: set[str] | None = None) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail("shape", file, pointer, "expected object")
    unknown, missing = set(value) - required - (optional or set()), required - set(value)
    if unknown:
        _fail("unknown-field", file, pointer + "/" + _pointer_token(sorted(unknown)[0]), "unknown field")
    if missing:
        _fail("missing-field", file, pointer, "missing field " + sorted(missing)[0])
    return value


def _array(value: Any, file: str, pointer: str, limit: int = MAX_PER_RECORD) -> list[Any]:
    if not isinstance(value, list):
        _fail("shape", file, pointer, "expected array")
    if len(value) > limit:
        _fail("limit", file, pointer, f"array exceeds {limit} items")
    return value


def _string(value: Any, file: str, pointer: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 128 or any(not c.isprintable() for c in value):
        _fail("name", file, pointer, "name must be 1..128 printable Unicode characters")
    return value


def _id(value: Any, file: str, pointer: str) -> str:
    if not isinstance(value, str) or len(value) > 65 or not ID_RE.fullmatch(value):
        _fail("id", file, pointer, "ID must be lowercase namespace:local")
    return value


def _uint(value: Any, low: int, high: int, file: str, pointer: str) -> int:
    if type(value) is not int or not low <= value <= high:
        _fail("integer", file, pointer, f"expected integer in {low}..{high}")
    return value


class _Root:
    def __init__(self, path: os.PathLike[str] | str):
        absolute = os.path.abspath(os.fspath(path))
        current = -1
        try:
            current = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
            for component in Path(absolute).parts[1:]:
                nxt = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                              dir_fd=current)
                os.close(current)
                current = nxt
            self.fd = current
        except OSError as exc:
            if current >= 0:
                os.close(current)
            raise ContentError([Diagnostic("root", ".", "", None, f"cannot open project directory: {exc.strerror}")]) from None
        self.total = 0

    def close(self) -> None:
        os.close(self.fd)

    def read(self, rel: str, max_bytes: int) -> bytes:
        current = os.dup(self.fd)
        try:
            parts = rel.split("/")
            for part in parts[:-1]:
                nxt = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
                os.close(current)
                current = nxt
            fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=current)
            try:
                info = os.fstat(fd)
                if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
                    _fail("file-type", rel, "", "source must be a regular, non-hard-linked file")
                if info.st_size > max_bytes:
                    _fail("file-size", rel, "", f"file exceeds {max_bytes} bytes")
                if self.total + info.st_size > MAX_TOTAL_BYTES:
                    _fail("total-size", rel, "", "project exceeds 8 MiB")
                raw = b""
                while len(raw) <= max_bytes:
                    chunk = os.read(fd, min(65536, max_bytes + 1 - len(raw)))
                    if not chunk:
                        break
                    raw += chunk
                if len(raw) != info.st_size or len(raw) > max_bytes:
                    _fail("file-changed", rel, "", "file size changed during bounded read")
                self.total += len(raw)
                return raw
            finally:
                os.close(fd)
        except ContentError:
            raise
        except OSError as exc:
            _fail("file", rel, "", f"cannot securely read file: {exc.strerror}")
        finally:
            os.close(current)


def _doc(root: _Root, rel: str) -> dict[str, Any]:
    value = _decode(root.read(rel, MAX_JSON_BYTES), rel)
    if value.get("schemaVersion") != SCHEMA:
        _fail("schema-version", rel, "/schemaVersion", 'schemaVersion must be "content-0"')
    return value


def _unique(values: list[str], file: str, pointer: str, what: str) -> None:
    seen: set[str] = set()
    for value in values:
        if value in seen:
            _fail("duplicate", file, pointer, f"duplicate {what}: {value}", value)
        seen.add(value)


def _parse_ppm(raw: bytes, file: str) -> None:
    match = re.fullmatch(rb"P6\n([1-9][0-9]{0,2}) ([1-9][0-9]{0,2})\n255\n([\s\S]*)", raw)
    if not match:
        _fail("ppm", file, "", "asset must use the exact P6 PPM header")
    width, height = int(match[1]), int(match[2])
    if width > 256 or height > 256 or len(match[3]) != width * height * 3:
        _fail("ppm", file, "", "PPM dimensions or pixel byte count is invalid")


def _kernel(tokens: list[int], kernel_path: os.PathLike[str] | str,
            species: list[tuple[Species, str, int]], encounters: list[tuple[Encounter, str]],
            maps: list[tuple[MapRecord, str]], project: Project) -> None:
    wire = " ".join(map(str, tokens)).encode("ascii")
    if len(tokens) > MAX_WIRE_TOKENS or len(wire) > MAX_WIRE_BYTES:
        _fail("wire-limit", "manifest.json", "", "native validation wire exceeds limit")
    try:
        executable = os.path.abspath(os.fspath(kernel_path))
        with tempfile.NamedTemporaryFile(prefix="content-wire.", mode="wb", delete=True) as stream:
            stream.write(wire)
            stream.flush()
            # `--` terminates trusted Bend runtime flags; IO.args receives one path.
            result = subprocess.run([executable, "--", os.path.abspath(stream.name)],
                                    stdin=subprocess.DEVNULL, capture_output=True, timeout=15,
                                    check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise InfrastructureError(f"content kernel unavailable: {exc}") from None
    try:
        stdout = result.stdout.decode("ascii", "strict")
        stderr = result.stderr.decode("ascii", "strict")
    except UnicodeDecodeError:
        raise InfrastructureError("content kernel emitted non-ASCII output") from None
    if result.returncode == 0 and stdout == "OK\n" and not stderr:
        return
    if result.returncode == 0 or stdout:
        raise InfrastructureError("content kernel protocol failure")
    if stderr.startswith("WIRE "):
        if not re.fullmatch(r"WIRE [ -~]+\n", stderr):
            raise InfrastructureError("content kernel emitted malformed wire failure")
        raise InfrastructureError("content kernel rejected trusted wire input")
    lines = stderr.splitlines(keepends=True)
    diagnostics: list[Diagnostic] = []
    messages = {1: "species sprite does not resolve", 2: "encounter species does not resolve",
                3: "encounter level must be 1..200", 4: "map dimensions must be 1..512",
                5: "map encounter does not resolve", 6: "project entryMap does not resolve"}
    for line in lines:
        match = re.fullmatch(r"ERR ([1-6]) ([0-9]+) ([0-9]+)\n", line)
        if not match:
            raise InfrastructureError("content kernel emitted malformed diagnostics")
        code, record, item = map(int, match.groups())
        if code == 1 and record < len(species):
            entity, file, pos = species[record]
            pointer = f"/species/{pos}/sprite"
        elif code in {2, 3} and record < len(encounters) and item < len(encounters[record][0].entries):
            entity, file = encounters[record]
            pointer = f"/entries/{item}/" + ("species" if code == 2 else "level")
        elif code in {4, 5} and record < len(maps) and (code == 4 or item < len(maps[record][0].encounters)):
            entity, file = maps[record]
            pointer = ("/width" if not 1 <= entity.width <= 512 else "/height") if code == 4 else f"/encounters/{item}"
        elif code == 6:
            entity, file, pointer = project, "project.json", "/entryMap"
        else:
            raise InfrastructureError("content kernel diagnostic index is out of bounds")
        diagnostics.append(Diagnostic(f"kernel-{code}", file, pointer, str(entity.id), messages[code]))
    if not diagnostics:
        raise InfrastructureError("content kernel failed without diagnostics")
    raise ContentError(diagnostics)


def load_project(path: os.PathLike[str] | str, kernel_path: os.PathLike[str] | str | None = None) -> LoadedProject:
    root = _Root(path)
    try:
        p = _object(_doc(root, "project.json"), {"schemaVersion", "id", "name", "ruleset", "entryMap"}, "project.json", "")
        if p["ruleset"] != "unassigned":
            _fail("ruleset", "project.json", "/ruleset", 'ruleset must be "unassigned"')
        project = Project(ProjectId(_id(p["id"], "project.json", "/id")), _string(p["name"], "project.json", "/name"),
                          "unassigned", MapId(_id(p["entryMap"], "project.json", "/entryMap")))
        m = _object(_doc(root, "manifest.json"), {"schemaVersion", "catalogs", "maps", "encounters", "assets"}, "manifest.json", "", {"moves", "mixRecipes", "mixResults"})
        catalog_paths = [_valid_path(v, ".json", "manifest.json", f"/catalogs/{i}") for i, v in enumerate(_array(m["catalogs"], "manifest.json", "/catalogs"))]
        map_paths = [_valid_path(v, ".json", "manifest.json", f"/maps/{i}") for i, v in enumerate(_array(m["maps"], "manifest.json", "/maps"))]
        encounter_paths = [_valid_path(v, ".json", "manifest.json", f"/encounters/{i}") for i, v in enumerate(_array(m["encounters"], "manifest.json", "/encounters"))]
        move_paths = [_valid_path(v, ".json", "manifest.json", f"/moves/{i}") for i, v in enumerate(_array(m.get("moves", []), "manifest.json", "/moves"))]
        recipe_paths = [_valid_path(v, ".json", "manifest.json", f"/mixRecipes/{i}") for i, v in enumerate(_array(m.get("mixRecipes", []), "manifest.json", "/mixRecipes"))]
        result_paths = [_valid_path(v, ".json", "manifest.json", f"/mixResults/{i}") for i, v in enumerate(_array(m.get("mixResults", []), "manifest.json", "/mixResults"))]
        all_docs = catalog_paths + map_paths + encounter_paths + move_paths + recipe_paths + result_paths
        if len(all_docs) > MAX_FILES:
            _fail("file-count", "manifest.json", "", "manifest references more than 64 files")
        _unique(all_docs, "manifest.json", "", "manifest path")
        catalog_paths.sort(); map_paths.sort(); encounter_paths.sort(); move_paths.sort(); recipe_paths.sort(); result_paths.sort()
        assets: list[Asset] = []
        asset_values = _array(m["assets"], "manifest.json", "/assets")
        for i, raw_asset in enumerate(asset_values):
            a = _object(raw_asset, {"id", "path", "mediaType", "bytes", "sha256"}, "manifest.json", f"/assets/{i}")
            aid = AssetId(_id(a["id"], "manifest.json", f"/assets/{i}/id"))
            apath = _valid_path(a["path"], ".ppm", "manifest.json", f"/assets/{i}/path")
            if a["mediaType"] != "image/x-portable-pixmap":
                _fail("media-type", "manifest.json", f"/assets/{i}/mediaType", "unsupported media type", aid)
            size = _uint(a["bytes"], 0, MAX_TOTAL_BYTES, "manifest.json", f"/assets/{i}/bytes")
            digest = a["sha256"]
            if not isinstance(digest, str) or not SHA_RE.fullmatch(digest):
                _fail("sha256", "manifest.json", f"/assets/{i}/sha256", "sha256 must be 64 lowercase hex characters", aid)
            assets.append(Asset(aid, apath, a["mediaType"], size, digest))
        _unique([str(a.id) for a in assets], "manifest.json", "/assets", "asset ID")
        _unique([a.path for a in assets] + all_docs, "manifest.json", "", "manifest path")
        if len(all_docs) + len(assets) > MAX_FILES:
            _fail("file-count", "manifest.json", "", "manifest references more than 64 files")
        for asset in assets:
            body = root.read(asset.path, min(asset.bytes, MAX_TOTAL_BYTES) if asset.bytes else 0)
            if len(body) != asset.bytes or hashlib.sha256(body).hexdigest() != asset.sha256:
                _fail("asset-integrity", asset.path, "", "asset byte size or SHA-256 does not match manifest", asset.id)
            _parse_ppm(body, asset.path)

        assets_by_id = {str(a.id) for a in assets}
        moves: list[MoveRecord] = []
        for rel in move_paths:
            raw_move = _doc(root, rel)
            d = _object(raw_move, {"schemaVersion", "id", "name", "windup", "recovery", "cooldown", "animation"}, rel, "", {"accuracy", "alwaysHit", "components"})
            mid = MoveId(_id(d["id"], rel, "/id"))
            name = _string(d["name"], rel, "/name")
            has_accuracy, has_always = "accuracy" in d, "alwaysHit" in d
            if has_accuracy == has_always:
                _fail("accuracy-mode", rel, "", "specify exactly one of accuracy or alwaysHit")
            if has_accuracy:
                accuracy = _uint(d["accuracy"], 500, 10000, rel, "/accuracy")
                always_hit = False
            else:
                if d["alwaysHit"] is not True:
                    _fail("accuracy-mode", rel, "/alwaysHit", "alwaysHit must be true")
                accuracy, always_hit = None, True
            windup = _uint(d["windup"], 0, 600, rel, "/windup")
            recovery = _uint(d["recovery"], 30, 600, rel, "/recovery")
            cooldown = _uint(d["cooldown"], 60, 3600, rel, "/cooldown")
            animation = AssetId(_id(d["animation"], rel, "/animation"))
            if str(animation) not in assets_by_id:
                _fail("reference", rel, "/animation", "animation asset does not resolve", mid)
            components = None
            if "components" in d:
                raw_components = _array(d["components"], rel, "/components", 4)
                if not 1 <= len(raw_components) <= 4:
                    _fail("mix-components", rel, "/components", "move requires 1 to 4 components", mid)
                components = tuple(TypeId(_uint(v, 0, 9, rel, f"/components/{i}")) for i, v in enumerate(raw_components))
                _unique([str(int(v)) for v in components], rel, "/components", "component type")
            moves.append(MoveRecord(mid, name, accuracy, always_hit, windup, recovery, cooldown, animation, components))
        if len(moves) > MAX_ENTITIES:
            _fail("entity-limit", "manifest.json", "/moves", "more than 256 moves")
        _unique([str(v.id) for v in moves], "manifest.json", "/moves", "move ID")
        moves.sort(key=lambda v: str(v.id))

        mix_results: list[MixResultDescriptor] = []
        for rel in result_paths:
            d = _object(_doc(root, rel), {"schemaVersion", "id", "name", "components", "power", "windup", "recovery", "cooldown", "animation"}, rel, "", {"accuracy", "alwaysHit"})
            result_id = ResultId(_id(d["id"], rel, "/id"))
            name = _string(d["name"], rel, "/name")
            raw_components = _array(d["components"], rel, "/components", 4)
            if not 1 <= len(raw_components) <= 4:
                _fail("mix-components", rel, "/components", "result requires 1 to 4 components", result_id)
            components = tuple(TypeId(_uint(v, 0, 9, rel, f"/components/{i}")) for i, v in enumerate(raw_components))
            _unique([str(int(v)) for v in components], rel, "/components", "component type")
            power = _uint(d["power"], 1, 200, rel, "/power")
            has_accuracy, has_always = "accuracy" in d, "alwaysHit" in d
            if has_accuracy == has_always:
                _fail("accuracy-mode", rel, "", "specify exactly one of accuracy or alwaysHit", result_id)
            if has_accuracy:
                accuracy = _uint(d["accuracy"], 500, 10000, rel, "/accuracy")
                always_hit = False
            else:
                if d["alwaysHit"] is not True:
                    _fail("accuracy-mode", rel, "/alwaysHit", "alwaysHit must be true", result_id)
                accuracy, always_hit = None, True
            windup = _uint(d["windup"], 0, 600, rel, "/windup")
            recovery = _uint(d["recovery"], 30, 600, rel, "/recovery")
            cooldown = _uint(d["cooldown"], 60, 3600, rel, "/cooldown")
            animation = AssetId(_id(d["animation"], rel, "/animation"))
            if str(animation) not in assets_by_id:
                _fail("reference", rel, "/animation", "animation asset does not resolve", result_id)
            mix_results.append(MixResultDescriptor(result_id, name, components, power, accuracy, always_hit,
                                                    windup, recovery, cooldown, animation))
        if len(mix_results) > MAX_ENTITIES:
            _fail("entity-limit", "manifest.json", "/mixResults", "more than 256 mix results")
        _unique([str(v.id) for v in mix_results], "manifest.json", "/mixResults", "mix result ID")
        _unique([str(v.id) for v in moves] + [str(v.id) for v in mix_results], "manifest.json", "/mixResults", "move/result ID")
        mix_results.sort(key=lambda v: str(v.id))

        mix_recipes: list[MixRecipe] = []
        for rel in recipe_paths:
            d = _object(_doc(root, rel), {"schemaVersion", "id", "sourceA", "sourceB", "result"}, rel, "")
            recipe_id = RecipeId(_id(d["id"], rel, "/id"))
            source_a = MoveId(_id(d["sourceA"], rel, "/sourceA"))
            source_b = MoveId(_id(d["sourceB"], rel, "/sourceB"))
            result_id = ResultId(_id(d["result"], rel, "/result"))
            if source_a == source_b:
                _fail("mix-self-pair", rel, "/sourceB", "recipe sources must be distinct", recipe_id)
            if str(source_a) not in {str(v.id) for v in moves}:
                _fail("reference", rel, "/sourceA", "source move does not resolve to a registered base move", recipe_id)
            if str(source_b) not in {str(v.id) for v in moves}:
                _fail("reference", rel, "/sourceB", "source move does not resolve to a registered base move", recipe_id)
            move_by_id = {str(v.id): v for v in moves}
            for pointer, source in (("/sourceA", source_a), ("/sourceB", source_b)):
                source_record = move_by_id[str(source)]
                if source_record.components is None or len(source_record.components) != 1:
                    _fail("mix-source-components", rel, pointer, "recipe source must have exactly one declared component", recipe_id)
            if str(result_id) not in {str(v.id) for v in mix_results}:
                _fail("reference", rel, "/result", "result does not resolve to a registered mix descriptor", recipe_id)
            mix_recipes.append(MixRecipe(recipe_id, source_a, source_b, result_id))
        if len(mix_recipes) > MAX_ENTITIES:
            _fail("entity-limit", "manifest.json", "/mixRecipes", "more than 256 mix recipes")
        _unique([str(v.id) for v in mix_recipes], "manifest.json", "/mixRecipes", "mix recipe ID")
        seen_pairs: set[tuple[str, str]] = set()
        for recipe in mix_recipes:
            pair = tuple(sorted((str(recipe.source_a), str(recipe.source_b))))
            if pair in seen_pairs:
                _fail("duplicate", "manifest.json", "/mixRecipes", "duplicate unordered mix source pair", recipe.id)
            seen_pairs.add(pair)
        mix_recipes.sort(key=lambda v: str(v.id))

        catalogs: list[Catalog] = []
        species_locations: list[tuple[Species, str, int]] = []
        for rel in catalog_paths:
            d = _object(_doc(root, rel), {"schemaVersion", "id", "species"}, rel, "")
            ss: list[Species] = []
            for i, raw in enumerate(_array(d["species"], rel, "/species")):
                s = _object(raw, {"id", "name", "sprite"}, rel, f"/species/{i}")
                record = Species(SpeciesId(_id(s["id"], rel, f"/species/{i}/id")), _string(s["name"], rel, f"/species/{i}/name"), AssetId(_id(s["sprite"], rel, f"/species/{i}/sprite")))
                ss.append(record); species_locations.append((record, rel, i))
            ss.sort(key=lambda value: str(value.id))
            catalogs.append(Catalog(CatalogId(_id(d["id"], rel, "/id")), tuple(ss)))
        if len(species_locations) > MAX_ENTITIES:
            _fail("entity-limit", "manifest.json", "/catalogs", "more than 256 species")
        _unique([str(c.id) for c in catalogs], "manifest.json", "/catalogs", "catalog ID")
        _unique([str(s.id) for s, _, _ in species_locations], "manifest.json", "/catalogs", "species ID")

        encounters_loc: list[tuple[Encounter, str]] = []
        total_entries = 0
        for rel in encounter_paths:
            d = _object(_doc(root, rel), {"schemaVersion", "id", "entries"}, rel, "")
            entries: list[EncounterEntry] = []
            for i, raw in enumerate(_array(d["entries"], rel, "/entries")):
                e = _object(raw, {"species", "level"}, rel, f"/entries/{i}")
                entries.append(EncounterEntry(SpeciesId(_id(e["species"], rel, f"/entries/{i}/species")), _uint(e["level"], 0, 2**32 - 1, rel, f"/entries/{i}/level")))
            total_entries += len(entries)
            encounters_loc.append((Encounter(EncounterId(_id(d["id"], rel, "/id")), tuple(entries)), rel))
        if total_entries > MAX_TOTAL_REFS:
            _fail("reference-limit", "manifest.json", "/encounters", "more than 4096 encounter entries")
        _unique([str(e.id) for e, _ in encounters_loc], "manifest.json", "/encounters", "encounter ID")

        maps_loc: list[tuple[MapRecord, str]] = []
        total_refs = 0
        for rel in map_paths:
            d = _object(_doc(root, rel), {"schemaVersion", "id", "name", "width", "height", "encounters"}, rel, "")
            refs = tuple(EncounterId(_id(v, rel, f"/encounters/{i}")) for i, v in enumerate(_array(d["encounters"], rel, "/encounters")))
            _unique([str(v) for v in refs], rel, "/encounters", "encounter reference")
            total_refs += len(refs)
            maps_loc.append((MapRecord(MapId(_id(d["id"], rel, "/id")), _string(d["name"], rel, "/name"),
                                       _uint(d["width"], 0, 2**32 - 1, rel, "/width"), _uint(d["height"], 0, 2**32 - 1, rel, "/height"), refs), rel))
        if total_refs > MAX_TOTAL_REFS:
            _fail("reference-limit", "manifest.json", "/maps", "more than 4096 map references")
        _unique([str(v.id) for v, _ in maps_loc], "manifest.json", "/maps", "map ID")

        assets.sort(key=lambda v: str(v.id)); catalogs.sort(key=lambda v: str(v.id)); species_locations.sort(key=lambda v: str(v[0].id)); encounters_loc.sort(key=lambda v: str(v[0].id)); maps_loc.sort(key=lambda v: str(v[0].id))
        asset_index = {str(v.id): i for i, v in enumerate(assets)}
        species_index = {str(v.id): i for i, (v, _, _) in enumerate(species_locations)}
        encounter_index = {str(v.id): i for i, (v, _) in enumerate(encounters_loc)}
        map_index = {str(v.id): i for i, (v, _) in enumerate(maps_loc)}
        tokens = [1, len(assets), len(species_locations)]
        tokens += [asset_index.get(str(s.sprite), len(assets)) for s, _, _ in species_locations]
        tokens += [len(encounters_loc)]
        for encounter, _ in encounters_loc:
            tokens.append(len(encounter.entries))
            for entry in encounter.entries:
                tokens += [species_index.get(str(entry.species), len(species_locations)), entry.level]
        tokens += [len(maps_loc)]
        for map_record, _ in maps_loc:
            tokens += [map_record.width, map_record.height, len(map_record.encounters)]
            tokens += [encounter_index.get(str(ref), len(encounters_loc)) for ref in map_record.encounters]
        tokens += [map_index.get(str(project.entry_map), len(maps_loc))]
        _kernel(tokens, kernel_path or Path(__file__).resolve().parents[2] / "build/content-kernel",
                species_locations, encounters_loc, maps_loc, project)

        canonical = {"project": p, "assets": [dict(id=str(a.id), path=a.path, mediaType=a.media_type, bytes=a.bytes, sha256=a.sha256) for a in assets],
                     "catalogs": [{"schemaVersion": SCHEMA, "id": str(c.id), "species": [{"id": str(s.id), "name": s.name, "sprite": str(s.sprite)} for s in sorted(c.species, key=lambda x: str(x.id))]} for c in catalogs],
                     "encounters": [{"schemaVersion": SCHEMA, "id": str(e.id), "entries": [{"species": str(x.species), "level": x.level} for x in e.entries]} for e, _ in encounters_loc],
                     "maps": [{"schemaVersion": SCHEMA, "id": str(v.id), "name": v.name, "width": v.width, "height": v.height, "encounters": list(v.encounters)} for v, _ in maps_loc]}
        if moves:
            canonical["moves"] = [{"schemaVersion": SCHEMA, "id": str(v.id), "name": v.name,
                                    **({"alwaysHit": True} if v.always_hit else {"accuracy": v.accuracy}),
                                    "windup": v.windup, "recovery": v.recovery,
                                    "cooldown": v.cooldown, "animation": str(v.animation),
                                    **({"components": [int(x) for x in v.components]} if v.components is not None else {})}
                                   for v in moves]
        if mix_results:
            canonical["mixResults"] = [{"schemaVersion": SCHEMA, "id": str(v.id), "name": v.name,
                                        "components": [int(x) for x in v.components], "power": v.power,
                                        **({"alwaysHit": True} if v.always_hit else {"accuracy": v.accuracy}),
                                        "windup": v.windup, "recovery": v.recovery,
                                        "cooldown": v.cooldown, "animation": str(v.animation)}
                                       for v in mix_results]
        if mix_recipes:
            canonical["mixRecipes"] = [{"schemaVersion": SCHEMA, "id": str(v.id),
                                        "sourceA": sorted((str(v.source_a), str(v.source_b)))[0],
                                        "sourceB": sorted((str(v.source_a), str(v.source_b)))[1],
                                        "result": str(v.result)} for v in mix_recipes]
        canonical_bytes = json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
        return LoadedProject(project, tuple(assets), tuple(catalogs), tuple(v[0] for v in species_locations),
                             tuple(v[0] for v in encounters_loc), tuple(v[0] for v in maps_loc), tuple(moves),
                             tuple(mix_recipes), tuple(mix_results), canonical_bytes,
                             hashlib.sha256(canonical_bytes).hexdigest())
    finally:
        root.close()
