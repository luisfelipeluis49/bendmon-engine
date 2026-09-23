import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/runtime.bend as Mixing
import ../../engine/mixing/observation.bend as Learning
import ../../engine/mixing/ledger.bend as Ledger
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

def effect_actor() -> Effects.EffectActor:
  Effects.EffectActor{100, 100, 10, 10, stages(), Nil{}, False{}, Nil{}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 10, 0}

def program() -> Effects.EffectProgram:
  Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Source{}, 20}}]}

def recipe() -> MixModel.Recipe:
  MixModel.Recipe{MixModel.RecipeId{3n}, Math.MoveId{7n},
    Math.MoveId{8n}, MixModel.ResultId{4n}}

def catalog() -> MixModel.Catalog:
  MixModel.Catalog{[recipe()],
    [MixModel.BaseMoveMeta{Math.MoveId{7n}, [Multi.TypeId{1n}], 60, False{}},
     MixModel.BaseMoveMeta{Math.MoveId{8n}, [Multi.TypeId{2n}], 61, False{}}],
    [MixModel.ResultDescriptor{MixModel.ResultId{4n}, program(),
      [Multi.TypeId{1n}, Multi.TypeId{2n}], True{}}]}

def learning() -> Learning.LearningState:
  Learning.LearningState{MixModel.MonsterId{11n}, [MixModel.RecipeId{3n}],
    [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}

def initial_ledger() -> Ledger.IndividualLedger:
  Ledger.IndividualLedger{learning(), [], []}

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Battle.BattleState{0, 60,
      [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 100n, 100n,
          Battle.Ready{}, 0},
       Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 100n, 90n,
          Battle.Ready{}, 0}], Nil{}, 0n, Battle.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 0, False{}},
     Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Battle.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Battle.ActorId{0n}, Battle.ActorId{1n},
      Effects.EffectWorld{effect_actor(), effect_actor()}}}}

def request() -> Mixing.MixSubmitRequest:
  Mixing.MixSubmitRequest{True{}, True{}, Battle.ActorId{0n},
    Battle.ActorId{1n}, MixModel.MonsterId{11n}, Math.MoveId{7n},
    Math.MoveId{8n}, catalog(), learning(), [Math.MoveId{7n}, Math.MoveId{8n}],
    profile(), [Multi.TypeId{1n}], [Multi.TypeId{2n}],
    [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
       [Math.MoveId{7n}, Math.MoveId{8n}]},
     Runtime.RuntimeMixWitness{12n, Battle.ActorId{1n}, True{}, True{}, Nil{}}],
    Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{}, Math.AlwaysHit{},
      Effects.NormalPhysical{}, 0}, 0, 30, 0n, 0n}

def accepted_state(result: Mixing.MixSubmitResult) -> Runtime.RuntimeState:
  match result:
    case Mixing.MixSubmitAccepted{state, emitted}: state
    case Mixing.MixSubmitRejected{state, reason}: state
    case Mixing.MixSubmitRuntimeRejected{state, diagnostics}: state

def queued_result() -> Runtime.RuntimeRunResult:
  +submitted = {Mixing.submit_mix(8n, state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}}]) : Mixing.MixSubmitResult}
  Runtime.runtime_run(64n, accepted_state(submitted))

def full_hp_source(state: Runtime.RuntimeState) -> Bool:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders,
        Some{Runtime.RuntimeEffectState{actor, target,
          Effects.EffectWorld{Effects.EffectActor{100, 100, defense,
            special_defense, stages, statuses, flinched, volatile}, other}}}}:
      True{}
    case _: False{}

def no_harmony_ledger(sequence: Nat, ledger: Ledger.IndividualLedger) -> Bool:
  match ledger:
    case Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{11n}, observed,
          [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]},
        [Learning.StagedObservation{staged_sequence,
          MixModel.RecipeId{3n}, witnesses}], completed}:
      Nat.is_eq(sequence, staged_sequence)
    case _: False{}

def no_harmony_after(event: Runtime.RuntimeEvent,
  ledger: Ledger.IndividualLedger) -> Bool:
  match event:
    case Runtime.RuntimeMixEffectsCommitted{+sequence, 3n, 11n, witnesses,
        Effects.NoEffect{Effects.Source{}, Effects.FullHp{}} <>
          Effects.OpportunityEnded{False{}, residual} <> Nil{}, False{}}:
      no_harmony_ledger(sequence, Ledger.apply_event(catalog(),
        Runtime.RuntimeMixEffectsCommitted{sequence, 3n, 11n, witnesses,
          [Effects.NoEffect{Effects.Source{}, Effects.FullHp{}},
            Effects.OpportunityEnded{False{}, residual}], False{}},
        ledger))
    case _: False{}

def committed_shape(events: List<&2, Runtime.RuntimeEvent>,
  ledger: Ledger.IndividualLedger) -> Bool:
  match events:
    case Runtime.RuntimeMixEffectsCommitted{+sequence, 3n, 11n, witnesses,
        Effects.NoEffect{Effects.Source{}, Effects.FullHp{}} <>
          Effects.OpportunityEnded{False{}, residual} <> Nil{}, False{}} <> rest:
      no_harmony_after(Runtime.RuntimeMixEffectsCommitted{sequence, 3n, 11n,
        witnesses, [Effects.NoEffect{Effects.Source{}, Effects.FullHp{}},
          Effects.OpportunityEnded{False{}, residual}], False{}}, ledger)
    case event <> rest: committed_shape(rest, ledger)
    case Nil{}: False{}

def result_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      U32.to_nat(Bool.to_u32(Bool.and(full_hp_source(state),
        committed_shape(combat_events, initial_ledger()))))
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      U32.to_nat(Bool.to_u32(Bool.and(full_hp_source(state),
        committed_shape(combat_events, initial_ledger()))))
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}:
      U32.to_nat(Bool.to_u32(Bool.and(full_hp_source(state),
        committed_shape(combat_events, initial_ledger()))))
    case _: 0n

def main() -> Nat:
  result_code(queued_result())

#| 1
