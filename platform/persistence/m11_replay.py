"""Bounded canonical command replay envelopes and authoritative verification.

This module validates persistence records only. Gameplay and command acceptance
remain owned by the injected Bend runtime.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
import re
from typing import Any, Callable

from .battle_replay import (RNG_VERSION, RULESET_VERSION,
                            SUPPORTED_REPLAY_RULESETS)
from .canonical_json import canonical_json
from .replay_checkpoints import CHECKPOINT_INTERVAL

REPLAY_SCHEMA_VERSION = 1
MAX_REPLAY_BYTES = 2 * 1024 * 1024
MAX_COMMANDS = 4096
MAX_JSON_DEPTH = 32
MAX_JSON_NODES = 100_000
_DIGEST = re.compile(r"[0-9a-f]{64}\Z")


class ReplayFileError(ValueError):
    """Raised for malformed, incompatible, or unverifiable replay data."""


def _uint(value: Any, name: str, maximum: int = 0xFFFFFFFF) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise ReplayFileError(f"{name} must be an integer in [0, {maximum}]")
    return value


def _digest(value: Any, name: str) -> str:
    if type(value) is not str or not _DIGEST.fullmatch(value):
        raise ReplayFileError(f"{name} must be lowercase SHA-256")
    return value


def _json_tree(value: Any, *, depth: int = 0, budget: list[int] | None = None) -> None:
    if budget is None:
        budget = [MAX_JSON_NODES]
    budget[0] -= 1
    if budget[0] < 0 or depth > MAX_JSON_DEPTH:
        raise ReplayFileError("JSON value exceeds replay depth or node limit")
    if value is None or type(value) in (str, int):
        if type(value) is str and any(0xD800 <= ord(ch) <= 0xDFFF for ch in value):
            raise ReplayFileError("surrogate code points are not allowed")
        return
    if type(value) is list:
        for child in value:
            _json_tree(child, depth=depth + 1, budget=budget)
        return
    if type(value) is dict:
        for key, child in value.items():
            if type(key) is not str:
                raise ReplayFileError("JSON object keys must be strings")
            _json_tree(key, depth=depth + 1, budget=budget)
            _json_tree(child, depth=depth + 1, budget=budget)
        return
    raise ReplayFileError(f"unsupported replay JSON value: {type(value).__name__}")


@dataclass(frozen=True, slots=True)
class ReplayHeader:
    ruleset_version: str
    content_digest: str
    rng_version: str
    rng_state: tuple[int, int, int, int]
    wait_ticks: int
    engine_build: str
    initial_state: Any

    def __post_init__(self) -> None:
        if type(self.ruleset_version) is not str or self.ruleset_version not in SUPPORTED_REPLAY_RULESETS:
            raise ReplayFileError(f"unsupported replay ruleset: {self.ruleset_version!r}")
        _digest(self.content_digest, "content digest")
        if self.rng_version != RNG_VERSION:
            raise ReplayFileError(f"unsupported RNG revision: {self.rng_version!r}")
        if (type(self.rng_state) is not tuple or len(self.rng_state) != 4
                or any(type(word) is not int or not 0 <= word <= 0xFFFFFFFF
                       for word in self.rng_state) or not any(self.rng_state)):
            raise ReplayFileError("RNG state must be four U32 words and not all zero")
        if type(self.wait_ticks) is not int or self.wait_ticks not in (30, 60, 120):
            raise ReplayFileError("Wait choice must be 30, 60, or 120 ticks")
        if type(self.engine_build) is not str or not self.engine_build or len(self.engine_build) > 128:
            raise ReplayFileError("engine build must contain 1–128 characters")
        if type(self.initial_state) is not dict:
            raise ReplayFileError("initial state must be a JSON object")
        _json_tree(self.initial_state)

    def canonical_value(self) -> dict[str, Any]:
        return {"contentDigest": self.content_digest, "engineBuild": self.engine_build,
                "initialState": self.initial_state,
                "rng": {"state": list(self.rng_state), "version": self.rng_version},
                "rulesetVersion": self.ruleset_version, "waitTicks": self.wait_ticks}


@dataclass(frozen=True, slots=True)
class AcceptedCommand:
    logical_tick: int
    barrier_id: int
    command_ordinal: int
    actor_id: int
    payload: dict[str, Any]

    def __post_init__(self) -> None:
        _uint(self.logical_tick, "logical tick")
        _uint(self.barrier_id, "barrier id")
        _uint(self.command_ordinal, "command ordinal")
        _uint(self.actor_id, "actor id")
        if type(self.payload) is not dict or not self.payload:
            raise ReplayFileError("command payload must be a non-empty object")
        if type(self.payload.get("kind")) is not str or not self.payload["kind"]:
            raise ReplayFileError("command payload requires a non-empty string kind")
        _json_tree(self.payload)

    def canonical_value(self) -> dict[str, Any]:
        return {"actorId": self.actor_id, "barrierId": self.barrier_id,
                "commandOrdinal": self.command_ordinal, "logicalTick": self.logical_tick,
                "payload": self.payload}


@dataclass(frozen=True, slots=True)
class ReplayCheckpoint:
    command_count: int
    state_digest: str

    def __post_init__(self) -> None:
        _uint(self.command_count, "checkpoint command count", MAX_COMMANDS)
        _digest(self.state_digest, "checkpoint state digest")

    def canonical_value(self) -> dict[str, Any]:
        return {"commandCount": self.command_count, "stateDigest": self.state_digest}


@dataclass(frozen=True, slots=True)
class ReplayFile:
    header: ReplayHeader
    commands: tuple[AcceptedCommand, ...]
    checkpoints: tuple[ReplayCheckpoint, ...] = ()
    terminal: bool = False

    def __post_init__(self) -> None:
        if type(self.commands) is not tuple or len(self.commands) > MAX_COMMANDS:
            raise ReplayFileError(f"commands must be a tuple of at most {MAX_COMMANDS}")
        if (type(self.checkpoints) is not tuple
                or len(self.checkpoints) > MAX_COMMANDS // CHECKPOINT_INTERVAL + 1):
            raise ReplayFileError("checkpoints must be a tuple")
        if type(self.terminal) is not bool:
            raise ReplayFileError("terminal must be a boolean")
        if any(not isinstance(point, ReplayCheckpoint) for point in self.checkpoints):
            raise ReplayFileError("invalid checkpoint record")
        _validate_order(self.commands)
        counts = tuple(point.command_count for point in self.checkpoints)
        expected = tuple(range(CHECKPOINT_INTERVAL, len(self.commands) + 1,
                               CHECKPOINT_INTERVAL))
        if self.terminal and (not expected or expected[-1] != len(self.commands)):
            expected += (len(self.commands),)
        if counts and counts != expected:
            raise ReplayFileError(f"checkpoint positions must be {expected!r}")

    def canonical_value(self) -> dict[str, Any]:
        return {"checkpoints": [row.canonical_value() for row in self.checkpoints],
                "commands": [row.canonical_value() for row in self.commands],
                "header": self.header.canonical_value(), "schemaVersion": REPLAY_SCHEMA_VERSION,
                "terminal": int(self.terminal)}


def _validate_order(commands: tuple[AcceptedCommand, ...]) -> None:
    prior: AcceptedCommand | None = None
    next_ordinal = 0
    for command in commands:
        if not isinstance(command, AcceptedCommand):
            raise ReplayFileError("commands must contain AcceptedCommand records")
        if prior is None or command.barrier_id != prior.barrier_id:
            if prior is not None and (command.logical_tick < prior.logical_tick
                                      or command.barrier_id <= prior.barrier_id):
                raise ReplayFileError("command tick/barrier order must increase")
            next_ordinal = 0
        elif command.logical_tick != prior.logical_tick:
            raise ReplayFileError("one barrier must use one logical tick")
        if command.command_ordinal != next_ordinal:
            raise ReplayFileError("command ordinal has a duplicate or gap")
        next_ordinal += 1
        prior = command


def encode_replay(replay: ReplayFile) -> bytes:
    data = canonical_json(replay.canonical_value())
    if len(data) > MAX_REPLAY_BYTES:
        raise ReplayFileError(f"replay exceeds {MAX_REPLAY_BYTES} bytes")
    return data


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ReplayFileError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _exact(value: Any, fields: set[str], name: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != fields:
        raise ReplayFileError(f"{name} requires exactly {sorted(fields)!r}")
    return value


def _decode_command(value: Any) -> AcceptedCommand:
    row = _exact(value, {"actorId", "barrierId", "commandOrdinal", "logicalTick", "payload"},
                 "command")
    return AcceptedCommand(row["logicalTick"], row["barrierId"], row["commandOrdinal"],
                          row["actorId"], row["payload"])


def decode_replay(data: bytes, *, expected_ruleset: str = RULESET_VERSION,
                  expected_content_digest: str | None = None) -> ReplayFile:
    if type(data) is not bytes or len(data) > MAX_REPLAY_BYTES:
        raise ReplayFileError(f"replay must be bytes no larger than {MAX_REPLAY_BYTES}")
    try:
        value = json.loads(data.decode("utf-8", "strict"), object_pairs_hook=_pairs,
                           parse_float=lambda _: (_ for _ in ()).throw(ReplayFileError("floats are forbidden")),
                           parse_constant=lambda _: (_ for _ in ()).throw(ReplayFileError("non-finite numbers are forbidden")))
    except ReplayFileError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as exc:
        raise ReplayFileError(f"invalid replay JSON: {exc}") from exc
    _json_tree(value)
    if canonical_json(value) != data:
        raise ReplayFileError("replay bytes are not canonical JSON")
    envelope = _exact(value, {"checkpoints", "commands", "header", "schemaVersion", "terminal"},
                      "replay")
    if (type(envelope["schemaVersion"]) is not int or
            envelope["schemaVersion"] != REPLAY_SCHEMA_VERSION):
        raise ReplayFileError(f"unsupported replay schema: {envelope['schemaVersion']!r}")
    head = _exact(envelope["header"], {"contentDigest", "engineBuild", "initialState", "rng",
                                       "rulesetVersion", "waitTicks"}, "header")
    rng = _exact(head["rng"], {"state", "version"}, "rng")
    header = ReplayHeader(head["rulesetVersion"], head["contentDigest"], rng["version"],
                          tuple(rng["state"]) if type(rng["state"]) is list else (),
                          head["waitTicks"], head["engineBuild"], head["initialState"])
    if header.ruleset_version != expected_ruleset:
        raise ReplayFileError(f"ruleset mismatch: expected {expected_ruleset!r}, actual {header.ruleset_version!r}")
    if expected_content_digest is not None and header.content_digest != _digest(expected_content_digest, "expected content digest"):
        raise ReplayFileError(f"content digest mismatch: expected {expected_content_digest!r}, actual {header.content_digest!r}")
    if type(envelope["commands"]) is not list or len(envelope["commands"]) > MAX_COMMANDS:
        raise ReplayFileError(f"commands must be an array of at most {MAX_COMMANDS}")
    if type(envelope["checkpoints"]) is not list:
        raise ReplayFileError("checkpoints must be an array")
    checkpoints = tuple(ReplayCheckpoint(row["commandCount"], row["stateDigest"])
                       for row in (_exact(item, {"commandCount", "stateDigest"}, "checkpoint")
                                   for item in envelope["checkpoints"]))
    terminal = envelope["terminal"]
    if type(terminal) is not int or terminal not in (0, 1):
        raise ReplayFileError("terminal must be canonical integer 0 or 1")
    return ReplayFile(header, tuple(_decode_command(item) for item in envelope["commands"]),
                      checkpoints, bool(terminal))


@dataclass(frozen=True, slots=True)
class ReplayRunStep:
    accepted: bool
    state_digest: str
    terminal: bool = False


@dataclass(frozen=True, slots=True)
class ReplayRunResult:
    command_count: int
    terminal: bool
    final_state_digest: str


def verify_replay(replay: ReplayFile, *, expected_ruleset: str,
                  expected_content_digest: str,
                  initialize: Callable[[ReplayHeader], str],
                  submit: Callable[[AcceptedCommand], ReplayRunStep]) -> ReplayRunResult:
    """Replay each accepted record through authoritative injected runtime calls."""
    if replay.header.ruleset_version != expected_ruleset:
        raise ReplayFileError(f"ruleset mismatch: expected {expected_ruleset!r}, actual {replay.header.ruleset_version!r}")
    if replay.header.content_digest != expected_content_digest:
        raise ReplayFileError("project content identity mismatch")
    state_digest = _digest(initialize(replay.header), "initial state digest")
    points = {point.command_count: point.state_digest for point in replay.checkpoints}
    if 0 in points and points[0] != state_digest:
        raise ReplayFileError("initial checkpoint mismatch")
    terminal = False
    for index, command in enumerate(replay.commands, 1):
        if terminal:
            raise ReplayFileError("command follows authoritative terminal result")
        step = submit(command)
        if not isinstance(step, ReplayRunStep) or type(step.accepted) is not bool:
            raise ReplayFileError("authoritative runner returned an invalid result")
        if not step.accepted:
            raise ReplayFileError(f"authoritative runner rejected command {index - 1}")
        state_digest = _digest(step.state_digest, "authoritative state digest")
        terminal = step.terminal
        if type(terminal) is not bool:
            raise ReplayFileError("authoritative terminal marker must be boolean")
        if index in points and points[index] != state_digest:
            raise ReplayFileError(f"checkpoint mismatch at command {index}")
    if replay.terminal != terminal:
        raise ReplayFileError("terminal result does not match replay envelope")
    if len(replay.commands) in points and points[len(replay.commands)] != state_digest:
        raise ReplayFileError("terminal checkpoint mismatch")
    return ReplayRunResult(len(replay.commands), terminal, state_digest)


__all__ = ["AcceptedCommand", "MAX_COMMANDS", "MAX_REPLAY_BYTES", "REPLAY_SCHEMA_VERSION",
           "ReplayCheckpoint", "ReplayFile", "ReplayFileError", "ReplayHeader",
           "ReplayRunResult", "ReplayRunStep", "decode_replay", "encode_replay",
           "verify_replay"]
