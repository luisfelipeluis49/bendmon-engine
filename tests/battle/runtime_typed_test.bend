import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/multi_type.bend as Multi
import ../../engine/battle/runtime.bend as Runtime

def stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def effect_actor(hp: U32) -> Effects.EffectActor:
  Effects.EffectActor{hp, 100, 10, 10, stages(), Nil{}, False{}, Nil{}}

def world() -> Effects.EffectWorld:
  Effects.EffectWorld{effect_actor(100), effect_actor(100)}

def snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{}, Math.AlwaysHit{},
    Effects.NormalPhysical{}, 0}

def damage_program() -> Effects.EffectProgram:
  Effects.EffectProgram{Effects.Leaf{Effects.Damage{1n, Effects.Target{},
    Effects.Physical{}, 5}} <> Nil{}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{}, Math.StageNeutral{},
    5, 50, 100, 10, 0}

def actor_types() -> List<&2, Multi.TypeId>:
  [Multi.TypeId{1n}]

def target_types() -> List<&2, Multi.TypeId>:
  [Multi.TypeId{3n}]

def components() -> List<&2, Multi.TypeId>:
  [Multi.TypeId{1n}]

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 100n, 100n,
        Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 100n, 90n,
        Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n}, world()}}}

def accepted_state(result: Runtime.RuntimeSubmitResult) -> Runtime.RuntimeState:
  match result:
    case Runtime.RuntimeAccepted{state, emitted}: state
    case Runtime.RuntimeSubmitRejected{state, diagnostics}: state

def source_deadline(sources: List<&2, Sources.MoveSource>) -> U32:
  match sources:
    case Sources.MoveSource{owner, move, deadline, reserved} <> rest: deadline
    case Nil{}: 0

def damage_components_have_stab(events: List<&2, Effects.EffectEvent>) -> Bool:
  match events:
    case Effects.DamageComponentsApplied{1n,
        Multi.ComponentDamage{Multi.TypeId{1n}, power, amount, False{}, True{}}
          <> components} <> rest: True{}
    case _ <> rest: damage_components_have_stab(rest)
    case Nil{}: False{}

def typed_event_has_stab(events: List<&2, Runtime.RuntimeEvent>) -> Bool:
  match events:
    case Runtime.RuntimeEffectsCommitted{effect_events} <> rest:
      damage_components_have_stab(effect_events)
    case _ <> rest: typed_event_has_stab(rest)
    case Nil{}: False{}

def target_hp(state: Runtime.RuntimeState) -> U32:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders, effects}:
      match battle:
        case Model.BattleState{now, wait, Model.Actor{source_id, side, hp,
            speed, phase, cooldown} <> Model.Actor{Model.ActorId{1n}, side2,
            target_hp, speed2, phase2, cooldown2} <> rest, events, sequence,
            status}:
          U32.from_nat(target_hp)
        case _:
          0

def immune_component_result() -> Multi.ComponentResult:
  Multi.component_damage(Multi.DamageProfile{50, 100, 10},
    Multi.DamageComponent{Multi.TypeId{1n}, 5}, Multi.TypeImmune{}, True{})

def immune_component_is_zero_and_stab(result: Multi.ComponentResult) -> Bool:
  match result:
    case Multi.ComponentResolved{Multi.ComponentDamage{Multi.TypeId{1n},
        power, 0, True{}, True{}}}: True{}
    case _ : False{}

def run_result_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{+state, emitted, combat}:
      U32.to_nat(Bool.to_u32(Bool.and(immune_component_is_zero_and_stab(
        immune_component_result()), Bool.and(
        U32.is_eq(source_deadline(Runtime.runtime_sources(state)), 60),
        Bool.and(U32.is_lt(target_hp(state), 100),
          typed_event_has_stab(combat))))))
    case _:
      0n

def run_test() -> Nat:
  +accepted = accepted_state(Runtime.runtime_submit(8n, state(),
    [Runtime.RuntimeTypedMove{Model.ActorId{0n}, Model.ActorId{1n},
      Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile(), damage_program(),
      components(), actor_types(), target_types(), snapshot()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))
  run_result_code(Runtime.runtime_run(16n, accepted))

def main() -> Nat:
  run_test()
