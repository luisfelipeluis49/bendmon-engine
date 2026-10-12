import Base
import ./catalog.bend as Catalog
import ./dynamic_catalog.bend as World
import ./dynamic_events.bend as DynamicEvents
import ./encounter_handoff.bend as Handoff

type BoundContent is Data:
  BoundContent{identity: U32, entry_map: Nat,
    catalog: Catalog.Catalog,
    encounter_tables: List<&2, Handoff.EncounterTable>}

type JoinResult is Data:
  JoinRejected{reason: String}
  JoinAccepted{content: BoundContent}

def graph_exists(+id: Nat, graphs: List<&2, DynamicEvents.EventsGraph>) -> Bool:
  match graphs:
    case Nil{}: False{}
    case DynamicEvents.EventsGraph{row_id, entry, nodes} <> rest:
      Bool.or(Nat.is_eq(id, row_id), graph_exists(id, rest))

def table_exists(+id: Nat,
  tables: List<&2, Handoff.EncounterTable>) -> Bool:
  match tables:
    case Nil{}: False{}
    case Handoff.EncounterTable{row_id, entries} <> rest:
      Bool.or(Nat.is_eq(id, row_id), table_exists(id, rest))

def regions_resolve(regions: List<&2, Catalog.EncounterRegion>,
  +tables: List<&2, Handoff.EncounterTable>) -> Bool:
  match regions:
    case Nil{}: True{}
    case Catalog.EncounterRegion{id, encounter_id, faces} <> rest:
      Bool.and(table_exists(encounter_id, tables),
        regions_resolve(rest, tables))

def npc_event_resolves(ref: Maybe<&2, Nat>,
  graphs: List<&2, DynamicEvents.EventsGraph>) -> Bool:
  match ref:
    case None{}: True{}
    case Some{id}: graph_exists(id, graphs)

def npcs_resolve(npcs: List<&2, Catalog.Npc>,
  +graphs: List<&2, DynamicEvents.EventsGraph>) -> Bool:
  match npcs:
    case Nil{}: True{}
    case Catalog.Npc{id, point, event_id} <> rest:
      Bool.and(npc_event_resolves(event_id, graphs),
        npcs_resolve(rest, graphs))

def triggers_resolve(triggers: List<&2, Catalog.Trigger>,
  +graphs: List<&2, DynamicEvents.EventsGraph>) -> Bool:
  match triggers:
    case Nil{}: True{}
    case Catalog.Trigger{id, vertices, event_id} <> rest:
      Bool.and(graph_exists(event_id, graphs),
        triggers_resolve(rest, graphs))

def maps_resolve(maps: List<&2, Catalog.WorldMap>,
  +graphs: List<&2, DynamicEvents.EventsGraph>,
  +tables: List<&2, Handoff.EncounterTable>) -> Bool:
  match maps:
    case Nil{}: True{}
    case Catalog.WorldMap{id, navigation, regions, npcs,
        triggers, transitions} <> rest:
      Bool.and(regions_resolve(regions, tables),
        Bool.and(npcs_resolve(npcs, graphs),
        Bool.and(triggers_resolve(triggers, graphs),
          maps_resolve(rest, graphs, tables))))

def catalog_graphs(graphs: List<&2, DynamicEvents.EventsGraph>) ->
  List<&2, Catalog.EventGraph>:
  match graphs:
    case Nil{}: Nil{}
    case DynamicEvents.EventsGraph{id, entry, nodes} <> rest:
      Catalog.EventGraph{id, entry, nodes} <> catalog_graphs(rest)

def joined(ok: Bool, +identity: U32, entry_map: Nat,
  maps: List<&2, Catalog.WorldMap>,
  graphs: List<&2, DynamicEvents.EventsGraph>,
  tables: List<&2, Handoff.EncounterTable>) -> JoinResult:
  match ok:
    case False{}: JoinRejected{"world event or encounter reference does not resolve"}
    case True{}:
      JoinAccepted{BoundContent{identity, entry_map,
        Catalog.Catalog{8n, U32.to_nat(identity), maps,
          catalog_graphs(graphs)}, tables}}

def matching_identity(equal: Bool, identity: U32, entry_map: Nat,
  +maps: List<&2, Catalog.WorldMap>,
  +graphs: List<&2, DynamicEvents.EventsGraph>,
  +tables: List<&2, Handoff.EncounterTable>) -> JoinResult:
  match equal:
    case False{}: JoinRejected{"world and event content identities differ"}
    case True{}:
      joined(maps_resolve(maps, graphs, tables), identity,
        entry_map, maps, graphs, tables)

# Join independently decoded numeric records only after exact identity and
# all cross-document event/encounter references resolve in the Bend core.
def join(world: World.DecodeResult,
  events: DynamicEvents.DecodeResult) -> JoinResult:
  match world events:
    case World.DecodeRejected{reason} _: JoinRejected{"world wire rejected"}
    case _ DynamicEvents.DecodeRejected{reason}:
      JoinRejected{"event/encounter wire rejected"}
    case World.DecodeAccepted{World.DynamicCatalog{+world_identity,
        entry_map, Catalog.Catalog{ruleset, catalog_identity, maps, empty}}}
         DynamicEvents.DecodeAccepted{DynamicEvents.DynamicEvents{
           event_identity, graphs, tables}}:
      matching_identity(U32.is_eq(world_identity, event_identity),
        world_identity, entry_map, maps, graphs, tables)
