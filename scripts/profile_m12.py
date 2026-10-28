#!/usr/bin/env python3
"""Profile generated Content-0 projects and deterministic Bend batch workloads."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PLATFORM = str(ROOT / "platform")
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if PLATFORM not in sys.path:
    sys.path.insert(0, PLATFORM)
from content.loader import load_project
from performance.profiling import measure
from scripts.m12_corpus import write_geometry_project, write_project

BEND = ROOT / "scripts/bend"
FIXTURES = ROOT / "tests/m12"


def source_identities() -> dict[str, str]:
    paths = [ROOT / relative for relative in (
        'engine/performance/parallel_workload.bend', 'engine/world/encounters.bend',
        'engine/battle/rng.bend', 'platform/content/loader.py',
        'platform/content/process.py', 'scripts/m12_corpus.py',
        'scripts/profile_m12.py', 'platform/performance/profiling.py')]
    paths.extend(FIXTURES.glob('*.bend'))
    return {path.relative_to(ROOT).as_posix(): digest(path.read_bytes())
            for path in sorted(paths)}


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def gpu_evidence() -> dict[str, Any]:
    nvidia_smi = shutil.which("nvidia-smi")
    if nvidia_smi:
        try:
            check = subprocess.run([nvidia_smi, "-L"], capture_output=True, text=True, timeout=3)
        except (OSError, subprocess.TimeoutExpired):
            return {'available': False, 'reason': 'GPU device query failed or exceeded 3 seconds'}
        if check.returncode == 0 and check.stdout.strip():
            return {"available": True, "device_query": check.stdout.strip()[:1000],
                    "benchmarked": False,
                    "reason": "Encounter batches use CPU parallel lets and have no GPU bang route"}
    if platform.system() == "Darwin":
        return {"available": False,
                "reason": "Metal device detection is unavailable in this headless profiling path"}
    return {"available": False,
            "benchmarked": False,
            "nvidia_smi": nvidia_smi,
            "cuda_toolkit_present": Path('/usr/local/cuda').exists(),
            "nvidia_control_device_present": Path('/dev/nvidiactl').exists(),
            "reason": ('nvidia-smi is unavailable; CUDA support cannot be established'
                       if nvidia_smi is None else 'NVIDIA device query found no usable device')}


def compile_fixture(source: str, output: Path) -> None:
    subprocess.run([str(BEND), str(FIXTURES / source), "-o", str(output)],
                   check=True, capture_output=True, timeout=120)


def run_binary(path: Path, workers: int) -> tuple[int, bytes]:
    started = time.perf_counter_ns()
    result = subprocess.run([str(path), "--threads", str(workers), "--gpu", "off"],
                            check=True, capture_output=True, timeout=120)
    return time.perf_counter_ns() - started, result.stdout


def record_runs(binary: Path, route: str, workers: int, repeats: int,
                scale: str, expected_digest: str | None = None) -> tuple[dict[str, Any], str]:
    samples: list[int] = []
    output_digest = expected_digest
    for _ in range(repeats):
        elapsed_ns, output = run_binary(binary, workers)
        samples.append(elapsed_ns)
        current_digest = digest(output)
        if output_digest is None:
            output_digest = current_digest
        elif current_digest != output_digest:
            raise RuntimeError(f"{route} result differs across runs/serial output for {scale}")
    assert output_digest is not None
    return ({"kind": "encounter_batch", "scale": scale, "route": route,
             "execution_route": ('serial' if route == 'serial' or scale == 'small_latency'
                                 else 'parallel'),
             "workers": workers, "elapsed_ns_samples": samples,
             "median_elapsed_ns": statistics.median(samples),
             "result_digest": output_digest}, output_digest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("m12-profile.json"))
    parser.add_argument("--repeats", type=int, default=3,
                        help="timed process repetitions per workload and worker count (1..20)")
    args = parser.parse_args()
    if not 1 <= args.repeats <= 20:
        parser.error("--repeats must be in [1, 20]")
    sources = source_identities()
    records: list[dict[str, Any]] = []
    profiles: dict[str, str] = {}
    with tempfile.TemporaryDirectory(prefix="m12-profile-") as temp_name:
        temp = Path(temp_name)
        for scale in ("small", "large", "geometry"):
            project = (write_geometry_project(temp / scale) if scale == 'geometry'
                       else write_project(temp / scale, scale=scale))
            elapsed_samples = []
            baseline_hash = None
            for _ in range(args.repeats):
                started = time.perf_counter_ns()
                loaded = load_project(project)
                elapsed_samples.append(time.perf_counter_ns() - started)
                if baseline_hash is not None and loaded.content_hash != baseline_hash:
                    raise RuntimeError(f'project identity changed across {scale} load samples')
                baseline_hash = loaded.content_hash
            loaded, measurement = measure(lambda: load_project(project))
            if loaded.content_hash != baseline_hash:
                raise RuntimeError(f'profiling changed {scale} content identity')
            records.append({"kind": "project_load", "scale": scale,
                            "elapsed_ns_samples": elapsed_samples,
                            "median_elapsed_ns": statistics.median(elapsed_samples),
                            "instrumented_elapsed_ns": measurement.elapsed_ns,
                            "instrumentation": 'cProfile and tracemalloc; excludes native child allocations',
                            "peak_bytes": measurement.peak_bytes,
                            "content_hash": loaded.content_hash})
            profiles[f"load_{scale}"] = measurement.profile

        for scale, parallel_fixture, serial_fixture in (
            ("small_latency", "profile_small_parallel.bend", "profile_small_serial.bend"),
            ("bulk_256_jobs_64_entries_x256_repeats", "profile_parallel.bend", "profile_serial.bend"),
        ):
            parallel = temp / f"{scale}-parallel"
            serial = temp / f"{scale}-serial"
            compile_fixture(parallel_fixture, parallel)
            compile_fixture(serial_fixture, serial)
            serial_record, serial_digest = record_runs(
                serial, "serial", 1, args.repeats, scale)
            records.append(serial_record)
            for workers in (1, 2, 4):
                parallel_record, _ = record_runs(
                    parallel, "batch", workers, args.repeats, scale, serial_digest)
                records.append(parallel_record)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if source_identities() != sources:
        raise RuntimeError('profile sources changed during measurement; rerun on stable sources')
    report = {"schema": "m12-profile-v1", "metadata": {
        "sources": sources,
        "python": platform.python_version(), "platform": platform.platform(),
        "processor": platform.processor(), "logical_cpus": os.cpu_count(),
        "bend": subprocess.run([str(BEND), "--version"], check=True,
                                capture_output=True, text=True).stdout.strip(),
        "gpu": gpu_evidence()}, "measurements": records, "profiles": profiles}
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
