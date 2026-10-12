"""Tests for the validated frozen-snapshot boundary of M10 playtest."""
from __future__ import annotations

from pathlib import Path
import json
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from maker.playtest import (PlaytestError, PlaytestUnavailable, freeze_project,
                            prepare_runtime_wires, start_playtest)


class PlaytestBoundaryTest(unittest.TestCase):
    def test_freezes_exact_shipping_validated_snapshot_and_seed(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m8-world",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        self.assertEqual(snapshot.content_hash, __import__("hashlib").sha256(
            snapshot.canonical_json).hexdigest())
        self.assertEqual(snapshot.rng_state, (1, 2, 3, 4))
        self.assertEqual(snapshot.wait_ticks, 60)
        self.assertIsInstance(snapshot.canonical_json, bytes)

    def test_rejects_invalid_canonical_rng_or_wait_before_loading(self) -> None:
        with self.assertRaisesRegex(PlaytestError, "RNG"):
            freeze_project(ROOT / "missing-project", rng_state=(0, 0, 0, 0), wait_ticks=60)
        with self.assertRaisesRegex(PlaytestError, "Wait pacing"):
            freeze_project(ROOT / "missing-project", rng_state=(1, 2, 3, 4), wait_ticks=31)

    def test_runtime_requires_authored_start_point(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m8-world",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        with self.assertRaisesRegex(PlaytestError, "authored entryPoint"):
            prepare_runtime_wires(snapshot)

    def test_does_not_claim_fixture_executable_playtests_arbitrary_snapshot(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m8-world",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        with self.assertRaisesRegex(PlaytestUnavailable, "generic validated-content"):
            start_playtest(snapshot)

    def test_frozen_project_binds_matching_numeric_runtime_wires(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = Path(temporary) / "world"
            shutil.copytree(ROOT / "examples/m8-world", project_root)
            project_file = project_root / "project.json"
            project = json.loads(project_file.read_text(encoding="utf-8"))
            project["entryPoint"] = {"x": 1024, "y": 0, "z": 1024}
            project_file.write_text(json.dumps(project), encoding="utf-8")
            snapshot = freeze_project(project_root, rng_state=(1, 2, 3, 4),
                                      wait_ticks=60)
            wires = prepare_runtime_wires(snapshot)
            identity = int(snapshot.content_hash[:8], 16)
            for numeric in (wires.world, wires.events, wires.species,
                            wires.moves, wires.dialogue, wires.boot):
                self.assertEqual(int(numeric.split()[2]), identity)
            self.assertEqual(wires.content_hash, snapshot.content_hash)
            project["name"] = "Changed after freeze"
            project_file.write_text(json.dumps(project), encoding="utf-8")
            with self.assertRaisesRegex(PlaytestError, "changed before runtime"):
                prepare_runtime_wires(snapshot)


if __name__ == "__main__":
    unittest.main()
