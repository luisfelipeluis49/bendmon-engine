import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/runtime.bend as Runtime

def stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def effect_actor(hp: U32) -> Effects.EffectActor:
  Effects.EffectActor{hp, 100, 10, 10, stages(), Nil{}, False{}, Nil{}}

def world() -> Effects.EffectWorld:
  Effects.EffectWorld{effect_actor(100), effect_actor(50)}

def snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{}, Math.AlwaysHit{},
    Effects.NormalPhysical{}, 0}

def program() -> Effects.EffectProgram:
  Effects.EffectProgram{Effects.Leaf{Effects.Heal{Effects.Target{}, 25}} <> Nil{}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{}, Math.StageNeutral{},
    100, 50, 100, 10, 0}

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 100n, 100n,
        Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 90n,
        Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n}, world()}}}

def accepted_state(result: Runtime.RuntimeSubmitResult) -> Runtime.RuntimeState:
  match result:
    case Runtime.RuntimeAccepted{state, emitted}:
      state
    case Runtime.RuntimeSubmitRejected{state, diagnostics}:
      state

def runtime_world_code(world: Effects.EffectWorld) -> Nat:
  match world:
    case Effects.EffectWorld{source, target}:
      U32.to_nat(Bool.to_u32(U32.is_eq(Effects.actor_hp(target), 75)))
def runtime_actors_code(actors: List<&2, Model.Actor>) -> Nat:
  match actors:
    case first <> Model.Actor{Model.ActorId{1n}, side, hp, speed, phase, cd}
        <> rest:
      U32.to_nat(Bool.to_u32(Nat.is_eq(hp, 75n)))
    case first <> rest:
      runtime_actors_code(rest)
    case Nil{}:
      0n

def runtime_battle_code(battle: Model.BattleState) -> Nat:
  match battle:
    case Model.BattleState{now, wait_ticks, actors, events, sequence, status}:
      runtime_actors_code(actors)

def runtime_rng_code(rng: Rng.RngState) -> Nat:
  match rng:
    case Rng.RngState{1, 2, 3, 4}:
      1n
    case _:
      0n

def runtime_state_code(state: Runtime.RuntimeState) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        Nil{}, trapped, defenders,
        Some{Runtime.RuntimeEffectState{source_id, target_id, world}}}:
      U32.to_nat(U32.add(U32.from_nat(runtime_world_code(world)),
        U32.add(U32.from_nat(runtime_battle_code(battle)),
          U32.from_nat(runtime_rng_code(rng)))))
    case _:
      0n

def effect_events_code(events: List<&2, Effects.EffectEvent>) -> Nat:
  match events:
    case Effects.HpRestored{Effects.Target{}, 25} <> rest:
      1n
    case _:
      0n

def runtime_events_code(events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  match events:
    case Runtime.RuntimeEffectsCommitted{effect_events} <> rest:
      effect_events_code(effect_events)
    case _:
      0n

def result_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat}:
      U32.to_nat(U32.add(U32.mul(U32.from_nat(runtime_state_code(state)), 10),
        U32.from_nat(runtime_events_code(combat))))
    case _:
      0n

def canonical_code(snapshot_value: Effects.ActionSnapshot) -> Nat:
  match snapshot_value:
    case Effects.ActionSnapshot{level, physical_attack, special_attack,
        Math.StageDown{2n}, mode, Effects.BurnedPhysical{}, critical_bonus}:
      1n
    case _:
      0n

def run_test() -> Nat:
  +accepted = accepted_state(Runtime.runtime_submit(8n, state(),
    [Runtime.RuntimeEffectMove{Model.ActorId{0n}, Model.ActorId{1n},
      Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile(), program(), snapshot()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))
  result_code(Runtime.runtime_run(16n, accepted))

def blind_burn_snapshot() -> Effects.ActionSnapshot:
  Runtime.queued_effect_snapshot(
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n},
      Effects.EffectWorld{Effects.EffectActor{100, 100, 10, 10, stages(),
          [Effects.StatusInstance{Effects.Burn{}, 3, 1},
           Effects.StatusInstance{Effects.Blind{}, 3, 1}], False{}, Nil{}},
        effect_actor(50)}}}, snapshot())

def capture_world() -> Effects.EffectWorld:
  Effects.EffectWorld{Effects.EffectActor{100, 100, 10, 10, stages(),
      [Effects.StatusInstance{Effects.Burn{}, 3, 1},
       Effects.StatusInstance{Effects.Blind{}, 3, 1}], False{}, Nil{}},
    effect_actor(50)}

def capture_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 100n, 100n,
        Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 90n,
        Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n},
      capture_world()}}}

def accepted_capture_code(result: Runtime.RuntimeSubmitResult) -> Nat:
  match result:
    case Runtime.RuntimeAccepted{Runtime.RuntimeState{
        battle, rng, encounter, failed, sources,
        Runtime.QueuedEffectMove{sequence, reservation, attacker, recoil,
          program, queued_snapshot} <> Nil{}, trapped, defenders, effects},
        emitted}:
      canonical_code(queued_snapshot)
    case _:
      0n

def accepted_capture_test() -> Nat:
  accepted_capture_code(Runtime.runtime_submit(8n, capture_state(),
    [Runtime.RuntimeEffectMove{Model.ActorId{0n}, Model.ActorId{1n},
      Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile(), program(), snapshot()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))

def invalid_program() -> Effects.EffectProgram:
  Effects.EffectProgram{Effects.Leaf{Effects.Heal{Effects.Target{}, 0}} <> Nil{}}

def invalid_result_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunRejected{state,
        Effects.InvalidAmount{0} <> Nil{}}:
      1n
    case _:
      0n

def invalid_test() -> Nat:
  +accepted = accepted_state(Runtime.runtime_submit(8n, state(),
    [Runtime.RuntimeEffectMove{Model.ActorId{0n}, Model.ActorId{1n},
      Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile(), invalid_program(), snapshot()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))
  invalid_result_code(Runtime.runtime_run(16n, accepted))

def blocked_world() -> Effects.EffectWorld:
  Effects.EffectWorld{Effects.EffectActor{100, 100, 10, 10, stages(),
      [Effects.StatusInstance{Effects.Sleep{}, 2, 0}], False{}, Nil{}},
    effect_actor(50)}

def blocked_program() -> Effects.EffectProgram:
  Effects.EffectProgram{Effects.Leaf{Effects.Damage{1n, Effects.Target{},
    Effects.Physical{}, 1}} <> Nil{}}

def blocked_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 100n, 100n,
        Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 90n,
        Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n},
      blocked_world()}}}

def blocked_effect_code(events: List<&2, Effects.EffectEvent>) -> Nat:
  match events:
    case Effects.ActionBlocked{} <>
        Effects.OpportunityEnded{True{}, 0} <> rest:
      1n
    case _:
      0n

def blocked_events_code(events: List<&2, Runtime.RuntimeEvent>) -> Nat:
  match events:
    case Runtime.RuntimeEffectsCommitted{effect_events} <> rest:
      blocked_effect_code(effect_events)
    case _:
      0n

def blocked_status_list_code(
  values: List<&2, Effects.StatusInstance>
) -> Nat:
  match values:
    case Effects.StatusInstance{Effects.Sleep{}, 1, 0} <> rest:
      1n
    case _:
      0n

def blocked_status_code(world: Effects.EffectWorld) -> Nat:
  match world:
    case Effects.EffectWorld{source, target}:
      blocked_status_list_code(Effects.actor_statuses(source))

def blocked_state_code(state: Runtime.RuntimeState) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        Nil{}, trapped, defenders,
        Some{Runtime.RuntimeEffectState{source_id, target_id, world}}}:
      blocked_status_code(world)
    case _:
      0n
def blocked_result_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat}:
      U32.to_nat(U32.add(U32.mul(U32.from_nat(blocked_state_code(state)), 10),
        U32.from_nat(blocked_events_code(combat))))
    case _:
      0n

def blocked_test() -> Nat:
  +accepted = accepted_state(Runtime.runtime_submit(8n, blocked_state(),
    [Runtime.RuntimeEffectMove{Model.ActorId{0n}, Model.ActorId{1n},
      Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile(), blocked_program(), snapshot()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))
  blocked_result_code(Runtime.runtime_run(16n, accepted))

def mixed_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 100n, 100n,
        Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 90n,
        Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n},
      world()}}}

def mixed_world_code(world: Effects.EffectWorld) -> Nat:
  match world:
    case Effects.EffectWorld{source, target}:
      U32.to_nat(Bool.to_u32(U32.is_zero(Effects.actor_hp(target))))

def mixed_state_code(state: Runtime.RuntimeState) -> Nat:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        Nil{}, trapped, defenders,
        Some{Runtime.RuntimeEffectState{source_id, target_id, world}}}:
      mixed_world_code(world)
    case _:
      0n

def mixed_result_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunTerminal{state, emitted, combat}:
      mixed_state_code(state)
    case _:
      0n

def mixed_test() -> Nat:
  +accepted = accepted_state(Runtime.runtime_submit(8n, mixed_state(),
    [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n}, Math.MoveId{7n},
      0, 30, 60, 0n, 0n, profile()}, Runtime.RuntimeWait{Model.ActorId{1n}}]))
  mixed_result_code(Runtime.runtime_run(16n, accepted))

def main() -> List<&2, Nat>:
  [run_test(), accepted_capture_test(), invalid_test(),
   blocked_test(), mixed_test()]

#| [31, 1, 1, 11, 1]
