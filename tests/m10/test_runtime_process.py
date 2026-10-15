"""Host process contract with a named fake runner; no binary is compiled here."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_command_wire import Activate
from maker.playtest import PlaytestUnavailable, freeze_project
from maker.runtime_process import RuntimeProcessError, run_runtime
from maker.runtime_request import RuntimeWires
from maker.runtime_response import MAX_RESPONSE_BYTES
from persistence.world_state import WorldSnapshot
from persistence.m11_progression import decode_m11_progression, encode_m11_progression_tokens


class FakeProcessRunner:
    def __init__(self, stdout: bytes, *, returncode: int = 0,
                 stderr: bytes = b"") -> None:
        self.stdout = stdout
        self.returncode = returncode
        self.stderr = stderr
        self.argv: list[str] | None = None
        self.request: bytes | None = None

    def __call__(self, argv: list[str], *, timeout: float):
        self.argv = argv
        self.request = Path(argv[1]).read_bytes()
        self.timeout = timeout
        return subprocess.CompletedProcess(argv, self.returncode,
                                           self.stdout, self.stderr)


class RuntimeProcessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="m10-runtime-process-")
        cls.root = Path(cls.temp.name)
        cls.binary = cls.root / "m10-runtime"
        cls.binary.write_bytes(b"precompiled-test-runtime")
        cls.binary.chmod(0o755)
        project_root = cls.root / "project"
        shutil.copytree(ROOT / "examples/m8-world", project_root)
        project_file = project_root / "project.json"
        project = json.loads(project_file.read_text(encoding="utf-8"))
        project["entryPoint"] = {"x": 1024, "y": 0, "z": 1024}
        project_file.write_text(json.dumps(project), encoding="utf-8")
        cls.snapshot = freeze_project(project_root, rng_state=(1, 2, 3, 4),
                                      wait_ticks=60)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def response(self, identity: int, commands: int = 1) -> bytes:
        scene = f"1,{identity},1," + ",".join(["0"] * 15)
        return (f"M10PLAY2 ACCEPTED\nIDENTITY {identity}\n"
                f"COMMANDS {commands}\nDIALOGUE 0 0 1\nSCENE {scene}\nCUES 1,0\n").encode("ascii")

    def run_with(self, runner: FakeProcessRunner):
        return run_runtime(self.snapshot, (Activate(3),),
                           executable_path=self.binary,
                           process_runner=runner)

    def save_row(self, identity: int, world: WorldSnapshot) -> str:
        coordinates = tuple(token for value in (world.x, world.y, world.z)
                            for token in ((1 if value < 0 else 0), abs(value)))
        values = (identity, world.map_id, *coordinates, world.region_id or 0,
                  world.weighted_distance, world.encounter_threshold,
                  world.safe_distance, *world.rng_state,
                  len(world.persistent_values),
                  *(token for pair in world.persistent_values for token in pair),
                  len(world.persistent_entities), *world.persistent_entities)
        return "SAVE 1," + ",".join(map(str, values))

    def accepted_response(self, identity: int, commands: int,
                          world: WorldSnapshot | None = None) -> bytes:
        output = self.response(identity, commands).decode("ascii")
        if world is not None:
            output += self.save_row(identity, world) + "\n"
        return output.encode("ascii")

    def test_runs_explicit_binary_and_parses_typed_response(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        runner = FakeProcessRunner(self.response(identity))
        response = self.run_with(runner)
        self.assertEqual((response.status, response.content_hash,
                          response.accepted_commands),
                         ("accepted", self.snapshot.content_hash, 1))
        self.assertEqual(response.scene.content_identity, identity)
        self.assertEqual(runner.argv[0], str(self.binary.resolve()))
        self.assertEqual(runner.request.splitlines()[0], b"M10PLAY2")
        self.assertEqual(runner.request.count(b"\n"), 8)
        self.assertEqual(runner.timeout, 10.0)
        self.assertFalse(Path(runner.argv[1]).exists())

    def test_rejects_full_hash_mismatch_even_when_compact_identity_matches(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        forged_hash = self.snapshot.content_hash[:8] + "f" * 56
        forged = RuntimeWires(forged_hash,
            f"10 2 {identity} 1 1", f"12 1 {identity} 0 0",
            f"13 2 {identity} 1 0", f"15 3 {identity} 0",
            f"16 1 {identity} 0 0", f"11 2 {identity} 1")
        runner = FakeProcessRunner(self.response(identity))
        with patch("maker.runtime_process.prepare_runtime_wires", return_value=forged):
            with self.assertRaisesRegex(RuntimeProcessError, "full content hash"):
                self.run_with(runner)
        self.assertIsNone(runner.argv)

    def test_rejects_nonzero_exit_stderr_and_oversized_stdout(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        for runner in (FakeProcessRunner(self.response(identity), returncode=1),
                       FakeProcessRunner(self.response(identity), stderr=b"diagnostic"),
                       FakeProcessRunner(b"x" * (MAX_RESPONSE_BYTES + 1))):
            with self.subTest(runner=runner), self.assertRaises(RuntimeProcessError):
                self.run_with(runner)

    def test_requires_explicit_executable_and_bounds_timeout(self) -> None:
        with self.assertRaisesRegex(PlaytestUnavailable, "explicit precompiled"):
            run_runtime(self.snapshot, (), executable_path="",
                        process_runner=FakeProcessRunner(b""))
        with self.assertRaisesRegex(RuntimeProcessError, "timeout"):
            run_runtime(self.snapshot, (), executable_path=self.binary,
                        timeout=61, process_runner=FakeProcessRunner(b""))

    def test_restore_row_is_appended_after_commands_and_receipted(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        restored = WorldSnapshot(1, -12, 0, 23, None, 0, 0, 0,
                                 (9, 8, 7, 6), ((7, 8),), (4,))
        advanced = WorldSnapshot(1, -11, 0, 23, None, 0, 0, 0,
                                 (9, 8, 7, 6), ((7, 9),), (4,))
        runner = FakeProcessRunner(self.accepted_response(identity, 1, advanced))
        result = run_runtime(self.snapshot, (Activate(3),),
                             executable_path=self.binary, process_runner=runner,
                             restore_snapshot=restored)
        self.assertEqual(result.save_snapshot, advanced)
        rows = runner.request.decode("ascii").splitlines()
        self.assertEqual(len(rows), 9)
        self.assertTrue(rows[7].startswith("14 "))
        self.assertEqual(rows[8],
            f"18 2 {identity} 1 1 12 0 0 0 23 0 0 0 0 9 8 7 6 1 7 8 1 4 0 0")

    def test_restore_row_carries_schema_three_progression_tokens(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        progression = decode_m11_progression({
            "economy": {"capacity": {"party": 6, "moves": 4, "storage": 1000,
                "stack": 999, "entries": 512, "currency": 9_999_999},
                "tier": 0, "party": 0, "storage": 0, "equippedMoves": 0,
                "currency": 0, "inventory": []},
            "roster": {"capacity": {"party": 6, "moves": 4, "storage": 1000,
                "stack": 999, "entries": 512, "currency": 9_999_999},
                "party": [], "storage": []},
            "owned": [], "ledger": {"completedEncounters": []},
            "ruleset": 7, "contentIdentity": identity,
        })
        restored = WorldSnapshot(1, 0, 0, 0, None, 0, 0, 0,
                                 (1, 2, 3, 4), ())
        runner = FakeProcessRunner(self.accepted_response(identity, 0, restored))
        run_runtime(self.snapshot, (), executable_path=self.binary,
                    process_runner=runner, restore_snapshot=restored,
                    restore_progression=progression)
        row = runner.request.decode("ascii").splitlines()[8].split()
        self.assertEqual(row[:3], ["18", "2", str(identity)])
        tokens = encode_m11_progression_tokens(progression)
        self.assertEqual(row[-len(tokens) - 2:-len(tokens)], ["1", str(len(tokens))])
        self.assertEqual(tuple(map(int, row[-len(tokens):])), tokens)

    def test_empty_command_restore_requires_exact_receipt(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        restored = WorldSnapshot(1, 0, 0, 0, None, 0, 0, 0,
                                 (1, 2, 3, 4), ())
        runner = FakeProcessRunner(self.accepted_response(identity, 0, restored))
        result = run_runtime(self.snapshot, (), executable_path=self.binary,
                             process_runner=runner, restore_snapshot=restored)
        self.assertEqual(result.save_snapshot, restored)
        wrong = WorldSnapshot(1, 1, 0, 0, None, 0, 0, 0,
                              (1, 2, 3, 4), ())
        mismatch = FakeProcessRunner(self.accepted_response(identity, 0, wrong))
        with self.assertRaisesRegex(RuntimeProcessError, "receipt does not match"):
            run_runtime(self.snapshot, (), executable_path=self.binary,
                        process_runner=mismatch, restore_snapshot=restored)

    def test_restore_rejects_old_runtime_and_unstable_snapshot(self) -> None:
        identity = int(self.snapshot.content_hash[:8], 16)
        restored = WorldSnapshot(1, 0, 0, 0, None, 0, 0, 0,
                                 (1, 2, 3, 4), ())
        old_runtime = FakeProcessRunner(b"M10PLAY2 REJECTED\n")
        with self.assertRaisesRegex(RuntimeProcessError, "rejected the M11 restore"):
            run_runtime(self.snapshot, (Activate(3),), executable_path=self.binary,
                        process_runner=old_runtime, restore_snapshot=restored)
        unstable = WorldSnapshot(1, 0, 0, 0, None, 0, 0, 0,
                                 (1, 2, 3, 4), (), event_active=True)
        runner = FakeProcessRunner(self.accepted_response(identity, 0))
        with self.assertRaisesRegex(RuntimeProcessError, "not a valid stable world"):
            run_runtime(self.snapshot, (), executable_path=self.binary,
                        process_runner=runner, restore_snapshot=unstable)
        self.assertIsNone(runner.argv)


if __name__ == "__main__":
    unittest.main()
