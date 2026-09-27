import Base
import ./geometry.bend as Geometry
import ./events.bend as Events

# The trusted host binds validated Content-0 IDs to dense positive Nat values.
# The Bend world still checks map/region lookups before any transition.
type EncounterRegion is Data:
  EncounterRegion{id: Nat, encounter_id: Nat, faces: List<&2, U32>}

type Npc is Data:
  Npc{id: Nat, point: Geometry.Point, event_id: Maybe<&2, Nat>}

type Trigger is Data:
  Trigger{id: Nat, vertices: List<&2, U32>, event_id: Nat}

type Transition is Data:
  Transition{id: Nat, vertices: List<&2, U32>,
    target_map: Nat, destination: Geometry.Point}

type WorldMap is Data:
  WorldMap{id: Nat, navigation: Geometry.NavSurface,
    regions: List<&2, EncounterRegion>, npcs: List<&2, Npc>,
    triggers: List<&2, Trigger>, transitions: List<&2, Transition>}

type EventGraph is Data:
  EventGraph{id: Nat, entry: Nat, nodes: List<&2, Events.Node>}

type Catalog is Data:
  Catalog{ruleset: Nat, content_identity: Nat,
    maps: List<&2, WorldMap>, events: List<&2, EventGraph>}

def keep_map(equal: Bool, row: WorldMap,
  found: Maybe<&2, WorldMap>) -> Maybe<&2, WorldMap>:
  match equal:
    case True{}: Some{row}
    case False{}: found

def map_scan(maps: List<&2, WorldMap>, +id: Nat,
  found: Maybe<&2, WorldMap>) ->
  Maybe<&2, WorldMap>:
  match maps:
    case Nil{}: found
    case WorldMap{+row_id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      map_scan(rest, id,
        keep_map(Nat.is_eq(row_id, id),
          WorldMap{row_id, navigation, regions, npcs, triggers, transitions},
          found))

def map_by_id(maps: List<&2, WorldMap>, id: Nat) ->
  Maybe<&2, WorldMap>:
  map_scan(maps, id, None{})

def keep_event(equal: Bool, row: EventGraph,
  found: Maybe<&2, EventGraph>) -> Maybe<&2, EventGraph>:
  match equal:
    case True{}: Some{row}
    case False{}: found

def event_scan(graphs: List<&2, EventGraph>, +id: Nat,
  found: Maybe<&2, EventGraph>) ->
  Maybe<&2, EventGraph>:
  match graphs:
    case Nil{}: found
    case EventGraph{+row_id, +entry, +nodes} <> rest:
      event_scan(rest, id,
        keep_event(Nat.is_eq(row_id, id), EventGraph{row_id, entry, nodes},
          found))

def event_by_id(graphs: List<&2, EventGraph>, id: Nat) ->
  Maybe<&2, EventGraph>:
  event_scan(graphs, id, None{})

def face_in_region(+face: U32, faces: List<&2, U32>) -> Bool:
  match faces:
    case Nil{}: False{}
    case current <> rest:
      Bool.or(U32.is_eq(face, current), face_in_region(face, rest))

def keep_region(included: Bool, region: EncounterRegion,
  found: Maybe<&2, EncounterRegion>) ->
  Maybe<&2, EncounterRegion>:
  match included:
    case True{}: Some{region}
    case False{}: found

def region_scan(regions: List<&2, EncounterRegion>, +face: U32,
  found: Maybe<&2, EncounterRegion>) ->
  Maybe<&2, EncounterRegion>:
  match regions:
    case Nil{}: found
    case EncounterRegion{+id, +encounter_id, +faces} <> rest:
      region_scan(rest, face,
        keep_region(face_in_region(face, faces),
          EncounterRegion{id, encounter_id, faces}, found))

def region_for_face(regions: List<&2, EncounterRegion>, face: U32) ->
  Maybe<&2, EncounterRegion>:
  region_scan(regions, face, None{})

def region_at_face(face: Geometry.FaceChoice,
  regions: List<&2, EncounterRegion>) -> Maybe<&2, EncounterRegion>:
  match face:
    case Geometry.FaceAccepted{index}: region_for_face(regions, index)
    case Geometry.FaceRejected{}: None{}

def region_at_point(map: WorldMap, point: Geometry.Point) ->
  Maybe<&2, EncounterRegion>:
  match map:
    case WorldMap{id, navigation, regions, npcs, triggers, transitions}:
      region_at_face(Geometry.face_for_point(navigation, point), regions)
