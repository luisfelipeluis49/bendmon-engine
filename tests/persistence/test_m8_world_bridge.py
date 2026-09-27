from __future__ import annotations

from pathlib import Path
import json
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
sys.path.insert(0, str(ROOT / "tests" / "content"))

from content.loader import load_project
from persistence.save_identity import SaveIdentity
from persistence.world_state import WorldSnapshot, encode_world_state
from persistence.m8_world_bridge import M8WorldBridgeError, decode_m8_world_save
from test_loader import make_kernel, make_project, write_json
from test_m8_content import add_world


class M8WorldBridgeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        project = make_project(base / "project")
        self.kernel = make_kernel(base)
        add_world(project)
        catalog_path = project / "data/catalog.json"
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        catalog["species"][0]["progression"] = {
            "baseStats": {"hp": 50, "attack": 51, "defense": 52,
                          "specialAttack": 53, "specialDefense": 54,
                          "speed": 55},
            "captureRate": 500, "baseXpYield": 100, "baseCurrencyYield": 2,
        }
        write_json(catalog_path, catalog)
        self.loaded = load_project(project, self.kernel)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def snapshot(self, **changes: object) -> WorldSnapshot:
        values: dict[str, object] = {
            "map_id": 1, "x": -12, "y": 2, "z": 99, "region_id": 1,
            "weighted_distance": 180, "encounter_threshold": 100_000,
            "safe_distance": 15, "rng_state": (1, 2, 3, 4),
            "persistent_values": ((2, 1), (9, 42), (2, 0)),
            "persistent_entities": (7, 7, 12),
        }
        values.update(changes)
        return WorldSnapshot(**values)  # type: ignore[arg-type]

    def test_emits_numeric_snapshot_and_preserves_duplicate_journals(self) -> None:
        identity = SaveIdentity(1, "m8-1", self.loaded.content_hash)
        encoded = encode_world_state(identity, self.snapshot())
        result = decode_m8_world_save(encoded, self.loaded)
        self.assertTrue(result.startswith("Save.Snapshot{"))
        self.assertIn("Geometry.Coord{True{}, 12}", result)
        self.assertIn("Events.Value{2n, 1n}, Events.Value{9n, 42n}, Events.Value{2n, 0n}", result)
        self.assertIn("[7n, 7n, 12n]", result)
        self.assertNotIn("demo:", result)
        self.assertNotIn(self.loaded.content_hash, result)

    def test_rejects_save_with_different_full_content_digest(self) -> None:
        wrong_identity = SaveIdentity(1, "m8-1", "b" * 64)
        encoded = encode_world_state(wrong_identity, self.snapshot())
        with self.assertRaisesRegex(M8WorldBridgeError, "identity mismatch"):
            decode_m8_world_save(encoded, self.loaded)

    def test_rejects_digest_with_same_bend_identity_prefix(self) -> None:
        digest = self.loaded.content_hash
        replacement = "0" if digest[-1] != "0" else "1"
        wrong_identity = SaveIdentity(1, "m8-1", digest[:-1] + replacement)
        encoded = encode_world_state(wrong_identity, self.snapshot())
        with self.assertRaisesRegex(M8WorldBridgeError, "identity mismatch"):
            decode_m8_world_save(encoded, self.loaded)

    def test_rejects_unbound_numeric_map_or_region(self) -> None:
        identity = SaveIdentity(1, "m8-1", self.loaded.content_hash)
        for changes, expected in (({"map_id": 9}, "map ID"),
                                  ({"region_id": 9}, "region ID")):
            encoded = encode_world_state(identity, self.snapshot(**changes))
            with self.subTest(expected=expected), self.assertRaisesRegex(
                M8WorldBridgeError, expected
            ):
                decode_m8_world_save(encoded, self.loaded)


if __name__ == "__main__":
    unittest.main()
