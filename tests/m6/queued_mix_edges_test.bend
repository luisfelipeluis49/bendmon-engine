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
import ../../engine/battle/reducer.bend as Reducer

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
          Battle.Ready{}, 0},
       Battle.Actor{Battle.ActorId{2n}, Battle.Player{}, 100n, 80n,
          Battle.Ready{}, 0},
       Battle.Actor{Battle.ActorId{3n}, Battle.Enemy{}, 100n, 70n,
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
      Nil{}},
     Runtime.RuntimeMixWitness{13n, Battle.ActorId{2n}, True{}, True{}, Nil{}},
     Runtime.RuntimeMixWitness{14n, Battle.ActorId{3n}, True{}, True{}, Nil{}}],
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

def after_actor_damage(state: Runtime.RuntimeState,
  wanted: Battle.ActorId) -> Runtime.RuntimeState:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}:
      match battle:
        case Battle.BattleState{now, wait_ticks, actors, events, sequence,
            status}:
          Runtime.RuntimeState{Battle.BattleState{now, wait_ticks,
              Reducer.damage_actor(wanted, 100n, actors), events, sequence,
              status}, rng, encounter, failed, sources, reservations,
            trapped, defenders, effects}

def accepted() -> Runtime.RuntimeState:
  accepted_state(Mixing.submit_mix(8n, state(), request(),
    [Runtime.RuntimeWait{Battle.ActorId{1n}},
     Runtime.RuntimeWait{Battle.ActorId{2n}},
     Runtime.RuntimeWait{Battle.ActorId{3n}}]))

def fizzle_runtime() -> Runtime.RuntimeRunResult:
  Runtime.runtime_run(64n, after_actor_damage(accepted(),
    Battle.ActorId{1n}))

def cancel_runtime() -> Runtime.RuntimeRunResult:
  Runtime.runtime_run(64n, after_actor_damage(accepted(),
    Battle.ActorId{0n}))

def source_state_code(sources: List<&2, Sources.MoveSource>,
  reserved: Bool) -> Nat:
  match sources reserved:
    case [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, d1,
          False{}},
        Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, d2,
          False{}}] True{}:
      U32.to_nat(Bool.to_u32(Bool.and(U32.is_eq(d1, 90),
        U32.is_eq(d2, 92))))
    case [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, d1,
          False{}},
        Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, d2,
          False{}}] False{}:
      U32.to_nat(Bool.to_u32(Bool.and(U32.is_eq(d1, 0),
        U32.is_eq(d2, 0))))
    case _ _:
      0n

def state_sources_code(state: Runtime.RuntimeState,
  charged: Bool) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}:
      source_state_code(sources, charged)

def state_edge_code(state: Runtime.RuntimeState, charged: Bool) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, Rng.RngState{1, 2, 3, 4}, encounter,
        failed, sources, reservations, trapped, defenders, effects}:
      source_state_code(sources, charged)
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}: 0n

def fizzle_event_code(events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  match events:
    case Runtime.RuntimeFizzle{Battle.ActorId{0n}, Battle.ActorId{1n}} <> rest:
      1n
    case event <> rest: fizzle_event_code(rest)
    case Nil{}: 0n

def cancel_event_code(events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  match events:
    case Runtime.RuntimeCancel{Battle.ActorId{0n}, Battle.ActorId{1n}} <> rest:
      1n
    case event <> rest: cancel_event_code(rest)
    case Nil{}: 0n

def mix_commit_count(events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  match events:
    case Runtime.RuntimeMixEffectsCommitted{sequence, recipe_id, individual,
        witnesses, effect_events, changed} <> rest:
      1n
    case event <> rest: mix_commit_count(rest)
    case Nil{}: 0n

def fizzle_state_code(state: Runtime.RuntimeState,
  +events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  U32.to_nat(Bool.to_u32(Bool.and(
    Nat.is_eq(state_edge_code(state, True{}), 1n),
    Bool.and(Nat.is_eq(fizzle_event_code(events), 1n),
      Nat.is_eq(mix_commit_count(events), 0n)))))

def fizzle_path_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      fizzle_state_code(state, combat_events)
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      fizzle_state_code(state, combat_events)
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}:
      fizzle_state_code(state, combat_events)
    case Runtime.RuntimeRunStalled{state, emitted, combat_events}:
      fizzle_state_code(state, combat_events)
    case _: 0n

def cancel_state_code(state: Runtime.RuntimeState,
  +events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  U32.to_nat(Bool.to_u32(Bool.and(
    Nat.is_eq(state_edge_code(state, False{}), 1n),
    Bool.and(Nat.is_eq(cancel_event_code(events), 1n),
      Nat.is_eq(mix_commit_count(events), 0n)))))

def cancel_path_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      cancel_state_code(state, combat_events)
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      cancel_state_code(state, combat_events)
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}:
      cancel_state_code(state, combat_events)
    case Runtime.RuntimeRunStalled{state, emitted, combat_events}:
      cancel_state_code(state, combat_events)
    case _: 0n

def main() -> List<&2, Nat>:
  +submitted = {Mixing.submit_mix(8n, state(), request(),
      [Runtime.RuntimeWait{Battle.ActorId{1n}},
       Runtime.RuntimeWait{Battle.ActorId{2n}},
       Runtime.RuntimeWait{Battle.ActorId{3n}}]) : Mixing.MixSubmitResult}
  +fizzle = {fizzle_runtime() : Runtime.RuntimeRunResult}
  +cancel = {cancel_runtime() : Runtime.RuntimeRunResult}
  [acceptance_code(submitted), fizzle_path_code(fizzle),
    cancel_path_code(cancel)]

#| [1, 1, 1]
