"""Measurement reports must reject changed outputs and malformed budgets."""
from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.profile_m12 import record_runs


class ChangingBinaryRunner:
    def __init__(self) -> None:
        self.calls = 0

    def __call__(self, path: Path, workers: int) -> tuple[int, bytes]:
        self.calls += 1
        return 100, str(self.calls).encode()


class ProfilingCLITests(unittest.TestCase):
    def test_measurement_rejects_outputs_that_change_between_samples(self) -> None:
        runner = ChangingBinaryRunner()
        with patch('scripts.profile_m12.run_binary', side_effect=runner):
            with self.assertRaisesRegex(RuntimeError, 'differs across runs'):
                record_runs(Path('unused'), 'batch', 2, 2, 'test')
        self.assertEqual(runner.calls, 2)

    def test_cli_rejects_invalid_repeat_budget_before_running_workloads(self) -> None:
        for script, repeats in (('profile_m12.py', '0'), ('profile_m12.py', '21'),
                                ('benchmark_m12_loading.py', '0')):
            command = [sys.executable, str(ROOT / 'scripts' / script), '--repeats', repeats,
                       '--output', '/tmp/m12-unused-invalid-profile.json']
            if script == 'benchmark_m12_loading.py':
                command.extend(['--label', 'invalid'])
            result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=5)
            with self.subTest(script=script, repeats=repeats):
                self.assertEqual(result.returncode, 2)
                self.assertIn(b'--repeats must be', result.stderr)


if __name__ == '__main__':
    unittest.main()
