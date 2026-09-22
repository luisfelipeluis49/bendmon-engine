import Base
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/runtime.bend as Runtime

def bool_code(ok: Bool) -> Nat:
  match ok:
    case True{}: 1n
    case False{}: 0n

def neutral_stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def make_actor(+hp: U32, +maximum: U32,
  statuses: List<&2, Effects.StatusInstance>, protected: Bool,
  immunities: List<&2, Effects.StatusId>) -> Effects.EffectActor:
  Effects.EffectActor{hp, maximum, 100, 100, neutral_stages(), statuses, protected,
    immunities}

def world() -> Effects.EffectWorld:
  Effects.EffectWorld{make_actor(40, 100, Nil{}, False{}, Nil{}),
    make_actor(200, 200, Nil{}, False{}, Nil{})}

def snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{50, 100, 200, Math.StageNeutral{},
    Math.AlwaysHit{}, Effects.NormalPhysical{}, 0}

def ordinary_snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{50, 100, 200, Math.StageNeutral{},
    Math.OrdinaryAccuracy{500}, Effects.NormalPhysical{}, 0}

def zero_damage_snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{1, 1, 1, Math.StageNeutral{}, Math.AlwaysHit{},
    Effects.NormalPhysical{}, 0}

def burned_snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{50, 100, 200, Math.StageNeutral{}, Math.AlwaysHit{},
    Effects.BurnedPhysical{}, 0}

def test_rng() -> Rng.RngState:
  Rng.RngState{1, 2, 3, 4}

def hp_of(actor: Effects.EffectActor) -> U32:
  Effects.EffectActor{hp, maximum, physical_defense, special_defense, stages,
    statuses, protected, immunities} = actor
  hp

def ordered_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{
        Effects.EffectWorld{source, +target}, next_rng,
        Effects.DamageApplied{7n, Effects.Target{}, Effects.Physical{}, amount,
          critical} <>
        Effects.HpRestored{Effects.Source{}, +restored} <>
        Effects.ConditionalSelected{True{}} <>
        Effects.StatusApplied{Effects.Target{}, Effects.Poison{}, False{}} <>
        Effects.StatModified{Effects.Target{}, Effects.Defense{}, before, after} <>
        Nil{}, [Effects.DamageRecord{7n, +recorded}]}:
      bool_code(Bool.and(U32.is_eq(amount, recorded), Bool.and(
        U32.is_eq(restored, U32.div(recorded, 2)), Bool.and(
        U32.is_eq(hp_of(source), U32.add(40, restored)), Bool.and(
        U32.is_eq(hp_of(target), U32.sub(200, recorded)),
        Effects.status_present(Effects.Poison{}, Effects.actor_statuses(target)))))))
    case _: 0n

def ordered_program() -> Effects.EffectProgram:
  Effects.EffectProgram{
    [Effects.Leaf{Effects.Damage{7n, Effects.Target{}, Effects.Physical{}, 100}},
     Effects.Leaf{Effects.Drain{Effects.Source{}, 7n, 1, 2}},
     Effects.Conditional{Effects.PriorDamagePositive{7n},
       [Effects.ApplyStatus{Effects.Target{}, Effects.Poison{}}],
       [Effects.Heal{Effects.Target{}, 1}]},
     Effects.Leaf{Effects.ModifyStat{Effects.Target{}, Effects.Defense{},
       Effects.Lower{2}}}]}

def target_hp(result: Effects.EffectResult) -> U32:
  match result:
    case Effects.EffectsCommitted{Effects.EffectWorld{source, target}, rng,
        events, damage}: hp_of(target)
    case _: 9999

def category_code() -> Nat:
  +physical = Effects.run(Effects.EffectProgram{[
    Effects.Leaf{Effects.Damage{1n, Effects.Target{}, Effects.Physical{}, 100}}]},
    world(), snapshot(), test_rng())
  +special = Effects.run(Effects.EffectProgram{[
    Effects.Leaf{Effects.Damage{1n, Effects.Target{}, Effects.Special{}, 100}}]},
    world(), snapshot(), test_rng())
  bool_code(U32.is_lt(target_hp(special), target_hp(physical)))

def poison_replaces_code(result: Maybe<&2, Effects.EffectActor>) -> Nat:
  match result:
    case Some{Effects.EffectActor{hp, maximum, physical_defense,
        special_defense, stages,
        [Effects.StatusInstance{Effects.Poison{}, 4, 12}], protected,
        immunities}}: 1n
    case None{}: 0n
    case _: 0n

def burn_replaces_weak_poison_code(result: Maybe<&2, Effects.EffectActor>) -> Nat:
  match result:
    case Some{Effects.EffectActor{hp, maximum, physical_defense,
        special_defense, stages,
        [Effects.StatusInstance{Effects.Burn{}, 3, 6}], protected,
        immunities}}: 1n
    case None{}: 0n
    case _: 0n

def refresh_code(result: Maybe<&2, Effects.EffectActor>) -> Nat:
  match result:
    case Some{Effects.EffectActor{hp, maximum, physical_defense,
        special_defense, stages,
        [Effects.StatusInstance{Effects.Burn{}, 3, 99}], protected,
        immunities}}: 1n
    case None{}: 0n
    case _: 0n

def none_code(result: Maybe<&2, Effects.EffectActor>) -> Nat:
  match result:
    case None{}: 1n
    case Some{actor}: 0n

def upper_stage_code(stage: Math.Stage) -> Nat:
  match stage:
    case Math.StageUp{6n}: 1n
    case _: 0n

def blind_stage_code(stage: Math.Stage) -> Nat:
  match stage:
    case Math.StageDown{2n}: 1n
    case _: 0n

def opportunity_code(result: Effects.OpportunityResult) -> Nat:
  match result:
    case Effects.OpportunityCompleted{
        Effects.EffectActor{90, 160, physical_defense, special_defense, stages,
          [Effects.StatusInstance{Effects.Sleep{}, 1, 0}], protected,
          immunities}, True{}, 10}: 1n
    case _: 0n

def lethal_residual_code(result: Effects.OpportunityResult) -> Nat:
  match result:
    case Effects.OpportunityCompleted{
        Effects.EffectActor{0, 1, physical_defense, special_defense, stages,
          Nil{}, protected, immunities}, False{}, 1}: 1n
    case _: 0n

def rejection_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsRejected{Effects.EffectWorld{source, target},
        Rng.RngState{1, 2, 3, 4},
        Effects.ForwardDamageReference{9n} <> rest}:
      bool_code(Bool.and(U32.is_eq(hp_of(source), 40),
        U32.is_eq(hp_of(target), 200)))
    case _: 0n

def predicate_forward_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsRejected{world_value, rng_value,
        Effects.ForwardDamageReference{9n} <> rest}: 1n
    case _: 0n

def fault_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsFaulted{same_world, Rng.RngState{0, 0, 0, 0},
        Rng.RngInvalidState{Rng.RngState{0, 0, 0, 0}}}: 1n
    case _: 0n

def protected_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{same_world, same_rng,
        [Effects.NoEffect{Effects.Target{}, Effects.Protected{}}], Nil{}}: 1n
    case _: 0n

def invalid_state_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsRejected{world_value, rng_value,
        Effects.InvalidActorState{} <> rest}: 1n
    case _: 0n

def action_miss_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{Effects.EffectWorld{source, target}, rng,
        [Effects.ActionMissed{1520}], Nil{}}:
      bool_code(Bool.not(Effects.status_present(Effects.Burn{},
        Effects.actor_statuses(target))))
    case _: 0n

def damage_miss_stops_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{Effects.EffectWorld{source, target}, rng,
        [Effects.DamageMissed{3n, Effects.Target{}, 1520}],
        [Effects.DamageRecord{3n, 0}]}:
      bool_code(U32.is_eq(hp_of(source), 40))
    case _: 0n

def branch_damage_rejected_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsRejected{world_value, rng_value,
        Effects.BranchDamageUnsupported{4n} <> rest}: 1n
    case _: 0n

def zero_drain_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{world_value, rng_value,
        [Effects.DamageNoEffect{5n, Effects.Target{}, Effects.ZeroDamage{}},
         Effects.NoEffect{Effects.Source{}, Effects.ZeroDerived{}}],
        [Effects.DamageRecord{5n, 0}]}: 1n
    case _: 0n

def burned_damage_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{world_value, rng_value,
        [Effects.DamageApplied{6n, Effects.Target{}, Effects.Physical{}, 37,
          False{}}], [Effects.DamageRecord{6n, 37}]}: 1n
    case _: 0n

def max_heal_code(actor: Effects.EffectActor) -> Nat:
  match actor:
    case Effects.EffectActor{4294967295, 4294967295, physical_defense,
        special_defense, stages, statuses, protected, immunities}: 1n
    case _: 0n

def large_status_code(result: Maybe<&2, Effects.EffectActor>) -> Nat:
  match result:
    case Some{Effects.EffectActor{hp, 4294967295, physical_defense,
        special_defense, stages,
        [Effects.StatusInstance{Effects.Burn{}, 3, 268435455}], protected,
        immunities}}: 1n
    case _: 0n

def large_poison_code(result: Maybe<&2, Effects.EffectActor>) -> Nat:
  match result:
    case Some{Effects.EffectActor{hp, 4294967295, physical_defense,
        special_defense, stages,
        [Effects.StatusInstance{Effects.Poison{}, 4, 536870911}], protected,
        immunities}}: 1n
    case _: 0n

def residual_saturation_code(amount: U32) -> Nat:
  bool_code(U32.is_eq(amount, 4294967295))

def runtime_blocked_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{
        Effects.EffectWorld{Effects.EffectActor{40, 100, physical_defense,
          special_defense, stages,
          [Effects.StatusInstance{Effects.Sleep{}, 1, 0}], protected,
          immunities}, target}, Rng.RngState{1, 2, 3, 4},
        [Effects.ActionBlocked{}, Effects.OpportunityEnded{True{}, 0}], Nil{}}:
      bool_code(U32.is_eq(hp_of(target), 200))
    case _: 0n

def branch_after_heal_code(result: Effects.EffectResult) -> Nat:
  match result:
    case Effects.EffectsCommitted{Effects.EffectWorld{source, target}, rng,
        [Effects.HpRestored{Effects.Source{}, 20},
         Effects.ConditionalSelected{False{}},
         Effects.StatModified{Effects.Source{}, Effects.Attack{}, before,
           Math.StageDown{1n}}], Nil{}}: 1n
    case _: 0n

def main() -> List<&2, Nat>:
  +zero_rng = {Rng.RngState{0, 0, 0, 0} : Rng.RngState}
  +forward = {Effects.EffectProgram{
    [Effects.Leaf{Effects.Drain{Effects.Source{}, 9n, 1, 2}},
     Effects.Leaf{Effects.Damage{9n, Effects.Target{}, Effects.Physical{}, 50}}]}
    : Effects.EffectProgram}
  +protected_world = {Effects.EffectWorld{
    make_actor(40, 100, Nil{}, False{}, Nil{}),
    make_actor(200, 200, Nil{}, True{}, Nil{})} : Effects.EffectWorld}
  +branch_program = {Effects.EffectProgram{
    [Effects.Leaf{Effects.Heal{Effects.Source{}, 20}},
     Effects.Conditional{Effects.HpBelowHalf{Effects.Source{}},
       [Effects.ModifyStat{Effects.Source{}, Effects.Attack{}, Effects.Raise{1}}],
       [Effects.ModifyStat{Effects.Source{}, Effects.Attack{}, Effects.Lower{1}}]}]}
    : Effects.EffectProgram}
  +predicate_forward = {Effects.EffectProgram{
    [Effects.Conditional{Effects.PriorDamagePositive{9n},
       [Effects.Heal{Effects.Source{}, 1}],
       [Effects.Heal{Effects.Source{}, 1}]},
     Effects.Leaf{Effects.Damage{9n, Effects.Target{}, Effects.Physical{}, 50}}]}
    : Effects.EffectProgram}
  [ordered_code(Effects.run(ordered_program(), world(), snapshot(), test_rng())),
   category_code(),
   poison_replaces_code(Effects.apply_status(Effects.Poison{}, make_actor(100, 100,
     [Effects.StatusInstance{Effects.Burn{}, 3, 6}], False{}, Nil{}))),
   burn_replaces_weak_poison_code(Effects.apply_status(Effects.Burn{},
     make_actor(100, 100, [Effects.StatusInstance{Effects.Poison{}, 1, 12}],
       False{}, Nil{}))),
   refresh_code(Effects.apply_status(Effects.Burn{}, make_actor(100, 100,
     [Effects.StatusInstance{Effects.Burn{}, 1, 99}], False{}, Nil{}))),
   none_code(Effects.apply_status(Effects.Burn{}, make_actor(100, 100,
     [Effects.StatusInstance{Effects.Poison{}, 4, 12}], False{}, Nil{}))),
   upper_stage_code(Effects.apply_delta(Math.StageUp{5n}, Effects.Raise{6})),
   rejection_code(Effects.run(forward, world(), snapshot(), test_rng())),
   predicate_forward_code(Effects.run(predicate_forward, world(), snapshot(),
     test_rng())),
   fault_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.Damage{1n, Effects.Target{}, Effects.Physical{}, 100}}]},
     world(), snapshot(), zero_rng)),
   protected_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.ApplyStatus{Effects.Target{}, Effects.Burn{}}}]},
     protected_world, snapshot(), test_rng())),
   branch_after_heal_code(Effects.run(branch_program, world(), snapshot(), test_rng())),
   bool_code(U32.is_eq(Effects.physical_damage_after_status(100,
     [Effects.StatusInstance{Effects.Burn{}, 3, 6}]), 75)),
   blind_stage_code(Effects.accuracy_after_status(Math.StageNeutral{},
     [Effects.StatusInstance{Effects.Blind{}, 3, 2}])),
   opportunity_code(Effects.complete_opportunity(make_actor(100, 160,
     [Effects.StatusInstance{Effects.Burn{}, 1, 10},
      Effects.StatusInstance{Effects.Sleep{}, 2, 0}], False{}, Nil{}))),
   lethal_residual_code(Effects.complete_opportunity(make_actor(1, 1,
     [Effects.StatusInstance{Effects.Poison{}, 1, 1}], False{}, Nil{}))),
   invalid_state_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.Heal{Effects.Source{}, 1}}]},
     Effects.EffectWorld{make_actor(40, 100, Nil{}, False{}, Nil{}),
       make_actor(100, 100,
         [Effects.StatusInstance{Effects.Burn{}, 3, 6},
          Effects.StatusInstance{Effects.Poison{}, 4, 12}], False{}, Nil{})},
     snapshot(), test_rng())),
   action_miss_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.ApplyStatus{Effects.Target{}, Effects.Burn{}}}]},
     world(), ordinary_snapshot(), test_rng())),
   damage_miss_stops_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.Damage{3n, Effects.Target{}, Effects.Physical{}, 100}},
     Effects.Leaf{Effects.Heal{Effects.Source{}, 20}}]}, world(),
     ordinary_snapshot(), test_rng())),
   branch_damage_rejected_code(Effects.run(Effects.EffectProgram{[
     Effects.Conditional{Effects.HpBelowHalf{Effects.Source{}},
       [Effects.Damage{4n, Effects.Target{}, Effects.Physical{}, 100}],
       [Effects.Drain{Effects.Source{}, 4n, 1, 2}]}]}, world(), snapshot(),
     test_rng())),
   invalid_state_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.Heal{Effects.Source{}, 1}}]}, world(),
     Effects.ActionSnapshot{50, 100, 200, Math.StageNeutral{},
       Math.OrdinaryAccuracy{499}, Effects.NormalPhysical{}, 0}, test_rng())),
   zero_drain_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.Damage{5n, Effects.Target{}, Effects.Physical{}, 1}},
     Effects.Leaf{Effects.Drain{Effects.Source{}, 5n, 1, 2}}]}, world(),
     zero_damage_snapshot(), test_rng())),
   burned_damage_code(Effects.run(Effects.EffectProgram{[
     Effects.Leaf{Effects.Damage{6n, Effects.Target{}, Effects.Physical{}, 100}}]},
     world(), burned_snapshot(), test_rng())),
   max_heal_code(Effects.heal_actor(1, make_actor(4294967294, 4294967295,
     Nil{}, False{}, Nil{}))),
   large_status_code(Effects.apply_status(Effects.Burn{},
     make_actor(4294967295, 4294967295, Nil{}, False{}, Nil{}))),
   large_poison_code(Effects.apply_status(Effects.Poison{},
     make_actor(4294967295, 4294967295, Nil{}, False{}, Nil{}))),
   residual_saturation_code(Effects.residual_damage(4294967295,
     [Effects.StatusInstance{Effects.Burn{}, 3, 4294967295},
      Effects.StatusInstance{Effects.Poison{}, 4, 4294967295}])),
   runtime_blocked_code(Runtime.runtime_effect_attempt(Effects.EffectProgram{[
     Effects.Leaf{Effects.Damage{8n, Effects.Target{}, Effects.Physical{}, 100}}]},
     Effects.EffectWorld{make_actor(40, 100,
       [Effects.StatusInstance{Effects.Sleep{}, 2, 0}], False{}, Nil{}),
       make_actor(200, 200, Nil{}, False{}, Nil{})}, snapshot(), test_rng(),
     True{}))]

#| [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
