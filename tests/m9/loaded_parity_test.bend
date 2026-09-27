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
import ../../engine/m7/battle.bend as M7Battle
import ../../engine/m7/reward_bridge.bend as RewardBridge
import ../../engine/progression/core.bend as Progression
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/rng.bend as Rng
import ../../engine/presentation/projection.bend as Projection
import ../../engine/presentation/wire.bend as Wire
import ../../engine/world/presentation_cues.bend as Cues
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

def near_threshold(session: WorldSession.WorldSession) ->
  WorldSession.WorldSession:
  match session:
    case WorldSession.WorldSession{EventBridge.State{
        Exploration.State{map_id, point,
          Encounters.Meter{region, weighted, +threshold, safe, rng},
          pending, +identity}, +persistent, None{}}, None{}}:
      WorldSession.WorldSession{EventBridge.State{
        Exploration.State{map_id, point,
          Encounters.Meter{region, Nat.sub(threshold, 1n), threshold,
            safe, rng}, pending, identity}, persistent, None{}}, None{}}
    case other: other

def initial(result: Exploration.OpenResult) -> Maybe<WorldSession.WorldSession>:
  match result:
    case Exploration.Opened{state}:
      Some{near_threshold(WorldSession.WorldSession{EventBridge.State{state,
        Events.World{[], []}, None{}}, None{}})}
    case _: None{}

def return_status_code(status: Session.StepStatus) -> Nat:
  match status:
    case Session.Committed{}: 0n
    case Session.Skipped{}: 1n
    case Session.Advancing{}: 2n
    case Session.Rejected{}: 3n
    case Session.Idle{}: 4n

def maybe_region_csv(region: Maybe<&2, Nat>) -> String:
  match region:
    case None{}: "0,0"
    case Some{value}: "1," ++ Nat.show(value)

def rng_csv(rng: Rng.RngState) -> String:
  match rng:
    case Rng.RngState{a, b, c, d}:
      Nat.show(U32.to_nat(a)) ++ "," ++ Nat.show(U32.to_nat(b)) ++
      "," ++ Nat.show(U32.to_nat(c)) ++ "," ++ Nat.show(U32.to_nat(d))

def value_csv_join(values: List<&2, Events.Value>, output: String) -> String:
  match values:
    case Nil{}: output
    case Events.Value{key, value} <> rest:
      value_csv_join(rest, output ++ ";" ++ Nat.show(key) ++ "," ++
        Nat.show(value))

def value_csv(values: List<&2, Events.Value>) -> String:
  match values:
    case Nil{}: ""
    case Events.Value{key, value} <> rest:
      value_csv_join(rest, Nat.show(key) ++ "," ++ Nat.show(value))

def persistent_values(world: Events.World) -> List<&2, Events.Value>:
  match world:
    case Events.World{values, entities}: values

def event_values(world: Events.World) -> String:
  match world:
    case Events.World{values, entities}:
      value_csv(values)

def nat_csv_join(values: List<&2, Nat>, output: String) -> String:
  match values:
    case Nil{}: output
    case value <> rest:
      nat_csv_join(rest, output ++ "," ++ Nat.show(value))

def nat_csv(values: List<&2, Nat>) -> String:
  match values:
    case Nil{}: ""
    case value <> rest: nat_csv_join(rest, Nat.show(value))

def battle_status_code(status: Battle.BattleStatus) -> Nat:
  match status:
    case Battle.AwaitingCommands{}: 0n
    case Battle.Advancing{}: 1n
    case Battle.Victory{}: 2n
    case Battle.Defeat{}: 3n
    case Battle.Draw{}: 4n
    case Battle.Timeout{}: 5n
    case Battle.Escaped{}: 6n
    case Battle.SchedulerStalled{}: 7n

def transition_fields(event: Battle.TransitionEvent) -> List<&2, Nat>:
  match event:
    case Battle.BattleBecameReady{Battle.ActorId{actor}, tick}:
      [0n, actor, U32.to_nat(tick)]
    case Battle.BattleActionExecuted{Battle.ActorId{actor},
        Battle.ActorId{target}, damage, recoil}:
      [1n, actor, target, damage, recoil]
    case Battle.BattleActionCancelled{Battle.ActorId{actor}}: [2n, actor]
    case Battle.BattleActionFizzled{Battle.ActorId{actor},
        Battle.ActorId{target}}: [3n, actor, target]
    case Battle.BattleActorSwitched{Battle.ActorId{actor},
        Battle.ActorId{incoming}}: [4n, actor, incoming]
    case Battle.BattleEscapeFailed{Battle.ActorId{actor}}: [5n, actor]
    case Battle.BattleEscapeSucceeded{Battle.ActorId{actor}}: [6n, actor]
    case Battle.BattleCompleted{status, tick}:
      [7n, battle_status_code(status), U32.to_nat(tick)]
    case Battle.BattlePendingDiscarded{count}: [8n, count]

def append_fields(left: List<&2, Nat>, right: List<&2, Nat>) -> List<&2, Nat>:
  match left:
    case Nil{}: right
    case value <> rest: value <> append_fields(rest, right)

def transition_fields_join(events: List<&2, Battle.TransitionEvent>,
  output: List<&2, Nat>) -> List<&2, Nat>:
  match events:
    case Nil{}: output
    case event <> rest:
      transition_fields_join(rest,
        append_fields(output, transition_fields(event)))

def transition_csv(events: List<&2, Battle.TransitionEvent>) -> String:
  nat_csv(transition_fields_join(events, []))

def success_code(success: Bool) -> Nat:
  match success:
    case False{}: 0n
    case True{}: 1n

def capture_fields(event: M7Battle.CaptureEvent) -> List<&2, Nat>:
  match event:
    case M7Battle.CaptureResolved{Battle.ActorId{source},
        Battle.ActorId{target}, individual, species, success,
        destination, chance, draw}:
      [source, target, species, success_code(success),
        U32.to_nat(chance), U32.to_nat(draw)]

def capture_fields_join(events: List<&2, M7Battle.CaptureEvent>,
  output: List<&2, Nat>) -> List<&2, Nat>:
  match events:
    case Nil{}: output
    case event <> rest:
      capture_fields_join(rest, append_fields(output, capture_fields(event)))

def capture_csv(events: List<&2, M7Battle.CaptureEvent>) -> String:
  nat_csv(capture_fields_join(events, []))

def event_entities(world: Events.World) -> String:
  match world:
    case Events.World{values, entities}: nat_csv(entities)

def final_return_valid(status: Session.StepStatus, map_id: Nat,
  identity: Nat, values: List<&2, Events.Value>) -> Bool:
  match status values:
    case Session.Committed{} Events.Value{7n, 1n} <> rest:
      Bool.and(Nat.is_eq(map_id, 1n), Nat.is_eq(identity, Loaded.identity()))
    case _ _: False{}

def checked_signature(valid: Bool, signature: String) -> String:
  match valid:
    case True{}: signature
    case False{}: "FAIL"

def final_signature(+status: Session.StepStatus,
  battle_scene: String, events: List<&2, Battle.TransitionEvent>,
  captures: List<&2, M7Battle.CaptureEvent>,
  state: WorldSession.WorldSession) -> String:
  match state:
    case WorldSession.WorldSession{EventBridge.State{
        Exploration.State{+map_id, +point,
          Encounters.Meter{+region, +weighted, +threshold, +safe, +rng},
          pending, +identity}, +persistent, None{}}, None{}}:
      signature = "OK|" ++ Nat.show(return_status_code(status)) ++ "|" ++
        Wire.serialize(Projection.project(Loaded.catalog(), state,
          Projection.East{})) ++ "|" ++ maybe_region_csv(region) ++ "," ++
        Nat.show(weighted) ++ "," ++ Nat.show(threshold) ++ "," ++
        Nat.show(safe) ++ "," ++ rng_csv(rng) ++ "|" ++
        event_values(persistent) ++ "|entities=" ++ event_entities(persistent) ++
        "|battle=" ++ battle_scene ++ "|events=" ++ transition_csv(events) ++
        "|captures=" ++ capture_csv(captures)
      checked_signature(final_return_valid(status, map_id, identity,
        persistent_values(persistent)), signature)
    case _: "FAIL"

def returned(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.BattleReturned{+state, status, +events, +captures}:
      final_signature(status,
        Wire.serialize(Projection.project(Loaded.catalog(), state,
          Projection.East{})),
        events, captures,
        WorldSession.resume_world(state))
    case _: "FAIL"

def after_choice(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.BattleChoice{+state}:
      returned(WorldSession.choose_move(state, 77n, 7, False{}, None{}))
    case _: "FAIL"

def after_submit(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.Advanced{state}:
      after_choice(WorldSession.advance_battle(state))
    case _: "FAIL"

def after_encounter(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.EncounterReady{+state, 1n, 1n}:
      after_submit(WorldSession.submit_battle(state, 10n,
        [BattleFixture.lethal_move(),
          Runtime.RuntimeWait{Battle.ActorId{1n}}]))
    case _: "FAIL"

def after_prepared(result: WorldSession.PrepareResult,
  playable: Playable.PlayableSession) -> String:
  match result:
    case WorldSession.Prepared{WorldSession.PreparedSession{world,
        Handoff.Prepared{selected_world, encounter_id, species_id, level,
          +source_rng}}, 1n, 1n}:
      after_encounter(WorldSession.begin_encounter(
        WorldSession.PreparedSession{world,
          Handoff.Prepared{selected_world, encounter_id, species_id, level,
            source_rng}}, Handoff.rebase_playable(playable, source_rng)))
    case _: "FAIL"

def with_battle(state: WorldSession.WorldSession,
  battle: Maybe<Playable.PlayableSession>) -> String:
  match battle:
    case Some{playable}:
      after_prepared(WorldSession.prepare_encounter(
        Loaded.encounter_tables(), state), playable)
    case _: "FAIL"

def after_move(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.EncounterPending{+state, 1n}:
      with_battle(state, battle())
    case _: "FAIL"

def after_event(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.Advanced{state}:
      after_move(WorldSession.move(Loaded.catalog(), state, east()))
    case _: "FAIL"

def after_final_event_step(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.Advanced{state}:
      after_event(WorldSession.event_step(state, Events.NoInput{}))
    case _: "FAIL"

def after_signal_step(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.Advanced{state}:
      after_final_event_step(WorldSession.event_step(state, Events.NoInput{}))
    case _: "FAIL"

def after_command(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.Advanced{state}:
      after_final_event_step(WorldSession.event_step(state, Events.NoInput{}))
    case _: "FAIL"

def after_presented_final(result: WorldSession.PresentedResult) -> String:
  match result:
    case WorldSession.PresentedResult{result, cues}:
      after_event(result)

def after_presented_signal(result: WorldSession.PresentedResult) -> String:
  match result:
    case WorldSession.PresentedResult{WorldSession.Advanced{+state}, cues}:
      after_presented_final(WorldSession.event_step_presented(state,
        Events.NoInput{}, 42n))
    case _: "FAIL"

def observed_command(result: WorldSession.PresentedResult) -> String:
  match result:
    case WorldSession.PresentedResult{WorldSession.Advanced{+state}, cues}:
      after_presented_signal(WorldSession.event_step_presented(state,
        Events.NoInput{}, 41n))
    case _: "FAIL"

def observed_initial(found: Maybe<WorldSession.WorldSession>) -> String:
  match found:
    case None{}: "FAIL"
    case Some{state}:
      observed_command(WorldSession.command_presented(Loaded.catalog(), state,
        Commands.Activate{1n}, 40n))

def observed_run_once() -> String:
  observed_initial(initial(Exploration.open(Loaded.catalog(),
    Loaded.entry_map(), point(), Rng.RngState{1, 2, 3, 4},
    Loaded.identity())))

def from_initial(found: Maybe<WorldSession.WorldSession>) -> String:
  match found:
    case None{}: "FAIL"
    case Some{+state}:
      after_command(WorldSession.command(Loaded.catalog(), state,
        Commands.Activate{1n}))

def run_once() -> String:
  from_initial(initial(Exploration.open(Loaded.catalog(),
    Loaded.entry_map(), point(), Rng.RngState{1, 2, 3, 4},
    Loaded.identity())))

def loaded_scene_from(found: Maybe<WorldSession.WorldSession>) -> String:
  match found:
    case None{}: "open-rejected"
    case Some{+state}:
      Wire.serialize(Projection.project(Loaded.catalog(), state,
        Projection.East{}))

def append_cues(scene: String, presented: WorldSession.PresentedResult) -> String:
  match presented:
    case WorldSession.PresentedResult{result, cues}:
      scene ++ "\n" ++ Wire.serialize_cues(cues)

def append_cue_list(left: List<&2, Cues.Cue>,
  right: List<&2, Cues.Cue>) -> List<&2, Cues.Cue>:
  match left:
    case Nil{}: right
    case cue <> rest: cue <> append_cue_list(rest, right)

def observed_third_step(scene: String, first_cues: List<&2, Cues.Cue>,
  second_cues: List<&2, Cues.Cue>, third: WorldSession.PresentedResult) -> String:
  match third:
    case WorldSession.PresentedResult{result, cues}:
      scene ++ "\n" ++ Wire.serialize_cues(first_cues) ++
        "\n" ++ Wire.serialize_cues(append_cue_list(second_cues, cues))

def observed_second_step(scene: String,
  first_cues: List<&2, Cues.Cue>, second: WorldSession.PresentedResult) -> String:
  match second:
    case WorldSession.PresentedResult{result, cues}:
      match result:
        case WorldSession.Advanced{state}:
          observed_third_step(scene, first_cues, cues,
            WorldSession.event_step_presented(state, Events.NoInput{}, 42n))
        case _: scene

def observed_steps(scene: String, first: WorldSession.PresentedResult) -> String:
  match first:
    case WorldSession.PresentedResult{WorldSession.Advanced{state}, cues}:
      observed_second_step(scene, cues,
        WorldSession.event_step_presented(state, Events.NoInput{}, 41n))
    case _: scene

def observed_scene_from(found: Maybe<WorldSession.WorldSession>) -> String:
  match found:
    case None{}: "open-rejected"
    case Some{+state}:
      scene = Wire.serialize(Projection.project(Loaded.catalog(), state,
        Projection.East{}))
      presented = WorldSession.command_presented(Loaded.catalog(), state,
        Commands.Activate{1n}, 40n)
      observed_steps(scene, presented)

def initial_open() -> Maybe<WorldSession.WorldSession>:
  initial(Exploration.open(Loaded.catalog(), Loaded.entry_map(), point(),
    Rng.RngState{1, 2, 3, 4}, Loaded.identity()))

def observed_prefix() -> String:
  loaded_scene_from(initial_open()) ++ "\n" ++ observed_scene_from(initial_open())

def output_tail(+headless: String, +observed: String) -> String:
  headless ++ "\n" ++ observed ++ "\n" ++
    Bool.show(Bool.and(String.eq(headless, observed),
      Bool.not(String.eq(headless, "FAIL"))))

def main() -> String:
  # Both routes replay the loaded journey; the observed route also projects
  # scenes and cue CSVs while the shared battle/return transitions stay equal.
  +headless = run_once()
  +observed = observed_run_once()
  observed_prefix() ++ "\n" ++ output_tail(headless, observed)
