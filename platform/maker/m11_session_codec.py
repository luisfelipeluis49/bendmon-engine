"""Translate frozen M10 maker sessions to and from M11 replay records.

M10 records accepted UI commands and Bend logical ticks. The maker assigns one
barrier per UI command, including the trusted enemy wait at ordinal one when
Bend generated it. The packaged Bend runner remains the simulation oracle.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import json
from typing import Callable

from content.m10_command_wire import (
    Activate, AdvanceBattle, AdvanceDialogue, BattleEscape, BattleMove,
    BattleWait, ChooseEvent, ContinueEvent, FastTravel, Interact, M10Command,
    Move, Traverse, encode_m10_commands,
)
from content.m11_command_codec import M10CommandJSONError, decode_m10_command
from persistence.m11_replay import (
    AcceptedCommand, ReplayFile, ReplayFileError, ReplayHeader,
    encode_replay,
)
from persistence.m11_progression import (M11Progression, M11ProgressionError,
                                          decode_m11_progression,
                                          encode_m11_progression)
from persistence.save_identity import SaveIdentity
from persistence.world_state import (WorldSnapshot, WorldStateError,
                                     decode_world_state, encode_world_state)
from .playtest import FrozenPlaytestSnapshot
from .runtime_process import run_runtime
from .runtime_response import CommandTraceStep, RuntimeResponse

RULESET_VERSION = "m8-1"


class M11SessionCodecError(ValueError):
    """A maker replay does not match the frozen M10 session contract."""


def command_to_value(command: M10Command) -> dict[str, object]:
    """Return a strict bool-free JSON payload for one typed M10 command."""
    try:
        encode_m10_commands((command,))
    except (TypeError, ValueError) as exc:
        raise M11SessionCodecError(f"invalid M10 command: {exc}") from exc
    if type(command) is Move:
        return {"kind": "move", "xNegative": int(command.x.negative),
                "xMagnitude": command.x.magnitude, "zNegative": int(command.z.negative),
                "zMagnitude": command.z.magnitude, "analog": int(command.analog),
                "sprint": int(command.sprint)}
    if type(command) is Interact:
        return {"kind": "interact", "npcId": command.npc_id,
                "facingXNegative": int(command.facing_x.negative),
                "facingXMagnitude": command.facing_x.magnitude,
                "facingZNegative": int(command.facing_z.negative),
                "facingZMagnitude": command.facing_z.magnitude}
    if type(command) in (Activate, Traverse, FastTravel):
        kind = ("activate" if type(command) is Activate else
                "traverse" if type(command) is Traverse else "fastTravel")
        return {"kind": kind, "id": command.trigger_id if type(command) is Activate
                else command.transition_id}
    if type(command) is ChooseEvent:
        return {"kind": "chooseEvent", "yes": int(command.yes)}
    if type(command) in (ContinueEvent, AdvanceDialogue, AdvanceBattle):
        kind = ("continueEvent" if type(command) is ContinueEvent else
                "advanceDialogue" if type(command) is AdvanceDialogue else "advanceBattle")
        return {"kind": kind}
    if type(command) in (BattleWait, BattleEscape):
        return {"kind": "battleWait" if type(command) is BattleWait else "battleEscape",
                "actorId": command.actor_id}
    if type(command) is BattleMove:
        return {"kind": "battleMove", "actorId": command.actor_id,
                "targetId": command.target_id, "moveId": command.move_id}
    raise M11SessionCodecError("unsupported M10 command variant")


def _command_actor_id(command: M10Command) -> int:
    """Project the authoritative actor field for battle commands."""
    if type(command) in (BattleWait, BattleEscape, BattleMove):
        return command.actor_id
    return 0


def _may_generate_enemy_wait(command: M10Command) -> bool:
    return type(command) in (BattleWait, BattleEscape, BattleMove, AdvanceBattle)


def _replay_rows(command: M10Command, step: CommandTraceStep,
                 barrier_id: int) -> tuple[AcceptedCommand, ...]:
    if step.enemy_wait and not _may_generate_enemy_wait(command):
        raise M11SessionCodecError("world command cannot generate an enemy battle wait")
    player = AcceptedCommand(step.logical_tick, barrier_id, 0,
                             _command_actor_id(command), command_to_value(command))
    if not step.enemy_wait:
        return (player,)
    enemy = AcceptedCommand(step.logical_tick, barrier_id, 1, 1,
                            {"kind": "battleWait", "actorId": 1})
    return (player, enemy)


def _maker_commands(replay: ReplayFile) -> tuple[tuple[M10Command, ...],
                                                 tuple[int, ...], tuple[bool, ...]]:
    commands: list[M10Command] = []
    ticks: list[int] = []
    enemy_waits: list[bool] = []
    cursor = 0
    while cursor < len(replay.commands):
        player = replay.commands[cursor]
        barrier_id = len(commands) + 1
        if player.barrier_id != barrier_id or player.command_ordinal != 0:
            raise M11SessionCodecError("replay command does not use M10 maker barrier ordering")
        command = command_from_value(player.payload)
        if player.actor_id != _command_actor_id(command):
            raise M11SessionCodecError("replay command actor id does not match its accepted payload")
        cursor += 1
        has_enemy = cursor < len(replay.commands) and replay.commands[cursor].barrier_id == barrier_id
        if has_enemy:
            enemy = replay.commands[cursor]
            if (not _may_generate_enemy_wait(command) or enemy.command_ordinal != 1
                    or enemy.actor_id != 1 or enemy.logical_tick != player.logical_tick
                    or enemy.payload != {"kind": "battleWait", "actorId": 1}):
                raise M11SessionCodecError("replay has an invalid trusted enemy wait record")
            cursor += 1
        commands.append(command)
        ticks.append(player.logical_tick)
        enemy_waits.append(has_enemy)
    return tuple(commands), tuple(ticks), tuple(enemy_waits)


def command_from_value(value: object) -> M10Command:
    """Decode a bool-free command payload and revalidate it with the M10 wire."""
    try:
        return decode_m10_command(value)
    except M10CommandJSONError as exc:
        raise M11SessionCodecError(str(exc)) from exc


def _snapshot_state(snapshot: FrozenPlaytestSnapshot,
                    restore_snapshot: WorldSnapshot | None = None,
                    restore_progression: M11Progression | None = None) -> dict[str, object]:
    if type(snapshot) is not FrozenPlaytestSnapshot:
        raise M11SessionCodecError("replay requires a frozen playtest snapshot")
    if (sha256(snapshot.canonical_json).hexdigest() != snapshot.content_hash or
            type(snapshot.rng_state) is not tuple or len(snapshot.rng_state) != 4 or
            type(snapshot.wait_ticks) is not int or snapshot.wait_ticks not in (30, 60, 120)):
        raise M11SessionCodecError("frozen snapshot identity or boot settings are invalid")
    initial_rng = (restore_snapshot.rng_state
                   if restore_snapshot is not None else snapshot.rng_state)
    initial = {"contentDigest": snapshot.content_hash,
               "rngState": list(initial_rng), "waitTicks": snapshot.wait_ticks}
    if restore_snapshot is not None:
        try:
            initial["restoreWorld"] = json.loads(encode_world_state(
                SaveIdentity(1, RULESET_VERSION, snapshot.content_hash),
                restore_snapshot))
        except (WorldStateError, ValueError) as exc:
            raise M11SessionCodecError(f"invalid replay restore world: {exc}") from exc
    if restore_progression is not None:
        if restore_snapshot is None:
            raise M11SessionCodecError("replay progression restore requires a restore world")
        if type(restore_progression) is not M11Progression:
            raise M11SessionCodecError("replay restore progression must be typed")
        if (restore_progression.ruleset != 7 or
                restore_progression.content_identity != int(snapshot.content_hash[:8], 16)):
            raise M11SessionCodecError("restore progression identity does not match replay content")
        try:
            initial["restoreProgression"] = encode_m11_progression(restore_progression)
        except M11ProgressionError as exc:
            raise M11SessionCodecError(f"invalid replay restore progression: {exc}") from exc
    return initial


def build_m11_replay(snapshot: FrozenPlaytestSnapshot,
                     commands: tuple[M10Command, ...], *, engine_build: str,
                     command_trace: tuple[CommandTraceStep, ...],
                     restore_snapshot: WorldSnapshot | None = None,
                     restore_progression: M11Progression | None = None) -> ReplayFile:
    """Create an M8 replay using logical ticks observed at accepted engine boundaries."""
    initial = _snapshot_state(snapshot, restore_snapshot, restore_progression)
    if type(commands) is not tuple or len(commands) > 4096:
        raise M11SessionCodecError("commands must be a tuple of at most 4096 records")
    if (type(command_trace) is not tuple or len(command_trace) != len(commands)
            or any(type(step) is not CommandTraceStep or step.command_index != index
                   or type(step.enemy_wait) is not bool
                   for index, step in enumerate(command_trace))):
        raise M11SessionCodecError("replay requires one authoritative timing trace step per command")
    try:
        encode_m10_commands(commands)
        records = tuple(row for index, (command, step) in enumerate(
            zip(commands, command_trace)) for row in _replay_rows(command, step, index + 1))
        header = ReplayHeader(RULESET_VERSION, snapshot.content_hash,
                              "xoshiro128ss-1.1", tuple(initial["rngState"]),
                              snapshot.wait_ticks, engine_build, initial)
        return ReplayFile(header, records)
    except (ReplayFileError, TypeError, ValueError) as exc:
        raise M11SessionCodecError(f"could not create M11 replay: {exc}") from exc


@dataclass(frozen=True, slots=True)
class M11ReplayVerification:
    response: RuntimeResponse
    replay_digest: str


def verify_m11_replay(replay: ReplayFile, snapshot: FrozenPlaytestSnapshot, *,
                      executable_path: str,
                      runtime: Callable[..., RuntimeResponse] = run_runtime) -> M11ReplayVerification:
    """Verify an entire replay by resubmitting it through the packaged Bend runtime."""
    base_initial = _snapshot_state(snapshot)
    initial_state = replay.header.initial_state
    restore_snapshot = None
    restore_progression = None
    if type(initial_state) is dict and ("restoreWorld" in initial_state or
                                        "restoreProgression" in initial_state):
        extras = set(initial_state) - set(base_initial)
        if "restoreWorld" not in extras or extras - {"restoreWorld", "restoreProgression"}:
            raise M11SessionCodecError("replay restore initial state has unexpected fields")
        try:
            restore_snapshot = decode_world_state(
                json.dumps(initial_state["restoreWorld"], sort_keys=True,
                           separators=(",", ":")).encode("utf-8"),
                SaveIdentity(1, RULESET_VERSION, snapshot.content_hash))
        except (WorldStateError, ValueError, TypeError) as exc:
            raise M11SessionCodecError(f"invalid replay restore world: {exc}") from exc
        if "restoreProgression" in initial_state:
            try:
                restore_progression = decode_m11_progression(initial_state["restoreProgression"])
            except M11ProgressionError as exc:
                raise M11SessionCodecError(f"invalid replay restore progression: {exc}") from exc
    expected_initial = _snapshot_state(snapshot, restore_snapshot, restore_progression)
    if (replay.header.ruleset_version != RULESET_VERSION or
            replay.header.content_digest != snapshot.content_hash or
            replay.header.rng_state != tuple(expected_initial["rngState"]) or
            replay.header.wait_ticks != snapshot.wait_ticks or
            replay.header.initial_state != expected_initial):
        raise M11SessionCodecError("replay identity or initial state does not match frozen snapshot")
    if replay.terminal:
        raise M11SessionCodecError("M10 maker runs cannot claim an authoritative terminal result")
    commands, ticks, enemy_waits = _maker_commands(replay)
    try:
        encode_m10_commands(commands)
        options = ({"restore_snapshot": restore_snapshot}
                   if restore_snapshot is not None else {})
        if restore_progression is not None:
            options["restore_progression"] = restore_progression
        response = runtime(snapshot, commands, executable_path=executable_path,
                           **options)
    except Exception as exc:
        raise M11SessionCodecError(f"authoritative replay runtime failed: {exc}") from exc
    if (type(response) is not RuntimeResponse or
            response.content_hash != snapshot.content_hash or
            response.accepted_commands != len(commands) or
            response.status not in {"accepted", "encounter", "battle"}):
        raise M11SessionCodecError("authoritative runtime did not accept the complete replay")
    if (len(response.command_trace) != len(commands) or
            any(step.command_index != index or step.logical_tick != ticks[index]
                or step.enemy_wait != enemy_waits[index]
                for index, step in enumerate(response.command_trace))):
        raise M11SessionCodecError(
            "authoritative replay timing differs or generated enemy wait mismatches recorded rows")
    # A terminal checkpoint cannot be checked from M10's display-only response.
    if replay.checkpoints:
        raise M11SessionCodecError("M10 runtime does not expose state hashes for replay checkpoints")
    return M11ReplayVerification(response, sha256(encode_replay(replay)).hexdigest())


__all__ = ["M11ReplayVerification", "M11SessionCodecError", "RULESET_VERSION",
           "build_m11_replay", "command_from_value", "command_to_value",
           "verify_m11_replay"]
