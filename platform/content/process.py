"""Bounded selector-based subprocess adapter for the content kernel."""
from __future__ import annotations

from dataclasses import dataclass
import os
import selectors
import signal
import subprocess
import time
from typing import BinaryIO

MAX_KERNEL_STDOUT = 64 * 1024
MAX_KERNEL_STDERR = 64 * 1024
MAX_KERNEL_TIMEOUT = 15.0
_POST_EXIT_PIPE_GRACE = 0.25


@dataclass(frozen=True, slots=True)
class ProcessResult:
    returncode: int
    stdout: bytes
    stderr: bytes


def _kill_group(process: subprocess.Popen[bytes]) -> None:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except OSError:
        try:
            process.kill()
        except OSError:
            pass


def _stop(process: subprocess.Popen[bytes]) -> None:
    _kill_group(process)
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def _read_ready(selector: selectors.BaseSelector,
                outputs: dict[str, bytearray]) -> None:
    for key, _ in selector.select(timeout=0):
        channel = key.data
        stream = key.fileobj
        output = outputs[channel]
        limit = MAX_KERNEL_STDOUT if channel == "stdout" else MAX_KERNEL_STDERR
        while True:
            try:
                chunk = os.read(stream.fileno(), min(4096, limit + 2 - len(output)))
            except BlockingIOError:
                break
            if not chunk:
                selector.unregister(stream)
                stream.close()
                break
            output.extend(chunk)
            if len(output) > limit:
                raise OSError(f"content kernel {channel} exceeded {limit} bytes")


def run_bounded(argv: list[str], *, timeout: float) -> ProcessResult:
    """Run with capped byte streams; reject overflow, timeout, or held pipes."""
    if (type(timeout) not in (int, float) or not 0 < timeout <= MAX_KERNEL_TIMEOUT
            or type(argv) is not list or not argv
            or any(type(part) is not str for part in argv)):
        raise ValueError("kernel process requires argv and timeout in (0, 15] seconds")
    process = subprocess.Popen(argv, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, close_fds=True,
        start_new_session=True)
    streams: dict[str, BinaryIO] = {}
    outputs = {"stdout": bytearray(), "stderr": bytearray()}
    selector: selectors.BaseSelector | None = None
    try:
        assert process.stdout is not None and process.stderr is not None
        streams = {"stdout": process.stdout, "stderr": process.stderr}
        selector = selectors.DefaultSelector()
        for channel, stream in streams.items():
            os.set_blocking(stream.fileno(), False)
            selector.register(stream, selectors.EVENT_READ, channel)
        deadline = time.monotonic() + float(timeout)
        exited_at: float | None = None
        while selector.get_map():
            now = time.monotonic()
            if now >= deadline:
                raise subprocess.TimeoutExpired(argv, timeout)
            _read_ready(selector, outputs)
            if not selector.get_map():
                break
            returncode = process.poll()
            if returncode is not None:
                if exited_at is None:
                    exited_at = now
                elif now - exited_at >= _POST_EXIT_PIPE_GRACE:
                    raise OSError("content kernel exited while descendants held output pipes")
            wait_for = min(0.05, deadline - now)
            if exited_at is not None:
                wait_for = min(wait_for, max(0, _POST_EXIT_PIPE_GRACE - (now - exited_at)))
            selector.select(timeout=wait_for)
        returncode = process.wait(timeout=max(0.001, deadline - time.monotonic()))
        return ProcessResult(returncode, bytes(outputs["stdout"]),
                             bytes(outputs["stderr"]))
    except BaseException:
        _stop(process)
        raise
    finally:
        if selector is not None:
            selector.close()
        for stream in streams.values():
            if not stream.closed:
                stream.close()
