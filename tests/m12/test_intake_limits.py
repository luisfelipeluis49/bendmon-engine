from __future__ import annotations

import json
import os
from pathlib import Path
import selectors
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from threading import Event
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
REAL_SELECTOR = selectors.DefaultSelector
sys.path.insert(0, str(ROOT / "platform"))
from content.loader import ContentError, _Root, _decode  # noqa: E402
from content.world_limits import MAX_TOTAL_BYTES  # noqa: E402
from content.process import run_bounded  # noqa: E402


def assert_process_stopped(test: unittest.TestCase, pid: int) -> None:
    stat_path = Path(f"/proc/{pid}/stat")
    deadline = time.monotonic() + 0.5
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        if stat_path.exists() and stat_path.read_text().split()[2] == "Z":
            return
        Event().wait(0.01)
    test.fail(f"process {pid} remained alive after adapter cleanup")


class IntakeLimitTests(unittest.TestCase):
    def test_aggregate_project_budget_accepts_ceiling_then_rejects_next_byte(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            with (project / 'full.asset').open('wb') as stream:
                stream.truncate(MAX_TOTAL_BYTES)
            (project / 'extra.asset').write_bytes(b'x')
            root = _Root(project)
            try:
                self.assertEqual(len(root.read('full.asset', MAX_TOTAL_BYTES)), MAX_TOTAL_BYTES)
                with self.assertRaises(ContentError) as caught:
                    root.read('extra.asset', 1)
                self.assertEqual(caught.exception.diagnostics[0].code, 'total-size')
                self.assertEqual(root.total, MAX_TOTAL_BYTES)
            finally:
                root.close()

    def test_oversized_source_rejects_before_read_allocation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root_path = Path(temporary)
            (root_path / "source.json").write_bytes(b" " * (1 << 20) + b"x")
            root = _Root(root_path)
            try:
                with self.assertRaises(ContentError) as caught:
                    root.read("source.json", 1 << 20)
                self.assertEqual(caught.exception.diagnostics[0].code, "file-size")
            finally:
                root.close()

    def test_huge_duplicate_key_has_bounded_actionable_diagnostic(self) -> None:
        key = "k" * 400_000
        raw = ("{" + json.dumps(key) + ":0," + json.dumps(key) + ":1}").encode()
        with self.assertRaises(ContentError) as caught:
            _decode(raw, "project.json")
        diagnostic = caught.exception.diagnostics[0]
        self.assertEqual(diagnostic.code, "json")
        self.assertIn("duplicate object key", diagnostic.message)
        self.assertLess(len(diagnostic.message), 300)

    def test_native_output_overflow_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            child = Path(temporary) / "flood.py"
            for channel in ('stdout', 'stderr'):
                child.write_text('#!/usr/bin/env python3\nimport sys\n'
                                 f"sys.{channel}.write('x' * 1000000)\n")
                child.chmod(child.stat().st_mode | stat.S_IXUSR)
                with self.subTest(channel=channel), self.assertRaisesRegex(OSError, channel):
                    run_bounded([str(child)], timeout=3)

    def test_native_timeout_terminates_hostile_child(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            child = Path(temporary) / "hang.py"
            pid_file = Path(temporary) / "pid"
            child.write_text(
                "#!/usr/bin/env python3\nimport os,time\n"
                f"open({str(pid_file)!r}, 'w').write(str(os.getpid()))\n"
                "time.sleep(30)\n")
            child.chmod(child.stat().st_mode | stat.S_IXUSR)
            with self.assertRaises(subprocess.TimeoutExpired):
                run_bounded([str(child)], timeout=0.5)
            assert_process_stopped(self, int(pid_file.read_text()))

    def test_descendant_holding_pipe_rejects_apparent_success(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            child = Path(temporary) / "parent.py"
            pid_file = Path(temporary) / "descendant.pid"
            descendant = (
                "import os,time; "
                f"open({str(pid_file)!r}, 'w').write(str(os.getpid())); "
                "time.sleep(30)")
            child.write_text(
                "#!/usr/bin/env python3\nimport subprocess,sys,time,pathlib\n"
                "print('OK', flush=True)\n"
                f"subprocess.Popen([sys.executable, '-c', {descendant!r}])\n"
                f"deadline=time.monotonic()+2\nwhile not pathlib.Path({str(pid_file)!r}).exists() and time.monotonic()<deadline: time.sleep(0.01)\n")
            child.chmod(child.stat().st_mode | stat.S_IXUSR)
            started = time.monotonic()
            with self.assertRaises(OSError):
                run_bounded([str(child)], timeout=3)
            assert_process_stopped(self, int(pid_file.read_text()))
        self.assertLess(time.monotonic() - started, 2)

    def test_selector_setup_failure_kills_started_child(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            child = Path(temporary) / "wait.py"
            pid_file = Path(temporary) / "pid"
            child.write_text(
                "#!/usr/bin/env python3\nimport os,time\n"
                f"open({str(pid_file)!r}, 'w').write(str(os.getpid()))\n"
                "time.sleep(30)\n")
            child.chmod(child.stat().st_mode | stat.S_IXUSR)

            class FailingRegistrationSelector:
                def __init__(self) -> None:
                    self.delegate = REAL_SELECTOR()

                def register(self, *_args, **_kwargs):
                    deadline = time.monotonic() + 2
                    while not pid_file.exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    raise OSError("injected selector registration failure")

                def close(self) -> None:
                    self.delegate.close()

            with patch("content.process.selectors.DefaultSelector",
                       FailingRegistrationSelector):
                with self.assertRaisesRegex(OSError, "injected selector"):
                    run_bounded([str(child)], timeout=3)
            assert_process_stopped(self, int(pid_file.read_text()))

if __name__ == "__main__":
    unittest.main()
