from __future__ import annotations

import json
from dataclasses import replace
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
sys.path.insert(0, str(ROOT / "tests" / "content"))
from content.loader import ContentError, load_project
from content.world import WorldRecordError, validate_world_records
from content.m8_binding import bind_m8_content
from test_loader import make_kernel, make_project, write_json


def add_world(project_root: Path) -> None:
    manifest_path = project_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["events"] = ["data/arrival.json"]
    write_json(manifest_path, manifest)
    map_path = project_root / "data/map.json"
    map_doc = json.loads(map_path.read_text(encoding="utf-8"))
    map_doc.update({
        "navigation": {
            "vertices": [
                {"x": 0, "y": 0, "z": 0},
                {"x": 1024, "y": 0, "z": 0},
                {"x": 0, "y": 0, "z": 1024},
            ],
            "faces": [[0, 1, 2]],
            "links": [],
        },
        "npcs": [{"id": "demo:guide", "name": "Guide", "x": 10,
                  "y": 0, "z": 10, "event": "demo:arrival"}],
        "triggers": [{"id": "demo:arrival-trigger", "event": "demo:arrival",
                      "vertices": [0, 1, 2]}],
        "encounterRegions": [{"id": "demo:grass", "encounter": "demo:field",
                               "faces": [0]}],
        "transitions": [{"id": "demo:door", "targetMap": "demo:start",
                         "vertices": [0, 1, 2], "x": 0, "y": 0, "z": 0}],
    })
    write_json(map_path, map_doc)
    write_json(project_root / "data/arrival.json", {
        "schemaVersion": "content-0", "id": "demo:arrival", "entry": 20,
        "nodes": [
            {"id": 20, "op": "setValue", "key": 4, "value": 5, "next": [30]},
            {"id": 30, "op": "stop", "next": []},
        ],
    })


class M8ContentTests(unittest.TestCase):
    def setUp(self) -> None:
        import tempfile
        self.tempdir = tempfile.TemporaryDirectory()
        base = Path(self.tempdir.name)
        self.root = make_project(base / "project")
        self.kernel = make_kernel(base)
        add_world(self.root)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_world_content_loads_as_immutable_hash_bound_records(self) -> None:
        loaded = load_project(self.root, self.kernel)
        map_record = loaded.maps[0]
        self.assertEqual(map_record.navigation.faces[0].b, 1)
        self.assertEqual(str(map_record.npcs[0].event), "demo:arrival")
        self.assertEqual(map_record.encounter_regions[0].encounter, "demo:field")
        self.assertEqual(map_record.encounter_regions[0].faces, (0,))
        self.assertEqual(map_record.transitions[0].target_map, "demo:start")
        self.assertEqual(loaded.events[0].entry, 0)
        self.assertEqual(loaded.events[0].nodes[0].next, (1,))
        identity = json.loads(loaded.canonical_json)
        self.assertEqual(identity["maps"][0]["navigation"]["vertices"][1]["x"], 1024)
        self.assertEqual(identity["events"][0]["entry"], 0)

    def test_invalid_face_reference_rejects_before_kernel_binding(self) -> None:
        path = self.root / "data/map.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["navigation"]["faces"] = [[0, 1, 9]]
        write_json(path, document)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/navigation/faces/0/2")

    def test_immediate_event_cycle_rejects(self) -> None:
        path = self.root / "data/arrival.json"
        event = json.loads(path.read_text(encoding="utf-8"))
        event["nodes"][1] = {"id": 30, "op": "wait", "ticks": 1, "next": [20]}
        write_json(path, event)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "event-cycle")

    def test_missing_transition_map_rejects(self) -> None:
        path = self.root / "data/map.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["transitions"][0]["targetMap"] = "demo:missing"
        write_json(path, document)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/transitions/0/targetMap")

    def test_overlapping_encounter_face_rejects(self) -> None:
        path = self.root / "data/map.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["encounterRegions"].append({
            "id": "demo:second-grass", "encounter": "demo:field", "faces": [0]})
        write_json(path, document)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code,
                         "encounter-region-overlap")

    def test_world_geometry_participates_in_content_identity(self) -> None:
        original = load_project(self.root, self.kernel).content_hash
        path = self.root / "data/map.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["navigation"]["vertices"][1]["x"] = 2048
        write_json(path, document)
        self.assertNotEqual(original, load_project(self.root, self.kernel).content_hash)

    def test_runtime_boundary_rechecks_fabricated_typed_records(self) -> None:
        loaded = load_project(self.root, self.kernel)
        record = loaded.maps[0]
        overlap = replace(record, encounter_regions=(
            *record.encounter_regions,
            replace(record.encounter_regions[0], id="demo:overlap"),
        ))
        forged = replace(loaded, maps=(overlap,))
        with self.assertRaises(WorldRecordError):
            validate_world_records(forged)

    def test_runtime_boundary_rejects_oversized_fabricated_collections_early(self) -> None:
        loaded = load_project(self.root, self.kernel)
        record = loaded.maps[0]
        oversized = replace(record, npcs=record.npcs * 257)
        forged = replace(loaded, maps=(oversized,))
        with self.assertRaisesRegex(WorldRecordError, "collection exceeds"):
            validate_world_records(forged)

    def test_original_sample_world_is_loadable(self) -> None:
        loaded = load_project(ROOT / "examples" / "m8-world", self.kernel)
        bound = bind_m8_content(loaded, expected_ruleset_version="m8-1",
                                expected_content_digest=loaded.content_hash)
        self.assertEqual(len(loaded.maps[0].navigation.faces), 1)
        self.assertEqual(len(loaded.maps[0].npcs), 1)
        self.assertEqual(loaded.maps[0].encounter_regions[0].faces, (0,))
        self.assertEqual(loaded.events[0].nodes[-1].opcode, "stop")
        self.assertEqual(bound.entry_map_id, bound.map_ids["sample:grove"])


if __name__ == "__main__":
    unittest.main()
