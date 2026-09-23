"""Cross-target checks for the existing pure battle/RNG golden entries."""

from __future__ import annotations

import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BEND = ROOT / "scripts" / "bend"
NODE = shutil.which("node")

GOLDENS = (
    (ROOT / "tests/battle/scheduler_test.bend", "[1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/reducer_test.bend", "[1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/rng_test.bend", "[1n, 1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/combat_math_test.bend", "[1n, 1n, 1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/combat_resolver_test.bend", "[1n, 1n, 1n, 1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/roster_test.bend", "[1n, 1n, 1n, 5000n, 1000n, 9500n]\n"),
    (ROOT / "tests/battle/participants_test.bend", "[1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/sources_test.bend", "[1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/driver_test.bend", "[1n, 1n, 1n]\n"),
    (ROOT / "tests/battle/runtime_test.bend", "[1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/replay/fold_test.bend", "[1n, 1n, 1n, 1n]\n"),
    (ROOT / "tests/replay/runtime_fold_test.bend", "[1n, 1n, 1n]\n"),
)


class CrossTargetBattleGoldenTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not BEND.is_file() or not BEND.stat().st_mode & 0o111:
            raise unittest.SkipTest("workspace-pinned Bend wrapper is unavailable")
        if NODE is None:
            raise unittest.SkipTest("Node.js is unavailable for the JavaScript target")

    def test_pinned_native_and_javascript_outputs_match_exactly(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bend-replay-cross-target-") as temp:
            output_dir = Path(temp)
            for source, expected in GOLDENS:
                stem = source.stem.removesuffix("_test")
                native = output_dir / stem
                javascript = output_dir / f"{stem}.js"
                self._compile(source, native)
                self._compile(source, javascript)

                native_output = self._run((native,))
                # The combined golden entry expands many independent Bend
                # checks into one generated module; give Node enough test
                # harness stack without changing gameplay execution.
                javascript_output = self._run((NODE, "--stack-size=8192", javascript))
                self.assertEqual(native_output, expected, source.name)
                self.assertEqual(javascript_output, expected, source.name)
                self.assertEqual(native_output, javascript_output, source.name)

    @staticmethod
    def _compile(source: Path, output: Path) -> None:
        result = subprocess.run(
            [str(BEND), str(source), "-o", str(output)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            # The integrated battle runtime takes longer to compile on hosted
            # Ubuntu than on the reference workstation; compilation remains
            # bounded while the exact native/JS golden assertions stay intact.
            timeout=180,
        )
        if result.returncode:
            raise AssertionError(
                f"Bend failed for {source.name}:\n{result.stdout}{result.stderr}"
            )

    @staticmethod
    def _run(command: tuple[Path | str, ...]) -> str:
        result = subprocess.run(
            [str(part) for part in command],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=20,
        )
        if result.returncode:
            raise AssertionError(
                f"golden executable failed ({result.returncode}):\n"
                f"{result.stdout}{result.stderr}"
            )
        return result.stdout


if __name__ == "__main__":
    unittest.main()
