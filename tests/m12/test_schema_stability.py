from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest
import sys

ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = ROOT / "schemas/compatibility-lock.json"
sys.path.insert(0, str(ROOT / "platform"))
from content import world_limits  # noqa: E402


class SchemaStabilityTests(unittest.TestCase):
    def test_schema_identity_and_content0_invariants_match_frozen_lock(self) -> None:
        lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
        self.assertEqual(set(lock), {"lockVersion", "sourceIdentity", "schemas", "invariants"})
        self.assertEqual(lock["lockVersion"], 1)
        self.assertEqual(lock["sourceIdentity"],
                         "sha256 of the exact UTF-8 schema file bytes; updates require compatibility review")
        schema_paths = sorted(path.relative_to(ROOT / "schemas").as_posix()
                              for path in (ROOT / "schemas").rglob("*.schema.json"))
        self.assertEqual(schema_paths, sorted(lock["schemas"]))
        for relative in schema_paths:
            digest = hashlib.sha256((ROOT / "schemas" / relative).read_bytes()).hexdigest()
            self.assertRegex(lock["schemas"][relative], r"^[0-9a-f]{64}$")
            self.assertEqual(digest, lock["schemas"][relative], relative)

        invariants = lock["invariants"]
        content_root = ROOT / "schemas/content-0"
        for path in content_root.rglob("*.schema.json"):
            schema = json.loads(path.read_text(encoding="utf-8"))
            self.assertIs(schema.get("additionalProperties"), False, path.name)
            properties = schema.get("properties", {})
            if "schemaVersion" in properties:
                self.assertEqual(properties["schemaVersion"].get("const"),
                                 invariants["schemaVersion"], path.name)
        catalog = json.loads((content_root / "catalog.schema.json").read_text())
        self.assertEqual(catalog["properties"]["species"]["maxItems"],
                         invariants["catalogSpeciesMaxItems"])
        map_schema = json.loads((content_root / "map.schema.json").read_text())
        self.assertEqual({key: map_schema["properties"][key]["maxItems"]
                          for key in invariants["mapArrayCaps"]},
                         invariants["mapArrayCaps"])
        self.assertEqual(json.loads((content_root / "manifest.schema.json").read_text())["required"],
                         invariants["manifestRequired"])
        self.assertEqual(json.loads((content_root / "project.schema.json").read_text())["required"],
                         invariants["projectRequired"])
        self.assertEqual(json.loads((content_root / "map.schema.json").read_text())
                         ["$defs"]["id"]["pattern"], invariants["idPattern"])
        self.assertEqual(invariants["catalogSpeciesMaxItems"], world_limits.MAX_PER_RECORD)
        self.assertTrue(all(cap == world_limits.MAX_PER_RECORD
                            for cap in invariants["mapArrayCaps"].values()))
        engine_names = {
            "maxDepth": "MAX_DEPTH", "maxEntities": "MAX_ENTITIES",
            "maxFiles": "MAX_FILES", "maxJsonBytes": "MAX_JSON_BYTES",
            "maxPerRecord": "MAX_PER_RECORD", "maxTotalBytes": "MAX_TOTAL_BYTES",
            "maxTotalRefs": "MAX_TOTAL_REFS", "maxWireBytes": "MAX_WIRE_BYTES",
            "maxWireTokens": "MAX_WIRE_TOKENS",
        }
        self.assertEqual(
            {locked: getattr(world_limits, engine)
             for locked, engine in engine_names.items()},
            invariants["engineLimits"],
        )


if __name__ == "__main__":
    unittest.main()
