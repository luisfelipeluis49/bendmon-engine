"""Closed bounded numeric wire for M10 playtest world-command logs."""
from __future__ import annotations

from dataclasses import dataclass

from .m8_binding import SignedCoord
from .world_limits import WORLD_COORD_LIMIT

MAGIC = 14
WIRE_VERSION = 1
MAX_COMMANDS = 4096
MAX_WIRE_TOKENS = 32_771
MAX_WIRE_BYTES = 512 * 1024
MAX_U32 = 0xFFFFFFFF


class M10CommandWireError(ValueError):
    """The command log is malformed or exceeds its wire bounds."""


@dataclass(frozen=True, slots=True)
class Move:
    x: SignedCoord
    z: SignedCoord
    analog: bool
    sprint: bool


@dataclass(frozen=True, slots=True)
class Interact:
    npc_id: int
    facing_x: SignedCoord
    facing_z: SignedCoord


@dataclass(frozen=True, slots=True)
class Activate:
    trigger_id: int


@dataclass(frozen=True, slots=True)
class Traverse:
    transition_id: int


@dataclass(frozen=True, slots=True)
class FastTravel:
    transition_id: int


@dataclass(frozen=True, slots=True)
class ContinueEvent:
    pass


@dataclass(frozen=True, slots=True)
class ChooseEvent:
    yes: bool


@dataclass(frozen=True, slots=True)
class AdvanceDialogue:
    pass


@dataclass(frozen=True, slots=True)
class BattleWait:
    actor_id: int


@dataclass(frozen=True, slots=True)
class BattleEscape:
    actor_id: int


@dataclass(frozen=True, slots=True)
class BattleMove:
    actor_id: int
    target_id: int
    move_id: int


@dataclass(frozen=True, slots=True)
class AdvanceBattle:
    pass


M10Command = (Move | Interact | Activate | Traverse | FastTravel |
              ContinueEvent | ChooseEvent | AdvanceDialogue | BattleWait |
              BattleEscape | BattleMove | AdvanceBattle)


@dataclass(frozen=True, slots=True)
class M10CommandWire:
    version: int
    tokens: tuple[int, ...]
    text: str


def _coord(value: object, label: str) -> tuple[int, int]:
    if type(value) is not SignedCoord:
        raise M10CommandWireError(f"{label} must be a signed coordinate")
    magnitude = value.magnitude
    if (type(value.negative) is not bool or type(magnitude) is not int
            or not 0 <= magnitude <= WORLD_COORD_LIMIT
            or (value.negative and magnitude == 0)):
        raise M10CommandWireError(f"{label} is outside the canonical coordinate bounds")
    return (1 if value.negative else 0, magnitude)


def _identifier(value: object, label: str) -> int:
    if type(value) is not int or not 1 <= value <= MAX_U32:
        raise M10CommandWireError(f"{label} must be in [1, {MAX_U32}]")
    return value


def _command_tokens(sequence: int, command: object) -> list[int]:
    prefix = [sequence]
    if type(command) is Move:
        x = _coord(command.x, "move x")
        z = _coord(command.z, "move z")
        if type(command.analog) is not bool or type(command.sprint) is not bool:
            raise M10CommandWireError("move flags must be booleans")
        return prefix + [1, *x, *z, int(command.analog), int(command.sprint)]
    if type(command) is Interact:
        x = _coord(command.facing_x, "interaction facing x")
        z = _coord(command.facing_z, "interaction facing z")
        return prefix + [2, _identifier(command.npc_id, "NPC id"), *x, *z]
    if type(command) is Activate:
        return prefix + [3, _identifier(command.trigger_id, "trigger id")]
    if type(command) is Traverse:
        return prefix + [4, _identifier(command.transition_id, "transition id")]
    if type(command) is FastTravel:
        return prefix + [5, _identifier(command.transition_id, "transition id")]
    if type(command) is ContinueEvent:
        return prefix + [6]
    if type(command) is ChooseEvent:
        if type(command.yes) is not bool:
            raise M10CommandWireError("event choice must be a boolean")
        return prefix + [7, int(command.yes)]
    if type(command) is AdvanceDialogue:
        return prefix + [8]
    if type(command) is BattleWait:
        if command.actor_id != 0 or type(command.actor_id) is not int:
            raise M10CommandWireError("battle wait actor id must be 0")
        return prefix + [9, 0]
    if type(command) is BattleEscape:
        if command.actor_id != 0 or type(command.actor_id) is not int:
            raise M10CommandWireError("battle escape actor id must be 0")
        return prefix + [10, 0]
    if type(command) is BattleMove:
        if (type(command.actor_id) is not int or command.actor_id != 0
                or type(command.target_id) is not int or command.target_id != 1):
            raise M10CommandWireError("battle move must target actor 1 from actor 0")
        return prefix + [12, 0, 1, _identifier(command.move_id, "move id")]
    if type(command) is AdvanceBattle:
        return prefix + [11]
    raise M10CommandWireError("unknown world command variant")


def encode_m10_commands(commands: object) -> M10CommandWire:
    """Encode a bounded ordered log; sequence numbers are assigned from zero."""
    if type(commands) is not tuple or len(commands) > MAX_COMMANDS:
        raise M10CommandWireError(f"command log must be a tuple of at most {MAX_COMMANDS}")
    tokens = [MAGIC, WIRE_VERSION, len(commands)]
    for sequence, command in enumerate(commands):
        tokens.extend(_command_tokens(sequence, command))
    if len(tokens) > MAX_WIRE_TOKENS:
        raise M10CommandWireError("command wire token count exceeds the supported bound")
    text = " ".join(map(str, tokens))
    if len(text.encode("ascii")) > MAX_WIRE_BYTES:
        raise M10CommandWireError("command wire bytes exceed the supported bound")
    return M10CommandWire(WIRE_VERSION, tuple(tokens), text)
