"""Deterministic SHA-256 checkpoints for an accepted replay prefix.

This is mechanical persistence plumbing. It does not validate commands,
advance a reducer, interpret identities, or write replay files.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

from .canonical_json import canonical_json_sha256

CHECKPOINT_INTERVAL = 1024


class ReplayCheckpointError(ValueError):
    """Raised when checkpoint inputs or intervals are malformed."""


@dataclass(frozen=True, slots=True)
class ReplayCheckpoint:
    """Digest of the initial state and the accepted command prefix."""

    command_count: int
    digest: str


def _count(value: Any, label: str) -> int:
    if type(value) is not int or value < 0:
        raise ReplayCheckpointError(f"{label} must be a non-negative integer")
    return value


def checkpoint_counts(command_count: int, *, terminal: bool = False) -> tuple[int, ...]:
    """Return required checkpoint positions for an accepted command count."""
    total = _count(command_count, "command_count")
    if type(terminal) is not bool:
        raise ReplayCheckpointError("terminal must be a boolean")
    counts = list(range(CHECKPOINT_INTERVAL, total + 1, CHECKPOINT_INTERVAL))
    if terminal and (not counts or counts[-1] != total):
        counts.append(total)
    return tuple(counts)


def validate_checkpoint_counts(
    counts: Iterable[int], command_count: int, *, terminal: bool = False
) -> tuple[int, ...]:
    """Validate supplied checkpoint positions against the fixed 1024 interval."""
    expected = checkpoint_counts(command_count, terminal=terminal)
    try:
        actual = tuple(counts)
    except TypeError as exc:
        raise ReplayCheckpointError("checkpoint counts must be iterable") from exc
    if actual != expected:
        raise ReplayCheckpointError(
            f"malformed checkpoint intervals: expected {expected}, got {actual}"
        )
    return actual


def checkpoint_digest(initial_state: Any, accepted_commands: Any) -> str:
    """Hash one canonical replay envelope for an initial state and command log."""
    return canonical_json_sha256(
        {"acceptedCommands": accepted_commands, "initialState": initial_state}
    )


def replay_checkpoints(
    initial_state: Any,
    accepted_commands: Iterable[Any],
    *,
    terminal: bool = False,
) -> tuple[ReplayCheckpoint, ...]:
    """Return fixed interval digests, plus the terminal digest when requested.

    The command iterable is materialized once so checkpoint prefixes are stable
    even when the caller supplied a generator. Commands are treated as already
    accepted records; this function does not infer or alter their semantics.
    """
    try:
        commands = list(accepted_commands)
    except TypeError as exc:
        raise ReplayCheckpointError("accepted_commands must be iterable") from exc
    counts = checkpoint_counts(len(commands), terminal=terminal)
    return tuple(
        ReplayCheckpoint(count, checkpoint_digest(initial_state, commands[:count]))
        for count in counts
    )
