import Base
import ../../build/m8_catalog.bend as Loaded
import ../../engine/world/world_session.bend as WorldSession
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/events.bend as Events
import ../../engine/world/commands.bend as Commands
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/battle_bridge.bend as BattleBridge
import ../../engine/world/encounter_handoff.bend as Handoff
import ../../engine/m7/playable.bend as Playable
import ../../engine/m7/session.bend as Session
import ../../engine/m7/reward_bridge.bend as RewardBridge
import ../../engine/progression/core.bend as Progression
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/rng.bend as Rng
import ../m7/session_test.bend as BattleFixture
import ../m7/session_learning_test.bend as LearningFixture

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 1024}}

def east() -> Geometry.Input:
  Geometry.Input{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, False{}, False{}}

def enemy() -> Session.Enemy:
  Session.Enemy{Battle.ActorId{1n},
    Progression.Individual{88n, 1n, 1, 0, 1, 12,
      BattleFixture.zero_ivs(), [], [], [], [], [0]},
    BattleFixture.base_stats(), Progression.DefeatedReward{1, 100, 5}}

def reward_context_from(context: RewardBridge.Context) -> RewardBridge.Context:
  match context:
    case RewardBridge.Context{encounter, defeated, owned, items,
        economy, ledger}:
      RewardBridge.Context{1n, defeated, owned, items, economy, ledger}

def reward_context() -> RewardBridge.Context:
  reward_context_from(LearningFixture.full_context())

def battle() -> Maybe<Playable.PlayableSession>:
  Playable.open(Session.State{BattleFixture.battle_state(),
      reward_context(), [enemy()], [BattleFixture.owner_binding()]},
    Playable.ContentCatalog{LearningFixture.catalog(), [], 7n,
      Loaded.identity()}, 7n, Loaded.identity())

def initial(result: Exploration.OpenResult) -> Maybe<WorldSession.WorldSession>:
  match result:
    case Exploration.Opened{state}:
      Some{WorldSession.WorldSession{EventBridge.State{state,
        Events.World{[], []}, None{}}, None{}}}
    case _: None{}

def near_threshold(session: WorldSession.WorldSession) ->
  WorldSession.WorldSession:
  match session:
    case WorldSession.WorldSession{EventBridge.State{
        Exploration.State{map_id, point,
          Encounters.Meter{region, weighted, +threshold, safe, rng},
          pending, identity}, persistent, None{}}, None{}}:
      WorldSession.WorldSession{EventBridge.State{
        Exploration.State{map_id, point,
          Encounters.Meter{region, Nat.sub(threshold, 1n), threshold,
            safe, rng}, pending, identity}, persistent, None{}}, None{}}
    case other: other

def returned_world(state: WorldSession.WorldSession) -> Bool:
  match state:
    case WorldSession.WorldSession{
        EventBridge.State{Exploration.State{1n, point, meter, None{},
          identity}, Events.World{Events.Value{7n, 1n} <> values,
          entities}, None{}}, None{}}:
      Nat.is_eq(identity, Loaded.identity())
    case _: False{}

def returned(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.BattleReturned{state, status, events, captures}:
      returned_world(WorldSession.resume_world(state))
    case _: False{}

def after_choice(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.BattleChoice{state}:
      returned(WorldSession.choose_move(state, 77n, 7, False{}, None{}))
    case _: False{}

def after_submit(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.Advanced{state}:
      after_choice(WorldSession.advance_battle(state))
    case _: False{}

def after_encounter(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.EncounterReady{state, 1n, 1n}:
      after_submit(WorldSession.submit_battle(state, 10n,
        [BattleFixture.lethal_move(),
          Runtime.RuntimeWait{Battle.ActorId{1n}}]))
    case _: False{}

def after_prepared(result: WorldSession.PrepareResult,
  playable: Playable.PlayableSession) -> Bool:
  match result:
    case WorldSession.Prepared{WorldSession.PreparedSession{world,
        Handoff.Prepared{selected_world, encounter_id, species_id, level,
          +source_rng}}, 1n, 1n}:
      after_encounter(WorldSession.begin_encounter(
        WorldSession.PreparedSession{world,
          Handoff.Prepared{selected_world, encounter_id, species_id, level,
            source_rng}}, Handoff.rebase_playable(playable, source_rng)))
    case _: False{}

def with_battle(state: WorldSession.WorldSession,
  battle: Maybe<Playable.PlayableSession>) -> Bool:
  match battle:
    case Some{playable}:
      after_prepared(WorldSession.prepare_encounter(
        Loaded.encounter_tables(), state), playable)
    case _: False{}

def after_move(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.EncounterPending{state, 1n}:
      with_battle(state, battle())
    case _: False{}

def after_event(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.Advanced{state}:
      after_move(WorldSession.move(Loaded.catalog(), near_threshold(state),
        east()))
    case _: False{}

def after_signal(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.Advanced{state}:
      after_event(WorldSession.event_step(state, Events.NoInput{}))
    case _: False{}

def after_command(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.Advanced{state}:
      after_signal(WorldSession.event_step(state, Events.NoInput{}))
    case _: False{}

def from_initial(found: Maybe<WorldSession.WorldSession>) -> Bool:
  match found:
    case None{}: False{}
    case Some{state}:
      after_command(WorldSession.command(Loaded.catalog(), state,
        Commands.Activate{1n}))

def run_once() -> Bool:
  from_initial(initial(Exploration.open(Loaded.catalog(),
    Loaded.entry_map(), point(), Rng.RngState{1, 2, 3, 4},
    Loaded.identity())))

def main() -> List<&2, Bool>:
  [run_once(), run_once()]
