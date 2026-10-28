"""Bounded profiling helpers for M12 corpus loading and host workloads."""
from __future__ import annotations

import cProfile
import io
import pstats
import time
import tracemalloc
from collections.abc import Callable
from dataclasses import dataclass
from typing import TypeVar

T = TypeVar("T")


@dataclass(frozen=True)
class Measurement:
    elapsed_ns: int
    peak_bytes: int
    profile: str


def measure(call: Callable[[], T]) -> tuple[T, Measurement]:
    """Run a callable once while collecting CPU profile and peak allocations."""
    profiler = cProfile.Profile()
    tracemalloc.start()
    started = time.perf_counter_ns()
    profiler.enable()
    try:
        result = call()
    finally:
        profiler.disable()
        elapsed_ns = time.perf_counter_ns() - started
        _, peak_bytes = tracemalloc.get_traced_memory()
        tracemalloc.stop()
    report = io.StringIO()
    pstats.Stats(profiler, stream=report).sort_stats("cumulative").print_stats(20)
    return result, Measurement(elapsed_ns, peak_bytes, report.getvalue())
