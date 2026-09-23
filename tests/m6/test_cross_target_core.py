"""Native/JavaScript differential run for the production M6 learning golden."""

from __future__ import annotations

import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BEND = ROOT / "scripts" / "bend"
NODE = shutil.which("node")
SOURCE = ROOT / "tests" / "m6" / "learning_test.bend"
EXPECTED = "[1n, 1n, 1n, 1n, 1n]\n"


class M6CrossTargetCoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not BEND.is_file() or not BEND.stat().st_mode & 0o111:
            raise unittest.SkipTest("workspace-pinned Bend wrapper is unavailable")
        if NODE is None:
            raise unittest.SkipTest("Node.js is unavailable")

    def test_production_learning_golden_matches_native_and_javascript(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bend-m6-core-") as temp:
            native = Path(temp) / "learning"
            javascript = Path(temp) / "learning.js"
            for output in (native, javascript):
                compiled = subprocess.run(
                    [str(BEND), str(SOURCE), "-o", str(output)],
                    cwd=ROOT, capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(compiled.returncode, 0,
                                 compiled.stdout + compiled.stderr)
            native_run = subprocess.run(
                [str(native)], cwd=ROOT, capture_output=True, text=True,
                timeout=20,
            )
            javascript_run = subprocess.run(
                [NODE, "--stack-size=8192", str(javascript)], cwd=ROOT,
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(native_run.returncode, 0, native_run.stderr)
            self.assertEqual(javascript_run.returncode, 0,
                             javascript_run.stderr)
            self.assertEqual(native_run.stdout, EXPECTED)
            self.assertEqual(javascript_run.stdout, native_run.stdout)


if __name__ == "__main__":
    unittest.main()
