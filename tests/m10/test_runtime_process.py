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


if __name__ == "__main__":
    unittest.main()
