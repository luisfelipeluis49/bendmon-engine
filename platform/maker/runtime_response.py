"""Parse the closed precompiled M10 process result and M9 display records."""
from __future__ import annotations

from dataclasses import dataclass
import re

from presentation.wire import CueView, SceneView, SceneWireError, parse_cues, parse_scene

_DECIMAL = re.compile(r"(?:0|[1-9][0-9]*)\Z")
_HASH = re.compile(r"[0-9a-f]{64}\Z")
MAX_RESPONSE_BYTES = 64 * 1024


class RuntimeResponseError(ValueError):
    """The Bend process returned a malformed or mismatched result."""


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
    if len(rows) != (7 if encounter else 6):
        raise RuntimeResponseError("runtime response has the wrong row count")
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
    scene_row, cue_row = rows[-2:]
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
    return RuntimeResponse("battle" if battle else "encounter" if encounter else "accepted",
                           expected_content_hash, commands, scene, cues,
                           encounter_id, scene_row[6:], cue_row[5:],
                           dialogue_id, line_index, bool(closed))
