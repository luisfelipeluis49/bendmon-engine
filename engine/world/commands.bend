import Base
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry
import ./encounters.bend as Encounters
import ./exploration.bend as Exploration
import ./events.bend as Events
import ./event_bridge.bend as Bridge

# User facing world commands resolve only against the bound, deterministic
# catalog. Positional interactions use baked navigation faces as their range.
type Command is Data:
  Interact{npc_id: Nat, facing_x: Geometry.Coord,
    facing_z: Geometry.Coord}
  Activate{trigger_id: Nat}
  Traverse{transition_id: Nat}
  FastTravel{transition_id: Nat}

type CommandResult is Data:
  Applied{state: Bridge.State}
  EventStarted{result: Bridge.EventBridgeResult}
  Rejected{state: Bridge.State}

def face_for(map: Catalog.WorldMap, point: Geometry.Point) -> Geometry.FaceChoice:
  match map:
    case Catalog.WorldMap{id, navigation, regions, npcs, triggers, transitions}:
      Geometry.face_for_point(navigation, point)

def face_option(face: Geometry.FaceChoice) -> Maybe<&2, U32>:
  match face:
    case Geometry.FaceAccepted{value}: Some{value}
    case Geometry.FaceRejected{}: None{}

def current_face(map_found: Maybe<&2, Catalog.WorldMap>,
  point: Geometry.Point) -> Maybe<&2, U32>:
  match map_found:
    case None{}: None{}
    case Some{map}:
      face_option(face_for(map, point))

def npc_at(+id: Nat, rows: List<&2, Catalog.Npc>) -> Maybe<&2, Catalog.Npc>:
  match rows:
    case Nil{}: None{}
    case Catalog.Npc{+row_id, +point, +event_id} <> rest:
      Bool.pick(Maybe<&2, Catalog.Npc>, Nat.is_eq(id, row_id),
        Some{Catalog.Npc{row_id, point, event_id}}, npc_at(id, rest))

def trigger_at(+id: Nat, rows: List<&2, Catalog.Trigger>) ->
  Maybe<&2, Catalog.Trigger>:
  match rows:
    case Nil{}: None{}
    case Catalog.Trigger{+row_id, +vertices, +event_id} <> rest:
      Bool.pick(Maybe<&2, Catalog.Trigger>, Nat.is_eq(id, row_id),
        Some{Catalog.Trigger{row_id, vertices, event_id}}, trigger_at(id, rest))

def transition_at(+id: Nat, rows: List<&2, Catalog.Transition>) ->
  Maybe<&2, Catalog.Transition>:
  match rows:
    case Nil{}: None{}
    case Catalog.Transition{+row_id, +vertices, +target_map,
        +destination} <> rest:
      Bool.pick(Maybe<&2, Catalog.Transition>, Nat.is_eq(id, row_id),
        Some{Catalog.Transition{row_id, vertices, target_map, destination}},
        transition_at(id, rest))

def point_face_value(left: U32, face: Geometry.FaceChoice) -> Bool:
  match face:
    case Geometry.FaceRejected{}: False{}
    case Geometry.FaceAccepted{value}: U32.is_eq(left, value)

def point_face_match(a: Geometry.FaceChoice,
  b: Geometry.FaceChoice) -> Bool:
  match a:
    case Geometry.FaceRejected{}: False{}
    case Geometry.FaceAccepted{value}: point_face_value(value, b)

def npc_event_face(same_face: Bool, event_id: Nat) -> Maybe<&2, Nat>:
  match same_face:
    case True{}: Some{event_id}
    case False{}: None{}

def npc_event(npc: Maybe<&2, Catalog.Npc>, face: Maybe<&2, U32>,
  map: Catalog.WorldMap, +player_point: Geometry.Point,
  facing_x: Geometry.Coord, facing_z: Geometry.Coord) -> Maybe<&2, Nat>:
  match npc face:
    case Some{Catalog.Npc{id, +point, Some{event_id}}} Some{player_face}:
      npc_event_face(Bool.and(point_face_match(face_for(map, point),
        Geometry.FaceAccepted{player_face}),
        Bool.and(Geometry.interaction_in_range(Geometry.traveled(point,
          player_point)), Geometry.interaction_in_cone(player_point,
          point, facing_x, facing_z))), event_id)
    case _ _: None{}

def trigger_event_inside(inside: Bool, event_id: Nat) -> Maybe<&2, Nat>:
  match inside:
    case True{}: Some{event_id}
    case False{}: None{}

def trigger_event(trigger: Maybe<&2, Catalog.Trigger>,
  map: Catalog.WorldMap, point: Geometry.Point) -> Maybe<&2, Nat>:
  match trigger:
    case Some{Catalog.Trigger{id, vertices, event_id}}:
      match map:
        case Catalog.WorldMap{id, navigation, regions, npcs, triggers,
            transitions}:
          trigger_event_inside(Geometry.polygon_contains(navigation,
            vertices, point), event_id)
    case _: None{}

def route_event(result: Bridge.EventBridgeResult) -> CommandResult:
  match result:
    case Bridge.EventRejected{state}: Rejected{state}
    case _: EventStarted{result}

def event_result(found: Maybe<&2, Nat>, catalog: Catalog.Catalog,
  +state: Bridge.State) -> CommandResult:
  match found:
    case None{}: Rejected{state}
    case Some{id}: route_event(Bridge.start(catalog, state, id))

def interact_at(+world_map: Catalog.WorldMap, +state: Bridge.State,
  catalog: Catalog.Catalog, npc_id: Nat,
  facing_x: Geometry.Coord, facing_z: Geometry.Coord) -> CommandResult:
  match world_map state:
    case Catalog.WorldMap{id, navigation, regions, npcs, triggers,
        transitions}
         Bridge.State{Exploration.State{map_id, +point, meter, None{}, identity},
           persistent, None{}}:
      event_result(npc_event(npc_at(npc_id, npcs),
        current_face(Some{Catalog.WorldMap{id, navigation, regions, npcs,
          triggers, transitions}}, point),
        Catalog.WorldMap{id, navigation, regions, npcs, triggers, transitions},
        point, facing_x, facing_z),
        catalog, state)
    case _ _: Rejected{state}

def activate_at(+world_map: Catalog.WorldMap, +state: Bridge.State,
  catalog: Catalog.Catalog, trigger_id: Nat) -> CommandResult:
  match world_map state:
    case Catalog.WorldMap{id, navigation, regions, npcs, triggers,
        transitions}
         Bridge.State{Exploration.State{map_id, point, meter, None{}, identity},
           persistent, None{}}:
      event_result(trigger_event(trigger_at(trigger_id, triggers),
        Catalog.WorldMap{id, navigation, regions, npcs, triggers, transitions},
        point), catalog, state)
    case _ _: Rejected{state}

def validate_identity(catalog: Catalog.Catalog, state: Bridge.State) -> Bool:
  match catalog state:
    case Catalog.Catalog{ruleset, identity, maps, events}
         Bridge.State{Exploration.State{map_id, point, meter, pending,
           state_identity}, persistent, active}:
      Bool.and(Nat.is_eq(ruleset, 8n), Nat.is_eq(identity, state_identity))

def interact_lookup(found: Maybe<&2, Catalog.WorldMap>, state: Bridge.State,
  catalog: Catalog.Catalog, npc_id: Nat,
  facing_x: Geometry.Coord, facing_z: Geometry.Coord) -> CommandResult:
  match found:
    case None{}: Rejected{state}
    case Some{map}: interact_at(map, state, catalog, npc_id,
      facing_x, facing_z)

def activate_lookup(found: Maybe<&2, Catalog.WorldMap>, state: Bridge.State,
  catalog: Catalog.Catalog, trigger_id: Nat) -> CommandResult:
  match found:
    case None{}: Rejected{state}
    case Some{map}: activate_at(map, state, catalog, trigger_id)

def replace_exploration(old: Bridge.State,
  next: Exploration.State) -> Bridge.State:
  match old:
    case Bridge.State{exploration, persistent, None{}}:
      Bridge.State{next, persistent, None{}}
    case Bridge.State{exploration, persistent, Some{machine}}:
      Bridge.State{exploration, persistent, Some{machine}}

def open_travel(result: Exploration.OpenResult, old: Bridge.State) -> CommandResult:
  match result:
    case Exploration.OpenRejected{}: Rejected{old}
    case Exploration.Opened{next}:
      Applied{replace_exploration(old, next)}

def meter_rng(meter: Encounters.Meter) -> Maybe<&2, Encounters.Meter>:
  Some{meter}

def travel_to(+catalog: Catalog.Catalog, +old: Bridge.State,
  map_id: Nat, point: Geometry.Point) -> CommandResult:
  match old:
    case Bridge.State{Exploration.State{prior_map, prior_point,
        Encounters.Meter{region, weighted, threshold, cooldown, rng}, None{},
        +identity}, persistent, None{}}:
      open_travel(Exploration.open(catalog, map_id, point, rng, identity), old)
    case _: Rejected{old}

# Fast-travel unlocks use the persistent value whose key is the authored
# transition ID and whose latest value is 1. Values are newest-first, so the
# first matching row decides; this reserves that key/value convention for each
# authored fast-travel node.
def fast_travel_flag(+transition_id: Nat,
  values: List<&2, Events.Value>) -> Bool:
  match values:
    case Nil{}: False{}
    case Events.Value{+key, +value} <> rest:
      Bool.pick(Bool, Nat.is_eq(transition_id, key), Nat.is_eq(value, 1n),
        fast_travel_flag(transition_id, rest))

def fast_travel_origin(inside: Bool, unlocked: Bool,
  +catalog: Catalog.Catalog, +old: Bridge.State, target_map: Nat,
  destination: Geometry.Point) -> CommandResult:
  match inside unlocked:
    case True{} True{}: travel_to(catalog, old, target_map, destination)
    case _ _: Rejected{old}

def fast_travel_candidate(transition: Maybe<&2, Catalog.Transition>,
  navigation: Geometry.NavSurface, +catalog: Catalog.Catalog,
  +old: Bridge.State) -> CommandResult:
  match transition:
    case Some{Catalog.Transition{row_id, vertices, target_map, destination}}:
      match old:
        case Bridge.State{Exploration.State{map_id, point, meter, None{},
               identity}, Events.World{values, entities}, None{}}:
          fast_travel_origin(Geometry.polygon_contains(navigation, vertices,
            point), fast_travel_flag(row_id, values), catalog, old,
            target_map, destination)
        case _: Rejected{old}
    case _: Rejected{old}

def fast_travel_at(found: Maybe<&2, Catalog.WorldMap>,
  +catalog: Catalog.Catalog, +old: Bridge.State,
  transition_id: Nat) -> CommandResult:
  match found:
    case None{}: Rejected{old}
    case Some{map}:
      match map:
        case Catalog.WorldMap{id, navigation, regions, npcs, triggers,
            transitions}:
          fast_travel_candidate(transition_at(transition_id, transitions),
            navigation, catalog, old)

def traverse_inside(inside: Bool, catalog: Catalog.Catalog,
  old: Bridge.State, target_map: Nat, destination: Geometry.Point) ->
  CommandResult:
  match inside:
    case True{}: travel_to(catalog, old, target_map, destination)
    case False{}: Rejected{old}


def traverse_candidate(transition: Maybe<&2, Catalog.Transition>,
  map: Catalog.WorldMap, point: Geometry.Point,
  catalog: Catalog.Catalog, old: Bridge.State) -> CommandResult:
  match transition:
    case Some{Catalog.Transition{row_id, vertices, target_map, destination}}:
      match map:
        case Catalog.WorldMap{id, navigation, regions, npcs, triggers,
            transitions}:
          traverse_inside(Geometry.polygon_contains(navigation, vertices,
            point), catalog, old, target_map, destination)
    case _: Rejected{old}

def traverse_at(found: Maybe<&2, Catalog.WorldMap>, catalog: Catalog.Catalog,
  +old: Bridge.State, transition_id: Nat) -> CommandResult:
  match found:
    case None{}: Rejected{old}
    case Some{+map}:
      match map old:
        case Catalog.WorldMap{id, navigation, regions, npcs, triggers,
            transitions}
             Bridge.State{Exploration.State{map_id, +point, meter, None{}, identity},
               persistent, None{}}:
          traverse_candidate(transition_at(transition_id, transitions),
            map, point, catalog, old)
        case _ _: Rejected{old}

def maps_of(catalog: Catalog.Catalog) -> List<&2, Catalog.WorldMap>:
  match catalog:
    case Catalog.Catalog{ruleset, content_identity, maps, events}: maps

def dispatch(valid: Bool, command: Command, +catalog: Catalog.Catalog,
  +state: Bridge.State) -> CommandResult:
  match valid command:
    case False{} _: Rejected{state}
    case True{} Interact{npc_id, facing_x, facing_z}:
      match state:
        case Bridge.State{Exploration.State{map_id, point, meter, pending,
            identity}, persistent, active}:
          interact_lookup(Catalog.map_by_id(maps_of(catalog), map_id), state,
            catalog, npc_id, facing_x, facing_z)
    case True{} Activate{trigger_id}:
      match state:
        case Bridge.State{Exploration.State{map_id, point, meter, pending,
            identity}, persistent, active}:
          activate_lookup(Catalog.map_by_id(maps_of(catalog), map_id), state, catalog, trigger_id)
    case True{} Traverse{transition_id}:
      match state:
        case Bridge.State{Exploration.State{map_id, point, meter, pending,
            identity}, persistent, active}:
          traverse_at(Catalog.map_by_id(maps_of(catalog), map_id), catalog, state, transition_id)
    case True{} FastTravel{transition_id}:
      match state:
        case Bridge.State{Exploration.State{map_id, point, meter, pending,
            identity}, persistent, active}:
          fast_travel_at(Catalog.map_by_id(maps_of(catalog), map_id), catalog,
            state, transition_id)

# NPCs and triggers activate the catalogued event graph. Traverse keeps its
# authored polygon check; unlocked fast travel uses a catalogued node at a
# stable boundary and reopens its destination through the identity/geometry gate.
def run(command: Command, +catalog: Catalog.Catalog,
  +state: Bridge.State) -> CommandResult:
  dispatch(validate_identity(catalog, state), command, catalog, state)
