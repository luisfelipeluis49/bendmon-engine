import Base
import ./model.bend as MixModel
import ./eligibility.bend as Eligibility
import ./observation.bend as Learning
import ./harmony.bend as Harmony
import ../battle/runtime.bend as Runtime
import ../battle/combat_math.bend as Math
import ../battle/multi_type.bend as Multi
import ../battle/effects.bend as Effects
import ../battle/model.bend as Battle

# Request data includes the acceptance-time individual/type/witness snapshot.
# The helper below is the supported constructor for RuntimeMixedMove: it
# recomputes Eligibility.plan against RuntimeState's current clock and sources,
# then lowers only the returned validated plan. Runtime.RuntimeMixPlan is an
# internal lowered payload and must not be constructed by other callers.
type MixSubmitRequest is Data:
  MixSubmitRequest{
    ready: Bool,
    target_valid: Bool,
    actor: Battle.ActorId,
    target: Battle.ActorId,
    individual: MixModel.MonsterId,
    first: Math.MoveId,
    second: Math.MoveId,
    catalog: MixModel.Catalog,
    learning: Learning.LearningState,
    current_moves: List<&2, Math.MoveId>,
    attacker: Runtime.CombatProfile,
    actor_types: List<&2, Multi.TypeId>,
    target_types: List<&2, Multi.TypeId>,
    witnesses: List<&2, Runtime.RuntimeMixWitness>,
    snapshot: Effects.ActionSnapshot,
    windup: U32,
    recovery: U32,
    priority: Nat,
    recoil: Nat
  }

type MixSubmitResult is Data:
  MixSubmitAccepted{state: Runtime.RuntimeState,
    emitted: List<&2, Battle.BattleEvent>}
  MixSubmitRejected{state: Runtime.RuntimeState,
    reason: Eligibility.MixDiagnostic}
  MixSubmitRuntimeRejected{state: Runtime.RuntimeState,
    diagnostics: List<&2, Battle.Diagnostic>}

# Derive the actor-side Harmony package at the command barrier. Accuracy is
# added to the ordinary base before stage/evasion math; critical is capped by
# the existing M4 critical_chance calculation after this accepted snapshot.
def harmony_accuracy(mode: Math.AccuracyMode, +bonus: U32) ->
  Math.AccuracyMode:
  match mode:
    case Math.AlwaysHit{}: Math.AlwaysHit{}
    case Math.OrdinaryAccuracy{base}:
      Math.OrdinaryAccuracy{U32.min(10000, U32.add(base, bonus))}

def harmony_progress(found: Maybe<U32>) -> U32:
  match found:
    case None{}: 0
    case Some{value}: value

def apply_harmony_package(snapshot: Effects.ActionSnapshot,
  package: Harmony.HarmonyPackage) -> Effects.ActionSnapshot:
  match snapshot package:
    case Effects.ActionSnapshot{level, physical_attack, special_attack,
        accuracy, mode, physical_damage, critical_bonus}
         Harmony.HarmonyPackage{accuracy_bonus, critical_bonus_extra}:
      Effects.ActionSnapshot{level, physical_attack, special_attack,
        accuracy, harmony_accuracy(mode, accuracy_bonus), physical_damage,
        U32.min(10000, U32.add(U32.min(critical_bonus, 10000),
          critical_bonus_extra))}

def harmony_snapshot(+accepted: Effects.ActionSnapshot,
  +state: Learning.LearningState, +recipe: MixModel.RecipeId) ->
  Effects.ActionSnapshot:
  match accepted state:
    case Effects.ActionSnapshot{level, physical_attack, special_attack,
        accuracy, mode, physical_damage, critical_bonus}
         Learning.LearningState{individual, observed, learned}:
      apply_harmony_package(Effects.ActionSnapshot{level, physical_attack,
        special_attack, accuracy, mode, physical_damage, critical_bonus},
        Harmony.bonuses(harmony_progress(
          Learning.find_learned(recipe, learned))))

def finish_runtime_submit(result: Runtime.RuntimeSubmitResult) -> MixSubmitResult:
  match result:
    case Runtime.RuntimeAccepted{state, emitted}:
      MixSubmitAccepted{state, emitted}
    case Runtime.RuntimeSubmitRejected{state, diagnostics}:
      MixSubmitRuntimeRejected{state, diagnostics}

def mix_individual_nat(individual: MixModel.MonsterId) -> Nat:
  match individual:
    case MixModel.MonsterId{value}: value

def lower_eligible_plan(+request: MixSubmitRequest,
  +plan: Eligibility.MixPlan, +fuel: Nat, +state: Runtime.RuntimeState,
  other_commands: List<&2, Runtime.RuntimeCommand>) -> MixSubmitResult:
  match request plan:
    case MixSubmitRequest{ready, target_valid, actor, target, individual,
        first, second, catalog, learning, current_moves, attacker,
        actor_types, target_types, witnesses, snapshot, windup, recovery,
        priority, recoil}
         Eligibility.MixPlan{recipe, descriptor, first, second,
          first_cooldown, second_cooldown, reserved_sources}:
      match recipe descriptor:
        case MixModel.Recipe{MixModel.RecipeId{recipe_id}, source_a,
            source_b, MixModel.ResultId{result_id}}
             MixModel.ResultDescriptor{id, program, components,
               is_registered}:
          +lowered = {Runtime.RuntimeMixPlan{mix_individual_nat(individual), recipe_id,
            result_id, first,
            second, first_cooldown, second_cooldown, program, components}
            : Runtime.RuntimeMixPlan}
          +command = {Runtime.RuntimeMixedMove{actor, target, windup,
            recovery, priority, recoil, attacker, lowered, actor_types,
            target_types, witnesses,
            harmony_snapshot(snapshot, learning, MixModel.RecipeId{recipe_id})}
            : Runtime.RuntimeCommand}
          finish_runtime_submit(Runtime.runtime_submit(fuel, state,
            command <> other_commands))

def lower_eligibility(result: Eligibility.MixEligibility,
  +request: MixSubmitRequest, +fuel: Nat, +state: Runtime.RuntimeState,
  other_commands: List<&2, Runtime.RuntimeCommand>) -> MixSubmitResult:
  match result:
    case Eligibility.MixRejected{reason}:
      MixSubmitRejected{state, reason}
    case Eligibility.MixEligible{plan}:
      lower_eligible_plan(request, plan, fuel, state, other_commands)

def submit_mix(+fuel: Nat, +state: Runtime.RuntimeState,
  +request: MixSubmitRequest,
  other_commands: List<&2, Runtime.RuntimeCommand>) -> MixSubmitResult:
  match request:
    case MixSubmitRequest{ready, target_valid, actor, target, individual,
        +first, +second, catalog, learning, +current_moves, attacker, actor_types,
        target_types, witnesses, snapshot, windup, recovery, priority, recoil}:
      lower_eligibility(Eligibility.plan(ready, target_valid,
        Runtime.runtime_now(state), actor, individual, first, second, catalog,
        learning, current_moves, Runtime.runtime_sources(state)), request, fuel,
        state, other_commands)
