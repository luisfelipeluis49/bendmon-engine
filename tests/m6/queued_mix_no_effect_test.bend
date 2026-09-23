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
import ../../engine/mixing/ledger.bend as Ledger

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

def queued_blocked_actor() -> Effects.EffectActor:
  Effects.EffectActor{100, 100, 10, 10, stages(),
    [Effects.StatusInstance{Effects.Sleep{}, 2, 0}], False{}, Nil{}}

def queued_blocked_state() -> Runtime.RuntimeState:
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
      Effects.EffectWorld{queued_blocked_actor(), effect_actor(100, 10)}}}}

def queued_blocked_run() -> Runtime.RuntimeRunResult:
  +submitted = {Mixing.submit_mix(8n, queued_blocked_state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}}]) : Mixing.MixSubmitResult}
  Runtime.runtime_run(64n, accepted_state(submitted))

def queued_blocked_award_code(award: Ledger.IndividualLedger,
  effect_events: List<&2, Effects.EffectEvent>, status_changed: Bool) -> Nat:
  match award:
    case Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{11n}, observed,
          [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}, staged,
        completed_actions}:
      match effect_events:
        case Effects.ActionBlocked{} <>
             Effects.OpportunityEnded{True{}, residual} <> Nil{}:
          U32.to_nat(Bool.to_u32(Bool.not(status_changed)))
        case _: 0n
    case _: 0n

def queued_blocked_commit(events: List<&2, Runtime.RuntimeEvent>,
  state: Ledger.IndividualLedger) -> Nat:
  match events:
    case Runtime.RuntimeMixEffectsCommitted{sequence, recipe_id,
        individual, witnesses, +effect_events, +status_changed} <> rest:
      queued_blocked_award_code(Ledger.apply_event(catalog(),
        Runtime.RuntimeMixEffectsCommitted{sequence, recipe_id, individual,
          witnesses, effect_events, status_changed}, state), effect_events,
        status_changed)
    case event <> rest: queued_blocked_commit(rest, state)
    case Nil{}: 0n


def effect_target_hp_code(state: Runtime.RuntimeState) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders,
        Some{Runtime.RuntimeEffectState{actor, target,
          Effects.EffectWorld{source,
            Effects.EffectActor{hp, max_hp, physical_defense,
              special_defense, stages, statuses, flinched, volatile}}}}}:
      U32.to_nat(Bool.to_u32(U32.is_eq(hp, 100)))
    case _: 0n

def queued_blocked_result(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      U32.to_nat(Bool.to_u32(Bool.and(
        Nat.is_eq(queued_blocked_commit(combat_events,
          Ledger.IndividualLedger{learning(), [], []}), 1n),
        Nat.is_eq(effect_target_hp_code(state), 1n))))
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      U32.to_nat(Bool.to_u32(Bool.and(
        Nat.is_eq(queued_blocked_commit(combat_events,
          Ledger.IndividualLedger{learning(), [], []}), 1n),
        Nat.is_eq(effect_target_hp_code(state), 1n))))
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}:
      U32.to_nat(Bool.to_u32(Bool.and(
        Nat.is_eq(queued_blocked_commit(combat_events,
          Ledger.IndividualLedger{learning(), [], []}), 1n),
        Nat.is_eq(effect_target_hp_code(state), 1n))))
    case Runtime.RuntimeRunStalled{state, emitted, combat_events}: 0n
    case _: 0n


def queued_status_blocked_no_harmony_test() -> Nat:
  queued_blocked_result(queued_blocked_run())

def main() -> List<&2, Nat>:
  [queued_status_blocked_no_harmony_test()]

#| [1]
