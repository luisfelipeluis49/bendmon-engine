from __future__ import annotations

import json
from dataclasses import replace
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.canonical_json import canonical_json, canonical_sha256
from persistence.m11_save import (
    MAX_M11_SAVE_BYTES, M11Save, M11SaveError, SaveExpectation,
    decode_m11_save, encode_m11_save,
    migrate_m8_v1_to_v2,
)
from persistence.m11_progression import decode_m11_progression
from persistence.save_identity import SaveIdentity
from persistence.world_state import WorldSnapshot, encode_world_state

MOVE_COMMAND = {"kind": "move", "xNegative": 0, "xMagnitude": 1,
                "zNegative": 0, "zMagnitude": 0, "analog": 0, "sprint": 0}


class M11SaveTests(unittest.TestCase):
    def setUp(self) -> None:
        self.expected = SaveExpectation("m8-1", "a" * 64, "project.demo", "catalog.main")
        self.snapshot = WorldSnapshot(
            3, -12, 2, 99, 4, 180, 100_000, 15, (1, 2, 3, 4),
            ((2, 1), (9, 42)), (7, 12),
        )
        self.save = M11Save(
            "build-11", self.expected.project_id, self.expected.catalog_id,
            self.expected.ruleset_version, self.expected.content_digest, 60,
            self.snapshot, (11, 12, 13, 14), (MOVE_COMMAND,),
        )

    def progression_state(self):
        cap = {"party": 6, "moves": 4, "storage": 1000, "stack": 999,
               "entries": 512, "currency": 9_999_999}
        return decode_m11_progression({
            "economy": {"capacity": cap, "tier": 0, "party": 0, "storage": 0,
                "equippedMoves": 0, "currency": 0, "inventory": []},
            "roster": {"capacity": cap, "party": [], "storage": []},
            "owned": [], "ledger": {"completedEncounters": []},
            "ruleset": 7, "contentIdentity": int("a" * 8, 16),
        })

    def test_round_trip_is_byte_exact_and_carries_replay_context(self) -> None:
        encoded = encode_m11_save(self.save)
        decoded = decode_m11_save(encoded, self.expected)
        self.assertEqual(decoded, self.save)
        self.assertEqual(encode_m11_save(decoded), encoded)
        value = json.loads(encoded)
        self.assertEqual(value["payload"]["initialRngState"], [11, 12, 13, 14])
        self.assertEqual(value["payload"]["acceptedCommands"], [MOVE_COMMAND])

    def test_full_identity_and_integrity_mismatches_reject(self) -> None:
        encoded = encode_m11_save(self.save)
        with self.assertRaisesRegex(M11SaveError, "content identity mismatch"):
            decode_m11_save(encoded, SaveExpectation("m8-1", "b" * 64,
                                                      "project.demo", "catalog.main"))
        value = json.loads(encoded)
        value["projectId"] = "project.other"
        with self.assertRaisesRegex(M11SaveError, "projectId mismatch"):
            decode_m11_save(canonical_json(value), self.expected)
        value = json.loads(encoded)
        value["payload"]["world"]["mapId"] = 4
        with self.assertRaisesRegex(M11SaveError, "integrity digest mismatch"):
            decode_m11_save(canonical_json(value), self.expected)

    def test_rejects_noncanonical_bad_shape_wait_rng_and_active_boundary(self) -> None:
        encoded = encode_m11_save(self.save)
        with self.assertRaisesRegex(M11SaveError, "not canonical"):
            decode_m11_save(encoded + b" ", self.expected)
        for update, message in (({"waitTicks": 45}, "waitTicks"),):
            value = json.loads(encoded)
            value.update(update)
            with self.subTest(update=update), self.assertRaisesRegex(M11SaveError, message):
                decode_m11_save(canonical_json(value), self.expected)
        value = json.loads(encoded)
        value["payload"]["initialRngState"] = [0, 0, 0, 0]
        value["payloadDigest"] = canonical_sha256(value["payload"])
        with self.assertRaisesRegex(M11SaveError, "initialRngState"):
            decode_m11_save(canonical_json(value), self.expected)
        unstable = M11Save(
            "build-11", "project.demo", "catalog.main", "m8-1", "a" * 64,
            60, WorldSnapshot(3, 0, 0, 0, None, 0, 0, 0, (1, 2, 3, 4), (), (),
                              event_active=True),
        )
        with self.assertRaisesRegex(M11SaveError, "no pending encounter, event, or battle"):
            encode_m11_save(unstable)

    def test_explicit_m8_v1_migration_preserves_exact_identity_and_checkpoint(self) -> None:
        legacy = encode_world_state(SaveIdentity(1, "m8-1", "a" * 64), self.snapshot)
        migrated = migrate_m8_v1_to_v2(legacy, self.expected,
                                      engine_build="build-11", wait_ticks=120)
        self.assertEqual(migrated.snapshot, self.snapshot)
        self.assertEqual(migrated.content_digest, "a" * 64)
        self.assertEqual(migrated.ruleset_version, "m8-1")
        self.assertEqual(migrated.initial_rng_state, self.snapshot.rng_state)
        self.assertEqual(migrated.accepted_commands, ())
        self.assertEqual(migrated.restore_snapshot, self.snapshot)
        self.assertEqual(migrated.schema_version, 2)
        self.assertEqual(decode_m11_save(encode_m11_save(migrated), self.expected), migrated)

    def test_future_schema_and_oversized_command_log_reject(self) -> None:
        value = json.loads(encode_m11_save(self.save))
        value["saveSchemaVersion"] = 5
        with self.assertRaisesRegex(M11SaveError, "unsupported save schema"):
            decode_m11_save(canonical_json(value), self.expected)
        too_many = M11Save("build-11", "project.demo", "catalog.main", "m8-1",
                           "a" * 64, 60, self.snapshot,
                           accepted_commands=tuple({"n": i} for i in range(4097)))
        with self.assertRaisesRegex(M11SaveError, "at most 4096"):
            encode_m11_save(too_many)

    def test_full_command_log_fits_practical_bound_and_total_bytes_stay_capped(self) -> None:
        commands = tuple(MOVE_COMMAND for _ in range(4096))
        complete = M11Save("build-11", "project.demo", "catalog.main", "m8-1",
                           "a" * 64, 60, self.snapshot,
                           (11, 12, 13, 14), commands)
        encoded = encode_m11_save(complete)
        self.assertLess(len(encoded), MAX_M11_SAVE_BYTES)
        self.assertEqual(decode_m11_save(encoded, self.expected).accepted_commands, commands)

    def test_command_log_is_typed_at_encode_and_decode_boundaries(self) -> None:
        for malformed in (None, {"kind": "unknown"},
                          {"kind": "move", "xNegative": 0}):
            with self.subTest(malformed=malformed):
                invalid = replace(self.save, accepted_commands=(malformed,))
                with self.assertRaisesRegex(M11SaveError, "accepted command log"):
                    encode_m11_save(invalid)

                value = json.loads(encode_m11_save(replace(self.save, accepted_commands=())))
                value["payload"]["acceptedCommands"] = [malformed]
                value["payloadDigest"] = canonical_sha256(value["payload"])
                with self.assertRaisesRegex(M11SaveError, "accepted command log"):
                    decode_m11_save(canonical_json(value), self.expected)

    def test_schema_three_progression_round_trip_and_null_field(self) -> None:
        state = self.progression_state()
        save = replace(self.save, schema_version=3, progression=state)
        encoded = encode_m11_save(save)
        value = json.loads(encoded)
        self.assertEqual(value["saveSchemaVersion"], 3)
        self.assertIsInstance(value["payload"]["progression"], dict)
        decoded = decode_m11_save(encoded, self.expected)
        self.assertEqual(decoded, save)
        self.assertEqual(encode_m11_save(decoded), encoded)

        empty_v3 = replace(self.save, schema_version=3)
        empty_value = json.loads(encode_m11_save(empty_v3))
        self.assertIsNone(empty_value["payload"]["progression"])
        self.assertIsNone(decode_m11_save(encode_m11_save(empty_v3), self.expected).progression)

    def test_schema_four_preserves_distinct_restore_and_final_progression(self) -> None:
        baseline = self.progression_state()
        final = replace(baseline, ledger=replace(baseline.ledger,
                                                   completed_encounters=(17,)))
        anchored = replace(self.save, schema_version=4, initial_rng_state=self.snapshot.rng_state,
                           restore_snapshot=self.snapshot,
                           progression=final, restore_progression=baseline)
        encoded = encode_m11_save(anchored)
        decoded = decode_m11_save(encoded, self.expected)
        self.assertEqual(decoded.restore_progression, baseline)
        self.assertEqual(decoded.progression, final)
        self.assertEqual(encode_m11_save(decoded), encoded)

    def test_schema_three_rejects_corrupt_progression_and_identity_mismatches(self) -> None:
        state = self.progression_state()
        with self.assertRaisesRegex(M11SaveError, "content identity"):
            encode_m11_save(replace(self.save, schema_version=3,
                                    progression=replace(state, content_identity=7)))
        with self.assertRaisesRegex(M11SaveError, "ruleset must be 7"):
            encode_m11_save(replace(self.save, schema_version=3,
                                    progression=replace(state, ruleset=8)))

        encoded = encode_m11_save(replace(self.save, schema_version=3, progression=state))
        value = json.loads(encoded)
        value["payload"]["progression"]["ruleset"] = 8
        value["payloadDigest"] = canonical_sha256(value["payload"])
        with self.assertRaisesRegex(M11SaveError, "ruleset 7"):
            decode_m11_save(canonical_json(value), self.expected)

        value = json.loads(encoded)
        value["payload"]["progression"]["contentIdentity"] = 8
        value["payloadDigest"] = canonical_sha256(value["payload"])
        with self.assertRaisesRegex(M11SaveError, "progression content identity"):
            decode_m11_save(canonical_json(value), self.expected)

        value = json.loads(encoded)
        value["payload"]["progression"]["unexpected"] = 1
        value["payloadDigest"] = canonical_sha256(value["payload"])
        with self.assertRaisesRegex(M11SaveError, "invalid progression payload"):
            decode_m11_save(canonical_json(value), self.expected)

    def test_schema_two_remains_the_default_legacy_encoding_and_m8_migration(self) -> None:
        encoded = encode_m11_save(self.save)
        value = json.loads(encoded)
        self.assertEqual(value["saveSchemaVersion"], 2)
        self.assertNotIn("progression", value["payload"])
        self.assertEqual(decode_m11_save(encoded, self.expected).schema_version, 2)


if __name__ == "__main__":
    unittest.main()
