"""Versioned bounded numeric wire for validated M8 events and encounters.

The payload carries only closed numeric opcodes, arguments, references, and
tables. It does not serialize authored strings or executable content.
"""
from __future__ import annotations

from dataclasses import dataclass

from .m8_binding import (
    BoundEncounter, BoundEncounterEntry, BoundEventGraph, BoundEventNode,
    M8ContentBinding,
)
from .world_limits import (
    EVENT_BYTES_LIMIT, EVENT_VALUE_LIMIT, MAX_ENTITIES, MAX_TOTAL_REFS,
    MAX_WIRE_BYTES, MAX_WIRE_TOKENS,
)

MAGIC = 12
WIRE_VERSION = 1
_OPCODES = {
    "setValue": (0, ("key", "value"), 1),
    "addEntity": (1, ("entity", "bytes"), 1),
    "emitSignal": (2, ("kind", "bytes"), 1),
    "wait": (3, ("ticks",), 1),
    "choice": (4, ("prompt",), 2),
    "stop": (5, (), 0),
}


class M10EventsWireError(ValueError):
    """The validated event/encounter subset exceeds the M10 wire contract."""


@dataclass(frozen=True, slots=True)
class M10EventsWire:
    version: int
    tokens: tuple[int, ...]
    text: str


def _uint(value: object, label: str, maximum: int = 0xFFFFFFFF) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise M10EventsWireError(f"{label} must be an integer in [0, {maximum}]")
    return value


def _positive_id(value: object, label: str) -> int:
    result = _uint(value, label)
    if result == 0:
        raise M10EventsWireError(f"{label} must be positive")
    return result


def _encode_graph(graph: BoundEventGraph, total_refs: list[int]) -> list[int]:
    if type(graph) is not BoundEventGraph or type(graph.nodes) is not tuple:
        raise M10EventsWireError("binding contains a malformed event graph")
    graph_id = _positive_id(graph.id, "event graph id")
    count = len(graph.nodes)
    if not 1 <= count <= MAX_ENTITIES:
        raise M10EventsWireError(f"event graph {graph_id} node count is outside bounds")
    entry = _uint(graph.entry, f"event graph {graph_id} entry", count - 1)
    total_refs[0] += count
    out = [graph_id, entry, count]
    edges: list[tuple[int, ...]] = []
    for index, node in enumerate(graph.nodes):
        if (type(node) is not BoundEventNode or type(node.arguments) is not tuple
                or type(node.successors) is not tuple or type(node.id) is not int
                or node.id != index or type(node.opcode) is not str):
            raise M10EventsWireError(f"event graph {graph_id} has noncanonical nodes")
        opcode = _OPCODES.get(node.opcode)
        if opcode is None:
            raise M10EventsWireError(f"event node {index} has unknown closed opcode")
        code, argument_names, successor_count = opcode
        if len(node.arguments) != len(argument_names) or len(node.successors) != successor_count:
            raise M10EventsWireError(f"event node {index} has invalid opcode shape")
        if any(type(pair) is not tuple or len(pair) != 2
               or type(pair[0]) is not str for pair in node.arguments):
            raise M10EventsWireError(f"event node {index} has malformed arguments")
        arguments = dict(node.arguments)
        if (len(arguments) != len(node.arguments)
                or set(arguments) != set(argument_names)):
            raise M10EventsWireError(f"event node {index} has invalid opcode arguments")
        out.extend((index, code))
        for name in argument_names:
            limit = EVENT_BYTES_LIMIT if name == "bytes" else EVENT_VALUE_LIMIT
            out.append(_uint(arguments[name], f"event node {index} {name}", limit))
        successors = tuple(_uint(successor, f"event node {index} successor", count - 1)
                           for successor in node.successors)
        edges.append(successors)
        out.extend(successors)
    colors = [0] * count

    def visit(current: int) -> None:
        if colors[current] == 1:
            raise M10EventsWireError(f"event graph {graph_id} has an immediate cycle")
        if colors[current] == 2:
            return
        colors[current] = 1
        for target in edges[current]:
            visit(target)
        colors[current] = 2

    for start in range(count):
        visit(start)
    total_refs[0] += sum(map(len, edges))
    return out


def _encode_encounter(table: BoundEncounter) -> list[int]:
    if type(table) is not BoundEncounter or type(table.entries) is not tuple:
        raise M10EventsWireError("binding contains a malformed encounter table")
    table_id = _positive_id(table.id, "encounter id")
    count = len(table.entries)
    if not 1 <= count <= MAX_ENTITIES:
        raise M10EventsWireError(f"encounter {table_id} entry count is outside bounds")
    out = [table_id, count]
    for entry in table.entries:
        if type(entry) is not BoundEncounterEntry:
            raise M10EventsWireError(f"encounter {table_id} has a malformed entry")
        species = _uint(entry.species_id, "species id", MAX_ENTITIES)
        if species == 0:
            raise M10EventsWireError("species id must be positive")
        weight = _uint(entry.weight, "encounter weight", 10_000)
        minimum = _uint(entry.min_level, "minimum level", 200)
        maximum = _uint(entry.max_level, "maximum level", 200)
        if weight == 0 or minimum == 0 or minimum > maximum:
            raise M10EventsWireError(f"encounter {table_id} has an invalid entry")
        out.extend((species, weight, minimum, maximum))
    return out


def encode_m10_events(binding: M8ContentBinding) -> M10EventsWire:
    """Encode only the event graphs and encounter tables of an M8 binding."""
    if type(binding) is not M8ContentBinding or binding.ruleset_version != "m8-1":
        raise M10EventsWireError("event wire source must be a validated m8-1 binding")
    if type(binding.events) is not tuple or type(binding.encounters) is not tuple:
        raise M10EventsWireError("binding has malformed event or encounter arrays")
    identity = _uint(binding.content_identity, "content identity")
    if len(binding.events) > MAX_ENTITIES or len(binding.encounters) > MAX_ENTITIES:
        raise M10EventsWireError("event graph or encounter table count exceeds bounds")
    graph_ids = [_positive_id(row.id, "event graph id") for row in binding.events]
    encounter_ids = [_positive_id(row.id, "encounter id") for row in binding.encounters]
    if len(set(graph_ids)) != len(graph_ids) or len(set(encounter_ids)) != len(encounter_ids):
        raise M10EventsWireError("event and encounter IDs must be unique")
    tokens = [MAGIC, WIRE_VERSION, identity, len(binding.events)]
    total_refs = [0]
    for graph in binding.events:
        tokens.extend(_encode_graph(graph, total_refs))
    tokens.append(len(binding.encounters))
    for table in binding.encounters:
        tokens.extend(_encode_encounter(table))
        total_refs[0] += len(table.entries)
    if total_refs[0] > MAX_TOTAL_REFS:
        raise M10EventsWireError("event and encounter reference total exceeds bounds")
    if len(tokens) > MAX_WIRE_TOKENS:
        raise M10EventsWireError("numeric wire token count exceeds the supported bound")
    text = " ".join(map(str, tokens))
    if len(text.encode("ascii")) > MAX_WIRE_BYTES:
        raise M10EventsWireError("numeric wire bytes exceed the supported bound")
    return M10EventsWire(WIRE_VERSION, tuple(tokens), text)
