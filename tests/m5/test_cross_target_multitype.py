"""Pinned native/JavaScript differential execution for the M5 Bend golden."""

from __future__ import annotations

import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BEND = ROOT / "scripts" / "bend"
NODE = shutil.which("node")
SOURCE = ROOT / "tests" / "m5" / "multi_type_test.bend"


class M5CrossTargetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not BEND.is_file() or not BEND.stat().st_mode & 0o111:
            raise unittest.SkipTest("workspace-pinned Bend wrapper is unavailable")
        if NODE is None:
            raise unittest.SkipTest("Node.js is unavailable")

    def test_native_and_javascript_outputs_match(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bend-m5-cross-target-") as temp:
            native = Path(temp) / "multi_type"
            javascript = Path(temp) / "multi_type.js"
            for output in (native, javascript):
                result = subprocess.run(
                    [str(BEND), str(SOURCE), "-o", str(output)],
                    cwd=ROOT, capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            native_result = subprocess.run([str(native)], cwd=ROOT, capture_output=True, text=True, timeout=20)
            js_result = subprocess.run([NODE, "--stack-size=8192", str(javascript)], cwd=ROOT, capture_output=True, text=True, timeout=20)
            self.assertEqual(native_result.returncode, 0, native_result.stderr)
            self.assertEqual(js_result.returncode, 0, js_result.stderr)
            self.assertEqual(native_result.stdout, "[1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n]\n")
            self.assertEqual(js_result.stdout, native_result.stdout)


if __name__ == "__main__":
    unittest.main()
