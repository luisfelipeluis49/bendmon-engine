"""Parse the closed precompiled M10 process result and M9 display records."""
from __future__ import annotations

from dataclasses import dataclass
import re

from presentation.wire import CueView, SceneView, SceneWireError, parse_cues, parse_scene
from persistence.m11_progression import (
    M11Progression, M11ProgressionError, decode_m11_progression_tokens,
)
from persistence.save_identity import SaveIdentity
from persistence.world_state import WorldSnapshot, WorldStateError, encode_world_state

_DECIMAL = re.compile(r"(?:0|[1-9][0-9]*)\Z")
_HASH = re.compile(r"[0-9a-f]{64}\Z")
MAX_RESPONSE_BYTES = 512 * 1024


class RuntimeResponseError(ValueError):
    """The Bend process returned a malformed or mismatched result."""


@dataclass(frozen=True, slots=True)
class CommandTraceStep:
    """One accepted UI command's Bend acceptance and completion trace."""

    command_index: int
    logical_tick: int
    post_tick: int | None = None
    enemy_wait: bool = False


@dataclass(frozen=True, slots=True)
class RuntimeResponse:
    status: str
    content_hash: str
    accepted_commands: int
    scene: SceneView | None
    cues: tuple[CueView, ...]
    encounter_id: int | None
    scene_csv: str | None
    cues_csv: str | None
    dialogue_id: int = 0
    dialogue_line_index: int = 0
    dialogue_closed: bool = True
    save_snapshot: WorldSnapshot | None = None
    progression: M11Progression | None = None
    command_trace: tuple[CommandTraceStep, ...] = ()


def _save_snapshot(row: str, content_hash: str, identity: int) -> WorldSnapshot | None:
    if row == "SAVE 0":
        return None
    if not row.startswith("SAVE 1,"):
        raise RuntimeResponseError("runtime save projection has an invalid tag")
    tokens = row[5:].split(",")
    if any(not _DECIMAL.fullmatch(token) or len(token) > 10 for token in tokens):
        raise RuntimeResponseError("runtime save projection requires canonical U32 tokens")
    numbers = tuple(map(int, tokens))
    if any(number > 0xFFFFFFFF for number in numbers) or len(numbers) < 18:
        raise RuntimeResponseError("runtime save projection is oversized or incomplete")
    cursor = 0

    def take() -> int:
        nonlocal cursor
        if cursor >= len(numbers):
            raise RuntimeResponseError("runtime save projection is truncated")
        value = numbers[cursor]
        cursor += 1
        return value

    if take() != 1 or take() != identity:
        raise RuntimeResponseError("runtime save projection identity mismatches the request")
    map_id = take()
    position = []
    for _ in range(3):
        sign, magnitude = take(), take()
        if sign not in (0, 1) or (sign == 1 and magnitude == 0):
            raise RuntimeResponseError("runtime save projection has a noncanonical coordinate")
        position.append(-magnitude if sign else magnitude)
    region = take() or None
    weighted, threshold, safe = take(), take(), take()
    rng = tuple(take() for _ in range(4))
    value_count = take()
    if value_count > 4096 or value_count * 2 > len(numbers) - cursor:
        raise RuntimeResponseError("runtime save projection has invalid value count")
    values = tuple((take(), take()) for _ in range(value_count))
    entity_count = take()
    if entity_count > 4096 or entity_count != len(numbers) - cursor:
        raise RuntimeResponseError("runtime save projection has invalid entity count")
    entities = tuple(take() for _ in range(entity_count))
    snapshot = WorldSnapshot(map_id, *position, region, weighted, threshold,
                             safe, rng, values, entities)
    try:
        encode_world_state(SaveIdentity(1, "m8-1", content_hash), snapshot)
    except WorldStateError as exc:
        raise RuntimeResponseError(f"runtime save projection is invalid: {exc}") from exc
    return snapshot


def _progression(row: str) -> M11Progression | None:
    if row == "PROGRESSION 0":
        return None
    if not row.startswith("PROGRESSION 1,"):
        raise RuntimeResponseError("runtime progression has an invalid tag")
    raw = row[len("PROGRESSION 1,"):].split(",")
    if (not raw or any(not _DECIMAL.fullmatch(token) or len(token) > 10 for token in raw)):
        raise RuntimeResponseError("runtime progression requires canonical U32 tokens")
    numbers = tuple(map(int, raw))
    if any(number > 0xFFFFFFFF for number in numbers):
        raise RuntimeResponseError("runtime progression token exceeds U32")
    try:
        return decode_m11_progression_tokens(numbers)
    except M11ProgressionError as exc:
        raise RuntimeResponseError(f"runtime progression is invalid: {exc}") from exc


def _number(line: str, prefix: str, maximum: int = 0xFFFFFFFF) -> int:
    if not line.startswith(prefix) or not _DECIMAL.fullmatch(line[len(prefix):]):
        raise RuntimeResponseError(f"runtime response is missing canonical {prefix.strip()}")
    value = int(line[len(prefix):])
    if value > maximum:
        raise RuntimeResponseError(f"runtime {prefix.strip()} exceeds {maximum}")
    return value


def parse_runtime_response(output: str, *, expected_content_hash: str,
                           expected_commands: int) -> RuntimeResponse:
    """Require exact framing, full host identity, and valid M9 scene/cue data."""
    if (type(output) is not str or not output.isascii()
            or len(output) > MAX_RESPONSE_BYTES
            or type(expected_content_hash) is not str
            or not _HASH.fullmatch(expected_content_hash)
            or type(expected_commands) is not int
            or not 0 <= expected_commands <= 4096):
        raise RuntimeResponseError("runtime response arguments are invalid or oversized")
    if output == "M10PLAY2 REJECTED\n":
        return RuntimeResponse("rejected", expected_content_hash, 0, None, (),
                               None, None, None)
    if not output.endswith("\n") or output.endswith("\n\n"):
        raise RuntimeResponseError("runtime response must have one final newline")
    rows = output[:-1].split("\n")
    if not rows or rows[0] not in {"M10PLAY2 ACCEPTED", "M10PLAY2 ENCOUNTER",
                                    "M10PLAY2 BATTLE"}:
        raise RuntimeResponseError("runtime response has an unknown status")
    battle = rows[0] == "M10PLAY2 BATTLE"
    encounter = rows[0] != "M10PLAY2 ACCEPTED"
    legacy_rows = 7 if encounter else 6
    if len(rows) < legacy_rows:
        raise RuntimeResponseError("runtime response has the wrong row count")
    optional_rows = rows[legacy_rows:]
    trace_rows = tuple(row for row in optional_rows
                       if row.startswith(("TRACE ", "TRACE_STEP ")))
    metadata_rows = tuple(row for row in optional_rows if row not in trace_rows)
    if (any(not row.startswith(("SAVE ", "PROGRESSION ")) for row in metadata_rows)
            or sum(row.startswith("SAVE ") for row in optional_rows) > 1
            or sum(row.startswith("PROGRESSION ") for row in optional_rows) > 1
            or len(trace_rows) not in (0, expected_commands + 1)):
        raise RuntimeResponseError(
            "runtime response has the wrong row count, duplicate, or unknown optional rows"
        )
    command_trace = _command_trace(trace_rows, expected_commands)
    identity = _number(rows[1], "IDENTITY ")
    commands = _number(rows[2], "COMMANDS ", 4096)
    if identity != int(expected_content_hash[:8], 16) or commands != expected_commands:
        raise RuntimeResponseError("runtime identity or accepted-command count mismatches the request")
    encounter_id = _number(rows[3], "ENCOUNTER ") if encounter else None
    if encounter and encounter_id == 0:
        raise RuntimeResponseError("runtime encounter ID must be positive")
    dialogue_row = rows[4 if encounter else 3]
    dialogue_parts = dialogue_row.split(" ")
    if (len(dialogue_parts) != 4 or dialogue_parts[0] != "DIALOGUE" or
            any(not _DECIMAL.fullmatch(part) for part in dialogue_parts[1:])):
        raise RuntimeResponseError("runtime response has an invalid dialogue cursor")
    dialogue_id, line_index, closed = map(int, dialogue_parts[1:])
    if (dialogue_id > 0xFFFFFFFF or line_index > 63 or closed not in {0, 1} or
            (dialogue_id == 0 and (line_index != 0 or closed != 1)) or
            (encounter and dialogue_id != 0)):
        raise RuntimeResponseError("runtime response has an invalid dialogue cursor")
    save_row = next((row for row in optional_rows if row.startswith("SAVE ")), None)
    progression_row = next((row for row in optional_rows
                            if row.startswith("PROGRESSION ")), None)
    scene_row, cue_row = rows[legacy_rows - 2:legacy_rows]
    if not scene_row.startswith("SCENE ") or not cue_row.startswith("CUES "):
        raise RuntimeResponseError("runtime response lacks scene or cue records")
    try:
        scene = parse_scene(scene_row[6:])
        cues = parse_cues(cue_row[5:])
    except SceneWireError as exc:
        raise RuntimeResponseError(f"runtime display record is invalid: {exc}") from exc
    if scene.content_identity != identity or any(cue.ordinal > commands for cue in cues):
        raise RuntimeResponseError("runtime display identity or cue ordinal mismatches the request")
    if battle and scene.battle is None:
        raise RuntimeResponseError("runtime battle status lacks a battle scene")
    save_snapshot = (_save_snapshot(save_row, expected_content_hash, identity)
                     if save_row is not None else None)
    progression = _progression(progression_row) if progression_row is not None else None
    if save_snapshot is not None and (encounter or not closed):
        raise RuntimeResponseError("runtime active encounter or dialogue cannot be saved")
    if progression is not None and (encounter or not closed or
                                    progression.content_identity != identity):
        raise RuntimeResponseError("runtime progression requires the closed matching world identity")
    return RuntimeResponse("battle" if battle else "encounter" if encounter else "accepted",
                           expected_content_hash, commands, scene, cues,
                           encounter_id, scene_row[6:], cue_row[5:],
                           dialogue_id, line_index, bool(closed), save_snapshot,
                           progression, command_trace)


def _command_trace(rows: tuple[str, ...], expected_commands: int) -> tuple[CommandTraceStep, ...]:
    """Parse the replay-fold trace emitted at each accepted command boundary."""
    if not rows:
        return ()
    header = rows[0].split(" ")
    if (len(header) != 2 or header[0] != "TRACE" or
            not re.fullmatch(r"2,[0-9]+", header[1])):
        raise RuntimeResponseError("runtime command trace requires TRACE 2,<count>")
    version, count = header[1].split(",")
    if version != "2" or int(count) != expected_commands:
        raise RuntimeResponseError("runtime command trace version or count mismatches request")
    result: list[CommandTraceStep] = []
    prior_post_tick = 0
    for index, row in enumerate(rows[1:]):
        parts = row.split(" ")
        if len(parts) != 2 or parts[0] != "TRACE_STEP":
            raise RuntimeResponseError("runtime command trace rows are malformed")
        values = parts[1].split(",")
        if len(values) != 4 or any(not _DECIMAL.fullmatch(value) for value in values):
            raise RuntimeResponseError("runtime command trace requires canonical index,preTick,postTick,enemyWait")
        row_index, tick, post_tick, enemy_wait = map(int, values)
        if (row_index != index or tick > 0xFFFFFFFF or
                post_tick > 0xFFFFFFFF or enemy_wait not in (0, 1) or
                tick < prior_post_tick or post_tick < tick):
            raise RuntimeResponseError("runtime command trace index or logical tick is invalid")
        result.append(CommandTraceStep(row_index, tick, post_tick, bool(enemy_wait)))
        prior_post_tick = post_tick
    if len(result) != expected_commands:
        raise RuntimeResponseError("runtime command trace is incomplete")
    return tuple(result)
