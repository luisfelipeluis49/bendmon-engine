from __future__ import annotations

import json
import hashlib
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
sys.path.insert(0, str(ROOT / "scripts"))

from content.loader import ContentError, InfrastructureError, _decode, _kernel, load_project  # noqa: E402
from content.world_limits import MAX_DEPTH, MAX_ENTITIES, MAX_FILES  # noqa: E402
from m12_corpus import write_geometry_project, write_project  # noqa: E402
from persistence.canonical_json import canonical_json  # noqa: E402


class GeneratedContentTests(unittest.TestCase):
    def test_large_geometry_map_and_vertex_dimension_overflows(self) -> None:
        with tempfile.TemporaryDirectory(prefix='m12-geometry-') as temporary:
            project = write_geometry_project(Path(temporary) / 'project')
            loaded = load_project(project, self.kernel)
            world = loaded.maps[0]
            self.assertEqual((world.width, world.height), (512, 512))
            self.assertEqual(len(world.navigation.vertices), 256)
            self.assertEqual(len(world.navigation.faces), 254)
            path = project / 'maps/glade.json'
            original = path.read_text()
            for case in ('vertices', 'width'):
                value = json.loads(original)
                if case == 'vertices':
                    value['navigation']['vertices'].append({'x': 1, 'y': 0, 'z': 1})
                else:
                    value['width'] = 513
                path.write_text(json.dumps(value))
                with self.subTest(case=case), self.assertRaises(ContentError):
                    load_project(project, self.kernel)

    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="m12-native-")
        cls.kernel = Path(cls.temp.name) / "content-kernel"
        subprocess.run([str(ROOT / "scripts/bend"), "platform/content/kernel.bend",
                        "-o", str(cls.kernel)], cwd=ROOT, check=True,
                       capture_output=True, text=True, timeout=240)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def test_seeded_malformed_raw_and_structured_corpus_rejects_cleanly(self) -> None:
        seed = 0x4D313242
        randomizer = random.Random(seed)
        mutations = ["bad-utf8", "duplicate-key", "trailing-json", "surrogate",
                     "depth", "unknown-project-field", "wrong-schema", "bad-id",
                     "missing-map", "dangling-encounter", "duplicate-species",
                     "oversized-catalog", "bad-map-width", "bad-map-graph",
                     "bad-path", "executable-field"]
        order = mutations[:]
        randomizer.shuffle(order)
        with tempfile.TemporaryDirectory(prefix="m12-fuzz-") as temp:
            root = Path(temp)
            for case in order:
                project = write_project(root / case, "small")
                if case == "bad-utf8":
                    (project / "project.json").write_bytes(b"\xff")
                elif case == "duplicate-key":
                    (project / "project.json").write_bytes(b'{"schemaVersion":"content-0","id":"a","id":"b"}')
                elif case == "trailing-json":
                    (project / "project.json").write_bytes(b'{"schemaVersion":"content-0"} true')
                elif case == "surrogate":
                    (project / "project.json").write_bytes(b'{"bad":"\\ud800"}')
                elif case == "depth":
                    (project / "project.json").write_text('{"x":' * 20 + '0' + '}' * 20)
                elif case in {"unknown-project-field", "wrong-schema", "bad-id"}:
                    value = json.loads((project / "project.json").read_text())
                    if case == "unknown-project-field": value["script"] = "run()"
                    if case == "wrong-schema": value["schemaVersion"] = "future"
                    if case == "bad-id": value["id"] = "../bad"
                    (project / "project.json").write_text(json.dumps(value))
                elif case == "missing-map":
                    (project / "maps/glade.json").unlink()
                elif case in {"dangling-encounter", "bad-map-width", "bad-map-graph"}:
                    value = json.loads((project / "maps/glade.json").read_text())
                    if case == "dangling-encounter": value["encounters"] = ["other:missing"]
                    if case == "bad-map-width": value["width"] = 0x1_0000_0000
                    if case == "bad-map-graph": value["navigation"]["faces"] = [[0, 1, 99]]
                    (project / "maps/glade.json").write_text(json.dumps(value))
                elif case in {"duplicate-species", "oversized-catalog"}:
                    value = json.loads((project / "catalogs/starter.json").read_text())
                    if case == "duplicate-species": value["species"].append(value["species"][0])
                    else: value["species"] *= 129
                    (project / "catalogs/starter.json").write_text(json.dumps(value))
                elif case == "bad-path":
                    value = json.loads((project / "manifest.json").read_text())
                    value["maps"] = ["../outside.json"]
                    (project / "manifest.json").write_text(json.dumps(value))
                else:
                    value = json.loads((project / "moves/moss-strike.json").read_text())
                    value["executable"] = "__import__('os').system('false')"
                    (project / "moves/moss-strike.json").write_text(json.dumps(value))
                with self.subTest(seed=seed, case=case), self.assertRaises(ContentError):
                    load_project(project, self.kernel)
        self.assertEqual(len(mutations), 16)

    def test_generated_lexical_parser_and_structured_project_corpora(self) -> None:
        seed = 0x4D313244
        randomizer = random.Random(seed)
        lexical_accepted = lexical_rejected = 0
        for index in range(512):
            shape = index % 8
            if shape == 0:
                raw = json.dumps({"quoted": "[{}]\\\"" + "\\" * (index % 80)}).encode()
            elif shape == 1:
                depth = MAX_DEPTH + 1 + index % 9
                raw = (b'{"x":' * depth) + b"0" + (b"}" * depth)
            elif shape == 2:
                raw = b'{"text":"' + bytes([0x80 + index % 0x70]) + b'"}'
            elif shape == 3:
                raw = b'{"text":"\\ud800"}'
            elif shape == 4:
                raw = b'{"key":1,"key":2}'
            elif shape == 5:
                raw = canonical_json({"number": randomizer.choice(
                    (-1, 0, 1, 2**31, 2**32, 2**63, 2**128))})
            elif shape == 6:
                raw = json.dumps({"brackets": "[]{}" * (index % 256),
                                  "escaped": "quote=\\\" slash=\\ backslash=" + "\\" * (index % 32)}).encode()
            else:
                raw = b'{"list":[1,2,],"n":' + str(randomizer.randrange(-2**63, 2**64)).encode() + b'}'
            try:
                value = _decode(raw, f"generated-{index}.json")
            except ContentError:
                lexical_rejected += 1
            else:
                encoded = canonical_json(value)
                self.assertEqual(json.loads(encoded), value)
                lexical_accepted += 1
        self.assertEqual(lexical_accepted + lexical_rejected, 512)
        self.assertGreater(lexical_accepted, 0)
        self.assertGreater(lexical_rejected, 0)

        structured_seed = 0x4D313245
        structured_random = random.Random(structured_seed)
        mutators = (
            "project-schema", "project-id", "project-script", "starter-level",
            "manifest-path", "manifest-script", "missing-document", "catalog-id",
            "catalog-types", "catalog-stat", "catalog-reference", "catalog-script",
            "map-width", "map-face", "map-reference", "map-script",
            "encounter-species", "encounter-level", "encounter-script",
            "move-accuracy", "move-script",
        )
        baseline_documents = {
            "project.json": json.loads((ROOT / "examples/m10-starter/project.json").read_text()),
            "manifest.json": json.loads((ROOT / "examples/m10-starter/manifest.json").read_text()),
            "catalogs/starter.json": json.loads((ROOT / "examples/m10-starter/catalogs/starter.json").read_text()),
            "maps/glade.json": json.loads((ROOT / "examples/m10-starter/maps/glade.json").read_text()),
            "encounters/glade-edge.json": json.loads((ROOT / "examples/m10-starter/encounters/glade-edge.json").read_text()),
            "moves/moss-strike.json": json.loads((ROOT / "examples/m10-starter/moves/moss-strike.json").read_text()),
        }
        accepted = rejected = 0
        with tempfile.TemporaryDirectory(prefix="m12-structured-fuzz-") as temp:
            project = write_project(Path(temp) / "project", "small")
            order = [mutators[index % len(mutators)] for index in range(512)]
            structured_random.shuffle(order)
            for index, family in enumerate(order):
                docs = json.loads(json.dumps(baseline_documents))
                document_path = "project.json"
                if family.startswith("project-"):
                    value = docs[document_path]
                    if family == "project-schema": value["schemaVersion"] = "future"
                    elif family == "project-id": value["id"] = "../bad"
                    else: value["script"] = "exec()"
                elif family == "starter-level":
                    value = docs[document_path]
                    value["starter"]["level"] = randomizer.randrange(101, 2**32)
                elif family.startswith("manifest-") or family == "missing-document":
                    document_path = "manifest.json"
                    value = docs[document_path]
                    if family == "manifest-path": value["maps"] = [f"../outside-{index}.json"]
                    elif family == "manifest-script": value["script"] = "run()"
                    else:
                        value["maps"] = [f"maps/missing-{index}.json"]
                elif family.startswith("catalog-"):
                    document_path = "catalogs/starter.json"
                    value = docs[document_path]
                    species = value["species"][0]
                    if family == "catalog-id": species["id"] = "invalid id"
                    elif family == "catalog-types": species["types"] = [10 + index]
                    elif family == "catalog-stat":
                        species["progression"]["baseStats"]["hp"] = 501 + index
                    elif family == "catalog-reference":
                        species["levelMoves"][0]["move"] = f"m12:missing-{index}"
                    else: value["script"] = "exec()"
                elif family.startswith("map-"):
                    document_path = "maps/glade.json"
                    value = docs[document_path]
                    if family == "map-width": value["width"] = 2**32 + index
                    elif family == "map-face": value["navigation"]["faces"] = [[0, 1, 99 + index]]
                    elif family == "map-reference": value["encounters"] = [f"m12:missing-{index}"]
                    else: value["script"] = "exec()"
                elif family.startswith("encounter-"):
                    document_path = "encounters/glade-edge.json"
                    value = docs[document_path]
                    if family == "encounter-species": value["entries"][0]["species"] = f"m12:missing-{index}"
                    elif family == "encounter-level": value["entries"][0]["level"] = 201 + index
                    else: value["script"] = "exec()"
                else:
                    document_path = "moves/moss-strike.json"
                    value = docs[document_path]
                    if family == "move-accuracy": value["accuracy"] = 10001 + index
                    else: value["executable"] = "exec()"

                for relative, document in docs.items():
                    (project / relative).write_text(json.dumps(document))
                if family == "missing-document":
                    # The manifest points to a unique absent file, so no file mutation is needed.
                    pass
                try:
                    loaded = load_project(project, self.kernel)
                except ContentError:
                    rejected += 1
                else:
                    self.assertEqual(hashlib.sha256(loaded.canonical_json).hexdigest(),
                                     loaded.content_hash)
                    self.assertEqual(canonical_json(json.loads(loaded.canonical_json)),
                                     loaded.canonical_json)
                    accepted += 1
        self.assertEqual(accepted + rejected, 512)
        self.assertEqual(accepted, 0)

    def test_native_kernel_rejects_bounded_malformed_wire_token_vectors(self) -> None:
        seed = 0x4D313246
        randomizer = random.Random(seed)
        with tempfile.TemporaryDirectory(prefix="m12-wire-fuzz-") as temp:
            project = write_project(Path(temp) / "project", "small")
            loaded = load_project(project, self.kernel)
            for index in range(128):
                count = index % 4
                tokens = [randomizer.randrange(0, 2**32) for _ in range(count)]
                if index % 4 == 0:
                    tokens = []
                with self.subTest(seed=seed, case=index, tokens=tokens):
                    with self.assertRaisesRegex(InfrastructureError,
                                                "content kernel rejected trusted wire input"):
                        _kernel(tokens, self.kernel, [], [], [], loaded.project)

    def test_large_cap_project_runs_through_native_kernel_and_cap_plus_one_rejects(self) -> None:
        with tempfile.TemporaryDirectory(prefix="m12-large-") as temp:
            root = Path(temp)
            project = write_project(root / "large", "large")
            loaded = load_project(project, self.kernel)
            self.assertEqual(len(loaded.species), MAX_ENTITIES)
            self.assertEqual(len(loaded.maps), 59)
            self.assertEqual(sum(len(row.npcs) for row in loaded.maps), MAX_ENTITIES)
            manifest = json.loads((project / "manifest.json").read_text())
            self.assertEqual(len(manifest["maps"]) + 4 + len(manifest["assets"]), MAX_FILES)

            catalog_path = project / "catalogs/starter.json"
            catalog = json.loads(catalog_path.read_text())
            extra = json.loads(json.dumps(catalog["species"][0]))
            extra["id"] = "m12:species-over-cap"
            catalog["species"].append(extra)
            catalog_path.write_text(json.dumps(catalog))
            with self.assertRaisesRegex(ContentError, "array exceeds 256 items"):
                load_project(project, self.kernel)

            entity_overflow = write_project(root / "entity-overflow", "large")
            map_path = entity_overflow / "maps/map-01.json"
            map_document = json.loads(map_path.read_text())
            extra_npc = {"id": "m12:npc-over-cap", "name": "Over-cap NPC",
                         "x": 2048, "y": 0, "z": 1024}
            map_document["npcs"].append(extra_npc)
            map_path.write_text(json.dumps(map_document))
            with self.assertRaisesRegex(ContentError, "more than 256 npc entities"):
                load_project(entity_overflow, self.kernel)

            file_overflow = write_project(root / "file-overflow", "large")
            overflow_manifest = json.loads((file_overflow / "manifest.json").read_text())
            overflow_manifest["maps"].append("maps/map-over-cap.json")
            (file_overflow / "manifest.json").write_text(json.dumps(overflow_manifest))
            with self.assertRaisesRegex(ContentError, "more than 64 files"):
                load_project(file_overflow, self.kernel)

    def test_canonical_identity_ignores_document_and_record_order(self) -> None:
        with tempfile.TemporaryDirectory(prefix="m12-order-") as temp:
            left = write_project(Path(temp) / "left", "small")
            right = write_project(Path(temp) / "right", "small")
            value = json.loads((right / "catalogs/starter.json").read_text())
            value["species"].reverse()
            (right / "catalogs/starter.json").write_text(json.dumps(value, indent=2))
            manifest = json.loads((right / "manifest.json").read_text())
            for key in ("catalogs", "maps", "encounters", "moves"):
                manifest[key].reverse()
            (right / "manifest.json").write_text(json.dumps(manifest, indent=2))
            first = load_project(left, self.kernel)
            second = load_project(right, self.kernel)
            self.assertEqual(first.content_hash, second.content_hash)


if __name__ == "__main__":
    unittest.main()
