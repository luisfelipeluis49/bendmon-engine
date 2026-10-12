import Base
import ../../engine/world/dynamic_content.bend as Joined
import ../../engine/world/dynamic_catalog.bend as World
import ../../engine/world/dynamic_events.bend as EventsWire
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/events.bend as Events
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/encounter_handoff.bend as Handoff
import ./dynamic_catalog_test.bend as WorldFixture

def event_tokens() -> List<&2, U32>:
  [12, 1, 123, 1, 5, 0, 1, 0, 5, 1, 2, 1, 1, 1, 1, 1]

def event_records(identity: U32, has_graph: Bool, has_table: Bool) ->
  EventsWire.DecodeResult:
  +graphs: List<&2, EventsWire.EventsGraph> =
    Bool.pick(List<&2, EventsWire.EventsGraph>, has_graph,
      [EventsWire.EventsGraph{5n, 0n,
        [Events.Node{0n, Events.Stop{}, []}]}], [])
  +tables: List<&2, Handoff.EncounterTable> =
    Bool.pick(List<&2, Handoff.EncounterTable>, has_table,
      [Handoff.EncounterTable{2n,
        [Encounters.EncounterEntry{1n, 1n, 1n, 1n}]}], [])
  EventsWire.DecodeAccepted{EventsWire.DynamicEvents{identity, graphs, tables}}

def accepted(result: Joined.JoinResult) -> Bool:
  match result:
    case Joined.JoinAccepted{Joined.BoundContent{123, 1n,
        Catalog.Catalog{8n, 123n, maps, graphs}, tables}}:
      Bool.and(Nat.is_eq(List.length(&2, Catalog.WorldMap, maps), 1n),
        Bool.and(Nat.is_eq(List.length(&2, Catalog.EventGraph, graphs), 1n),
          Nat.is_eq(List.length(&2, Handoff.EncounterTable, tables), 1n)))
    case _: False{}

def rejected(result: Joined.JoinResult) -> Bool:
  match result:
    case Joined.JoinRejected{reason}: True{}
    case _: False{}

def main() -> Bool:
  Bool.and(accepted(Joined.join(World.decode_tokens(WorldFixture.world_tokens()),
      EventsWire.decode_tokens(event_tokens()))),
    Bool.and(rejected(Joined.join(World.decode_tokens(WorldFixture.world_tokens()),
      event_records(124, True{}, True{}))),
    Bool.and(rejected(Joined.join(World.decode_tokens(WorldFixture.world_tokens()),
      event_records(123, False{}, True{}))),
      rejected(Joined.join(World.decode_tokens(WorldFixture.world_tokens()),
        event_records(123, True{}, False{}))))))

#| True
