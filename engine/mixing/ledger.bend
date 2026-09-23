import Base
import ./model.bend as MixModel
import ./recipe.bend as MixRecipe
import ./observation.bend as Learning
import ./harmony.bend as Harmony
import ../battle/runtime.bend as Runtime
import ../battle/effects.bend as Effects

# Battle-local state for one persistent individual's learning record. Staged
# observations are battle-local and are committed only by a terminal result.
type IndividualLedger is Data:
  IndividualLedger{learning: Learning.LearningState,
    staged: List<&2, Learning.StagedObservation>,
    completed_actions: List<&2, Nat>}

def event_witnesses(remaining: List<&2, Runtime.RuntimeMixWitness>) ->
  List<&2, Learning.Witness>:
  match remaining:
    case Nil{}: Nil{}
    case Runtime.RuntimeMixWitness{individual, actor, active, conscious,
        current_moves} <> rest:
      Learning.Witness{MixModel.MonsterId{individual}, active, conscious,
        current_moves} <> event_witnesses(rest)

def staged_has_sequence(+sequence: Nat,
  staged: List<&2, Learning.StagedObservation>) -> Bool:
  match staged:
    case Nil{}: False{}
    case Learning.StagedObservation{action_sequence, recipe, witnesses} <> rest:
      Bool.or(Nat.is_eq(sequence, action_sequence),
        staged_has_sequence(sequence, rest))

def append_stage_if_new(present: Bool, +observation: Learning.StagedObservation,
  staged: List<&2, Learning.StagedObservation>) ->
  List<&2, Learning.StagedObservation>:
  match present:
    case True{}: staged
    case False{}: observation <> staged

def finish_actor_award(award: Learning.HarmonyAwardState,
  staged: List<&2, Learning.StagedObservation>) -> IndividualLedger:
  match award:
    case Learning.HarmonyAwardState{next_learning, next_actions}:
      IndividualLedger{next_learning, staged, next_actions}

def ledger_matches_owner(owner: Nat, state: IndividualLedger) -> Bool:
  match state:
    case IndividualLedger{learning, staged, completed_actions}:
      match learning:
        case Learning.LearningState{MixModel.MonsterId{individual}, observed,
            learned}:
          Nat.is_eq(owner, individual)

def award_actor_if(actor_matches: Bool, sequence: Nat,
  recipe_id: MixModel.RecipeId, success: Bool,
  state: IndividualLedger) -> IndividualLedger:
  match actor_matches state:
    case False{} IndividualLedger{learning, staged, completed_actions}:
      IndividualLedger{learning, staged, completed_actions}
    case True{} IndividualLedger{learning, staged, completed_actions}:
      finish_actor_award(Learning.award_action(sequence, True{}, success,
        recipe_id, Learning.HarmonyAwardState{learning, completed_actions}),
        staged)

def apply_known_event(found: Maybe<MixModel.Recipe>, owner: Nat,
  status_state_changed: Bool, +sequence: Nat,
  recipe_id: MixModel.RecipeId,
  witnesses: List<&2, Runtime.RuntimeMixWitness>,
  events: List<&2, Effects.EffectEvent>, state: IndividualLedger) ->
  IndividualLedger:
  match found:
    case None{}: state
    case Some{recipe}:
      match state:
        case IndividualLedger{+learning, +staged, +completed_actions}:
          +next_staged = append_stage_if_new(
            staged_has_sequence(sequence, staged),
            Learning.stage(sequence, recipe, event_witnesses(witnesses)), staged)
          +success = Harmony.committed_effect_success(True{},
            status_state_changed, events)
          award_actor_if(ledger_matches_owner(owner,
              IndividualLedger{learning, next_staged, completed_actions}),
            sequence, recipe_id,
            success, IndividualLedger{learning, next_staged, completed_actions})

# Consume one authoritative completion event. The event's live witness
# snapshot is staged even when its effect list represents a miss/no-op; only
# the acting individual's learned recipe can receive Harmony progress.
def apply_event(catalog: MixModel.Catalog,
  event: Runtime.RuntimeEvent, state: IndividualLedger) -> IndividualLedger:
  match catalog event:
    case MixModel.Catalog{recipes, sources, results}
         Runtime.RuntimeMixEffectsCommitted{sequence, recipe_id, individual,
          witnesses, events, status_state_changed}:
      +id = {MixModel.RecipeId{recipe_id} : MixModel.RecipeId}
      apply_known_event(MixRecipe.find_recipe_by_id(id, recipes), individual,
        status_state_changed, sequence, id, witnesses, events, state)
    case _ _:
      state

def merge_terminal_inner(terminal: Bool, result: Learning.BattleResult,
  state: IndividualLedger) -> IndividualLedger:
  match terminal state:
    case False{} state: state
    case True{} IndividualLedger{learning, staged, completed_actions}:
      IndividualLedger{Learning.merge_terminal(result, learning, staged), [],
        completed_actions}

# Commit all staged observations atomically at a terminal battle result.
# Ongoing results keep the staging buffer intact.
def merge_terminal(+result: Learning.BattleResult,
  state: IndividualLedger) -> IndividualLedger:
  merge_terminal_inner(Learning.terminal_result(result), result, state)

def empty(individual: MixModel.MonsterId) -> IndividualLedger:
  IndividualLedger{Learning.empty_learning(individual), [], []}
