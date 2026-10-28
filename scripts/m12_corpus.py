"""Deterministic Content-0 corpus generator used by M12 tests and profiling."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "examples/m10-starter"


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True,
                               separators=(",", ":")) + "\n", encoding="utf-8")


def write_project(root: Path, scale: str) -> Path:
    """Write a self-contained generated project; ``scale`` is ``small`` or ``large``.

    Example: ``write_project(Path('/tmp/corpus'), 'large')``.
    Large reaches the catalog, global NPC, and manifest file ceilings while
    staying within the current total file budget.
    """
    if scale not in {"small", "large"}:
        raise ValueError("scale must be 'small' or 'large'")
    target = Path(root)
    if target.exists():
        if not target.is_dir() or any(target.iterdir()):
            raise ValueError(f"project target must be empty: {target}")
    else:
        target.mkdir(parents=True)
    for rel in ("project.json", "manifest.json", "catalogs/starter.json",
                "encounters/glade-edge.json", "moves/moss-strike.json",
                "dialogues/welcome.json", "assets/mosskip.ppm"):
        destination = target / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE / rel, destination)

    manifest = json.loads((target / "manifest.json").read_text())
    catalog = json.loads((target / "catalogs/starter.json").read_text())
    map_source = json.loads((SOURCE / "maps/glade.json").read_text())
    if scale == "small":
        catalog["species"] = catalog["species"][:2]
        maps = [map_source]
    else:
        exemplar = catalog["species"][0]
        catalog["species"] = []
        for index in range(256):
            row = json.loads(json.dumps(exemplar))
            row["id"] = f"m12:species-{index:03d}"
            row["name"] = f"Generated species {index:03d}"
            row["levelMoves"] = [{"level": 1, "move": "original:moss-strike"}]
            catalog["species"].append(row)
        encounter = json.loads((target / "encounters/glade-edge.json").read_text())
        encounter["entries"] = [{"species": row["id"], "level": 5}
                                 for row in catalog["species"]]
        _write_json(target / "encounters/glade-edge.json", encounter)
        maps = []
        for index in range(59):
            row = json.loads(json.dumps(map_source))
            row["id"] = f"m12:map-{index:02d}"
            row["name"] = f"Generated map {index:02d}"
            row["npcs"] = []
            row["encounterRegions"] = []
            maps.append(row)
        # The Content-0 global NPC cap is 256 and applies across all maps.
        maps[0]["npcs"] = [
            {"id": f"m12:npc-{index:03d}", "name": f"NPC {index:03d}",
             "x": 2048, "y": 0, "z": 1024}
            for index in range(256)
        ]
        project_doc = json.loads((target / "project.json").read_text())
        project_doc["entryMap"] = "m12:map-00"
        project_doc["starter"]["species"] = "m12:species-000"
        _write_json(target / "project.json", project_doc)
        manifest["maps"] = [f"maps/map-{index:02d}.json" for index in range(59)]
        for index, row in enumerate(maps):
            _write_json(target / manifest["maps"][index], row)
    _write_json(target / "catalogs/starter.json", catalog)
    if scale == "small":
        manifest["maps"] = ["maps/glade.json"]
        _write_json(target / "maps/glade.json", maps[0])
    _write_json(target / "manifest.json", manifest)
    return target


def write_learning_project(root: Path) -> Path:
    """Write a bounded project with 4096 learning references for profiling."""
    target = Path(root)
    write_project(target, "small")
    manifest = json.loads((target / "manifest.json").read_text())
    manifest["moves"] = []
    move_template = json.loads((target / "moves/moss-strike.json").read_text())
    for move_index in range(32):
        move_id = f"m12:move-{move_index:02d}"
        rel = f"moves/move-{move_index:02d}.json"
        row = json.loads(json.dumps(move_template))
        row["id"] = move_id
        row["name"] = f"Generated move {move_index:02d}"
        _write_json(target / rel, row)
        manifest["moves"].append(rel)
    (target / "moves/moss-strike.json").unlink()
    catalog_path = target / "catalogs/starter.json"
    catalog = json.loads(catalog_path.read_text())
    catalog["species"] = []
    species_template = json.loads((ROOT / "examples/m10-starter/catalogs/starter.json").read_text())["species"][0]
    for species_index in range(256):
        row = json.loads(json.dumps(species_template))
        row["id"] = f"m12:species-{species_index:03d}"
        row["name"] = f"Generated species {species_index:03d}"
        row["levelMoves"] = [
            {"level": level + 1, "move": f"m12:move-{level % 32:02d}"}
            for level in range(16)
        ]
        catalog["species"].append(row)
    _write_json(catalog_path, catalog)
    project_doc = json.loads((target / "project.json").read_text())
    project_doc["entryMap"] = "original:glade"
    project_doc["starter"]["species"] = "m12:species-000"
    _write_json(target / "project.json", project_doc)
    encounter_path = target / "encounters/glade-edge.json"
    encounter = json.loads(encounter_path.read_text())
    encounter["entries"] = [{"species": "m12:species-000", "level": 5}]
    _write_json(encounter_path, encounter)
    _write_json(target / "manifest.json", manifest)
    return target


def write_geometry_project(root: Path) -> Path:
    """Write a 512×512 map with 256 vertices and 254 nonoverlapping faces."""
    target = write_project(root, 'small')
    path = target / 'maps/glade.json'
    world = json.loads(path.read_text())
    vertices = [{'x': column * 4096, 'y': 0, 'z': z}
                for column in range(128) for z in (0, 512 * 1024)]
    faces = [face for column in range(127)
             for face in ([2 * column, 2 * column + 2, 2 * column + 1],
                          [2 * column + 2, 2 * column + 3, 2 * column + 1])]
    world.update(width=512, height=512,
                 navigation={'vertices': vertices, 'faces': faces, 'links': []})
    _write_json(path, world)
    return target


def project_digest(path: Path) -> str:
    digest = hashlib.sha256()
    for file in sorted(item for item in path.rglob("*") if item.is_file()):
        digest.update(file.relative_to(path).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(file.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()
