from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BEND = ROOT / "scripts/bend"
FIXTURES = ROOT / "tests/m12"


def compile_bend(source: Path, output: Path) -> None:
    subprocess.run([str(BEND), str(source), "-o", str(output)], cwd=ROOT,
                   check=True, capture_output=True, timeout=120)


def run_native(binary: Path, workers: int = 1) -> bytes:
    return subprocess.run([str(binary), "--threads", str(workers), "--gpu", "off"],
                          cwd=ROOT, check=True, capture_output=True,
                          timeout=120).stdout


class ParallelWorkloadTests(unittest.TestCase):
    def test_serial_parallel_order_and_native_worker_repeatability(self) -> None:
        with tempfile.TemporaryDirectory(prefix="m12-parallel-") as directory:
            temp = Path(directory)
            for suffix, count in (('', 9), ('_max', 256)):
                with self.subTest(count=count):
                    parallel = temp / f'parallel{suffix}'
                    serial = temp / f'serial{suffix}'
                    source = FIXTURES / f'parallel{suffix}_workload.bend'
                    compile_bend(source, parallel)
                    compile_bend(FIXTURES / f'serial{suffix}_workload.bend', serial)
                    expected = run_native(serial)
                    outputs = [run_native(parallel, workers) for workers in (1, 2, 4, 1)]
                    self.assertTrue(all(output == expected for output in outputs))
                    values = json.loads(expected)
                    self.assertEqual(values[0], 1)
                    self.assertEqual(len(values), 1 + 7 * count)
                    self.assertEqual(values[1::7], [1] * count)
                    javascript = temp / f'parallel{suffix}.js'
                    compile_bend(source, javascript)
                    output = subprocess.run(['node', '--stack-size=65500', str(javascript)],
                                            cwd=ROOT, check=True, capture_output=True,
                                            timeout=120).stdout
                    self.assertEqual(output, expected)

    def test_edge_cases_and_javascript_parity(self) -> None:
        with tempfile.TemporaryDirectory(prefix="m12-parallel-js-") as directory:
            temp = Path(directory)
            native = temp / "edges"
            javascript = temp / "edges.js"
            source = FIXTURES / "batch_edges.bend"
            compile_bend(source, native)
            native_output = run_native(native)
            self.assertEqual(native_output.strip(), b"[True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}]")
            compile_bend(source, javascript)
            js_run = subprocess.run(["node", "--stack-size=65500", str(javascript)],
                                    cwd=ROOT, check=True, capture_output=True, timeout=120)
            self.assertEqual(js_run.stdout, native_output)


if __name__ == "__main__":
    unittest.main()
