"""M11 maker save and replay must agree with the packaged Bend runtime."""
from __future__ import annotations

from dataclasses import replace
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from maker.service import MakerError, MakerService
from content.m10_command_wire import Traverse
from persistence.save_identity import SaveIdentity
from persistence.m11_save import M11_SAVE_SCHEMA_VERSION
from persistence.m11_progression import decode_m11_progression
from persistence.world_state import encode_world_state
from scripts.run_m10_maker import dispatch


class M11ServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.service = MakerService(self.temporary.name,
                                    runtime_path=ROOT / "build/m10_dynamic_runtime")
        self.project_id = self.service.create_project("M11 journey")["project"]["id"]
        self.digest = self.service.validate_project(self.project_id)["contentHash"]

    def _run(self) -> dict:
        started = self.service.playtest_project(self.project_id, [1, 2, 3, 4],
                                                60, self.digest)
        self.assertTrue(started["saveAvailable"])
        return self.service.step_playtest(started["sessionId"],
                                          {"kind": "move", "x": 0, "z": -1024,
                                           "analog": False, "sprint": False}, 0)

    def test_manual_round_trip_and_replay_verification(self) -> None:
        moved = self._run()
        self.assertEqual((moved["status"], moved["acceptedCommands"],
                          moved["saveAvailable"]), ("accepted", 1, True))
        self.service.save_playtest(moved["sessionId"], "manual-01")
        identity = self.service._save_identity(
            self.service._sessions[moved["sessionId"]].snapshot)
        stored, _ = self.service._slot_store(self.project_id).load("manual-01", identity)
        self.assertEqual(stored.schema_version, M11_SAVE_SCHEMA_VERSION)
        loaded = self.service.load_playtest(self.project_id, "manual-01", self.digest)
        self.assertEqual((loaded["acceptedCommands"], loaded["sceneCsv"]),
                         (moved["acceptedCommands"], moved["sceneCsv"]))
        replay = self.service.export_replay(moved["sessionId"])
        verified = self.service.verify_project_replay(
            self.project_id, self.digest, replay["replayBase64"])
        self.assertEqual((verified["valid"], verified["acceptedCommands"]),
                         (True, 1))

    def test_corrupt_primary_recovers_previous_verified_slot(self) -> None:
        moved = self._run()
        self.service.save_playtest(moved["sessionId"], "manual-02")
        self.service.save_playtest(moved["sessionId"], "manual-02")
        path = Path(self.temporary.name) / ".saves" / self.project_id / "manual-02.json"
        path.write_bytes(b"corrupt")
        loaded = self.service.load_playtest(self.project_id, "manual-02", self.digest)
        self.assertTrue(loaded["recovered"])
        self.assertEqual(loaded["acceptedCommands"], 1)

    def test_changed_content_cannot_load_or_verify_replay(self) -> None:
        moved = self._run()
        self.service.save_playtest(moved["sessionId"], "manual-03")
        replay = self.service.export_replay(moved["sessionId"])
        with self.assertRaisesRegex(MakerError, "exact validated project"):
            self.service.load_playtest(self.project_id, "manual-03", "0" * 64)
        with self.assertRaisesRegex(MakerError, "exact validated project"):
            self.service.verify_project_replay(self.project_id, "0" * 64,
                                               replay["replayBase64"])

    def test_api_routes_use_the_same_save_and_replay_boundaries(self) -> None:
        moved = self._run()
        session = moved["sessionId"]
        saved = dispatch(self.service, "POST", f"/api/playtests/{session}/saves",
                         {"slot": "manual-04"})
        self.assertEqual(saved["slot"], "manual-04")
        replay = dispatch(self.service, "GET", f"/api/playtests/{session}/replay", None)
        verified = dispatch(self.service, "POST",
                            f"/api/projects/{self.project_id}/replays/verify",
                            {"contentHash": self.digest,
                             "replayBase64": replay["replayBase64"]})
        resumed = dispatch(self.service, "POST",
                           f"/api/projects/{self.project_id}/saves/manual-04/load",
                           {"contentHash": self.digest})
        self.assertTrue(verified["valid"])
        self.assertEqual(resumed["acceptedCommands"], 1)

    def test_autosave_failure_does_not_desynchronize_accepted_command(self) -> None:
        started = self.service.playtest_project(self.project_id, [1, 2, 3, 4],
                                                60, self.digest)
        baseline = self.service._sessions[started["sessionId"]].response
        with (patch("maker.service.run_runtime",
                    return_value=replace(baseline, accepted_commands=1)),
              patch.object(self.service, "_save_record",
                           side_effect=MakerError("save-failed", "disk unavailable"))):
            advanced = self.service.step_playtest(started["sessionId"], Traverse(1), 0)
        self.assertEqual(advanced["acceptedCommands"], 1)
        self.assertEqual(advanced["autosaveWarning"], "disk unavailable")
        self.assertEqual(len(self.service._sessions[started["sessionId"]].commands), 1)

    def test_progressed_m8_snapshot_migrates_then_continues_and_resaves(self) -> None:
        progressed = self._run()
        world = self.service._sessions[progressed["sessionId"]].response.save_snapshot
        self.assertIsNotNone(world)
        path = Path(self.temporary.name) / ".saves" / self.project_id / "manual-05.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encode_world_state(SaveIdentity(1, "m8-1", self.digest), world))
        migrated = self.service.migrate_save(self.project_id, "manual-05", self.digest, 60)
        self.assertTrue(migrated["migrated"])
        self.assertEqual(self.service._sessions[migrated["sessionId"]].response.save_snapshot,
                         world)
        continued = self.service.step_playtest(
            migrated["sessionId"],
            {"kind": "move", "x": 1024, "z": 0, "analog": False, "sprint": False}, 0)
        self.assertEqual(continued["acceptedCommands"], 1)
        self.service.save_playtest(continued["sessionId"], "manual-06")
        reloaded = self.service.load_playtest(self.project_id, "manual-06", self.digest)
        self.assertEqual(reloaded["sceneCsv"], continued["sceneCsv"])
        replay = self.service.export_replay(continued["sessionId"])
        verified = self.service.verify_project_replay(self.project_id, self.digest,
                                                      replay["replayBase64"])
        self.assertEqual(verified["acceptedCommands"], 1)

    def test_save_reload_uses_anchor_progression_not_final_progression(self) -> None:
        moved = self._run()
        record = self.service._sessions[moved["sessionId"]]
        capacity = {"party": 6, "moves": 4, "storage": 1000, "stack": 999,
                    "entries": 512, "currency": 9_999_999}
        baseline = decode_m11_progression({
            "economy": {"capacity": capacity, "tier": 0, "party": 0, "storage": 0,
                        "equippedMoves": 0, "currency": 0, "inventory": []},
            "roster": {"capacity": capacity, "party": [], "storage": []},
            "owned": [], "ledger": {"completedEncounters": []},
            "ruleset": 7, "contentIdentity": int(self.digest[:8], 16),
        })
        final = replace(baseline, ledger=replace(baseline.ledger,
                                                  completed_encounters=(17,)))
        record.restore_snapshot = replace(record.response.save_snapshot,
                                          rng_state=record.snapshot.rng_state)
        record.restore_progression = baseline
        record.response = replace(record.response, progression=final)
        self.service.save_playtest(moved["sessionId"], "manual-07")
        stored, _ = self.service._slot_store(self.project_id).load(
            "manual-07", self.service._save_identity(record.snapshot))
        self.assertEqual(stored.progression, final)
        self.assertEqual(stored.restore_progression, baseline)

        observed = {}
        def resume(_snapshot, _commands, *, executable_path, **options):
            observed.update(options)
            return record.response

        with patch("maker.service.run_runtime", side_effect=resume):
            loaded = self.service.load_playtest(self.project_id, "manual-07", self.digest)
        self.assertEqual(loaded["acceptedCommands"], len(record.commands))
        self.assertEqual(observed["restore_progression"], baseline)
        self.assertNotEqual(observed["restore_progression"], final)


if __name__ == "__main__":
    unittest.main()
