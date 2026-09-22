import Base
import ./engine/core/bootstrap.bend as Boot
import ./engine/content/validation.bend as Content
import ./engine/battle/scheduler.bend as Battle
import ./engine/battle/model.bend as BattleModel
import ./engine/battle/rng.bend as Rng
import ./engine/battle/combat_math.bend as CombatMath
import ./engine/battle/roster.bend as Roster
import ./engine/battle/sources.bend as Sources
import ./engine/battle/driver.bend as Driver
import ./engine/battle/reducer.bend as Reducer
import ./engine/battle/participants.bend as Participants
import ./engine/battle/runtime.bend as Runtime
import ./engine/battle/effects.bend as Effects

# BOOT-1: adding zero preserves the headless accumulator for every Nat state.
# This is a toolchain/bootstrap law, not a battle or progression specification.
# Initial adoption follows the owner's implementation request. Semantic changes
# require human approval; implementations/proofs must satisfy this statement.
law bootstrap_zero:
  for n: Nat
  {Boot.transition(n, 0n) == n : Nat}


# REF-EMPTY: no typed reference can point into an empty catalog.
# Additive fixed content-validity requirement; BOOT-1 above is unchanged.
law content_empty_reference:
  for id: Nat
  {Content.ref_ok(id, 0n) == False{} : Bool}


# TIME-WAIT: the three engine-owned per-save Wait choices are legal.
law battle_wait_choices:
  {Bool.and(Battle.wait_setting_ok(30),
    Bool.and(Battle.wait_setting_ok(60), Battle.wait_setting_ok(120)))
    == True{} : Bool}


# RNG-REF: the approved xoshiro128** transition matches its frozen reference
# vector. This prevents silent algorithm or word-order substitution.
law rng_reference_step:
  {Rng.next(Rng.RngState{1, 2, 3, 4}) ==
    Rng.RngStep{Rng.RngState{7, 0, 1026, 12288}, 11520} : Rng.RngStep}


# DMG-REF: the approved integer formula floors once after the complete ratio.
law combat_reference_damage:
  {CombatMath.damage(100, 50, 100, 100) ==
    CombatMath.DamageValue{50, 100} : CombatMath.DamageResult}


# ACC-REF: a +3 target evasion stage halves ordinary 90% accuracy.
law combat_reference_accuracy:
  {CombatMath.accuracy(CombatMath.OrdinaryAccuracy{9000},
    CombatMath.StageNeutral{}, CombatMath.StageUp{3n}) ==
    CombatMath.AccuracyValue{4500} : CombatMath.AccuracyResult}


# TIME-CAP: the last legal tick accepts no positive-duration deadline.
law battle_clock_cap:
  {Battle.deadline_ok(216000, 1) == False{} : Bool}


# ESCAPE-REF: equal fastest speeds and no prior failure yield exactly 50%.
law escape_reference_chance:
  {Roster.escape_chance(100, 100, 0) == 5000 : U32}


# SOURCE-ATOMIC: a duplicate MoveId reservation batch rejects and preserves
# the exact original source list.
law source_duplicate_rejected:
  {Sources.reserve_batch(0,
      [Sources.SourceRequest{BattleModel.ActorId{0n}, CombatMath.MoveId{7n}},
       Sources.SourceRequest{BattleModel.ActorId{0n}, CombatMath.MoveId{7n}}],
      [Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{7n},
        0, False{}}]) ==
    Sources.SourcesRejected{
      [Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{7n},
        0, False{}}]} : Sources.ReserveResult}


# DET-FOLD: the bounded production driver is a pure function of complete state
# and fuel. Native/JavaScript goldens separately freeze its concrete encoding.
law battle_driver_deterministic:
  for fuel: Nat
  for state: BattleModel.BattleState
  {Driver.run(state, fuel) == Driver.run(state, fuel) : Driver.DriveResult}


# HP-SAT: damage beyond current HP saturates at zero and marks Defeated.
law battle_hp_saturation:
  {Reducer.damage_actor(BattleModel.ActorId{0n}, 10n,
      [BattleModel.Actor{BattleModel.ActorId{0n}, BattleModel.Player{}, 3n,
        100n, BattleModel.Ready{}, 0}]) ==
    [BattleModel.Actor{BattleModel.ActorId{0n}, BattleModel.Player{}, 0n,
      100n, BattleModel.Defeated{}, 0}] : List<&2, BattleModel.Actor>}


# REINFORCE: the first queued viable participant fills a vacant active slot.
law battle_reinforcement_order:
  {Participants.fill_reinforcements(
      [BattleModel.Actor{BattleModel.ActorId{0n}, BattleModel.Player{}, 10n,
        100n, BattleModel.Ready{}, 0},
       BattleModel.Actor{BattleModel.ActorId{1n}, BattleModel.Player{}, 10n,
        90n, BattleModel.Benched{}, 0}]) ==
    [BattleModel.Actor{BattleModel.ActorId{0n}, BattleModel.Player{}, 10n,
      100n, BattleModel.Ready{}, 0},
     BattleModel.Actor{BattleModel.ActorId{1n}, BattleModel.Player{}, 10n,
      90n, BattleModel.Ready{}, 0}] : List<&2, BattleModel.Actor>}


# RUNTIME-DET: the reducer-owned RNG runtime is deterministic for complete
# canonical state and bounded fuel.
law battle_runtime_deterministic:
  for fuel: Nat
  for state: Runtime.RuntimeState
  {Runtime.runtime_run(fuel, state) == Runtime.runtime_run(fuel, state)
    : Runtime.RuntimeRunResult}


# EFFECT-DET: the complete validated M4 action transaction is a pure function
# of its closed program, current world, accepted snapshot and RNG state.
law effect_runtime_deterministic:
  for program: Effects.EffectProgram
  for world: Effects.EffectWorld
  for snapshot: Effects.ActionSnapshot
  for rng: Rng.RngState
  {Effects.run(program, world, snapshot, rng) ==
    Effects.run(program, world, snapshot, rng) : Effects.EffectResult}


# EFFECT-STAGE-CAP: stage changes saturate at the engine-owned +6 ceiling.
law effect_stage_upper_saturation:
  {Effects.apply_delta(CombatMath.StageUp{5n}, Effects.Raise{6}) ==
    CombatMath.StageUp{6n} : CombatMath.Stage}


# STATUS-CATALOG: initial durations are engine data rather than authored values.
law effect_status_duration_catalog:
  {Effects.status_duration(Effects.Burn{}) == 3 : U32}


# STATUS-BURN: burn applies the approved exact 3/4 physical modifier.
law effect_burn_physical_modifier:
  {Effects.physical_damage_after_status(100,
    [Effects.StatusInstance{Effects.Burn{}, 3, 6}]) == 75 : U32}


# Approved future proof obligations (2026-09-21 decision packet):
#
# MIX-CD: ceil(3*c/2) strictly exceeds every legal ordinary cooldown c and
# charging both source deadlines is atomic.
# ESCAPE-ATOMIC: a rejected escape changes nothing; an attempted escape consumes
# exactly its specified draw/action cost and successful escape commits no reward.
# REINFORCE: queued reinforcements count as viable and fill vacant active slots
# in canonical order before terminal victory is evaluated.
# SWITCH-ATOMIC: voluntary and forced replacement either commit one legal active
# identity transition or leave battle state unchanged; locked targets never retarget.
# HARM-TIER: the six mastery thresholds and accuracy/critical packages are
# monotone and remain within the ordinary probability caps.
# MIX-ALLOC: quotient/remainder allocation over 1..4 distinct TypeIds preserves
# the complete base power budget before component modifiers.
# CAP-ATOMIC: capture, inventory, shop and capacity-tier transitions either
# commit their entire validated result or leave state unchanged.
# WORLD-DET: equal accepted fixed-point movement inputs and RNG state produce
# equal swept positions and encounter thresholds independent of rendered frames.
# EVENT-TERM: one immediate event activation is acyclic and bounded by cumulative
# fuel; persistent repetition crosses an activation boundary.
# SAVE-ID: a save/replay loads only under exact ruleset and project-content
# identity unless an explicit version-specific schema migration succeeds.
#
# These owner-approved obligations are recorded here before their M4–M11 domain
# functions exist. Replace each comment with a checked law and proof alongside
# its implementation; do not weaken the obligation to make a proof pass.
