"""Bounded host parser for the observational Bend M9 scene and cue records."""
from __future__ import annotations

from dataclasses import dataclass
import re


class SceneWireError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class NpcView:
    id: int
    x: int
    y: int
    z: int
    event_id: int | None


@dataclass(frozen=True, slots=True)
class ActorView:
    id: int
    side: int
    hp: int
    phase: int


@dataclass(frozen=True, slots=True)
class BattleView:
    tick: int
    status: int
    actors: tuple[ActorView, ...]


@dataclass(frozen=True, slots=True)
class SceneView:
    content_identity: int
    map_id: int
    x: int
    y: int
    z: int
    facing: int
    npcs: tuple[NpcView, ...]
    battle: BattleView | None
    camera_anchor: tuple[int, int, int] | None = None


@dataclass(frozen=True, slots=True)
class CueView:
    ordinal: int
    index: int
    kind: int
    payload: int
    aux: int


class _Fields:
    def __init__(self, line: str):
        if len(line) > 16384 or not re.fullmatch(r"(?:0|[1-9][0-9]*)(?:,(?:0|[1-9][0-9]*))*", line):
            raise SceneWireError("M9 wire must be one bounded ASCII numeric CSV line")
        self.parts = line.split(",")
        if any(len(part) > 10 for part in self.parts):
            raise SceneWireError("M9 wire fields must fit unsigned U32")
        self.position = 0

    def take(self, maximum: int = 0xffffffff) -> int:
        if self.position >= len(self.parts):
            raise SceneWireError("M9 wire ended before all required fields")
        value = int(self.parts[self.position])
        self.position += 1
        if value > maximum:
            raise SceneWireError(f"M9 field {self.position} exceeds {maximum}")
        return value

    def coord(self) -> int:
        sign, magnitude = self.take(1), self.take(524288)
        if sign and magnitude == 0:
            raise SceneWireError("M9 coordinate has noncanonical negative zero")
        return -magnitude if sign else magnitude

    def finish(self) -> None:
        if self.position != len(self.parts):
            raise SceneWireError("M9 wire contains trailing fields")


def parse_scene(line: str) -> SceneView:
    """Parse the version-1 Bend projection wire; reject malformed/oversized data."""
    fields = _Fields(line)
    if fields.take(1) != 1:
        raise SceneWireError("M9 scene wire version must be 1")
    identity, map_id = fields.take(), fields.take()
    x, y, z = fields.coord(), fields.coord(), fields.coord()
    facing = fields.take(3)
    camera_anchor = (fields.coord(), fields.coord(), fields.coord())
    count = fields.take(64)
    npcs: list[NpcView] = []
    npc_ids: set[int] = set()
    for _ in range(count):
        npc_id = fields.take()
        if npc_id in npc_ids:
            raise SceneWireError(f"M9 duplicate visible NPC ID {npc_id}")
        npc_ids.add(npc_id)
        nx, ny, nz = fields.coord(), fields.coord(), fields.coord()
        has_event, event_id = fields.take(1), fields.take()
        if not has_event and event_id:
            raise SceneWireError("M9 absent NPC event must have zero ID")
        npcs.append(NpcView(npc_id, nx, ny, nz,
                            event_id if has_event else None))
    has_battle = fields.take(1)
    battle = None
    if has_battle:
        tick, status, actor_count = fields.take(), fields.take(7), fields.take(64)
        actors = tuple(ActorView(fields.take(), fields.take(1), fields.take(),
                                 fields.take(4)) for _ in range(actor_count))
        if len({actor.id for actor in actors}) != len(actors):
            raise SceneWireError("M9 duplicate battle actor ID")
        battle = BattleView(tick, status, actors)
    fields.finish()
    return SceneView(identity, map_id, x, y, z, facing, tuple(npcs), battle,
                     camera_anchor)


def parse_cues(line: str) -> tuple[CueView, ...]:
    """Parse occurrence-labelled cues in authoritative emission order."""
    fields = _Fields(line)
    if fields.take(1) != 1:
        raise SceneWireError("M9 cue wire version must be 1")
    count = fields.take(256)
    cues = tuple(CueView(fields.take(), fields.take(), fields.take(3),
                         fields.take(), fields.take()) for _ in range(count))
    fields.finish()
    if len({(cue.ordinal, cue.index) for cue in cues}) != len(cues):
        raise SceneWireError("M9 cue occurrence IDs must be unique")
    previous_ordinal, previous_index = -1, -1
    for cue in cues:
        if cue.index > 255 or cue.ordinal < previous_ordinal or (
            cue.ordinal == previous_ordinal and cue.index != previous_index + 1
        ) or (cue.ordinal > previous_ordinal and cue.index != 0):
            raise SceneWireError("M9 cue order or index is invalid")
        if (cue.kind in (0, 1, 2) and cue.aux != 0) or (
            cue.kind == 3 and (cue.payload > 2 or (cue.payload == 2 and cue.aux != 0))
        ):
            raise SceneWireError("M9 cue payload is invalid")
        previous_ordinal, previous_index = cue.ordinal, cue.index
    return cues
