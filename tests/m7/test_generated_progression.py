"""Independent integer references for M7 progression edge fixtures."""
from __future__ import annotations

import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BEND = ROOT / "scripts" / "bend"
NODE = shutil.which("node")
FIXTURE = ROOT / "tests" / "m7" / "generated_progression.bend"


def stat_reference(base: tuple[int, ...], iv: tuple[int, ...], level: int) -> list[int]:
    scaled = [(2 * b + value) * level // 100 for b, value in zip(base, iv)]
    return [scaled[0] + level + 10, *(value + 5 for value in scaled[1:])]


def expected_vectors() -> list[int]:
    low = stat_reference((1,) * 6, (0,) * 6, 1)
    fractional = stat_reference((37, 38, 39, 40, 41, 42),
                                 (29, 28, 27, 26, 25, 24), 3)
    maximum = stat_reference((500,) * 6, (31,) * 6, 200)
    # Seven supported predicates all pass at their inclusive thresholds. The
    # second context misses every predicate, including its exact values.
    predicates = [1] * 7 + [0] * 7
    # 7*2//2 XP is added to the 101*3//2 award for each eligible participant.
    rewards = [1, 1, 1, 1]
    return low + fractional + maximum + predicates + [1] + rewards


class GeneratedProgressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not BEND.is_file() or not BEND.stat().st_mode & 0o111:
            raise unittest.SkipTest("workspace-pinned Bend wrapper is unavailable")
        if NODE is None:
            raise unittest.SkipTest("Node.js is unavailable")

    def test_generated_boundaries_and_reward_partition_match_native_and_js(self) -> None:
        expected = "[" + ", ".join(map(str, expected_vectors())) + "]\n"
        with tempfile.TemporaryDirectory(prefix="bend-m7-generated-") as temp:
            output_dir = Path(temp)
            native, javascript = output_dir / "fixture", output_dir / "fixture.js"
            for output in (native, javascript):
                compiled = subprocess.run(
                    [str(BEND), str(FIXTURE), "-o", str(output)], cwd=ROOT,
                    capture_output=True, text=True, timeout=180,
                )
                self.assertEqual(compiled.returncode, 0,
                                 compiled.stdout + compiled.stderr)
            native_run = subprocess.run([str(native)], cwd=ROOT,
                                        capture_output=True, text=True, timeout=60)
            js_run = subprocess.run([NODE, "--stack-size=8192", str(javascript)],
                                    cwd=ROOT, capture_output=True, text=True,
                                    timeout=60)
            self.assertEqual(native_run.returncode, 0, native_run.stderr)
            self.assertEqual(js_run.returncode, 0, js_run.stderr)
            self.assertEqual(native_run.stdout, expected)
            self.assertEqual(js_run.stdout, expected)


if __name__ == "__main__":
    unittest.main()
