"""Pure validation for immutable M8 world records at the runtime boundary."""
from __future__ import annotations

import re

from .models import (Encounter, EventGraph, EventNode, EncounterRegion,
                     LoadedProject, MapRecord, MapTransition, NavLink,
                     NavSurface, NavTriangle, NavVertex, NpcRecord,
                     TriggerRecord)
from .world_limits import (EVENT_BYTES_LIMIT, EVENT_VALUE_LIMIT, MAX_ENTITIES,
                           MAX_PER_RECORD, MAX_TOTAL_REFS, WORLD_COORD_LIMIT)

_CONTENT_ID = re.compile(r"[a-z][a-z0-9_-]{0,31}:[a-z][a-z0-9_-]{0,31}\Z")

class WorldRecordError(ValueError):
    """A typed world record violates the Content-0 world boundary."""


def _record_polygon_valid(indices: tuple[int, ...],
                          vertices: tuple[NavVertex, ...]) -> bool:
    if (type(indices) is not tuple or len(indices) < 3
            or len(indices) != len(set(indices))
            or any(type(index) is not int or not 0 <= index < len(vertices)
                   for index in indices)):
        return False
    points = [vertices[index] for index in indices]
    area = sum(points[i].x * points[(i + 1) % len(points)].z
               - points[(i + 1) % len(points)].x * points[i].z
               for i in range(len(points)))
    if area == 0:
        return False
    for first in range(len(points)):
        a, b = points[first], points[(first + 1) % len(points)]
        for second in range(first + 1, len(points)):
            if second == first + 1 or (first == 0 and second == len(points) - 1):
                continue
            if _segments_intersect(a, b, points[second],
                                   points[(second + 1) % len(points)]):
                return False
    return True


def _validate_surface(surface: NavSurface, map_id: str) -> None:
    if (type(surface) is not NavSurface or type(surface.vertices) is not tuple
            or type(surface.faces) is not tuple or type(surface.links) is not tuple):
        raise WorldRecordError(f"map {map_id}: malformed navigation record")
    vertices, faces = surface.vertices, surface.faces
    if not 3 <= len(vertices) <= MAX_PER_RECORD or not 1 <= len(faces) <= MAX_PER_RECORD:
        raise WorldRecordError(f"map {map_id}: navigation vertex/face count is out of bounds")
    for vertex in vertices:
        if (type(vertex) is not NavVertex or any(
                type(coord) is not int or not -WORLD_COORD_LIMIT <= coord <= WORLD_COORD_LIMIT
                for coord in (vertex.x, vertex.y, vertex.z))):
            raise WorldRecordError(f"map {map_id}: navigation coordinate is out of bounds")
    face_keys: set[tuple[int, int, int]] = set()
    for face in faces:
        if type(face) is not NavTriangle:
            raise WorldRecordError(f"map {map_id}: malformed navigation face")
        indices = (face.a, face.b, face.c)
        if any(type(index) is not int or not 0 <= index < len(vertices)
               for index in indices) or len(set(indices)) != 3:
            raise WorldRecordError(f"map {map_id}: invalid navigation face index")
        a, b, c = (vertices[index] for index in indices)
        if (b.x - a.x) * (c.z - a.z) == (b.z - a.z) * (c.x - a.x):
            raise WorldRecordError(f"map {map_id}: degenerate navigation face")
        key = tuple(sorted(indices))
        if key in face_keys:
            raise WorldRecordError(f"map {map_id}: duplicate navigation face")
        face_keys.add(key)
    link_keys: set[tuple[int, int]] = set()
    for link in surface.links:
        if type(link) is not NavLink:
            raise WorldRecordError(f"map {map_id}: malformed navigation link")
        pair = (link.from_face, link.to_face)
        if (any(type(index) is not int or not 0 <= index < len(faces)
                for index in pair) or pair[0] == pair[1] or pair in link_keys):
            raise WorldRecordError(f"map {map_id}: invalid navigation face link")
        shared = set((faces[pair[0]].a, faces[pair[0]].b, faces[pair[0]].c)) & set(
            (faces[pair[1]].a, faces[pair[1]].b, faces[pair[1]].c))
        if len(shared) < 2:
            raise WorldRecordError(f"map {map_id}: linked faces do not share a surface edge")
        link_keys.add(pair)


def _validate_event_graph(graph: EventGraph) -> None:
    if type(graph) is not EventGraph or type(graph.nodes) is not tuple:
        raise WorldRecordError("malformed event graph record")
    count = len(graph.nodes)
    if (type(graph.entry) is not int or not 1 <= count <= MAX_PER_RECORD
            or not 0 <= graph.entry < count):
        raise WorldRecordError(f"event {graph.id}: entry or node count is invalid")
    edges: list[tuple[int, ...]] = []
    op_fields = {"setValue": {"key", "value"}, "addEntity": {"entity", "bytes"},
                 "emitSignal": {"kind", "bytes"}, "wait": {"ticks"},
                 "choice": {"prompt"}, "stop": set()}
    arities = {"setValue": 1, "addEntity": 1, "emitSignal": 1,
               "wait": 1, "choice": 2, "stop": 0}
    for index, node in enumerate(graph.nodes):
        if (type(node) is not EventNode or type(node.id) is not int
                or node.id != index or type(node.opcode) is not str
                or node.opcode not in op_fields or type(node.next) is not tuple
                or type(node.arguments) is not tuple):
            raise WorldRecordError(f"event {graph.id}: node IDs/opcodes are not canonical")
        if any(type(pair) is not tuple or len(pair) != 2
               or type(pair[0]) is not str for pair in node.arguments):
            raise WorldRecordError(f"event {graph.id}: malformed opcode arguments")
        args = dict(node.arguments)
        if len(args) != len(node.arguments) or set(args) != op_fields[node.opcode]:
            raise WorldRecordError(f"event {graph.id}: node has invalid opcode arguments")
        if (len(node.next) != arities[node.opcode]
                or any(type(target) is not int or not 0 <= target < count
                       for target in node.next)):
            raise WorldRecordError(f"event {graph.id}: node successor is invalid")
        for key, value in args.items():
            limit = EVENT_BYTES_LIMIT if key == "bytes" else EVENT_VALUE_LIMIT
            if type(value) is not int or not 0 <= value <= limit:
                raise WorldRecordError(f"event {graph.id}: node argument is out of bounds")
        edges.append(node.next)
    colors = [0] * count
    for start in range(count):
        if colors[start]:
            continue
        stack: list[tuple[int, bool]] = [(start, False)]
        while stack:
            current, leaving = stack.pop()
            if leaving:
                colors[current] = 2
            elif colors[current] == 1:
                raise WorldRecordError(f"event {graph.id}: immediate cycle")
            elif colors[current] == 0:
                colors[current] = 1
                stack.append((current, True))
                stack.extend((target, False) for target in reversed(edges[current]))


def validate_world_records(loaded: LoadedProject) -> None:
    """Recheck typed world data before binding, including caller-built records."""
    from .world import _point_on_surface, _segments_intersect
    globals()["_point_on_surface"] = _point_on_surface
    globals()["_segments_intersect"] = _segments_intersect
    if (type(loaded.maps) is not tuple or type(loaded.events) is not tuple
            or type(loaded.encounters) is not tuple
            or any(type(record) is not MapRecord for record in loaded.maps)
            or any(type(graph) is not EventGraph for graph in loaded.events)
            or any(type(record) is not Encounter for record in loaded.encounters)):
        raise WorldRecordError("loaded world collections contain malformed records")
    if (len(loaded.maps) > MAX_ENTITIES or len(loaded.encounters) > MAX_ENTITIES
            or len(loaded.events) > MAX_ENTITIES):
        raise WorldRecordError("loaded map, encounter, or event count exceeds Content-0 limit")
    for identity in [*(str(record.id) for record in loaded.maps),
                     *(str(graph.id) for graph in loaded.events),
                     *(str(record.id) for record in loaded.encounters)]:
        if not _CONTENT_ID.fullmatch(identity):
            raise WorldRecordError(f"invalid typed content ID {identity!r}")
    maps = {str(record.id): record for record in loaded.maps}
    events = {str(graph.id): graph for graph in loaded.events}
    encounters = {str(encounter.id) for encounter in loaded.encounters}
    if len(maps) != len(loaded.maps) or len(events) != len(loaded.events):
        raise WorldRecordError("duplicate map or event ID")
    if len(loaded.events) > MAX_ENTITIES:
        raise WorldRecordError("event graph count exceeds Content-0 entity limit")
    event_nodes = sum(len(graph.nodes) for graph in loaded.events)
    if event_nodes > MAX_ENTITIES:
        raise WorldRecordError("event node count exceeds Content-0 entity limit")
    for graph in loaded.events:
        _validate_event_graph(graph)
    world_ids: dict[str, set[str]] = {kind: set() for kind in
                                      ("npc", "trigger", "region", "transition")}
    total_refs = 0
    for map_record in loaded.maps:
        map_id = str(map_record.id)
        if (type(map_record.width) is not int or type(map_record.height) is not int
                or not 1 <= map_record.width <= 512 or not 1 <= map_record.height <= 512):
            raise WorldRecordError(f"map {map_id}: dimensions are out of bounds")
        if any(type(records) is not tuple for records in
               (map_record.encounters, map_record.npcs, map_record.triggers,
                map_record.encounter_regions, map_record.transitions)):
            raise WorldRecordError(f"map {map_id}: malformed entity collection")
        if any(len(records) > MAX_PER_RECORD for records in
               (map_record.encounters, map_record.npcs, map_record.triggers,
                map_record.encounter_regions, map_record.transitions)):
            raise WorldRecordError(f"map {map_id}: entity collection exceeds Content-0 limit")
        total_refs += len(map_record.encounters)
        if total_refs > MAX_TOTAL_REFS:
            raise WorldRecordError("map encounter references exceed Content-0 total limit")
        surface = map_record.navigation
        has_world_data = bool(map_record.npcs or map_record.triggers
                              or map_record.encounter_regions or map_record.transitions)
        if has_world_data and surface is None:
            raise WorldRecordError(f"map {map_id}: world entities require navigation")
        vertices = surface.vertices if surface is not None else ()
        if surface is not None:
            _validate_surface(surface, map_id)
        event_refs = {str(graph.id) for graph in loaded.events}
        encounter_refs = {str(item) for item in map_record.encounters}
        if len(encounter_refs) != len(map_record.encounters):
            raise WorldRecordError(f"map {map_id}: duplicate encounter reference")
        for encounter_id in encounter_refs:
            if not _CONTENT_ID.fullmatch(encounter_id) or encounter_id not in encounters:
                raise WorldRecordError(f"map {map_id}: unresolved encounter {encounter_id}")
        for npc in map_record.npcs:
            if type(npc) is not NpcRecord:
                raise WorldRecordError(f"map {map_id}: malformed NPC")
            identity = str(npc.id)
            if not _CONTENT_ID.fullmatch(identity):
                raise WorldRecordError(f"NPC has invalid ID {identity!r}")
            if identity in world_ids["npc"]:
                raise WorldRecordError(f"duplicate NPC ID {identity}")
            world_ids["npc"].add(identity)
            if (any(type(coord) is not int or not -WORLD_COORD_LIMIT <= coord <= WORLD_COORD_LIMIT
                    for coord in (npc.x, npc.y, npc.z))
                    or surface is None or not _point_on_surface(npc.x, npc.z, surface)):
                raise WorldRecordError(f"NPC {identity}: position is invalid")
            if npc.event is not None and str(npc.event) not in event_refs:
                raise WorldRecordError(f"NPC {identity}: unresolved event")
        for trigger in map_record.triggers:
            if type(trigger) is not TriggerRecord:
                raise WorldRecordError(f"map {map_id}: malformed trigger")
            identity = str(trigger.id)
            if not _CONTENT_ID.fullmatch(identity):
                raise WorldRecordError(f"trigger has invalid ID {identity!r}")
            if identity in world_ids["trigger"]:
                raise WorldRecordError(f"duplicate trigger ID {identity}")
            world_ids["trigger"].add(identity)
            if (surface is None or not _record_polygon_valid(trigger.vertices, vertices)
                    or str(trigger.event) not in event_refs):
                raise WorldRecordError(f"trigger {identity}: geometry or event reference is invalid")
        face_owner: dict[int, str] = {}
        for region in map_record.encounter_regions:
            if type(region) is not EncounterRegion:
                raise WorldRecordError(f"map {map_id}: malformed encounter region")
            identity = region.id
            if type(identity) is not str or not _CONTENT_ID.fullmatch(identity):
                raise WorldRecordError(f"encounter region has invalid ID {identity!r}")
            if identity in world_ids["region"]:
                raise WorldRecordError(f"duplicate encounter region ID {identity}")
            world_ids["region"].add(identity)
            if (surface is None or type(region.faces) is not tuple
                    or not region.faces
                    or str(region.encounter) not in encounters
                    or str(region.encounter) not in encounter_refs):
                raise WorldRecordError(f"encounter region {identity}: unresolved data")
            for face_id in region.faces:
                if type(face_id) is not int or not 0 <= face_id < len(surface.faces):
                    raise WorldRecordError(f"encounter region {identity}: invalid face index")
                if face_id in face_owner:
                    raise WorldRecordError(f"encounter regions overlap on face {face_id}")
                face_owner[face_id] = identity
        for transition in map_record.transitions:
            if type(transition) is not MapTransition:
                raise WorldRecordError(f"map {map_id}: malformed transition")
            identity = transition.id
            if type(identity) is not str or not _CONTENT_ID.fullmatch(identity):
                raise WorldRecordError(f"transition has invalid ID {identity!r}")
            if identity in world_ids["transition"]:
                raise WorldRecordError(f"duplicate transition ID {identity}")
            world_ids["transition"].add(identity)
            target = maps.get(str(transition.target_map))
            if (surface is None or not _record_polygon_valid(transition.vertices, vertices)
                    or target is None or target.navigation is None
                    or any(type(coord) is not int or not -WORLD_COORD_LIMIT <= coord <= WORLD_COORD_LIMIT
                           for coord in (transition.x, transition.y, transition.z))
                    or not _point_on_surface(transition.x, transition.z, target.navigation)):
                raise WorldRecordError(f"transition {identity}: geometry or target is invalid")
    if any(len(identities) > MAX_ENTITIES for identities in world_ids.values()):
        raise WorldRecordError("world entity count exceeds Content-0 limit")
