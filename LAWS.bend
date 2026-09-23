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
import ./engine/battle/multi_type.bend as Multi
import ./engine/mixing/harmony.bend as Harmony
import ./engine/mixing/observation.bend as Learning
import ./engine/mixing/recipe.bend as MixRecipe
import ./engine/mixing/model.bend as MixModel
import ./engine/mixing/runtime.bend as MixRuntime

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


# EFFECT-ATTEMPT-DET: status blocking, action effects and optional aftermath
# remain deterministic at the production runtime boundary.
law effect_attempt_deterministic:
  for program: Effects.EffectProgram
  for world: Effects.EffectWorld
  for snapshot: Effects.ActionSnapshot
  for rng: Rng.RngState
  for aftermath: Bool
  {Effects.attempt(program, world, snapshot, rng, aftermath) ==
    Effects.attempt(program, world, snapshot, rng, aftermath)
    : Effects.EffectResult}


# DMG-1: production quotient/remainder allocation preserves the declared
# budget for the approved three-component reference, including authored order.
law multi_allocation_conservation_reference:
  {Multi.allocation_total(Multi.allocate(100,
    [Multi.TypeId{3n}, Multi.TypeId{1n}, Multi.TypeId{2n}])) == 100 : U32}


# DMG-2: immunity zeroes exactly one resolved component contribution while
# retaining its identity, allocated power and STAB diagnostic.
law multi_immunity_zero_reference:
  {Multi.component_damage(Multi.DamageProfile{50, 100, 100},
    Multi.DamageComponent{Multi.TypeId{1n}, 40}, Multi.TypeImmune{}, True{}) ==
    Multi.ComponentResolved{Multi.ComponentDamage{Multi.TypeId{1n}, 40, 0,
      True{}, True{}}} : Multi.ComponentResult}


# MIX-4: the production source transaction charges an odd ordinary cooldown
# with a ceiling and leaves neither source charged when the second is missing.
law mixed_source_duration_reference:
  {Sources.mixed_duration(61) == 92 : U32}

law mixed_source_partial_rejection:
  {Sources.charge_mixed_pair(100, BattleModel.ActorId{0n},
    CombatMath.MoveId{7n}, CombatMath.MoveId{8n}, 60, 60,
    [Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{7n},
      0, True{}}]) ==
    Sources.MixedSourcesRejected{
      [Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{7n},
        0, True{}}]} : Sources.MixedChargeResult}


# HARM-1/2 reference edges call the production saturation and package helpers.
# The broader per-action state-machine property is exercised by M6 goldens.
law harmony_saturation_reference:
  {Harmony.next_progress(40) == 40 : U32}

law harmony_familiar_package_reference:
  {Harmony.bonuses(5) == Harmony.HarmonyPackage{100, 125}
    : Harmony.HarmonyPackage}


# MIX-6: the production unordered-key helper gives the same identity when
# source order is reversed in the approved distinct-source reference.
law mix_pair_symmetry_reference:
  {MixRecipe.canonical_pair(CombatMath.MoveId{7n},
      CombatMath.MoveId{8n}) ==
    MixRecipe.canonical_pair(CombatMath.MoveId{8n},
      CombatMath.MoveId{7n}) : MixModel.SourcePair}


# HARM-2: the accepted mixed-action snapshot adds a Familiar accuracy package
# to an ordinary base before the M4 stage/evasion calculation.
law mix_harmony_accuracy_reference:
  {MixRuntime.harmony_accuracy(CombatMath.OrdinaryAccuracy{9000}, 100) ==
    CombatMath.OrdinaryAccuracy{9100} : CombatMath.AccuracyMode}


# HARM-THRESHOLD: inclusive first mastery boundary produces Familiar.
law harmony_familiar_threshold:
  {Harmony.tier(5) == Harmony.Familiar{} : Harmony.HarmonyTier}

law harmony_practiced_threshold:
  {Harmony.tier(10) == Harmony.Practiced{} : Harmony.HarmonyTier}

law harmony_expert_threshold:
  {Harmony.tier(20) == Harmony.Expert{} : Harmony.HarmonyTier}

law harmony_master_threshold:
  {Harmony.tier(30) == Harmony.Master{} : Harmony.HarmonyTier}

law harmony_progress_cap:
  {Harmony.progress_cap(41) == 40 : U32}

# HARM-AWARD-ONCE: replaying an already completed action preserves both
# progress and its completion ledger.
law harmony_award_replay_idempotent:
  {Harmony.award_once(True{}, True{}, 9n,
    Harmony.AwardState{5, [9n]}) == Harmony.AwardState{5, [9n]}
    : Harmony.AwardState}

# HARM-AWARD-REPLAY-ALL: action zero already at the head of the completion
# ledger is a replay for every progress value, outcome, and remaining ledger.
# This quantifies the production award boundary without claiming that an
# arbitrary save ledger is well-formed or duplicate-free.
law harmony_award_head_replay:
  for progress: U32
  for successful_effect: Bool
  for completed: List<&2, Nat>
  {Harmony.award_once(True{}, successful_effect, 0n,
      Harmony.AwardState{progress, 0n <> completed}) ==
    Harmony.AwardState{Harmony.progress_cap(progress), 0n <> completed}
    : Harmony.AwardState}

# HARM-CAP: a successful new committed action at the progress ceiling records
# its identity but cannot increase progress beyond the production cap.
law harmony_award_saturates:
  {Harmony.award_once(True{}, True{}, 10n,
    Harmony.AwardState{40, []}) == Harmony.AwardState{40, [10n]}
    : Harmony.AwardState}

# MIX-CHARGE-ATOMIC: after both distinct reserved source identities validate,
# one production call charges both with the mixed duration and clears both
# reservations in the same returned list.
law mixed_source_pair_charge:
  {Sources.charge_mixed_pair(100, BattleModel.ActorId{0n},
    CombatMath.MoveId{7n}, CombatMath.MoveId{8n}, 60, 61,
    [Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{7n},
       0, True{}},
     Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{8n},
       0, True{}}]) ==
    Sources.MixedSourcesCharged{
      [Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{7n},
         190, False{}},
       Sources.MoveSource{BattleModel.ActorId{0n}, CombatMath.MoveId{8n},
         192, False{}}]} : Sources.MixedChargeResult}

# LEARN-STAGE: execution-start observation includes a witness only when that
# combatant is active, conscious, and knows both sources; insertion is unique.
law mix_observation_filters_witness:
  {Learning.stage(3n,
    MixModel.Recipe{MixModel.RecipeId{4n}, CombatMath.MoveId{7n},
      CombatMath.MoveId{8n}, MixModel.ResultId{2n}},
    [Learning.Witness{MixModel.MonsterId{11n}, True{}, True{},
       [CombatMath.MoveId{7n}, CombatMath.MoveId{8n}]},
     Learning.Witness{MixModel.MonsterId{12n}, False{}, True{},
       [CombatMath.MoveId{7n}, CombatMath.MoveId{8n}]},
     Learning.Witness{MixModel.MonsterId{11n}, True{}, True{},
       [CombatMath.MoveId{7n}, CombatMath.MoveId{8n}]}]) ==
    Learning.StagedObservation{3n, MixModel.RecipeId{4n},
      [MixModel.MonsterId{11n}]} : Learning.StagedObservation}


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
