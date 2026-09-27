import Base
import ../world/catalog.bend as Catalog
import ../world/geometry.bend as Geometry
import ../world/world_session.bend as Session
import ../world/event_bridge.bend as EventBridge
import ../world/exploration.bend as Exploration
import ../world/battle_bridge.bend as BattleBridge
import ../world/events.bend as Events
import ../m7/playable.bend as Playable
import ../m7/session.bend as M7Session
import ../m7/battle.bend as M7
import ../battle/runtime.bend as Runtime
import ../battle/model.bend as Battle

# DTOs deliberately contain only bounded display state. The host owns camera
# smoothing and turns these immutable values into frames.
type Facing is Data:
  North{}
  East{}
  South{}
  West{}

type VisibleNpc is Data:
  VisibleNpc{id: Nat, point: Geometry.Point, event_id: Maybe<&2, Nat>}

type BattleActor is Data:
  BattleActor{id: Battle.ActorId, side: Battle.Side, hp: Nat,
    phase: Battle.Phase}

type BattleScene is Data:
  BattleScene{tick: U32, status: Battle.BattleStatus,
    actors: List<&2, BattleActor>}

type WorldScene is Data:
  WorldScene{content_identity: Nat, map_id: Nat, position: Geometry.Point,
    elevation: Geometry.Coord,
    facing: Facing, camera_anchor: Geometry.Point,
    visible_npcs: List<&2, VisibleNpc>, battle: Maybe<&2, BattleScene>}

type Scene is Data:
  Scene{world: WorldScene}

def elevation(point: Geometry.Point) -> Geometry.Coord:
  match point:
    case Geometry.Point{x, y, z}: y

def take_npcs(n: Nat, npcs: List<&2, Catalog.Npc>) ->
  List<&2, VisibleNpc>:
  match n:
    case 0n: []
    case 1n+prior:
      match npcs:
        case Nil{}: []
        case Catalog.Npc{id, point, event_id} <> rest:
          VisibleNpc{id, point, event_id} <> take_npcs(prior, rest)

def capped_npcs(npcs: List<&2, Catalog.Npc>) -> List<&2, VisibleNpc>:
  take_npcs(64n, npcs)

def battle_actor(actor: Battle.Actor) -> BattleActor:
  match actor:
    case Battle.Actor{id, side, hp, speed, phase, cooldown}:
      BattleActor{id, side, hp, phase}

def take_battle_actors(n: Nat, actors: List<&2, Battle.Actor>) ->
  List<&2, BattleActor>:
  match n:
    case 0n: []
    case 1n+prior:
      match actors:
        case Nil{}: []
        case actor <> rest:
          battle_actor(actor) <> take_battle_actors(prior, rest)

def battle_view(runtime: Runtime.RuntimeState) -> BattleScene:
  match runtime:
    case Runtime.RuntimeState{Battle.BattleState{now, wait_ticks, actors,
        events, sequence, status}, rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}:
      BattleScene{now, status, take_battle_actors(64n, actors)}

def m7_battle_view(state: M7.State) -> BattleScene:
  match state:
    case M7.State{runtime, economy, roster, captured, catalog}:
      battle_view(runtime)

def playable_battle_view(playable: Playable.PlayableSession) -> BattleScene:
  match playable:
    case Playable.PlayableSession{M7Session.State{battle, rewards,
        enemies, owners}, learning, evolution, learning_choices,
        evolution_choices, pending, ruleset, identity}:
      m7_battle_view(battle)

def maybe_battle(session: Session.WorldSession) -> Maybe<&2, BattleScene>:
  match session:
    case Session.Battling{persistent,
        BattleBridge.State{world, playable, returned}}:
      Some{playable_battle_view(playable)}
    case _: None{}

def world_map(found: Maybe<&2, Catalog.WorldMap>) ->
  List<&2, VisibleNpc>:
  match found:
    case None{}: []
    case Some{Catalog.WorldMap{id, navigation, regions, npcs,
        triggers, transitions}}: capped_npcs(npcs)

def catalog_npcs(catalog: Catalog.Catalog, map_id: Nat) ->
  List<&2, VisibleNpc>:
  match catalog:
    case Catalog.Catalog{ruleset, identity, maps, events}:
      world_map(Catalog.map_by_id(maps, map_id))

def world_view(identity: Nat, map_id: Nat, +point: Geometry.Point, facing: Facing,
  npcs: List<&2, VisibleNpc>, battle: Maybe<&2, BattleScene>) -> WorldScene:
  WorldScene{identity, map_id, point, elevation(point), facing, point,
    npcs, battle}

# Project one current session into bounded display data. Visible NPCs and
# battle actors are capped at 64; source session and RNG are never modified.
def project(catalog: Catalog.Catalog, +session: Session.WorldSession,
  facing: Facing) -> Scene:
  match session:
    case Session.WorldSession{EventBridge.State{
        Exploration.State{map_id, point, meter, pending, identity},
        persistent, active}, battle}:
      Scene{world_view(identity, map_id, point, facing,
        catalog_npcs(catalog, map_id),
        maybe_battle(session))}
    case Session.Battling{persistent, BattleBridge.State{
        Exploration.State{map_id, point, meter, pending, identity},
        playable, returned}}:
      Scene{world_view(identity, map_id, point, facing, [],
        maybe_battle(session))}
