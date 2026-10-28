#!/usr/bin/env python3
"""Measure validated learning-heavy content loads for a trusted source revision.

Example: python3 scripts/benchmark_m12_loading.py --label optimized --output build/load.json
The optional loader source is trusted developer code, never project content.
"""
from __future__ import annotations

import argparse
import cProfile
from functools import partial
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import pstats
import statistics
import sys
import tempfile
import time
import tracemalloc
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'platform'))
from content.loader import load_project
from content.models import LoadedProject
from m12_corpus import write_learning_project


def _loader(source: Path | None) -> Callable[[Path], LoadedProject]:
    if source is None:
        return load_project
    spec = importlib.util.spec_from_file_location('content.m12_baseline', source)
    if spec is None or spec.loader is None:
        raise ValueError('trusted loader source could not be imported')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return partial(module.load_project, kernel_path=ROOT / 'build/content-kernel')


def _profile(loader: Callable[[Path], LoadedProject], project: Path) -> list[dict[str, object]]:
    profiler = cProfile.Profile()
    profiler.runcall(loader, project)
    statistics_by_function = pstats.Stats(profiler).stats
    ranked = sorted(statistics_by_function.items(), key=lambda row: row[1][3], reverse=True)
    return [{'file': file, 'line': line, 'function': function,
             'calls': stats[1], 'selfSeconds': stats[2], 'cumulativeSeconds': stats[3]}
            for (file, line, function), stats in ranked[:20]]


def measure(source: Path | None, repeats: int, label: str) -> dict[str, object]:
    """Measure actual loader calls, keeping profiling overhead outside timings."""
    loader = _loader(source)
    with tempfile.TemporaryDirectory(prefix='m12-learning-profile.') as temporary:
        project = write_learning_project(Path(temporary) / 'project')
        expected = loader(project)
        elapsed: list[float] = []
        for _ in range(repeats):
            start = time.perf_counter()
            loaded = loader(project)
            elapsed.append(time.perf_counter() - start)
            if loaded.canonical_json != expected.canonical_json:
                raise ValueError('repeated validation changed canonical content')
        tracemalloc.start()
        loader(project)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        source_file = source or ROOT / 'platform/content/loader.py'
        return {'label': label, 'python': platform.python_version(),
                'platform': platform.platform(), 'repeats': repeats,
                'loaderSha256': hashlib.sha256(source_file.read_bytes()).hexdigest(),
                'contentHash': expected.content_hash, 'species': len(expected.species),
                'moves': len(expected.moves),
                'levelMoveReferences': sum(len(row.level_moves) for row in expected.species),
                'seconds': elapsed, 'medianSeconds': statistics.median(elapsed),
                'peakTracedBytes': peak, 'profile': _profile(loader, project)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--loader-source', type=Path,
                        help='trusted historical loader source for developer comparison')
    parser.add_argument('--label', required=True)
    parser.add_argument('--repeats', type=int, default=9)
    parser.add_argument('--output', type=Path, required=True)
    options = parser.parse_args()
    if not 1 <= options.repeats <= 100:
        parser.error('--repeats must be 1..100')
    report = measure(options.loader_source, options.repeats, options.label)
    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items() if key != 'profile'}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
