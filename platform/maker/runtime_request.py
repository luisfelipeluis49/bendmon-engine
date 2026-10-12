"""Exact bounded request assembly for the precompiled M10 Bend process."""
from __future__ import annotations

from dataclasses import dataclass
import re

from content.m10_command_wire import M10Command, encode_m10_commands
from .playtest import RuntimeWires

_NUMERIC_ROW = re.compile(r"(?:0|[1-9][0-9]*)(?: (?:0|[1-9][0-9]*))*\Z")
_DIGEST = re.compile(r"[0-9a-f]{64}\Z")
MAX_REQUEST_BYTES = 2 * 1024 * 1024


class RuntimeRequestError(ValueError):
    """A frozen playtest request does not match the bounded runtime protocol."""


@dataclass(frozen=True, slots=True)
class RuntimeRequest:
    content_hash: str
    command_count: int
    payload: bytes


def _checked_rows(wires: RuntimeWires) -> tuple[str, str, str, str]:
    if type(wires) is not RuntimeWires or not _DIGEST.fullmatch(wires.content_hash):
        raise RuntimeRequestError("runtime request requires an exact full content hash")
    expected = int(wires.content_hash[:8], 16)
    rows = (wires.world, wires.events, wires.species, wires.moves,
            wires.dialogue, wires.boot)
    headers = ((10, 2), (12, 1), (13, 2), (15, 3), (16, 1), (11, 2))
    for index, row in enumerate(rows):
        if type(row) is not str or not _NUMERIC_ROW.fullmatch(row):
            raise RuntimeRequestError(f"runtime wire row {index} is not canonical numeric text")
        parts = row.split(" ", 3)
        if len(parts) < 3 or int(parts[2]) != expected:
            raise RuntimeRequestError(f"runtime wire row {index} has a mismatched identity")
        if (int(parts[0]), int(parts[1])) != headers[index]:
            raise RuntimeRequestError(f"runtime wire row {index} has an unexpected header")
        if any(len(token) > 10 or int(token) > 0xFFFFFFFF
               for token in row.split(" ")):
            raise RuntimeRequestError(f"runtime wire row {index} contains a non-U32 token")
    return rows


def assemble_runtime_request(wires: RuntimeWires,
                             commands: tuple[M10Command, ...]) -> RuntimeRequest:
    """Build one exact seven-row numeric replay request with a version header."""
    rows = _checked_rows(wires)
    command_wire = encode_m10_commands(commands)
    payload = ("M10PLAY2\n" + "\n".join((*rows, command_wire.text)) +
               "\n").encode("ascii")
    if len(payload) > MAX_REQUEST_BYTES:
        raise RuntimeRequestError(
            f"runtime request exceeds {MAX_REQUEST_BYTES} bytes")
    return RuntimeRequest(wires.content_hash, len(commands), payload)
