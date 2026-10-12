"""Closed JSON command boundary for the M10 maker playtest controls."""
from __future__ import annotations

from content.m8_binding import SignedCoord
from content.m10_command_wire import (Activate, AdvanceBattle, AdvanceDialogue,
                                      BattleEscape, BattleMove, BattleWait, ChooseEvent, ContinueEvent,
                                      FastTravel, Interact, M10Command, Move,
                                      Traverse)
from content.world_limits import WORLD_COORD_LIMIT


class CommandInputError(ValueError):
    """A browser action is not one of the bounded runtime command variants."""


def _shape(value: object, required: set[str]) -> dict:
    if type(value) is not dict or set(value) != required:
        raise CommandInputError(f"command requires exactly {sorted(required)!r}")
    return value


def _coord(value: object, name: str) -> SignedCoord:
    if type(value) is not int or abs(value) > WORLD_COORD_LIMIT:
        raise CommandInputError(
            f"{name} must be an integer in [-{WORLD_COORD_LIMIT}, {WORLD_COORD_LIMIT}]")
    return SignedCoord(value < 0, abs(value))


def _id(value: object, name: str) -> int:
    if type(value) is not int or not 1 <= value <= 0xFFFFFFFF:
        raise CommandInputError(f"{name} must be an integer in [1, 4294967295]")
    return value


def _flag(value: object, name: str) -> bool:
    if type(value) is not bool:
        raise CommandInputError(f"{name} must be a boolean")
    return value


def parse_command(value: object) -> M10Command:
    """Convert one exact JSON object to an inert typed world command."""
    if type(value) is not dict or type(value.get("kind")) is not str:
        raise CommandInputError("command must be an object with a string kind")
    kind = value["kind"]
    if kind == "move":
        row = _shape(value, {"kind", "x", "z", "analog", "sprint"})
        return Move(_coord(row["x"], "move x"), _coord(row["z"], "move z"),
                    _flag(row["analog"], "analog"), _flag(row["sprint"], "sprint"))
    if kind == "interact":
        row = _shape(value, {"kind", "npcId", "facingX", "facingZ"})
        return Interact(_id(row["npcId"], "NPC id"),
                        _coord(row["facingX"], "facing x"),
                        _coord(row["facingZ"], "facing z"))
    if kind in {"activate", "traverse", "fastTravel"}:
        field = "triggerId" if kind == "activate" else "transitionId"
        row = _shape(value, {"kind", field})
        identifier = _id(row[field], field)
        return (Activate(identifier) if kind == "activate" else
                Traverse(identifier) if kind == "traverse" else
                FastTravel(identifier))
    if kind == "continueEvent":
        _shape(value, {"kind"})
        return ContinueEvent()
    if kind == "advanceDialogue":
        _shape(value, {"kind"})
        return AdvanceDialogue()
    if kind in {"battleWait", "battleEscape"}:
        row = _shape(value, {"kind", "actorId"})
        actor_id = row["actorId"]
        if type(actor_id) is not int or actor_id != 0:
            raise CommandInputError("battle actorId must be 0")
        return BattleWait(actor_id) if kind == "battleWait" else BattleEscape(actor_id)
    if kind == "advanceBattle":
        _shape(value, {"kind"})
        return AdvanceBattle()
    if kind == "battleMove":
        row = _shape(value, {"kind", "actorId", "targetId", "moveId"})
        if (type(row["actorId"]) is not int or row["actorId"] != 0
                or type(row["targetId"]) is not int or row["targetId"] != 1):
            raise CommandInputError("battle move must target actorId 1 from actorId 0")
        return BattleMove(0, 1, _id(row["moveId"], "moveId"))
    if kind == "chooseEvent":
        row = _shape(value, {"kind", "yes"})
        return ChooseEvent(_flag(row["yes"], "yes"))
    raise CommandInputError(f"unsupported command kind {kind!r}")
