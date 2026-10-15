"""Strict JSON codec for accepted M10 commands stored in M11 records."""

from __future__ import annotations

from .m10_command_wire import (
    Activate, AdvanceBattle, AdvanceDialogue, BattleEscape, BattleMove,
    BattleWait, ChooseEvent, ContinueEvent, FastTravel, Interact,
    M10Command, M10CommandWireError, Move, Traverse, encode_m10_commands,
)
from .m8_binding import SignedCoord


class M10CommandJSONError(ValueError):
    """An M10 command JSON value is malformed or outside the accepted wire."""


def _uint(value: object, field: str, maximum: int = 0xFFFFFFFF) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise M10CommandJSONError(f"{field} must be an integer in [0, {maximum}]")
    return value


def _exact(value: object, fields: set[str]) -> dict:
    if type(value) is not dict or set(value) != fields:
        raise M10CommandJSONError(f"command requires exactly {sorted(fields)!r}")
    return value


def _flag(value: object, field: str) -> bool:
    return bool(_uint(value, field, 1))


def _coord(negative: object, magnitude: object, field: str) -> SignedCoord:
    sign = _uint(negative, f"{field} sign", 1)
    amount = _uint(magnitude, f"{field} magnitude")
    if sign and amount == 0:
        raise M10CommandJSONError(f"{field} negative zero is not canonical")
    return SignedCoord(bool(sign), amount)


def decode_m10_command(value: object) -> M10Command:
    """Decode one canonical JSON payload and validate it with the M10 wire."""
    if type(value) is not dict or type(value.get("kind")) is not str:
        raise M10CommandJSONError("command payload must have a string kind")
    kind = value["kind"]
    if kind == "move":
        row = _exact(value, {"kind", "xNegative", "xMagnitude", "zNegative",
                             "zMagnitude", "analog", "sprint"})
        command: M10Command = Move(_coord(row["xNegative"], row["xMagnitude"], "x"),
                                   _coord(row["zNegative"], row["zMagnitude"], "z"),
                                   _flag(row["analog"], "analog"),
                                   _flag(row["sprint"], "sprint"))
    elif kind == "interact":
        row = _exact(value, {"kind", "npcId", "facingXNegative", "facingXMagnitude",
                             "facingZNegative", "facingZMagnitude"})
        command = Interact(_uint(row["npcId"], "NPC id"),
                           _coord(row["facingXNegative"], row["facingXMagnitude"], "facing x"),
                           _coord(row["facingZNegative"], row["facingZMagnitude"], "facing z"))
    elif kind in {"activate", "traverse", "fastTravel"}:
        _exact(value, {"kind", "id"})
        identifier = _uint(value["id"], "command id", 0xFFFFFFFF)
        command = (Activate(identifier) if kind == "activate" else
                   Traverse(identifier) if kind == "traverse" else FastTravel(identifier))
    elif kind == "chooseEvent":
        row = _exact(value, {"kind", "yes"})
        command = ChooseEvent(_flag(row["yes"], "yes"))
    elif kind == "continueEvent":
        _exact(value, {"kind"})
        command = ContinueEvent()
    elif kind == "advanceDialogue":
        _exact(value, {"kind"})
        command = AdvanceDialogue()
    elif kind == "advanceBattle":
        _exact(value, {"kind"})
        command = AdvanceBattle()
    elif kind == "battleWait":
        row = _exact(value, {"kind", "actorId"})
        command = BattleWait(_uint(row["actorId"], "actor id"))
    elif kind == "battleEscape":
        row = _exact(value, {"kind", "actorId"})
        command = BattleEscape(_uint(row["actorId"], "actor id"))
    elif kind == "battleMove":
        row = _exact(value, {"kind", "actorId", "targetId", "moveId"})
        command = BattleMove(_uint(row["actorId"], "actor id"),
                             _uint(row["targetId"], "target id"),
                             _uint(row["moveId"], "move id"))
    else:
        raise M10CommandJSONError(f"unknown M10 command kind: {kind!r}")
    try:
        encode_m10_commands((command,))
    except (M10CommandWireError, TypeError, ValueError) as exc:
        raise M10CommandJSONError(f"invalid M10 command: {exc}") from exc
    return command


def validate_m10_command_value(value: object) -> None:
    """Validate an M11 command payload without retaining a host object."""
    decode_m10_command(value)


__all__ = ["M10CommandJSONError", "decode_m10_command", "validate_m10_command_value"]
