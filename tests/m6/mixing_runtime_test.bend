import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/runtime.bend as Mixing
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
  Effects.EffectActor{hp, 100, defense, defense, stages(), Nil{}, False{}, Nil{}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 10, 0}

def program() -> Effects.EffectProgram:
  Effects.EffectProgram{[Effects.Leaf{Effects.Damage{0n,
    Effects.Target{}, Effects.Physical{}, 40}}]}

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
  Learning.LearningState{MixModel.MonsterId{11n},
    [MixModel.RecipeId{3n}],
    [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}

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
      Effects.EffectWorld{effect_actor(100, 10), effect_actor(100, 10)}}}}

def request() -> Mixing.MixSubmitRequest:
  Mixing.MixSubmitRequest{True{}, True{}, Battle.ActorId{0n},
    Battle.ActorId{1n}, MixModel.MonsterId{11n}, Math.MoveId{7n},
    Math.MoveId{8n}, catalog(), learning(), [Math.MoveId{7n}, Math.MoveId{8n}],
    profile(), [Multi.TypeId{1n}], [Multi.TypeId{2n}],
    [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
      [Math.MoveId{7n}, Math.MoveId{8n}]},
     Runtime.RuntimeMixWitness{12n, Battle.ActorId{1n}, True{}, True{},
      Nil{}}],
    Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{}, Math.AlwaysHit{},
      Effects.NormalPhysical{}, 0}, 0, 30, 0n, 0n}

def accepted_state(result: Mixing.MixSubmitResult) -> Runtime.RuntimeState:
  match result:
    case Mixing.MixSubmitAccepted{state, emitted}: state
    case Mixing.MixSubmitRejected{state, reason}: state
    case Mixing.MixSubmitRuntimeRejected{state, diagnostics}: state

def acceptance_code(result: Mixing.MixSubmitResult) -> Nat:
  match result:
    case Mixing.MixSubmitAccepted{state, emitted}: 1n
    case Mixing.MixSubmitRejected{state, reason}: 2n
    case Mixing.MixSubmitRuntimeRejected{state, diagnostics}: 3n

def rejection_diagnostic(result: Mixing.MixSubmitResult) -> Nat:
  match result:
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.TargetInvalid{actor, target} <> rest}: 5n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.ActorNotReady{actor} <> rest}: 6n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.SourceReserved{actor} <> rest}: 7n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.BattleNotAwaiting{} <> rest}: 8n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.IncompleteBarrier{} <> rest}: 9n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.ActorMissing{actor} <> rest}: 10n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.DuplicateActor{actor} <> rest}: 11n
    case Mixing.MixSubmitRuntimeRejected{state,
        Battle.TimingInvalid{actor} <> rest}: 12n
    case _: 0n

def accepted_pair(state: Runtime.RuntimeState) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed,
        Sources.MoveSource{owner_a, move_a, deadline_a, True{}} <>
        Sources.MoveSource{owner_b, move_b, deadline_b, True{}} <> rest,
        reservations, trapped, defenders, effects}:
      1n
    case _: 0n

def has_components(events: List<&2, Effects.EffectEvent>) -> Nat:
  match events:
    case Effects.DamageComponentsApplied{node, components} <> rest: 1n
    case event <> rest: has_components(rest)
    case Nil{}: 0n

def mixed_commit(events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  match events:
    case Runtime.RuntimeMixEffectsCommitted{sequence, 3n, 11n, witnesses,
        effect_events, status_state_changed} <> rest:
      has_components(effect_events)
    case event <> rest: mixed_commit(rest)
    case Nil{}: 0n

def runtime_event_code(code: Nat) -> Nat:
  match code:
    case 0n: 9n
    case _: code

def execution_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      runtime_event_code(mixed_commit(combat_events))
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      runtime_event_code(mixed_commit(combat_events))
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}:
      runtime_event_code(mixed_commit(combat_events))
    case Runtime.RuntimeRunStalled{state, emitted, combat_events}: 5n
    case Runtime.RuntimeRunFault{state, reason}: 6n
    case Runtime.RuntimeRunRejected{state, diagnostics}: 7n

def live_witness_code(values: List<&2, Runtime.RuntimeMixWitness>) -> Nat:
  match values:
    case Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, True{}, True{},
        moves} <> Nil{}: 1n
    case _: 0n

def live_witness_test() -> Nat:
  live_witness_code(Runtime.runtime_mix_witnesses_live(
    [Runtime.RuntimeMixWitness{11n, Battle.ActorId{0n}, False{}, False{},
       [Math.MoveId{7n}, Math.MoveId{8n}]},
     Runtime.RuntimeMixWitness{12n, Battle.ActorId{1n}, True{}, True{},
       [Math.MoveId{7n}, Math.MoveId{8n}]}],
    [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 100n, 100n,
       Battle.Ready{}, 0},
     Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 100n, 90n,
       Battle.Benched{}, 0}]))

def harmony_snapshot_code(snapshot: Effects.ActionSnapshot) -> Nat:
  match snapshot:
    case Effects.ActionSnapshot{level, physical_attack, special_attack,
        accuracy, Math.OrdinaryAccuracy{9100}, physical_damage, 2525}:
      U32.to_nat(Bool.to_u32(U32.is_eq(Math.critical_chance(2525), 2500)))
    case _: 0n

def harmony_snapshot_test() -> Nat:
  harmony_snapshot_code(Mixing.harmony_snapshot(
    Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{},
      Math.OrdinaryAccuracy{9000}, Effects.NormalPhysical{}, 2400},
    Learning.LearningState{MixModel.MonsterId{11n},
      [MixModel.RecipeId{3n}],
      [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 5}]},
    MixModel.RecipeId{3n}))

def status_change_test() -> Nat:
  +same = Effects.world_status_changed(
    Effects.EffectWorld{effect_actor(100, 10), effect_actor(100, 10)},
    Effects.EffectWorld{effect_actor(100, 10), effect_actor(100, 10)})
  +changed = Effects.world_status_changed(
    Effects.EffectWorld{effect_actor(100, 10), effect_actor(100, 10)},
    Effects.EffectWorld{effect_actor(100, 10),
      Effects.EffectActor{100, 100, 10, 10, stages(),
        [Effects.StatusInstance{Effects.Burn{}, 3, 1}], False{}, Nil{}}})
  U32.to_nat(Bool.to_u32(Bool.and(Bool.not(same), changed)))

def status_intent_test() -> Nat:
  +event = {[Effects.StatusApplied{Effects.Target{}, Effects.Burn{},
    True{}}] : List<&2, Effects.EffectEvent>}
  +already_full = Effects.status_event_changes(
    Effects.EffectWorld{effect_actor(100, 10),
      Effects.EffectActor{100, 100, 10, 10, stages(),
        [Effects.StatusInstance{Effects.Burn{}, 3, 6}], False{}, Nil{}}},
    event)
  +new_status = Effects.status_event_changes(
    Effects.EffectWorld{effect_actor(100, 10), effect_actor(100, 10)}, event)
  U32.to_nat(Bool.to_u32(Bool.and(Bool.not(already_full), new_status)))

def main() -> List<&2, Nat>:
  +submitted = {Mixing.submit_mix(8n, state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}}]) : Mixing.MixSubmitResult}
  +accepted = {accepted_state(submitted) : Runtime.RuntimeState}
  [acceptance_code(submitted), rejection_diagnostic(submitted),
    accepted_pair(accepted),
    execution_code(Runtime.runtime_run(64n, accepted)),
    live_witness_test(), harmony_snapshot_test(), status_change_test(),
    status_intent_test()]

#| [1, 0, 1, 1, 1, 1, 1, 1]
