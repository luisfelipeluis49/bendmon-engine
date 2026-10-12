"""Run one bounded request through an explicitly configured Bend binary."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from threading import Event, Thread
from typing import Protocol

from .playtest import (FrozenPlaytestSnapshot, PlaytestError,
                       PlaytestUnavailable, prepare_runtime_wires)
from content.m10_command_wire import M10Command, M10CommandWireError
from .runtime_request import RuntimeRequestError, assemble_runtime_request
from .runtime_response import (MAX_RESPONSE_BYTES, RuntimeResponse,
                               RuntimeResponseError, parse_runtime_response)

MAX_STDERR_BYTES = 4096
DEFAULT_TIMEOUT_SECONDS = 10.0
MAX_TIMEOUT_SECONDS = 60.0
_ROOT = Path(__file__).resolve().parents[2]


class RuntimeProcessError(PlaytestError):
    """The configured M10 process could not return a valid bounded result."""


class ProcessRunner(Protocol):
    def __call__(self, argv: list[str], *, timeout: float) -> subprocess.CompletedProcess[bytes]:
        """Run one process and return bounded byte streams and its exit code."""


@dataclass(frozen=True, slots=True)
class _ProcessResult:
    returncode: int
    stdout: bytes
    stderr: bytes


def _drain(stream, limit: int, output: bytearray, exceeded: Event,
           process: subprocess.Popen[bytes]) -> None:
    while True:
        chunk = stream.read(4096)
        if not chunk:
            return
        remaining = limit - len(output)
        if len(chunk) > remaining:
            if remaining > 0:
                output.extend(chunk[:remaining])
            exceeded.set()
            try:
                process.kill()
            except OSError:
                pass
            continue
        output.extend(chunk)


def _run_bounded(argv: list[str], *, timeout: float) -> _ProcessResult:
    process = subprocess.Popen(argv, cwd=_ROOT,
        env={"PATH": os.defpath, "LANG": "C", "LC_ALL": "C"},
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        close_fds=True)
    stdout, stderr = bytearray(), bytearray()
    stdout_overflow, stderr_overflow = Event(), Event()
    out_thread = Thread(target=_drain,
        args=(process.stdout, MAX_RESPONSE_BYTES, stdout, stdout_overflow, process),
        daemon=True)
    err_thread = Thread(target=_drain,
        args=(process.stderr, MAX_STDERR_BYTES, stderr, stderr_overflow, process),
        daemon=True)
    out_thread.start()
    err_thread.start()
    try:
        returncode = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        process.kill()
        process.wait()
        raise RuntimeProcessError("configured M10 runtime exceeded its timeout") from exc
    finally:
        out_thread.join()
        err_thread.join()
        process.stdout.close()
        process.stderr.close()
    if stdout_overflow.is_set() or stderr_overflow.is_set():
        raise RuntimeProcessError("configured M10 runtime exceeded its output bound")
    return _ProcessResult(returncode, bytes(stdout), bytes(stderr))


def _configured_binary(value: str | Path) -> Path:
    if not isinstance(value, (str, Path)) or not str(value):
        raise PlaytestUnavailable("an explicit precompiled M10 runtime path is required")
    binary = Path(value).expanduser().resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise PlaytestUnavailable("configured precompiled M10 runtime is not executable")
    return binary


def _checked_snapshot(snapshot: FrozenPlaytestSnapshot) -> None:
    if type(snapshot) is not FrozenPlaytestSnapshot:
        raise PlaytestError("runtime requires a frozen playtest snapshot")
    if (type(snapshot.canonical_json) is not bytes or
            hashlib.sha256(snapshot.canonical_json).hexdigest() != snapshot.content_hash):
        raise PlaytestError("frozen snapshot content hash does not match its canonical bytes")


def run_runtime(snapshot: FrozenPlaytestSnapshot,
                commands: tuple[M10Command, ...], *, executable_path: str | Path,
                timeout: float = DEFAULT_TIMEOUT_SECONDS,
                process_runner: ProcessRunner = _run_bounded) -> RuntimeResponse:
    """Run one frozen command log through an installed precompiled runtime.

    The creator path never compiles or discovers a fixture executable. The
    caller must choose the actual M10 binary explicitly.
    """
    _checked_snapshot(snapshot)
    if (type(timeout) not in (int, float) or not 0 < timeout <= MAX_TIMEOUT_SECONDS):
        raise RuntimeProcessError("runtime timeout must be in (0, 60] seconds")
    binary = _configured_binary(executable_path)
    wires = prepare_runtime_wires(snapshot)
    try:
        request = assemble_runtime_request(wires, commands)
    except (RuntimeRequestError, M10CommandWireError) as exc:
        raise RuntimeProcessError(f"frozen M10 runtime request is invalid: {exc}") from exc
    if request.content_hash != snapshot.content_hash:
        raise RuntimeProcessError("runtime request full content hash mismatches the snapshot")
    with tempfile.TemporaryDirectory(prefix="m10-runtime-request-") as temporary:
        request_path = Path(temporary) / "request.txt"
        request_path.write_bytes(request.payload)
        try:
            result = process_runner([str(binary), str(request_path)], timeout=float(timeout))
        except subprocess.TimeoutExpired as exc:
            raise RuntimeProcessError("configured M10 runtime exceeded its timeout") from exc
        except OSError as exc:
            raise PlaytestUnavailable("configured precompiled M10 runtime could not start") from exc
        if (not hasattr(result, "returncode") or not hasattr(result, "stdout")
                or not hasattr(result, "stderr")):
            raise RuntimeProcessError("M10 process runner returned an invalid result")
        if type(result.stdout) is not bytes or type(result.stderr) is not bytes:
            raise RuntimeProcessError("M10 process runner must return byte streams")
        if len(result.stdout) > MAX_RESPONSE_BYTES or len(result.stderr) > MAX_STDERR_BYTES:
            raise RuntimeProcessError("configured M10 runtime exceeded its output bound")
        if result.returncode != 0 or result.stderr:
            raise RuntimeProcessError("configured M10 runtime failed")
        try:
            output = result.stdout.decode("ascii", errors="strict")
            response = parse_runtime_response(output,
                expected_content_hash=snapshot.content_hash,
                expected_commands=request.command_count)
        except (UnicodeDecodeError, RuntimeResponseError) as exc:
            raise RuntimeProcessError(f"configured M10 runtime returned invalid output: {exc}") from exc
        if response.content_hash != snapshot.content_hash:
            raise RuntimeProcessError("runtime response full content hash mismatches the snapshot")
        return response
