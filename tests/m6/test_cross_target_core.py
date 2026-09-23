"""Native/JavaScript differential runs for production M6 runtime goldens."""

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
    (ROOT / "tests" / "m6" / "learning_test.bend",
     "[1n, 1n, 1n, 1n, 1n]\n"),
    # Exercises the production battle runtime and the M6 driver boundary:
    # terminal replay idempotence, rejected/fault preservation, enemy discovery,
    # folding multiple committed runtime events, and roster-wide terminal merge.
    (ROOT / "tests" / "m6" / "driver_test.bend",
     "[1n, 1n, 1n, 1n, 1n, 1n, 1n, 1n]\n"),
    # Exercises the full queued mixed-command cancellation and fizzle paths.
    (ROOT / "tests" / "m6" / "queued_mix_edges_test.bend",
     "[1n, 1n, 1n]\n"),
    # Production runtime cancellation and invalid-target fizzle transitions.
    (ROOT / "tests" / "m6" / "runtime_edges_test.bend",
     "[1n, 1n]\n"),
    # A terminal same-action KO keeps its witness; blocked actions earn no Harmony.
    (ROOT / "tests" / "m6" / "effect_edges_test.bend",
     "[1n, 1n]\n"),
    # The production queued mixed action is blocked by actor status, leaves
    # target HP unchanged, and earns no Harmony.
    (ROOT / "tests" / "m6" / "queued_mix_no_effect_test.bend",
     "[1n]\n"),
    # Legal chart-resolved components can all round to zero; the queued action
    # reports no damage, leaves HP unchanged, and earns no Harmony.
    (ROOT / "tests" / "m6" / "queued_zero_damage_test.bend",
     "1n\n"),
    # Full-HP source healing emits a no-effect reason and grants no Harmony.
    (ROOT / "tests" / "m6" / "full_heal_test.bend",
     "1n\n"),
    # Replays production mixed submission, execution, and terminal learning.
    (ROOT / "tests" / "m6" / "replay_test.bend",
     "[1n, 1n, 1n]\n"),
)


class M6CrossTargetCoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not BEND.is_file() or not BEND.stat().st_mode & 0o111:
            raise unittest.SkipTest("workspace-pinned Bend wrapper is unavailable")
        if NODE is None:
            raise unittest.SkipTest("Node.js is unavailable")

    def test_m6_runtime_goldens_match_native_and_javascript(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bend-m6-runtime-") as temp:
            output_dir = Path(temp)
            for source, expected in GOLDENS:
                stem = source.stem.removesuffix("_test")
                native = output_dir / stem
                javascript = output_dir / f"{stem}.js"
                for output in (native, javascript):
                    compiled = subprocess.run(
                        [str(BEND), str(source), "-o", str(output)],
                        cwd=ROOT, capture_output=True, text=True, timeout=180,
                    )
                    self.assertEqual(
                        compiled.returncode, 0,
                        f"Bend failed for {source.name}:\n"
                        f"{compiled.stdout}{compiled.stderr}",
                    )
                native_run = subprocess.run(
                    [str(native)], cwd=ROOT, capture_output=True, text=True,
                    timeout=60,
                )
                javascript_run = subprocess.run(
                    [NODE, "--stack-size=8192", str(javascript)], cwd=ROOT,
                    capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(native_run.returncode, 0, native_run.stderr)
                self.assertEqual(javascript_run.returncode, 0,
                                 javascript_run.stderr)
                self.assertEqual(native_run.stdout, expected, source.name)
                self.assertEqual(javascript_run.stdout, native_run.stdout,
                                 source.name)


if __name__ == "__main__":
    unittest.main()
