"""Exact-identity numeric binding for the headless M8 world.

Call ``bind_m8_content(load_project(root), expected_ruleset_version="m8-1",
expected_content_digest=save.content_digest)`` at a stable world boundary.
The returned records contain only validated inert values and dense IDs.
"""
from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from types import MappingProxyType
from typing import Mapping

from .m7_binding import M7ContentBinding, bind_m7_content
from .models import Encounter, EncounterEntry, EventGraph, LoadedProject, MapRecord
from .world import WorldRecordError, validate_world_records

M8_RULESET_VERSION = "m8-1"


class M8BindingError(ValueError):
    """The world cannot be bound to the requested ruleset and content."""


@dataclass(frozen=True, slots=True)
class SignedCoord:
    negative: bool
    magnitude: int


@dataclass(frozen=True, slots=True)
class BoundPoint:
    x: SignedCoord
    y: SignedCoord
    z: SignedCoord


@dataclass(frozen=True, slots=True)
class BoundRegion:
    id: int
    encounter_id: int
    faces: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class BoundNpc:
    id: int
    point: BoundPoint
    event_id: int | None


@dataclass(frozen=True, slots=True)
class BoundTrigger:
    id: int
    vertices: tuple[int, ...]
    event_id: int


@dataclass(frozen=True, slots=True)
class BoundTransition:
    id: int
    target_map_id: int
    vertices: tuple[int, ...]
    destination: BoundPoint


@dataclass(frozen=True, slots=True)
class BoundMap:
    id: int
    vertices: tuple[BoundPoint, ...]
    faces: tuple[tuple[int, int, int], ...]
    links: tuple[tuple[int, int], ...]
    regions: tuple[BoundRegion, ...]
    npcs: tuple[BoundNpc, ...]
    triggers: tuple[BoundTrigger, ...]
    transitions: tuple[BoundTransition, ...]


@dataclass(frozen=True, slots=True)
class BoundEventNode:
    id: int
    opcode: str
    arguments: tuple[tuple[str, int], ...]
    successors: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class BoundEventGraph:
    id: int
    entry: int
    nodes: tuple[BoundEventNode, ...]


@dataclass(frozen=True, slots=True)
class BoundEncounterEntry:
    species_id: int
    weight: int
    min_level: int
    max_level: int


@dataclass(frozen=True, slots=True)
class BoundEncounter:
    id: int
    entries: tuple[BoundEncounterEntry, ...]


@dataclass(frozen=True, slots=True)
class M8ContentBinding:
    ruleset_version: str
    content_digest: str
    content_identity: int
    entry_map_id: int
    maps: tuple[BoundMap, ...]
    events: tuple[BoundEventGraph, ...]
    encounters: tuple[BoundEncounter, ...]
    map_ids: Mapping[str, int]
    event_ids: Mapping[str, int]
    encounter_ids: Mapping[str, int]
    transition_ids: Mapping[tuple[str, str], int]
    m7: M7ContentBinding


def _coordinate(value: int) -> SignedCoord:
    return SignedCoord(value < 0, abs(value))


def _point(x: int, y: int, z: int) -> BoundPoint:
    return BoundPoint(_coordinate(x), _coordinate(y), _coordinate(z))


def _sorted_ids(values: tuple[object, ...]) -> dict[str, int]:
    return {value: index for index, value in enumerate(sorted(map(str, values)), 1)}


def _check_identity(loaded: LoadedProject, ruleset: str, digest: str) -> None:
    if type(loaded) is not LoadedProject:
        raise M8BindingError("M8 world binding requires a LoadedProject record")
    if ruleset != M8_RULESET_VERSION:
        raise M8BindingError(
            f"M8 world binding requires ruleset {M8_RULESET_VERSION!r}; got {ruleset!r}"
        )
    actual_digest = sha256(loaded.canonical_json).hexdigest()
    if actual_digest != loaded.content_hash:
        raise M8BindingError("loaded project content hash does not match its canonical bytes")
    if digest != actual_digest:
        raise M8BindingError(
            f"M8 world content identity mismatch: expected {digest!r}, "
            f"loaded {actual_digest!r}"
        )


def _bind_map(row: MapRecord, map_ids: Mapping[str, int],
              event_ids: Mapping[str, int],
              encounter_ids: Mapping[str, int],
              transition_ids: Mapping[tuple[str, str], int]) -> BoundMap:
    if row.navigation is None:
        raise M8BindingError(f"map {row.id!s} has no baked navigation surface")
    nav = row.navigation
    regions = tuple(
        BoundRegion(index, encounter_ids[str(region.encounter)], region.faces)
        for index, region in enumerate(sorted(row.encounter_regions,
                                               key=lambda part: part.id), 1)
    )
    npcs = tuple(
        BoundNpc(index, _point(npc.x, npc.y, npc.z),
                 event_ids[str(npc.event)] if npc.event is not None else None)
        for index, npc in enumerate(sorted(row.npcs, key=lambda part: str(part.id)), 1)
    )
    triggers = tuple(
        BoundTrigger(index, trigger.vertices, event_ids[str(trigger.event)])
        for index, trigger in enumerate(sorted(row.triggers,
                                               key=lambda part: str(part.id)), 1)
    )
    transitions = tuple(
        BoundTransition(transition_ids[(str(row.id), str(transition.id))],
                        map_ids[str(transition.target_map)],
                        transition.vertices,
                        _point(transition.x, transition.y, transition.z))
        for transition in sorted(row.transitions, key=lambda part: part.id)
    )
    return BoundMap(
        map_ids[str(row.id)],
        tuple(_point(vertex.x, vertex.y, vertex.z) for vertex in nav.vertices),
        tuple((face.a, face.b, face.c) for face in nav.faces),
        tuple((link.from_face, link.to_face) for link in nav.links),
        regions, npcs, triggers, transitions,
    )


def _bind_event_graph(row: EventGraph,
                      event_ids: Mapping[str, int]) -> BoundEventGraph:
    return BoundEventGraph(
        event_ids[str(row.id)], row.entry,
        tuple(BoundEventNode(node.id, node.opcode, node.arguments, node.next)
              for node in sorted(row.nodes, key=lambda part: part.id)),
    )


def _bind_encounters(loaded: LoadedProject,
                     encounter_ids: Mapping[str, int],
                     species_ids: Mapping[str, int]) -> tuple[BoundEncounter, ...]:
    bound: list[BoundEncounter] = []
    for row in sorted(loaded.encounters, key=lambda part: str(part.id)):
        if type(row) is not Encounter or type(row.entries) is not tuple:
            raise M8BindingError("malformed encounter record in M8 content")
        entries: list[BoundEncounterEntry] = []
        for entry in row.entries:
            if (type(entry) is not EncounterEntry
                    or type(entry.weight) is not int
                    or not 1 <= entry.weight <= 10000
                    or type(entry.min_level) is not int
                    or type(entry.max_level) is not int
                    or not 1 <= entry.min_level <= entry.max_level <= 200
                    or (entry.level is not None and
                        (type(entry.level) is not int
                         or entry.level != entry.min_level
                         or entry.level != entry.max_level))):
                raise M8BindingError(f"encounter {row.id!s} has an invalid entry")
            species_id = species_ids.get(str(entry.species))
            if species_id is None:
                raise M8BindingError(
                    f"encounter {row.id!s} references unknown species {entry.species!s}"
                )
            entries.append(BoundEncounterEntry(species_id, entry.weight,
                                                entry.min_level,
                                                entry.max_level))
        numeric_id = encounter_ids.get(str(row.id))
        if numeric_id is None:
            raise M8BindingError(f"encounter {row.id!s} has no numeric binding")
        bound.append(BoundEncounter(numeric_id, tuple(entries)))
    return tuple(bound)


def bind_m8_content(loaded: LoadedProject, *, expected_ruleset_version: str,
                    expected_content_digest: str) -> M8ContentBinding:
    """Bind a strictly loaded M8 project under the save's exact identity."""
    _check_identity(loaded, expected_ruleset_version, expected_content_digest)
    try:
        validate_world_records(loaded)
    except WorldRecordError as error:
        raise M8BindingError(str(error)) from error
    map_ids = _sorted_ids(tuple(row.id for row in loaded.maps))
    event_ids = _sorted_ids(tuple(row.id for row in loaded.events))
    encounter_ids = _sorted_ids(tuple(row.id for row in loaded.encounters))
    # Fast-travel unlocks persist numeric transition IDs across map changes.
    # Namespace authored IDs by their source map before assigning dense IDs.
    transition_keys = sorted(
        (str(row.id), str(transition.id))
        for row in loaded.maps for transition in row.transitions
    )
    transition_ids = {key: index for index, key in enumerate(transition_keys, 1)}
    if str(loaded.project.entry_map) not in map_ids:
        raise M8BindingError(
            f"entry map {loaded.project.entry_map!s} is absent from loaded maps"
        )
    maps = tuple(_bind_map(row, map_ids, event_ids, encounter_ids, transition_ids)
                 for row in sorted(loaded.maps, key=lambda part: str(part.id)))
    events = tuple(_bind_event_graph(row, event_ids)
                   for row in sorted(loaded.events, key=lambda part: str(part.id)))
    species_ids = _sorted_ids(tuple(row.id for row in loaded.species))
    encounters = _bind_encounters(loaded, encounter_ids, species_ids)
    m7 = bind_m7_content(loaded)
    # Bend's immediate Nat representation is bounded; this numeric runtime
    # token is derived only after the full SHA-256 digest has been checked.
    # Saves and replay envelopes continue to compare the full digest.
    return M8ContentBinding(
        M8_RULESET_VERSION, loaded.content_hash, int(loaded.content_hash[:8], 16),
        map_ids[str(loaded.project.entry_map)], maps, events, encounters,
        MappingProxyType(map_ids), MappingProxyType(event_ids),
        MappingProxyType(encounter_ids), MappingProxyType(transition_ids), m7,
    )
