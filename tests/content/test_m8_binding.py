from __future__ import annotations

import json
from dataclasses import replace
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
sys.path.insert(0, str(ROOT / "tests" / "content"))

from content.loader import load_project
from content.m8_binding import M8BindingError, bind_m8_content
from test_loader import make_kernel, make_project, write_json
from test_m8_content import add_world


class M8BindingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.root = make_project(base / "project")
        self.kernel = make_kernel(base)
        add_world(self.root)
        catalog_path = self.root / "data/catalog.json"
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        catalog["species"][0]["progression"] = {
            "baseStats": {"hp": 50, "attack": 51, "defense": 52,
                          "specialAttack": 53, "specialDefense": 54,
                          "speed": 55},
            "captureRate": 500, "baseXpYield": 100,
            "baseCurrencyYield": 2,
        }
        write_json(catalog_path, catalog)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_loaded_world_binds_dense_ids_and_signed_coordinates(self) -> None:
        loaded = load_project(self.root, self.kernel)
        binding = bind_m8_content(
            loaded, expected_ruleset_version="m8-1",
            expected_content_digest=loaded.content_hash,
        )
        self.assertEqual(binding.entry_map_id, 1)
        self.assertEqual(binding.maps[0].regions[0].faces, (0,))
        self.assertEqual(binding.maps[0].regions[0].encounter_id, 1)
        self.assertEqual(binding.encounters[0].id, 1)
        self.assertEqual(binding.encounters[0].entries[0].species_id, 1)
        self.assertEqual(binding.encounters[0].entries[0].weight, 1)
        self.assertEqual(binding.encounters[0].entries[0].min_level, 1)
        self.assertEqual(binding.encounters[0].entries[0].max_level, 1)
        self.assertEqual(binding.maps[0].npcs[0].event_id, 1)
        self.assertEqual(binding.maps[0].vertices[1].x.magnitude, 1024)
        self.assertFalse(binding.maps[0].vertices[1].x.negative)
        self.assertEqual(binding.events[0].nodes[0].successors, (1,))
        self.assertEqual(binding.m7.content_digest, binding.content_digest)
        self.assertEqual(binding.content_identity,
                         int(loaded.content_hash[:8], 16))

    def test_transition_ids_are_global_and_namespaced_by_source_map(self) -> None:
        map_path = self.root / "data/map.json"
        second = json.loads(map_path.read_text(encoding="utf-8"))
        second["id"] = "demo:second"
        second["name"] = "Second"
        second["npcs"][0]["id"] = "demo:second-guide"
        second["triggers"][0]["id"] = "demo:second-trigger"
        second["encounterRegions"][0]["id"] = "demo:second-grass"
        second["transitions"][0]["id"] = "demo:other-door"
        write_json(self.root / "data/second-map.json", second)
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["maps"].append("data/second-map.json")
        write_json(manifest_path, manifest)

        loaded = load_project(self.root, self.kernel)
        binding = bind_m8_content(
            loaded, expected_ruleset_version="m8-1",
            expected_content_digest=loaded.content_hash,
        )
        self.assertEqual([row.id for row in binding.maps], [1, 2])
        self.assertEqual([row.transitions[0].id for row in binding.maps], [1, 2])
        # The transitions remain in their source map after receiving global IDs.
        self.assertEqual([row.transitions[0].target_map_id for row in binding.maps],
                         [2, 2])

    def test_encounter_table_is_immutable(self) -> None:
        loaded = load_project(self.root, self.kernel)
        binding = bind_m8_content(
            loaded, expected_ruleset_version="m8-1",
            expected_content_digest=loaded.content_hash,
        )
        with self.assertRaises(AttributeError):
            binding.encounters[0].entries[0].weight = 3  # type: ignore[misc]

    def test_weighted_encounter_ranges_bind_as_authored(self) -> None:
        path = self.root / "data/encounter.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["entries"] = [{"species": "demo:fox", "weight": 23,
                                "minLevel": 7, "maxLevel": 12}]
        write_json(path, document)
        loaded = load_project(self.root, self.kernel)
        binding = bind_m8_content(
            loaded, expected_ruleset_version="m8-1",
            expected_content_digest=loaded.content_hash,
        )
        entry = binding.encounters[0].entries[0]
        self.assertEqual((entry.weight, entry.min_level, entry.max_level),
                         (23, 7, 12))

    def test_wrong_ruleset_or_digest_rejects_before_binding(self) -> None:
        loaded = load_project(self.root, self.kernel)
        with self.assertRaisesRegex(M8BindingError, "requires ruleset"):
            bind_m8_content(loaded, expected_ruleset_version="m7-1",
                            expected_content_digest=loaded.content_hash)
        with self.assertRaisesRegex(M8BindingError, "identity mismatch"):
            bind_m8_content(loaded, expected_ruleset_version="m8-1",
                            expected_content_digest="0" * 64)

    def test_navigation_change_invalidates_old_identity(self) -> None:
        old = load_project(self.root, self.kernel)
        map_path = self.root / "data/map.json"
        document = json.loads(map_path.read_text(encoding="utf-8"))
        document["navigation"]["vertices"][1]["x"] = 2048
        write_json(map_path, document)
        changed = load_project(self.root, self.kernel)
        with self.assertRaisesRegex(M8BindingError, "identity mismatch"):
            bind_m8_content(changed, expected_ruleset_version="m8-1",
                            expected_content_digest=old.content_hash)

    def test_fabricated_typed_record_cannot_bypass_world_validation(self) -> None:
        loaded = load_project(self.root, self.kernel)
        region = loaded.maps[0].encounter_regions[0]
        forged_map = replace(
            loaded.maps[0],
            encounter_regions=(replace(region, faces=(999,)),),
        )
        forged = replace(loaded, maps=(forged_map,))
        with self.assertRaises(M8BindingError):
            bind_m8_content(forged, expected_ruleset_version="m8-1",
                            expected_content_digest=loaded.content_hash)


if __name__ == "__main__":
    unittest.main()
