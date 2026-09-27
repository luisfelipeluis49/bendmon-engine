"""Bounded parser and validator for inert authored M8 world content."""
from __future__ import annotations

from typing import Any

from .models import (AssetId, Encounter, EncounterId, EventGraph, EventId, EventNode, EncounterRegion, MapPresentation,
                     MapId, MapRecord, MapTransition, NavLink, NavSurface,
                     NavTriangle, NavVertex, NpcId, NpcRecord, TriggerId,
                     TriggerRecord)

from .world_limits import (EVENT_BYTES_LIMIT, EVENT_VALUE_LIMIT, MAX_ENTITIES,
                           MAX_PER_RECORD, MAX_TOTAL_REFS, WORLD_COORD_LIMIT)

def _install_loader_helpers() -> None:
    # These parsing primitives remain owned by the secure Content-0 loader.
    # Install them lazily to keep the modules acyclic while sharing one validator.
    from . import loader
    for name in ("_fail", "_object", "_array", "_uint", "_string", "_id", "_unique", "_doc"):
        globals()[name] = getattr(loader, name)

def _world_coord(value: Any, file: str, pointer: str) -> int:
    return _uint_signed(value, -WORLD_COORD_LIMIT, WORLD_COORD_LIMIT, file, pointer)


def _uint_signed(value: Any, low: int, high: int, file: str,
                 pointer: str) -> int:
    if type(value) is not int or not low <= value <= high:
        _fail("integer", file, pointer, f"expected integer in {low}..{high}")
    return value


def _nav_surface(value: Any, file: str) -> NavSurface:
    pointer = "/navigation"
    surface = _object(value, {"vertices", "faces", "links"}, file, pointer)
    vertices: list[NavVertex] = []
    for i, raw in enumerate(_array(surface["vertices"], file,
                                   pointer + "/vertices")):
        p = f"{pointer}/vertices/{i}"
        row = _object(raw, {"x", "y", "z"}, file, p)
        vertices.append(NavVertex(*(_world_coord(row[axis], file, p + "/" + axis)
                                    for axis in ("x", "y", "z"))))
    if len(vertices) < 3:
        _fail("navigation", file, pointer + "/vertices",
              "navigation surface requires at least three vertices")
    faces: list[NavTriangle] = []
    for i, raw in enumerate(_array(surface["faces"], file, pointer + "/faces")):
        p = f"{pointer}/faces/{i}"
        if not isinstance(raw, list) or len(raw) != 3:
            _fail("navigation", file, p, "face must contain three vertex indices")
        ids = tuple(_uint(raw[j], 0, len(vertices) - 1, file, f"{p}/{j}")
                    for j in range(3))
        if len(set(ids)) != 3:
            _fail("navigation", file, p, "face vertex indices must be distinct")
        a, b, c = (vertices[index] for index in ids)
        if (b.x - a.x) * (c.z - a.z) == (b.z - a.z) * (c.x - a.x):
            _fail("navigation", file, p, "face must have nonzero horizontal area")
        if any(set((prior.a, prior.b, prior.c)) == set(ids) for prior in faces):
            _fail("duplicate", file, p, "duplicate navigation face")
        faces.append(NavTriangle(*ids))
    if not faces:
        _fail("navigation", file, pointer + "/faces",
              "navigation surface requires at least one face")
    links: list[NavLink] = []
    for i, raw in enumerate(_array(surface["links"], file, pointer + "/links")):
        p = f"{pointer}/links/{i}"
        row = _object(raw, {"from_face", "to_face"}, file, p)
        source = _uint(row["from_face"], 0, len(faces) - 1, file, p + "/from_face")
        target = _uint(row["to_face"], 0, len(faces) - 1, file, p + "/to_face")
        if source == target:
            _fail("navigation", file, p, "navigation link must connect distinct faces")
        links.append(NavLink(source, target))
    if len({(link.from_face, link.to_face) for link in links}) != len(links):
        _fail("duplicate", file, pointer + "/links", "duplicate directed face link")
    for index, link in enumerate(links):
        shared = set((faces[link.from_face].a, faces[link.from_face].b,
                      faces[link.from_face].c)) & set((faces[link.to_face].a,
                      faces[link.to_face].b, faces[link.to_face].c))
        if len(shared) < 2:
            _fail("navigation-link", file, f"{pointer}/links/{index}",
                  "navigation link faces must share a real surface edge")
    return NavSurface(tuple(vertices), tuple(faces), tuple(links))


def _polygon_indices(value: Any, vertices: tuple[NavVertex, ...], file: str,
                     pointer: str) -> tuple[int, ...]:
    indices = tuple(_uint(item, 0, len(vertices) - 1, file, f"{pointer}/{i}")
                    for i, item in enumerate(_array(value, file, pointer)))
    if len(indices) < 3 or len(set(indices)) != len(indices):
        _fail("polygon", file, pointer,
              "polygon requires at least three distinct vertex indices")
    points = [vertices[index] for index in indices]
    area2 = sum(points[i].x * points[(i + 1) % len(points)].z
                - points[(i + 1) % len(points)].x * points[i].z
                for i in range(len(points)))
    if area2 == 0:
        _fail("polygon", file, pointer, "polygon must have nonzero horizontal area")
    for first in range(len(points)):
        a, b = points[first], points[(first + 1) % len(points)]
        for second in range(first + 1, len(points)):
            if second == first + 1 or (first == 0 and second == len(points) - 1):
                continue
            c, d = points[second], points[(second + 1) % len(points)]
            if _segments_intersect(a, b, c, d):
                _fail("polygon", file, pointer,
                      "polygon edges must not self-intersect")
    return indices


def _segments_intersect(a: NavVertex, b: NavVertex,
                        c: NavVertex, d: NavVertex) -> bool:
    def orient(p: NavVertex, q: NavVertex, r: NavVertex) -> int:
        return (q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x)
    def on_segment(p: NavVertex, q: NavVertex, r: NavVertex) -> bool:
        return (min(p.x, r.x) <= q.x <= max(p.x, r.x)
                and min(p.z, r.z) <= q.z <= max(p.z, r.z))
    ab_c, ab_d = orient(a, b, c), orient(a, b, d)
    cd_a, cd_b = orient(c, d, a), orient(c, d, b)
    if ((ab_c > 0 > ab_d or ab_d > 0 > ab_c)
            and (cd_a > 0 > cd_b or cd_b > 0 > cd_a)):
        return True
    return ((ab_c == 0 and on_segment(a, c, b))
            or (ab_d == 0 and on_segment(a, d, b))
            or (cd_a == 0 and on_segment(c, a, d))
            or (cd_b == 0 and on_segment(c, b, d)))


def _point_in_triangle(x: int, z: int, a: NavVertex, b: NavVertex,
                       c: NavVertex) -> bool:
    def orient(p: NavVertex, q: NavVertex) -> int:
        return (q.x - p.x) * (z - p.z) - (q.z - p.z) * (x - p.x)
    values = (orient(a, b), orient(b, c), orient(c, a))
    return all(value >= 0 for value in values) or all(value <= 0 for value in values)


def _point_on_surface(x: int, z: int, surface: NavSurface) -> bool:
    for face in surface.faces:
        if _point_in_triangle(x, z, surface.vertices[face.a],
                              surface.vertices[face.b], surface.vertices[face.c]):
            return True
    return False


def _event_cycle_check(nodes: tuple[EventNode, ...], file: str, event_id: str) -> None:
    edges = {node.id: node.next for node in nodes}
    color = [0] * len(nodes)
    for start in range(len(nodes)):
        if color[start]:
            continue
        stack: list[tuple[int, bool]] = [(start, False)]
        while stack:
            current, leaving = stack.pop()
            if leaving:
                color[current] = 2
                continue
            if color[current] == 2:
                continue
            if color[current] == 1:
                _fail("event-cycle", file, f"/nodes/{current}/next",
                      "event graph contains an immediate cycle", event_id)
            color[current] = 1
            stack.append((current, True))
            for successor in reversed(edges[current]):
                if color[successor] == 1:
                    _fail("event-cycle", file,
                          f"/nodes/{current}/next",
                          "event graph contains an immediate cycle", event_id)
                if color[successor] == 0:
                    stack.append((successor, False))


def _parse_event(document: dict[str, Any], file: str) -> EventGraph:
    doc = _object(document, {"schemaVersion", "id", "entry", "nodes"}, file, "")
    event_id = _id(doc["id"], file, "/id")
    raw_nodes = _array(doc["nodes"], file, "/nodes")
    if not raw_nodes:
        _fail("event", file, "/nodes", "event graph requires at least one node", event_id)
    source_nodes: list[tuple[int, dict[str, Any], int]] = []
    for i, raw in enumerate(raw_nodes):
        p = f"/nodes/{i}"
        row = _object(raw, {"id", "op", "next"}, file, p,
                      {"key", "value", "entity", "bytes", "kind", "ticks", "prompt"})
        source_id = _uint(row["id"], 0, MAX_PER_RECORD - 1, file, p + "/id")
        source_nodes.append((source_id, row, i))
    _unique([str(node_id) for node_id, _, _ in source_nodes], file, "/nodes", "event node ID")
    source_nodes.sort(key=lambda item: item[0])
    dense_id = {source_id: i for i, (source_id, _, _) in enumerate(source_nodes)}
    raw_entry = _uint(doc["entry"], 0, MAX_PER_RECORD - 1, file, "/entry")
    if raw_entry not in dense_id:
        _fail("reference", file, "/entry", "event entry node does not resolve", event_id)
    nodes: list[EventNode] = []
    op_fields = {"setValue": ("key", "value"), "addEntity": ("entity", "bytes"),
                 "emitSignal": ("kind", "bytes"), "wait": ("ticks",),
                 "choice": ("prompt",), "stop": ()}
    for dense, (source_id, row, source_index) in enumerate(source_nodes):
        p = f"/nodes/{source_index}"
        op = row["op"]
        if type(op) is not str or op not in op_fields:
            _fail("event-opcode", file, p + "/op", "unknown closed event opcode", event_id)
        fields = op_fields[op]
        _object(row, {"id", "op", "next", *fields}, file, p)
        expected_edges = {"setValue": 1, "addEntity": 1, "emitSignal": 1,
                          "wait": 1, "choice": 2, "stop": 0}[op]
        refs = _array(row["next"], file, p + "/next", 2)
        if len(refs) != expected_edges:
            _fail("event-arity", file, p + "/next",
                  f"{op} requires exactly {expected_edges} successor(s)", event_id)
        successors: list[int] = []
        for edge, target in enumerate(refs):
            target_id = _uint(target, 0, MAX_PER_RECORD - 1, file,
                              f"{p}/next/{edge}")
            if target_id not in dense_id:
                _fail("reference", file, f"{p}/next/{edge}",
                      "event successor does not resolve", event_id)
            successors.append(dense_id[target_id])
        args = tuple((key, _uint(row[key], 0,
                                EVENT_BYTES_LIMIT if key == "bytes" else EVENT_VALUE_LIMIT,
                                file, p + "/" + key)) for key in fields)
        nodes.append(EventNode(dense, op, args, tuple(successors)))
    result = tuple(nodes)
    _event_cycle_check(result, file, event_id)
    return EventGraph(EventId(event_id), dense_id[raw_entry], result)


def parse_world_content(root: Any, map_paths: list[str], event_paths: list[str],
                        ) -> tuple[list[tuple[EventGraph, str]], list[tuple[MapRecord, str]]]:
    """Parse world documents and validate all typed links before runtime binding."""
    _install_loader_helpers()
    event_locations: list[tuple[EventGraph, str]] = []
    total_event_nodes = 0
    for rel in event_paths:
        event_graph = _parse_event(_doc(root, rel), rel)
        total_event_nodes += len(event_graph.nodes)
        event_locations.append((event_graph, rel))
    if total_event_nodes > MAX_ENTITIES:
        _fail("event-limit", "manifest.json", "/events",
              "combined event nodes exceed the 256 Content-0 entity limit")
    _unique([str(graph.id) for graph, _ in event_locations],
            "manifest.json", "/events", "event ID")
    event_ids = {str(graph.id) for graph, _ in event_locations}
    maps_loc: list[tuple[MapRecord, str]] = []
    world_ids: dict[str, dict[str, tuple[str, str]]] = {
        "npc": {}, "trigger": {}, "region": {}, "transition": {}}
    total_refs = 0
    for rel in map_paths:
        d = _object(_doc(root, rel), {"schemaVersion", "id", "name", "width", "height", "encounters"}, rel, "", {"navigation", "npcs", "triggers", "encounterRegions", "transitions", "presentation"})
        map_id = MapId(_id(d["id"], rel, "/id"))
        refs = tuple(EncounterId(_id(v, rel, f"/encounters/{i}")) for i, v in enumerate(_array(d["encounters"], rel, "/encounters")))
        _unique([str(v) for v in refs], rel, "/encounters", "encounter reference")
        total_refs += len(refs)
        map_name = _string(d["name"], rel, "/name")
        # Preserve the existing diagnostic boundary: the production Bend
        # kernel owns world dimension range checks for legacy map fields.
        width = _uint(d["width"], 0, 2**32 - 1, rel, "/width")
        height = _uint(d["height"], 0, 2**32 - 1, rel, "/height")
        navigation = _nav_surface(d["navigation"], rel) if "navigation" in d else None
        if any(key in d for key in ("npcs", "triggers", "encounterRegions", "transitions")) and navigation is None:
            _fail("navigation", rel, "/navigation",
                  "world entities require a baked navigation surface", map_id)
        nav_vertices = navigation.vertices if navigation else ()
        npcs: list[NpcRecord] = []
        for i, raw in enumerate(_array(d.get("npcs", []), rel, "/npcs")):
            p = f"/npcs/{i}"
            row = _object(raw, {"id", "name", "x", "y", "z"}, rel, p, {"event", "sprite"})
            npc_id = NpcId(_id(row["id"], rel, p + "/id"))
            event_id = EventId(_id(row["event"], rel, p + "/event")) if "event" in row else None
            if event_id is not None and str(event_id) not in event_ids:
                _fail("reference", rel, p + "/event", "NPC event does not resolve", npc_id)
            coords = tuple(_world_coord(row[axis], rel, p + "/" + axis)
                           for axis in ("x", "y", "z"))
            if navigation is None or not _point_on_surface(coords[0], coords[2], navigation):
                _fail("npc-position", rel, p,
                      "NPC position must project onto a navigation face", npc_id)
            sprite = AssetId(_id(row["sprite"], rel, p + "/sprite")) if "sprite" in row else None
            npcs.append(NpcRecord(npc_id, _string(row["name"], rel, p + "/name"),
                                  *coords, event_id, sprite))
        triggers: list[TriggerRecord] = []
        for i, raw in enumerate(_array(d.get("triggers", []), rel, "/triggers")):
            p = f"/triggers/{i}"
            row = _object(raw, {"id", "event", "vertices"}, rel, p)
            trigger_id = TriggerId(_id(row["id"], rel, p + "/id"))
            event_id = EventId(_id(row["event"], rel, p + "/event"))
            if str(event_id) not in event_ids:
                _fail("reference", rel, p + "/event", "trigger event does not resolve", trigger_id)
            triggers.append(TriggerRecord(trigger_id, event_id,
                _polygon_indices(row["vertices"], nav_vertices, rel, p + "/vertices")))
        regions: list[EncounterRegion] = []
        map_encounter_ids = {str(value) for value in refs}
        region_face_owner: dict[int, str] = {}
        for i, raw in enumerate(_array(d.get("encounterRegions", []), rel, "/encounterRegions")):
            p = f"/encounterRegions/{i}"
            row = _object(raw, {"id", "encounter", "faces"}, rel, p)
            region_id = _id(row["id"], rel, p + "/id")
            encounter_id = EncounterId(_id(row["encounter"], rel, p + "/encounter"))
            if str(encounter_id) not in map_encounter_ids:
                _fail("reference", rel, p + "/encounter", "region encounter must be listed by its map", region_id)
            face_count = len(navigation.faces) if navigation else 0
            face_ids = tuple(_uint(value, 0, face_count - 1, rel,
                                   f"{p}/faces/{face_index}")
                             for face_index, value in enumerate(
                                 _array(row["faces"], rel, p + "/faces")))
            if not face_ids or len(face_ids) != len(set(face_ids)):
                _fail("encounter-region", rel, p + "/faces",
                      "encounter region requires distinct navigation face indices", region_id)
            for face_id in face_ids:
                if face_id in region_face_owner:
                    _fail("encounter-region-overlap", rel, f"{p}/faces",
                          f"navigation face {face_id} is already assigned to encounter region {region_face_owner[face_id]}", region_id)
                region_face_owner[face_id] = region_id
            regions.append(EncounterRegion(region_id, encounter_id, face_ids))
        transitions: list[MapTransition] = []
        for i, raw in enumerate(_array(d.get("transitions", []), rel, "/transitions")):
            p = f"/transitions/{i}"
            row = _object(raw, {"id", "targetMap", "vertices", "x", "y", "z"}, rel, p)
            transition_id = _id(row["id"], rel, p + "/id")
            transitions.append(MapTransition(transition_id,
                MapId(_id(row["targetMap"], rel, p + "/targetMap")),
                _polygon_indices(row["vertices"], nav_vertices, rel, p + "/vertices"),
                *(_world_coord(row[axis], rel, p + "/" + axis)
                  for axis in ("x", "y", "z"))))
        for kind, records in (("npc", npcs), ("trigger", triggers),
                              ("region", regions), ("transition", transitions)):
            seen = world_ids[kind]
            for idx, record in enumerate(records):
                identity = str(record.id)
                if identity in seen:
                    _fail("duplicate", rel, f"/{kind}/{idx}/id",
                          f"duplicate {kind} ID", identity)
                seen[identity] = (rel, f"/{kind}/{idx}/id")
        presentation = MapPresentation()
        if "presentation" in d:
            row = _object(d["presentation"], set(), rel, "/presentation", {"cameraProfile", "background"})
            camera = _id(row["cameraProfile"], rel, "/presentation/cameraProfile") if "cameraProfile" in row else None
            background = AssetId(_id(row["background"], rel, "/presentation/background")) if "background" in row else None
            presentation = MapPresentation(camera, background)
        maps_loc.append((MapRecord(map_id, map_name, width, height, refs,
                                   navigation,
                                   tuple(sorted(npcs, key=lambda row: str(row.id))),
                                   tuple(sorted(triggers, key=lambda row: str(row.id))),
                                   tuple(sorted(regions, key=lambda row: row.id)),
                                   tuple(sorted(transitions, key=lambda row: row.id)),
                                   presentation.camera_profile, presentation), rel))
    if total_refs > MAX_TOTAL_REFS:
        _fail("reference-limit", "manifest.json", "/maps", "more than 4096 map references")
    _unique([str(v.id) for v, _ in maps_loc], "manifest.json", "/maps", "map ID")
    for kind, locations in world_ids.items():
        if len(locations) > MAX_ENTITIES:
            _fail("entity-limit", "manifest.json", "/maps",
                  f"more than 256 {kind} entities")
    map_ids = {str(record.id) for record, _ in maps_loc}
    for map_record, rel in maps_loc:
        for index, transition in enumerate(map_record.transitions):
            if str(transition.target_map) not in map_ids:
                _fail("reference", rel, f"/transitions/{index}/targetMap",
                      "transition target map does not resolve", transition.id)
            target_record = next(record for record, _ in maps_loc
                                 if record.id == transition.target_map)
            if target_record.navigation is None or not _point_on_surface(
                    transition.x, transition.z, target_record.navigation):
                _fail("transition-position", rel, f"/transitions/{index}",
                      "transition destination must project onto a target navigation face",
                      transition.id)
    return event_locations, maps_loc


from .world_records import WorldRecordError, validate_world_records
