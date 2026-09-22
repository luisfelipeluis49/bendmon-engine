import Base
import ./model.bend as MixModel
import ./harmony.bend as Harmony
import ../battle/combat_math.bend as Math

# Learned recipes keep Harmony progress with the individual's persistent
# learning record. Observations and learned recipes are maintained as sorted,
# unique lists so their representation is canonical without a mutable map.
type LearnedRecipe is Data:
  LearnedRecipe{recipe: MixModel.RecipeId, progress: U32}

type LearningState is Data:
  LearningState{individual: MixModel.MonsterId,
    observed: List<&2, MixModel.RecipeId>,
    learned: List<&2, LearnedRecipe>}

# This is the immutable combatant snapshot taken at mixed execution start.
type Witness is Data:
  Witness{individual: MixModel.MonsterId, active: Bool, conscious: Bool,
    current_moves: List<&2, Math.MoveId>}

type StagedObservation is Data:
  StagedObservation{action_sequence: Nat, recipe: MixModel.RecipeId,
    witnesses: List<&2, MixModel.MonsterId>}

# Battle-local action ledger paired with one persistent individual's learning
# state. The completed action keys are discarded after the battle transaction.
type HarmonyAwardState is Data:
  HarmonyAwardState{learning: LearningState,
    completed_actions: List<&2, Nat>}

type BattleResult is Data:
  Ongoing{}
  Victory{}
  Defeat{}
  Draw{}
  Timeout{}
  Escaped{}

def recipe_id_lt(left: MixModel.RecipeId, right: MixModel.RecipeId) -> Bool:
  MixModel.RecipeId{left_value} = left
  MixModel.RecipeId{right_value} = right
  Nat.is_lt(left_value, right_value)

def recipe_id_eq(left: MixModel.RecipeId, right: MixModel.RecipeId) -> Bool:
  MixModel.RecipeId{left_value} = left
  MixModel.RecipeId{right_value} = right
  Nat.is_eq(left_value, right_value)

def monster_id_lt(left: MixModel.MonsterId, right: MixModel.MonsterId) -> Bool:
  MixModel.MonsterId{left_value} = left
  MixModel.MonsterId{right_value} = right
  Nat.is_lt(left_value, right_value)

def monster_id_eq(left: MixModel.MonsterId, right: MixModel.MonsterId) -> Bool:
  MixModel.MonsterId{left_value} = left
  MixModel.MonsterId{right_value} = right
  Nat.is_eq(left_value, right_value)

def move_eq(left: Math.MoveId, right: Math.MoveId) -> Bool:
  Math.MoveId{left_value} = left
  Math.MoveId{right_value} = right
  Nat.is_eq(left_value, right_value)

def has_move(+wanted: Math.MoveId, moves: List<&2, Math.MoveId>) -> Bool:
  match moves:
    case Nil{}: False{}
    case move <> rest:
      Bool.or(move_eq(wanted, move), has_move(wanted, rest))

def recipe_id_le(left: MixModel.RecipeId, right: MixModel.RecipeId) -> Bool:
  MixModel.RecipeId{left_value} = left
  MixModel.RecipeId{right_value} = right
  Nat.is_le(left_value, right_value)

def recipe_insert_if(present: Bool, +needle: MixModel.RecipeId,
  values: List<&2, MixModel.RecipeId>) -> List<&2, MixModel.RecipeId>:
  match present:
    case True{}: values
    case False{}:
      List.sort(~MixModel.RecipeId, ~recipe_id_le, needle <> values)

def recipe_insert(+needle: MixModel.RecipeId,
  +values: List<&2, MixModel.RecipeId>) -> List<&2, MixModel.RecipeId>:
  recipe_insert_if(
    List.contains(~MixModel.RecipeId, ~recipe_id_eq, values, needle),
    needle, values)

def monster_id_le(left: MixModel.MonsterId, right: MixModel.MonsterId) -> Bool:
  MixModel.MonsterId{left_value} = left
  MixModel.MonsterId{right_value} = right
  Nat.is_le(left_value, right_value)

def monster_insert_if(present: Bool, +needle: MixModel.MonsterId,
  values: List<&2, MixModel.MonsterId>) -> List<&2, MixModel.MonsterId>:
  match present:
    case True{}: values
    case False{}:
      List.sort(~MixModel.MonsterId, ~monster_id_le, needle <> values)

def monster_insert(+needle: MixModel.MonsterId,
  +values: List<&2, MixModel.MonsterId>) -> List<&2, MixModel.MonsterId>:
  monster_insert_if(
    List.contains(~MixModel.MonsterId, ~monster_id_eq, values, needle),
    needle, values)

def knows_both(witness: Witness, recipe: MixModel.Recipe) -> Bool:
  match witness recipe:
    case Witness{id, True{}, True{}, +moves}
         MixModel.Recipe{recipe_id, source_a, source_b, result}:
      Bool.and(has_move(source_a, moves), has_move(source_b, moves))
    case _ _:
      False{}

def collect_witness_loop(remaining: List<&2, Witness>, +candidate: Witness,
  +recipe: MixModel.Recipe, eligible: Bool,
  out: List<&2, MixModel.MonsterId>) -> List<&2, MixModel.MonsterId>:
  match remaining candidate recipe eligible:
    case Nil{} Witness{individual, active, conscious, current_moves} _ True{}:
      monster_insert(individual, out)
    case Nil{} _ _ False{}: out
    case +next <> rest Witness{individual, active, conscious, current_moves}
         _ True{}:
      collect_witness_loop(rest, next, recipe, knows_both(next, recipe),
        monster_insert(individual, out))
    case +next <> rest _ _ False{}:
      collect_witness_loop(rest, next, recipe, knows_both(next, recipe), out)

def collect_witnesses(+recipe: MixModel.Recipe,
  combatants: List<&2, Witness>,
  out: List<&2, MixModel.MonsterId>) -> List<&2, MixModel.MonsterId>:
  match combatants:
    case Nil{}: out
    case +witness <> rest:
      collect_witness_loop(rest, witness, recipe, knows_both(witness, recipe),
        out)

# Called only after actor and locked target validation, immediately before
# mixed accuracy/effect resolution. Misses and same-action KOs still keep this
# snapshot; cancellation and invalid-target fizzle never call this function.
def stage(action_sequence: Nat, +recipe: MixModel.Recipe,
  combatants: List<&2, Witness>) -> StagedObservation:
  match recipe:
    case MixModel.Recipe{+id, source_a, source_b, result}:
      StagedObservation{action_sequence, id,
        collect_witnesses(recipe, combatants, [])}

def staged_has_individual(+individual: MixModel.MonsterId,
  witnesses: List<&2, MixModel.MonsterId>) -> Bool:
  match witnesses:
    case Nil{}: False{}
    case witness <> rest:
      Bool.or(monster_id_eq(individual, witness),
        staged_has_individual(individual, rest))

def observed_has(+recipe: MixModel.RecipeId,
  observed: List<&2, MixModel.RecipeId>) -> Bool:
  match observed:
    case Nil{}: False{}
    case item <> rest:
      Bool.or(recipe_id_eq(recipe, item), observed_has(recipe, rest))

def staged_includes(individual: MixModel.MonsterId,
  item: StagedObservation) -> Bool:
  match item:
    case StagedObservation{action_sequence, recipe, witnesses}:
      staged_has_individual(individual, witnesses)

def merge_loop(remaining: List<&2, StagedObservation>,
  +candidate: StagedObservation, eligible: Bool, state: LearningState,
  +individual: MixModel.MonsterId) -> LearningState:
  match remaining candidate eligible state:
    case Nil{} StagedObservation{action_sequence, recipe, witnesses} True{}
         LearningState{owner, observed, learned}:
      LearningState{owner, recipe_insert(recipe, observed), learned}
    case +next <> rest StagedObservation{action_sequence, recipe, witnesses}
         True{} LearningState{owner, observed, learned}:
      merge_loop(rest, next, staged_includes(individual, next),
        LearningState{owner, recipe_insert(recipe, observed), learned},
        individual)
    case Nil{} _ False{} state: state
    case +next <> rest _ False{} state:
      merge_loop(rest, next, staged_includes(individual, next), state,
        individual)

def merge_one(+individual: MixModel.MonsterId, state: LearningState,
  staged: List<&2, StagedObservation>) -> LearningState:
  match staged:
    case Nil{}: state
    case +item <> rest:
      merge_loop(rest, item, staged_includes(individual, item), state,
        individual)

def terminal_result(result: BattleResult) -> Bool:
  match result:
    case Ongoing{}: False{}
    case Victory{}: True{}
    case Defeat{}: True{}
    case Draw{}: True{}
    case Timeout{}: True{}
    case Escaped{}: True{}

# Persistent history changes only when the battle result commits. Repeated
# terminal delivery remains idempotent because recipe insertion is a set op.
def merge_terminal_inner(terminal: Bool, state: LearningState,
  staged: List<&2, StagedObservation>) -> LearningState:
  match terminal state:
    case False{} state: state
    case True{} LearningState{+individual, observed, learned}:
      merge_one(individual, state, staged)

def merge_terminal(result: BattleResult, state: LearningState,
  staged: List<&2, StagedObservation>) -> LearningState:
  merge_terminal_inner(terminal_result(result), state, staged)

def learned_id(item: LearnedRecipe) -> MixModel.RecipeId:
  match item:
    case LearnedRecipe{recipe, progress}: recipe

def learned_progress(item: LearnedRecipe) -> U32:
  match item:
    case LearnedRecipe{recipe, progress}: progress

def find_learned_loop(remaining: List<&2, LearnedRecipe>,
  +candidate: LearnedRecipe, +target: MixModel.RecipeId,
  found: Bool) -> Maybe<U32>:
  match remaining candidate found:
    case Nil{} LearnedRecipe{recipe, progress} True{}: Some{progress}
    case Nil{} _ False{}: None{}
    case +next <> rest _ False{}:
      find_learned_loop(rest, next, target,
        recipe_id_eq(target, learned_id(next)))
    case +next <> rest LearnedRecipe{recipe, progress} True{}: Some{progress}

def find_learned(+target: MixModel.RecipeId,
  learned: List<&2, LearnedRecipe>) -> Maybe<U32>:
  match learned:
    case Nil{}: None{}
    case +item <> rest:
      find_learned_loop(rest, item, target,
        recipe_id_eq(target, learned_id(item)))

def replace_progress_loop(remaining: List<&2, LearnedRecipe>,
  +candidate: LearnedRecipe, +target: MixModel.RecipeId, progress: U32,
  found: Bool) -> List<&2, LearnedRecipe>:
  match remaining candidate found:
    case Nil{} LearnedRecipe{recipe, old_progress} True{}:
      [LearnedRecipe{recipe, progress}]
    case Nil{} candidate False{}: [candidate]
    case +next <> rest LearnedRecipe{recipe, old_progress} True{}:
      LearnedRecipe{recipe, progress} <> next <> rest
    case +next <> rest candidate False{}:
      candidate <> replace_progress_loop(rest, next, target, progress,
        recipe_id_eq(target, learned_id(next)))

def replace_progress(+target: MixModel.RecipeId, progress: U32,
  learned: List<&2, LearnedRecipe>) -> List<&2, LearnedRecipe>:
  match learned:
    case Nil{}: Nil{}
    case +item <> rest:
      replace_progress_loop(rest, item, target, progress,
        recipe_id_eq(target, learned_id(item)))

def persist_award(award: Harmony.AwardState, recipe: MixModel.RecipeId,
  state: LearningState) -> LearningState:
  match award state:
    case Harmony.AwardState{progress, completed_actions}
         LearningState{individual, observed, learned}:
      LearningState{individual, observed,
        replace_progress(recipe, progress, learned)}

def finish_award(+award: Harmony.AwardState, recipe: MixModel.RecipeId,
  state: LearningState) -> HarmonyAwardState:
  match award:
    case Harmony.AwardState{progress, completed_actions}:
      HarmonyAwardState{persist_award(award, recipe, state),
        completed_actions}

def award_after_lookup(found: Maybe<U32>, action_sequence: Nat,
  committed: Bool, successful_effect: Bool, recipe: MixModel.RecipeId,
  state: LearningState, completed_actions: List<&2, Nat>) -> HarmonyAwardState:
  match found:
    case None{}: HarmonyAwardState{state, completed_actions}
    case Some{progress}:
      finish_award(Harmony.award_once(committed, successful_effect,
        action_sequence, Harmony.AwardState{progress, completed_actions}),
        recipe, state)

# Update one learned recipe once for a committed action. A committed miss/no-op
# records its action sequence but leaves progress unchanged, so duplicate
# completion delivery cannot later grant a point. Unlearned recipes are inert.
def award_action(action_sequence: Nat, committed: Bool,
  successful_effect: Bool, +recipe: MixModel.RecipeId,
  state: HarmonyAwardState) -> HarmonyAwardState:
  match state:
    case HarmonyAwardState{+learning, completed_actions}:
      match learning:
        case LearningState{individual, observed, +learned}:
          award_after_lookup(find_learned(recipe, learned), action_sequence,
            committed, successful_effect, recipe, learning, completed_actions)

def empty_learning(individual: MixModel.MonsterId) -> LearningState:
  LearningState{individual, [], []}

def forget_move_preserves(state: LearningState, forgotten: Math.MoveId) ->
  LearningState:
  # Move knowledge is a separate bounded roster concern. This transition
  # deliberately leaves observation, unlock and Harmony history untouched.
  state
