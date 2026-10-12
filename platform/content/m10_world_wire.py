"""Versioned bounded numeric wire for bound M8 runtime world records.

Wire v2 carries baked navigation, encounter regions, NPCs, trigger polygons,
and transitions. Event graphs and encounter tables remain joined-catalog data;
world records carry only their already-bound positive numeric references.
"""
from __future__ import annotations

from dataclasses import dataclass

from .m8_binding import (
    BoundMap, BoundNpc, BoundPoint, BoundRegion, BoundTransition, BoundTrigger,
    M8ContentBinding, SignedCoord,
)
from .world_limits import MAX_ENTITIES, MAX_PER_RECORD, MAX_TOTAL_REFS, WORLD_COORD_LIMIT

MAGIC = 10
WIRE_VERSION = 2
MAX_WIRE_TOKENS = 140_000
MAX_WIRE_BYTES = 2 << 20
MAX_U32 = 0xFFFFFFFF


class M10WorldWireError(ValueError):
    """The bound world is malformed or exceeds the numeric wire contract."""


@dataclass(frozen=True, slots=True)
class M10WorldWire:
    version: int
    tokens: tuple[int, ...]
    text: str


def _nat(value: object, label: str, maximum: int = MAX_U32,
         minimum: int = 0) -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise M10WorldWireError(
            f"{label} must be an integer in [{minimum}, {maximum}]"
        )
    return value


def _point_tokens(point: object, label: str) -> list[int]:
    if type(point) is not BoundPoint:
        raise M10WorldWireError(f"{label} is not a bound point")
    result: list[int] = []
    for coord in (point.x, point.y, point.z):
        if type(coord) is not SignedCoord:
            raise M10WorldWireError(f"{label} contains a malformed coordinate")
        magnitude = _nat(coord.magnitude, f"{label} coordinate magnitude",
                         WORLD_COORD_LIMIT)
        if type(coord.negative) is not bool or (coord.negative and magnitude == 0):
            raise M10WorldWireError(f"{label} contains a noncanonical coordinate")
        result.extend((1 if coord.negative else 0, magnitude))
    return result


def _signed_value(coord: SignedCoord) -> int:
    return -coord.magnitude if coord.negative else coord.magnitude


def _orientation(a: tuple[int, int], b: tuple[int, int],
                 c: tuple[int, int]) -> int:
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def _on_segment(a: tuple[int, int], point: tuple[int, int],
                b: tuple[int, int]) -> bool:
    return (min(a[0], b[0]) <= point[0] <= max(a[0], b[0])
            and min(a[1], b[1]) <= point[1] <= max(a[1], b[1]))


def _segments_intersect(a: tuple[int, int], b: tuple[int, int],
                        c: tuple[int, int], d: tuple[int, int]) -> bool:
    ab_c, ab_d = _orientation(a, b, c), _orientation(a, b, d)
    cd_a, cd_b = _orientation(c, d, a), _orientation(c, d, b)
    if ((ab_c > 0 > ab_d or ab_d > 0 > ab_c)
            and (cd_a > 0 > cd_b or cd_b > 0 > cd_a)):
        return True
    return ((ab_c == 0 and _on_segment(a, c, b))
            or (ab_d == 0 and _on_segment(a, d, b))
            or (cd_a == 0 and _on_segment(c, a, d))
            or (cd_b == 0 and _on_segment(c, b, d)))


def _polygon(values: object, vertices: tuple[BoundPoint, ...],
             label: str) -> tuple[int, ...]:
    vertex_count = len(vertices)
    if type(values) is not tuple or not 3 <= len(values) <= MAX_PER_RECORD:
        raise M10WorldWireError(f"{label} must contain 3..{MAX_PER_RECORD} vertices")
    indices = tuple(_nat(value, f"{label} vertex index", vertex_count - 1)
                    for value in values)
    if len(set(indices)) != len(indices):
        raise M10WorldWireError(f"{label} contains duplicate vertex indices")
    points = tuple((_signed_value(vertices[index].x),
                    _signed_value(vertices[index].z)) for index in indices)
    area = sum(points[index][0] * points[(index + 1) % len(points)][1]
               - points[(index + 1) % len(points)][0] * points[index][1]
               for index in range(len(points)))
    if area == 0:
        raise M10WorldWireError(f"{label} has zero horizontal area")
    for first in range(len(points)):
        a, b = points[first], points[(first + 1) % len(points)]
        for second in range(first + 1, len(points)):
            if second == first + 1 or (first == 0 and second == len(points) - 1):
                continue
            if _segments_intersect(a, b, points[second],
                                   points[(second + 1) % len(points)]):
                raise M10WorldWireError(f"{label} has self-intersecting edges")
    return indices


def encode_m10_world(binding: M8ContentBinding) -> M10WorldWire:
    """Encode a validated binding; event and encounter references stay numeric."""
    if type(binding) is not M8ContentBinding:
        raise M10WorldWireError("expected a validated M8ContentBinding")
    if binding.ruleset_version != "m8-1":
        raise M10WorldWireError("wire source must use ruleset 'm8-1'")
    if not 1 <= len(binding.maps) <= MAX_ENTITIES:
        raise M10WorldWireError("map count is outside the supported range")
    if any(type(row) is not BoundMap for row in binding.maps):
        raise M10WorldWireError("binding contains a malformed map record")
    map_ids = {_nat(row.id, "map id", minimum=1) for row in binding.maps}
    if len(map_ids) != len(binding.maps):
        raise M10WorldWireError("map IDs must be unique")
    entry = _nat(binding.entry_map_id, "entry map id", minimum=1)
    if entry not in map_ids:
        raise M10WorldWireError("entry map does not resolve in the bound catalog")
    event_ids = {_nat(row.id, "event id", minimum=1) for row in binding.events}
    encounter_ids = {_nat(row.id, "encounter id", minimum=1)
                      for row in binding.encounters}
    tokens = [MAGIC, WIRE_VERSION,
              _nat(binding.content_identity, "content identity"), entry,
              len(binding.maps)]
    total_refs = 0
    total_regions = total_npcs = total_triggers = total_transitions = 0

    for row in binding.maps:
        if (type(row.vertices) is not tuple or not 3 <= len(row.vertices) <= MAX_ENTITIES
                or type(row.faces) is not tuple or not 1 <= len(row.faces) <= MAX_ENTITIES
                or type(row.links) is not tuple or len(row.links) > MAX_TOTAL_REFS):
            raise M10WorldWireError(f"map {row.id} has malformed navigation arrays")
        total_refs += 3 * len(row.faces) + 2 * len(row.links)
        tokens.extend((_nat(row.id, "map id", minimum=1), len(row.vertices)))
        for index, point in enumerate(row.vertices):
            tokens.extend(_point_tokens(point, f"map {row.id} vertex {index}"))
        tokens.append(len(row.faces))
        for face in row.faces:
            if (type(face) is not tuple or len(face) != 3
                    or any(type(index) is not int or not 0 <= index < len(row.vertices)
                           for index in face)
                    or len(set(face)) != 3):
                raise M10WorldWireError(f"map {row.id} has an invalid navigation face")
            tokens.extend(face)
        tokens.append(len(row.links))
        for link in row.links:
            if (type(link) is not tuple or len(link) != 2
                    or any(type(index) is not int or not 0 <= index < len(row.faces)
                           for index in link)):
                raise M10WorldWireError(f"map {row.id} has an invalid navigation link")
            tokens.extend(link)

        regions = row.regions
        npcs = row.npcs
        triggers = row.triggers
        transitions = row.transitions
        for label, values in (("regions", regions), ("NPCs", npcs),
                              ("triggers", triggers), ("transitions", transitions)):
            if type(values) is not tuple or len(values) > MAX_ENTITIES:
                raise M10WorldWireError(f"map {row.id} {label} exceed the supported bound")

        total_regions += len(regions)
        total_npcs += len(npcs)
        total_triggers += len(triggers)
        total_transitions += len(transitions)
        tokens.append(len(regions))
        region_faces: set[int] = set()
        for region in regions:
            if type(region) is not BoundRegion:
                raise M10WorldWireError(f"map {row.id} contains a malformed region")
            region_id = _nat(region.id, "region id", maximum=MAX_PER_RECORD,
                             minimum=1)
            encounter_id = _nat(region.encounter_id, "region encounter id", minimum=1)
            if encounter_id not in encounter_ids:
                raise M10WorldWireError(f"region {region_id} references unknown encounter ID")
            if (type(region.faces) is not tuple or not region.faces
                    or len(region.faces) > MAX_PER_RECORD):
                raise M10WorldWireError(f"region {region_id} has an invalid face-reference count")
            faces = tuple(_nat(face, "region face index", len(row.faces) - 1)
                          for face in region.faces)
            if len(set(faces)) != len(faces):
                raise M10WorldWireError(f"region {region_id} repeats a face")
            if region_faces.intersection(faces):
                raise M10WorldWireError("encounter regions overlap on a navigation face")
            region_faces.update(faces)
            total_refs += len(faces)
            tokens.extend((region_id, encounter_id, len(faces), *faces))

        tokens.append(len(npcs))
        for npc in npcs:
            if type(npc) is not BoundNpc:
                raise M10WorldWireError(f"map {row.id} contains a malformed NPC")
            npc_id = _nat(npc.id, "NPC id", maximum=MAX_PER_RECORD, minimum=1)
            event_id = 0 if npc.event_id is None else _nat(npc.event_id, "NPC event id", minimum=1)
            if event_id and event_id not in event_ids:
                raise M10WorldWireError(f"NPC {npc_id} references unknown event ID")
            tokens.extend((npc_id, event_id, *_point_tokens(npc.point,
                                                              f"NPC {npc_id} point")))

        tokens.append(len(triggers))
        for trigger in triggers:
            if type(trigger) is not BoundTrigger:
                raise M10WorldWireError(f"map {row.id} contains a malformed trigger")
            trigger_id = _nat(trigger.id, "trigger id", maximum=MAX_PER_RECORD,
                              minimum=1)
            event_id = _nat(trigger.event_id, "trigger event id", minimum=1)
            if event_id not in event_ids:
                raise M10WorldWireError(f"trigger {trigger_id} references unknown event ID")
            polygon = _polygon(trigger.vertices, row.vertices,
                               f"trigger {trigger_id}")
            total_refs += len(polygon)
            tokens.extend((trigger_id, event_id, len(polygon), *polygon))

        tokens.append(len(transitions))
        for transition in transitions:
            if type(transition) is not BoundTransition:
                raise M10WorldWireError(f"map {row.id} contains a malformed transition")
            transition_id = _nat(transition.id, "transition id", maximum=MAX_U32,
                                 minimum=1)
            target_map = _nat(transition.target_map_id, "transition target map id", minimum=1)
            if target_map not in map_ids:
                raise M10WorldWireError(
                    f"transition {transition_id} references unknown target map ID"
                )
            polygon = _polygon(transition.vertices, row.vertices,
                               f"transition {transition_id}")
            total_refs += len(polygon)
            tokens.extend((transition_id, target_map,
                           *_point_tokens(transition.destination,
                                          f"transition {transition_id} destination"),
                           len(polygon), *polygon))

    if max(total_regions, total_npcs, total_triggers, total_transitions) > MAX_ENTITIES:
        raise M10WorldWireError("world entity total exceeds the supported bound")
    if total_refs > MAX_TOTAL_REFS:
        raise M10WorldWireError("world reference total exceeds the supported bound")
    if len(tokens) > MAX_WIRE_TOKENS:
        raise M10WorldWireError("numeric wire token count exceeds the supported bound")
    text = " ".join(map(str, tokens))
    if len(text.encode("ascii")) > MAX_WIRE_BYTES:
        raise M10WorldWireError("numeric wire bytes exceed the supported bound")
    return M10WorldWire(WIRE_VERSION, tuple(tokens), text)
