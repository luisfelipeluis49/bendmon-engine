"""Render validated M8 records as a closed, numeric Bend catalog module.

The generated module contains constructors and bounded integer literals only.
No project string is copied into Bend source, so authored content stays inert.
"""
from __future__ import annotations

from .m8_binding import (BoundEventNode, BoundPoint, M8ContentBinding,
                         SignedCoord)


def _number(value: int) -> str:
    if type(value) is not int or value < 0:
        raise ValueError(f"Bend catalog expected a nonnegative integer, got {value!r}")
    return f"{value}n"


def _uint(value: int) -> str:
    if type(value) is not int or not 0 <= value <= 0xFFFFFFFF:
        raise ValueError(f"Bend catalog expected a U32, got {value!r}")
    return str(value)


def _list(values: tuple[object, ...], render) -> str:
    return "[" + ", ".join(render(value) for value in values) + "]"


def _coord(value: SignedCoord) -> str:
    sign = "True{}" if value.negative else "False{}"
    return f"Geometry.Coord{{{sign}, {_uint(value.magnitude)}}}"


def _point(value: BoundPoint, constructor: str = "Point") -> str:
    return (f"Geometry.{constructor}{{{_coord(value.x)}, {_coord(value.y)}, "
            f"{_coord(value.z)}}}")


def _opcode(node: BoundEventNode) -> str:
    values = dict(node.arguments)
    fields = {
        "setValue": ("SetValue", ("key", "value")),
        "addEntity": ("AddEntity", ("entity", "bytes")),
        "emitSignal": ("EmitSignal", ("kind", "bytes")),
        "wait": ("Wait", ("ticks",)),
        "choice": ("Choice", ("prompt",)),
        "stop": ("Stop", ()),
    }
    if node.opcode not in fields:
        raise ValueError(f"unknown closed M8 event opcode {node.opcode!r}")
    constructor, names = fields[node.opcode]
    if set(values) != set(names) or len(node.arguments) != len(names):
        raise ValueError(f"event node {node.id} has invalid {node.opcode} fields")
    return f"Events.{constructor}{{{', '.join(_number(values[name]) for name in names)}}}"


def render_m8_catalog(binding: M8ContentBinding, *,
                      restore_map_id: int | None = None) -> str:
    """Build a closed Bend catalog from exact-hash validated M8 records.

    A save restore needs only its baked map and region records to recheck the
    stored position. The trusted host may emit that narrow projection before
    resuming commands against the complete catalog.
    """
    if type(binding) is not M8ContentBinding or binding.ruleset_version != "m8-1":
        raise ValueError("M8 catalog rendering requires an M8ContentBinding")
    if restore_map_id is not None and not any(
        row.id == restore_map_id for row in binding.maps
    ):
        raise ValueError(f"restore map ID {restore_map_id!r} is not bound")
    maps = []
    for row in binding.maps:
        if restore_map_id is not None and row.id != restore_map_id:
            continue
        vertices = _list(row.vertices, lambda point: _point(point, "Vertex"))
        faces = _list(row.faces, lambda face: "Geometry.Triangle{" +
                      ", ".join(_uint(index) for index in face) + "}")
        links = _list(row.links, lambda link: "Geometry.NavLink{" +
                      ", ".join(_uint(index) for index in link) + "}")
        surface = f"Geometry.NavSurface{{{vertices}, {faces}, {links}}}"
        regions = _list(row.regions, lambda region:
                        f"Catalog.EncounterRegion{{{_number(region.id)}, "
                        f"{_number(region.encounter_id)}, "
                        f"{_list(region.faces, _uint)}}}")
        npcs = _list(row.npcs, lambda npc:
                     f"Catalog.Npc{{{_number(npc.id)}, {_point(npc.point)}, "
                     f"{'None{}' if npc.event_id is None else 'Some{' + _number(npc.event_id) + '}'}}}") if restore_map_id is None else "[]"
        triggers = _list(row.triggers, lambda trigger:
                         f"Catalog.Trigger{{{_number(trigger.id)}, "
                         f"{_list(trigger.vertices, _uint)}, {_number(trigger.event_id)}}}") if restore_map_id is None else "[]"
        transitions = _list(row.transitions, lambda transition:
                            f"Catalog.Transition{{{_number(transition.id)}, "
                            f"{_list(transition.vertices, _uint)}, "
                            f"{_number(transition.target_map_id)}, "
                            f"{_point(transition.destination)}}}") if restore_map_id is None else "[]"
        maps.append(f"Catalog.WorldMap{{{_number(row.id)}, {surface}, {regions}, "
                    f"{npcs}, {triggers}, {transitions}}}")
    graphs = []
    for graph in (() if restore_map_id is not None else binding.events):
        nodes = _list(graph.nodes, lambda node:
                      f"Events.Node{{{_number(node.id)}, {_opcode(node)}, "
                      f"{_list(node.successors, _number)}}}")
        graphs.append(f"Catalog.EventGraph{{{_number(graph.id)}, "
                      f"{_number(graph.entry)}, {nodes}}}")
    tables = []
    for table in (() if restore_map_id is not None else binding.encounters):
        entries = _list(table.entries, lambda entry:
                        f"Encounters.EncounterEntry{{{_number(entry.species_id)}, "
                        f"{_number(entry.weight)}, {_number(entry.min_level)}, "
                        f"{_number(entry.max_level)}}}")
        tables.append(f"Handoff.EncounterTable{{{_number(table.id)}, {entries}}}")
    return ("# Generated from an exact-hash validated M8 content binding.\n"
            "import Base\n"
            "import ../engine/world/catalog.bend as Catalog\n"
            "import ../engine/world/geometry.bend as Geometry\n"
            "import ../engine/world/events.bend as Events\n"
            "import ../engine/world/encounters.bend as Encounters\n"
            "import ../engine/world/encounter_handoff.bend as Handoff\n\n"
            "def catalog() -> Catalog.Catalog:\n"
            f"  Catalog.Catalog{{8n, {_number(binding.content_identity)}, "
            f"[{', '.join(maps)}], [{', '.join(graphs)}]}}\n\n"
            "def encounter_tables() -> List<&2, Handoff.EncounterTable>:\n"
            f"  [{', '.join(tables)}]\n\n"
            "def entry_map() -> Nat:\n"
            f"  {_number(binding.entry_map_id)}\n\n"
            "def identity() -> Nat:\n"
            f"  {_number(binding.content_identity)}\n")
