import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/runtime.bend as Mixing
import ../../engine/mixing/driver.bend as Driver
import ../../engine/mixing/ledger.bend as Ledger
import ../../engine/mixing/observation.bend as Learning
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/multi_type.bend as Multi
import ../../engine/battle/runtime.bend as Runtime

def stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def effect_actor(hp: U32, +defense: U32) -> Effects.EffectActor:
  Effects.EffectActor{hp, 10000, defense, defense, stages(), Nil{}, False{}, Nil{}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 10, 0}

def program() -> Effects.EffectProgram:
  Effects.EffectProgram{[Effects.Leaf{Effects.Damage{0n,
    Effects.Target{}, Effects.Physical{}, 40}}]}

def catalog() -> MixModel.Catalog:
  MixModel.Catalog{[MixModel.Recipe{MixModel.RecipeId{3n},
      Math.MoveId{7n}, Math.MoveId{8n}, MixModel.ResultId{4n}}],
    [MixModel.BaseMoveMeta{Math.MoveId{7n}, [Multi.TypeId{1n}], 60, False{}},
     MixModel.BaseMoveMeta{Math.MoveId{8n}, [Multi.TypeId{2n}], 61, False{}}],
    [MixModel.ResultDescriptor{MixModel.ResultId{4n}, program(),
      [Multi.TypeId{1n}, Multi.TypeId{2n}], True{}}]}

def initial_learning() -> Learning.LearningState:
  Learning.LearningState{MixModel.MonsterId{11n},
    [MixModel.RecipeId{3n}],
    [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}

def initial_ledger() -> Ledger.IndividualLedger:
  Ledger.IndividualLedger{initial_learning(), [], []}

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Battle.BattleState{0, 60,
      [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 10000n, 100n,
          Battle.Ready{}, 0},
       Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 10000n, 90n,
          Battle.Ready{}, 0}], Nil{}, 0n, Battle.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 0, False{}},
     Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Battle.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Battle.ActorId{0n}, Battle.ActorId{1n},
      Effects.EffectWorld{effect_actor(10000, 10), effect_actor(10000, 10)}}}}

def request() -> Mixing.MixSubmitRequest:
  Mixing.MixSubmitRequest{True{}, True{}, Battle.ActorId{0n},
    Battle.ActorId{1n}, MixModel.MonsterId{11n}, Math.MoveId{7n},
    Math.MoveId{8n}, catalog(), initial_learning(),
    [Math.MoveId{7n}, Math.MoveId{8n}], profile(),
    [Multi.TypeId{1n}], [Multi.TypeId{2n}],
    [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
      [Math.MoveId{7n}, Math.MoveId{8n}]},
     Runtime.RuntimeMixWitness{12n, Battle.ActorId{1n}, True{}, True{},
       [Math.MoveId{7n}, Math.MoveId{8n}]}],
    Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{}, Math.AlwaysHit{},
      Effects.NormalPhysical{}, 0}, 0, 30, 0n, 0n}

def accepted_state(result: Mixing.MixSubmitResult) -> Runtime.RuntimeState:
  match result:
    case Mixing.MixSubmitAccepted{state, emitted}: state
    case Mixing.MixSubmitRejected{state, reason}: state
    case Mixing.MixSubmitRuntimeRejected{state, diagnostics}: state

def accepted_runtime_state() -> Runtime.RuntimeState:
  +submitted = {Mixing.submit_mix(8n, state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}}]) : Mixing.MixSubmitResult}
  accepted_state(submitted)

def real_runtime_result() -> Runtime.RuntimeRunResult:
  Runtime.runtime_run(64n, accepted_runtime_state())

def actual_drive() -> Driver.DrivenRunResult:
  Driver.run(64n, accepted_runtime_state(), catalog(), initial_ledger())

def actor_progress(ledger: Ledger.IndividualLedger, expected: U32) -> Bool:
  match ledger:
    case Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{11n}, observed,
          [Learning.LearnedRecipe{MixModel.RecipeId{3n}, progress}]},
        staged, completed}:
      U32.is_eq(progress, expected)
    case _: False{}

def staged_observation_exists(staged: List<&2, Learning.StagedObservation>) -> Bool:
  match staged:
    case [Learning.StagedObservation{sequence, MixModel.RecipeId{3n},
        [MixModel.MonsterId{11n}, MixModel.MonsterId{12n}]}]: True{}
    case _: False{}

def terminal_ledger_shape(learning: Learning.LearningState,
  staged: List<&2, Learning.StagedObservation>) -> Bool:
  match learning staged:
    case Learning.LearningState{MixModel.MonsterId{11n},
         [MixModel.RecipeId{3n}],
         [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 1}]}
         Nil{}: True{}
    case _ _: False{}

def nonterminal_drive_check(result: Driver.DrivenRunResult) -> Bool:
  match result:
    case Driver.DrivenRunResult{
        Runtime.RuntimeRunBoundary{state, emitted, combat_events},
        Ledger.IndividualLedger{learning, +staged, completed}}:
      Bool.and(actor_progress(Ledger.IndividualLedger{learning, staged,
          completed}, 1), staged_observation_exists(staged))
    case Driver.DrivenRunResult{
        Runtime.RuntimeRunYielded{state, emitted, combat_events},
        Ledger.IndividualLedger{learning, +staged, completed}}:
      Bool.and(actor_progress(Ledger.IndividualLedger{learning, staged,
          completed}, 1), staged_observation_exists(staged))
    case Driver.DrivenRunResult{
        Runtime.RuntimeRunTerminal{state, emitted, combat_events},
        Ledger.IndividualLedger{learning, +staged, completed}}:
      terminal_ledger_shape(learning, staged)
    case _: False{}

def force_victory(state: Runtime.RuntimeState) -> Runtime.RuntimeState:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}:
      match battle:
        case Battle.BattleState{now, wait_ticks, actors, events, sequence,
            status}:
          Runtime.RuntimeState{Battle.BattleState{now, wait_ticks, actors,
            events, sequence, Battle.Victory{}}, rng, encounter, failed,
            sources, reservations, trapped, defenders, effects}

def terminalize_result(+result: Runtime.RuntimeRunResult) ->
  Runtime.RuntimeRunResult:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      Runtime.RuntimeRunTerminal{force_victory(state), emitted, combat_events}
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      Runtime.RuntimeRunTerminal{force_victory(state), emitted, combat_events}
    case Runtime.RuntimeRunStalled{state, emitted, combat_events}:
      Runtime.RuntimeRunTerminal{force_victory(state), emitted, combat_events}
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}: result
    case Runtime.RuntimeRunRejected{state, diagnostics}: result
    case Runtime.RuntimeRunFault{state, reason}: result

def terminal_drive_result(ledger: Ledger.IndividualLedger,
  result: Runtime.RuntimeRunResult) -> Driver.DrivenRunResult:
  Driver.process_result(catalog(), terminalize_result(result), ledger)

def terminal_merge_code(result: Driver.DrivenRunResult) -> Bool:
  match result:
    case Driver.DrivenRunResult{
        Runtime.RuntimeRunTerminal{state, emitted, combat_events},
        Ledger.IndividualLedger{
          Learning.LearningState{MixModel.MonsterId{11n},
            [MixModel.RecipeId{3n}],
            [Learning.LearnedRecipe{MixModel.RecipeId{3n}, progress}]},
          [], completed}}:
      U32.is_eq(progress, 1)
    case _: False{}

def second_ledger(result: Driver.DrivenRunResult) -> Ledger.IndividualLedger:
  match result:
    case Driver.DrivenRunResult{runtime_result, ledger}: ledger

def terminal_replay_from(+driven: Driver.DrivenRunResult) -> Bool:
  match driven:
    case Driver.DrivenRunResult{+runtime_result, ledger}:
      +first_terminal = terminal_drive_result(ledger, runtime_result)
      +second_terminal = terminal_drive_result(
        second_ledger(first_terminal), runtime_result)
      Bool.and(terminal_merge_code(first_terminal),
        terminal_merge_code(second_terminal))

def terminal_and_replay() -> Bool:
  terminal_replay_from(actual_drive())

def unchanged_ledger_shape(ledger: Ledger.IndividualLedger) -> Bool:
  match ledger:
    case Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{11n},
          [MixModel.RecipeId{3n}],
          [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}, [], []}:
      True{}
    case _: False{}

def rejected_preserved(result: Driver.DrivenRunResult) -> Bool:
  match result:
    case Driver.DrivenRunResult{
        Runtime.RuntimeRunRejected{state, [Effects.EmptyProgram{}]}, ledger}:
      unchanged_ledger_shape(ledger)
    case _: False{}

def fault_preserved(result: Driver.DrivenRunResult) -> Bool:
  match result:
    case Driver.DrivenRunResult{
        Runtime.RuntimeRunFault{state,
          Some{Rng.RngInvalidState{Rng.RngState{1, 2, 3, 4}}}}, ledger}:
      unchanged_ledger_shape(ledger)
    case _: False{}

def rejected_fault_behavior() -> Bool:
  Bool.and(rejected_preserved(Driver.process_result(catalog(),
      Runtime.RuntimeRunRejected{state(), [Effects.EmptyProgram{}]},
      initial_ledger())),
    fault_preserved(Driver.process_result(catalog(),
      Runtime.RuntimeRunFault{state(),
        Some{Rng.RngInvalidState{Rng.RngState{1, 2, 3, 4}}}},
      initial_ledger())))

def enemy_terminal_observed(result: Driver.DrivenRunResult) -> Bool:
  match result:
    case Driver.DrivenRunResult{Runtime.RuntimeRunTerminal{state, emitted,
        combat_events}, Ledger.IndividualLedger{
          Learning.LearningState{MixModel.MonsterId{12n},
            [MixModel.RecipeId{3n}], []}, [], completed}}: True{}
    case _: False{}

def enemy_discovery() -> Bool:
  enemy_terminal_observed(Driver.process_result(catalog(),
    terminalize_result(real_runtime_result()),
    Ledger.empty(MixModel.MonsterId{12n})))

def synthetic_commit(sequence: Nat) -> Runtime.RuntimeEvent:
  Runtime.RuntimeMixEffectsCommitted{sequence, 3n, 11n,
    [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
      [Math.MoveId{7n}, Math.MoveId{8n}]}],
    [Effects.DamageApplied{0n, Effects.Target{}, Effects.Physical{}, 1,
      False{}}], False{}}

def two_event_ledger(result: Driver.DrivenRunResult) -> Bool:
  match result:
    case Driver.DrivenRunResult{Runtime.RuntimeRunBoundary{state, emitted,
        combat_events}, Ledger.IndividualLedger{
          Learning.LearningState{MixModel.MonsterId{11n}, observed,
            [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 2}]},
          first <> second <> Nil{}, completed}}: True{}
    case _: False{}

def multiple_event_fold() -> Bool:
  two_event_ledger(Driver.process_result(catalog(),
    Runtime.RuntimeRunBoundary{state(), [],
      [synthetic_commit(1n), synthetic_commit(2n)]}, initial_ledger()))

def runtime_kind(result: Driver.DrivenRunResult) -> Nat:
  match result:
    case Driver.DrivenRunResult{Runtime.RuntimeRunBoundary{_, _, _}, _}: 1n
    case Driver.DrivenRunResult{Runtime.RuntimeRunYielded{_, _, _}, _}: 2n
    case Driver.DrivenRunResult{Runtime.RuntimeRunTerminal{_, _, _}, _}: 3n
    case Driver.DrivenRunResult{Runtime.RuntimeRunStalled{_, _, _}, _}: 4n
    case _: 5n

def initial_ledgers() -> List<&2, Ledger.IndividualLedger>:
  [initial_ledger(), Ledger.empty(MixModel.MonsterId{12n})]

def roster_terminal_observed(result: Driver.DrivenRosterResult) -> Bool:
  match result:
    case Driver.DrivenRosterResult{
      Runtime.RuntimeRunTerminal{state, emitted, combat_events},
      [Ledger.IndividualLedger{
         Learning.LearningState{MixModel.MonsterId{11n},
           [MixModel.RecipeId{3n}],
           [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 1}]},
         [], completed_a},
       Ledger.IndividualLedger{
         Learning.LearningState{MixModel.MonsterId{12n},
           [MixModel.RecipeId{3n}], []}, [], completed_b}]}:
      True{}
    case _: False{}

def roster_terminal_merge() -> Bool:
  roster_terminal_observed(Driver.process_roster_result(catalog(),
    terminalize_result(real_runtime_result()), initial_ledgers()))

def roster_rejected_preserved(result: Driver.DrivenRosterResult) -> Bool:
  match result:
    case Driver.DrivenRosterResult{Runtime.RuntimeRunRejected{state,
        diagnostics},
      [Ledger.IndividualLedger{
         Learning.LearningState{MixModel.MonsterId{11n},
           [MixModel.RecipeId{3n}],
           [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}, [], []},
       Ledger.IndividualLedger{
         Learning.LearningState{MixModel.MonsterId{12n}, [], []}, [], []}]}:
      True{}
    case _: False{}

def roster_rejection() -> Bool:
  roster_rejected_preserved(Driver.process_roster_result(catalog(),
    Runtime.RuntimeRunRejected{state(), []}, initial_ledgers()))

def main() -> List<&2, Nat>:
  [runtime_kind(actual_drive()),
   U32.to_nat(Bool.to_u32(nonterminal_drive_check(actual_drive()))),
   U32.to_nat(Bool.to_u32(terminal_and_replay())),
   U32.to_nat(Bool.to_u32(rejected_fault_behavior())),
   U32.to_nat(Bool.to_u32(enemy_discovery())),
   U32.to_nat(Bool.to_u32(multiple_event_fold())),
   U32.to_nat(Bool.to_u32(roster_terminal_merge())),
   U32.to_nat(Bool.to_u32(roster_rejection()))]
