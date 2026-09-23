import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/runtime.bend as Mixing
import ../../engine/mixing/driver.bend as MixDriver
import ../../engine/mixing/ledger.bend as Ledger
import ../../engine/mixing/observation.bend as Learning
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/multi_type.bend as Multi
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/replay/runtime_fold.bend as Replay

def stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def actor(id: Nat, hp: Nat, side: Battle.Side, speed: Nat) -> Battle.Actor:
  Battle.Actor{Battle.ActorId{id}, side, hp, speed, Battle.Ready{}, 0}

def effect_actor(hp: U32) -> Effects.EffectActor:
  Effects.EffectActor{hp, 100, 10, 10, stages(), Nil{}, False{}, Nil{}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 10, 0}

def program() -> Effects.EffectProgram:
  Effects.EffectProgram{[Effects.Leaf{Effects.Damage{0n,
    Effects.Target{}, Effects.Physical{}, 40}}]}

def catalog() -> MixModel.Catalog:
  MixModel.Catalog{
    [MixModel.Recipe{MixModel.RecipeId{3n}, Math.MoveId{7n},
      Math.MoveId{8n}, MixModel.ResultId{4n}}],
    [MixModel.BaseMoveMeta{Math.MoveId{7n}, [Multi.TypeId{1n}], 60, False{}},
     MixModel.BaseMoveMeta{Math.MoveId{8n}, [Multi.TypeId{2n}], 61, False{}}],
    [MixModel.ResultDescriptor{MixModel.ResultId{4n}, program(),
      [Multi.TypeId{1n}, Multi.TypeId{2n}], True{}}]}

def learning(individual: Nat) -> Learning.LearningState:
  Learning.LearningState{MixModel.MonsterId{individual},
    [MixModel.RecipeId{3n}],
    [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Battle.BattleState{0, 60,
      [actor(0n, 100n, Battle.Player{}, 100n),
       actor(1n, 30n, Battle.Enemy{}, 90n)], Nil{}, 0n,
      Battle.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 0, False{}},
     Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Battle.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Battle.ActorId{0n}, Battle.ActorId{1n},
      Effects.EffectWorld{effect_actor(100), effect_actor(30)}}}}

def request() -> Mixing.MixSubmitRequest:
  Mixing.MixSubmitRequest{True{}, True{}, Battle.ActorId{0n},
    Battle.ActorId{1n}, MixModel.MonsterId{11n}, Math.MoveId{7n},
    Math.MoveId{8n}, catalog(), learning(11n),
    [Math.MoveId{7n}, Math.MoveId{8n}], profile(),
    [Multi.TypeId{1n}], [Multi.TypeId{2n}],
    [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
       [Math.MoveId{7n}, Math.MoveId{8n}]},
     Runtime.RuntimeMixWitness{12n, Battle.ActorId{1n}, True{}, True{},
       [Math.MoveId{7n}, Math.MoveId{8n}]}],
    Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{},
      Math.AlwaysHit{}, Effects.NormalPhysical{}, 0}, 0, 30, 0n, 0n}

def first_replay() -> Replay.RuntimeReplay:
  Replay.run_mixed(64n, state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}}])

def second_replay() -> Replay.RuntimeReplay:
  Replay.run_mixed(64n, state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}}])

def canonical_effects(values: List<&2, Effects.EffectEvent>) -> Bool:
  match values:
    case [Effects.DamageApplied{0n, Effects.Target{}, Effects.Physical{},
        30, False{}},
      Effects.DamageComponentsApplied{0n,
        [Multi.ComponentDamage{Multi.TypeId{1n}, 20, 75, False{}, True{}},
         Multi.ComponentDamage{Multi.TypeId{2n}, 20, 100, False{}, False{}}]},
      Effects.OpportunityEnded{False{}, 0}]: True{}
    case _: False{}

def canonical_event(events: List<&2, Runtime.RuntimeEvent>) -> Bool:
  match events:
    case [Runtime.RuntimeMixEffectsCommitted{0n, 3n, 11n,
        [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
          [Math.MoveId{7n}, Math.MoveId{8n}]},
         Runtime.RuntimeMixWitness{12n, Battle.ActorId{1n}, True{}, True{},
          [Math.MoveId{7n}, Math.MoveId{8n}]}], effect_events, False{}}]:
      canonical_effects(effect_events)
    case _: False{}

def canonical_transitions(values: List<&2, Battle.TransitionEvent>) -> Bool:
  match values:
    case [Battle.BattleActionExecuted{Battle.ActorId{0n},
        Battle.ActorId{1n}, 30n, 0n},
      Battle.BattleCompleted{Battle.Victory{}, 0},
      Battle.BattlePendingDiscarded{1n}]: True{}
    case _: False{}

def canonical_battle_state(state: Runtime.RuntimeState) -> Bool:
  match state:
    case Runtime.RuntimeState{
      Battle.BattleState{_, _, _, _, _, Battle.Victory{}},
      Rng.RngState{7, 0, 1026, 12288}, _, _, _, [], _, _, _}: True{}
    case _: False{}

def replay_ok(result: Replay.RuntimeReplay) -> Bool:
  match result:
    case Replay.RuntimeReplayFinished{state, emitted, combat_events}:
      Bool.and(canonical_battle_state(state),
        Bool.and(canonical_transitions(emitted), canonical_event(combat_events)))
    case _: False{}

def same_replay(left: Replay.RuntimeReplay,
  right: Replay.RuntimeReplay) -> Bool:
  match left right:
    case Replay.RuntimeReplayFinished{left_state, left_emitted, left_events}
         Replay.RuntimeReplayFinished{right_state, right_emitted, right_events}:
      Bool.and(replay_ok(left), replay_ok(right))
    case _ _: False{}

def result_for_learning(result: Replay.RuntimeReplay) -> Runtime.RuntimeRunResult:
  match result:
    case Replay.RuntimeReplayFinished{state, emitted, combat_events}:
      Runtime.RuntimeRunTerminal{state, emitted, combat_events}
    case Replay.RuntimeReplayFuelExhausted{state, emitted, combat_events}:
      Runtime.RuntimeRunYielded{state, emitted, combat_events}
    case Replay.RuntimeReplayRejected{state, diagnostics}:
      Runtime.RuntimeRunRejected{state, []}
    case Replay.RuntimeReplayEffectRejected{state, diagnostics}:
      Runtime.RuntimeRunRejected{state, diagnostics}
    case Replay.RuntimeReplayMixRejected{state, reason}:
      Runtime.RuntimeRunRejected{state, []}
    case Replay.RuntimeReplayFault{state, reason}:
      Runtime.RuntimeRunFault{state, reason}

def roster_ledgers(result: MixDriver.DrivenRosterResult) ->
  List<&2, Ledger.IndividualLedger>:
  match result:
    case MixDriver.DrivenRosterResult{runtime_result, ledgers}: ledgers

def replay_ledgers() -> List<&2, Ledger.IndividualLedger>:
  roster_ledgers(MixDriver.process_roster_result(catalog(),
    result_for_learning(first_replay()),
    [Ledger.IndividualLedger{learning(11n), [], []},
     Ledger.empty(MixModel.MonsterId{12n})]))

def learning_observed(ledgers: List<&2, Ledger.IndividualLedger>) -> Bool:
  match ledgers:
    case [Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{11n},
          [MixModel.RecipeId{3n}],
          [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 1}]}, [], _},
      Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{12n},
          [MixModel.RecipeId{3n}], []}, [], _}]: True{}
    case _: False{}

def main() -> List<&2, Nat>:
  [U32.to_nat(Bool.to_u32(replay_ok(first_replay()))),
   U32.to_nat(Bool.to_u32(same_replay(first_replay(), second_replay()))),
   U32.to_nat(Bool.to_u32(learning_observed(replay_ledgers())))]

#| [1, 1, 1]
