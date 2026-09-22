import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/recipe.bend as MixRecipe
import ../../engine/mixing/observation.bend as Observation
import ../../engine/mixing/training.bend as Training
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/multi_type.bend as Multi

def move(value: Nat) -> Math.MoveId:
  Math.MoveId{value}

def recipe() -> MixModel.Recipe:
  MixModel.Recipe{MixModel.RecipeId{7n}, move(1n), move(2n),
    MixModel.ResultId{3n}}

def valid_catalog() -> MixModel.Catalog:
  MixModel.Catalog{
    [recipe()],
    [MixModel.BaseMoveMeta{move(1n), [Multi.TypeId{1n}], 60, False{}},
     MixModel.BaseMoveMeta{move(2n), [Multi.TypeId{2n}], 120, False{}}],
    [MixModel.ResultDescriptor{MixModel.ResultId{3n},
      Effects.EffectProgram{[Effects.Leaf{
        Effects.Heal{Effects.Target{}, 1}}]}, [Multi.TypeId{3n}], True{}}]}

def eligible_witness(individual: Nat) -> Observation.Witness:
  Observation.Witness{MixModel.MonsterId{individual}, True{}, True{},
    [move(2n), move(1n)]}

def combatants() -> List<&2, Observation.Witness>:
  [eligible_witness(9n),
   Observation.Witness{MixModel.MonsterId{4n}, False{}, True{},
     [move(1n), move(2n)]},
   eligible_witness(2n),
   Observation.Witness{MixModel.MonsterId{5n}, True{}, False{},
     [move(1n), move(2n)]},
   Observation.Witness{MixModel.MonsterId{6n}, True{}, True{}, [move(1n)]},
   eligible_witness(2n)]

def staged() -> Observation.StagedObservation:
  Observation.stage(500n, recipe(), combatants())

def no_witness_check(result: Observation.StagedObservation) -> Nat:
  match result:
    case Observation.StagedObservation{501n, MixModel.RecipeId{7n}, []}: 1n
    case _: 0n

def no_witness_code() -> Nat:
  no_witness_check(Observation.stage(501n, recipe(), []))

def witness_selection_code(result: Observation.StagedObservation) -> Nat:
  match result:
    case Observation.StagedObservation{500n, MixModel.RecipeId{7n},
         [MixModel.MonsterId{2n}, MixModel.MonsterId{9n}]}:
      no_witness_code()
    case _: 0n

def merged_code(result: Observation.LearningState) -> Nat:
  match result:
    case Observation.LearningState{MixModel.MonsterId{2n},
         [MixModel.RecipeId{7n}], []}: 1n
    case _: 0n

def empty_learning_code(state: Observation.LearningState) -> Nat:
  match state:
    case Observation.LearningState{MixModel.MonsterId{2n}, [], []}: 1n
    case _: 0n

def terminal_matrix_code() -> Nat:
  +state = Observation.empty_learning(MixModel.MonsterId{2n})
  +events = {[staged(), staged()] : List<&2, Observation.StagedObservation>}
  +victory = Observation.merge_terminal(Observation.Victory{}, state, events)
  +defeat = Observation.merge_terminal(Observation.Defeat{}, state, events)
  +draw = Observation.merge_terminal(Observation.Draw{}, state, events)
  +timeout = Observation.merge_terminal(Observation.Timeout{}, state, events)
  +escaped = Observation.merge_terminal(Observation.Escaped{}, state, events)
  +ongoing = Observation.merge_terminal(Observation.Ongoing{}, state, events)
  U32.to_nat(Bool.to_u32(Bool.and(Nat.is_eq(merged_code(victory), 1n),
    Bool.and(Nat.is_eq(merged_code(defeat), 1n),
      Bool.and(Nat.is_eq(merged_code(draw), 1n),
        Bool.and(Nat.is_eq(merged_code(timeout), 1n),
          Bool.and(Nat.is_eq(merged_code(escaped), 1n),
            Nat.is_eq(empty_learning_code(ongoing), 1n))))))))

def learned_state(progress: U32) -> Observation.LearningState:
  Observation.LearningState{MixModel.MonsterId{2n},
    [MixModel.RecipeId{7n}],
    [Observation.LearnedRecipe{MixModel.RecipeId{7n}, progress}]}

def award_progress_code(state: Observation.HarmonyAwardState,
  expected: U32, expected_action: Nat) -> Nat:
  match state:
    case Observation.HarmonyAwardState{
        Observation.LearningState{MixModel.MonsterId{2n},
          [MixModel.RecipeId{7n}],
          [Observation.LearnedRecipe{MixModel.RecipeId{7n}, progress}]},
        [action]}:
      U32.to_nat(Bool.to_u32(Bool.and(U32.is_eq(progress, expected),
        Nat.is_eq(action, expected_action))))
    case _: 0n

def failed_award_code(state: Observation.HarmonyAwardState) -> Nat:
  match state:
    case Observation.HarmonyAwardState{
        Observation.LearningState{_, _,
          [Observation.LearnedRecipe{_, 5}]}, [78n, 77n]}: 1n
    case _: 0n

def award_idempotence_code() -> Nat:
  +initial = {Observation.HarmonyAwardState{learned_state(4), []} :
    Observation.HarmonyAwardState}
  +first = Observation.award_action(77n, True{}, True{},
    MixModel.RecipeId{7n}, initial)
  +duplicate = Observation.award_action(77n, True{}, True{},
    MixModel.RecipeId{7n}, first)
  +failed = Observation.award_action(78n, True{}, False{},
    MixModel.RecipeId{7n}, duplicate)
  U32.to_nat(Bool.to_u32(Bool.and(
    Nat.is_eq(award_progress_code(first, 5, 77n), 1n),
    Bool.and(Nat.is_eq(award_progress_code(duplicate, 5, 77n), 1n),
      Nat.is_eq(failed_award_code(failed), 1n)))))

def training_success_code(result: Training.TrainingResult) -> Nat:
  match result:
    case Training.TrainingAccepted{
        Observation.LearningState{MixModel.MonsterId{2n},
          [MixModel.RecipeId{7n}],
          [Observation.LearnedRecipe{MixModel.RecipeId{7n}, 0}]}, 0}: 1n
    case _: 0n

def recipe_list_eq(left: List<&2, MixModel.RecipeId>,
  right: List<&2, MixModel.RecipeId>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case left_id <> left_rest right_id <> right_rest:
      Bool.and(Observation.recipe_id_eq(left_id, right_id),
        recipe_list_eq(left_rest, right_rest))
    case _ _: False{}

def learned_list_eq(left: List<&2, Observation.LearnedRecipe>,
  right: List<&2, Observation.LearnedRecipe>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Observation.LearnedRecipe{left_id, left_progress} <> left_rest
         Observation.LearnedRecipe{right_id, right_progress} <> right_rest:
      Bool.and(Observation.recipe_id_eq(left_id, right_id),
        Bool.and(U32.is_eq(left_progress, right_progress),
          learned_list_eq(left_rest, right_rest)))
    case _ _: False{}

def learning_state_eq(left: Observation.LearningState,
  right: Observation.LearningState) -> Bool:
  match left right:
    case Observation.LearningState{MixModel.MonsterId{left_id},
         left_observed, left_learned}
         Observation.LearningState{MixModel.MonsterId{right_id},
         right_observed, right_learned}:
      Bool.and(Nat.is_eq(left_id, right_id),
        Bool.and(recipe_list_eq(left_observed, right_observed),
          learned_list_eq(left_learned, right_learned)))

def failure_reason_eq(left: Training.TrainingFailure,
  right: Training.TrainingFailure) -> Bool:
  match left right:
    case Training.InBattle{} Training.InBattle{}: True{}
    case Training.NoTrainer{} Training.NoTrainer{}: True{}
    case Training.NoToken{} Training.NoToken{}: True{}
    case Training.NotObserved{} Training.NotObserved{}: True{}
    case Training.AlreadyLearned{} Training.AlreadyLearned{}: True{}
    case Training.MissingSource{} Training.MissingSource{}: True{}
    case Training.MissingRecipe{} Training.MissingRecipe{}: True{}
    case Training.InvalidCatalog{} Training.InvalidCatalog{}: True{}
    case _ _: False{}

def failure_unchanged(result: Training.TrainingResult,
  original: Observation.LearningState, tokens: U32,
  expected: Training.TrainingFailure) -> Nat:
  match result:
    case Training.TrainingRejected{same_state, same_tokens, reason}:
      U32.to_nat(Bool.to_u32(Bool.and(learning_state_eq(same_state, original),
        Bool.and(U32.is_eq(same_tokens, tokens),
          failure_reason_eq(reason, expected)))))
    case _: 0n

def training_matrix_code() -> Nat:
  +observed = {Observation.LearningState{MixModel.MonsterId{2n},
    [MixModel.RecipeId{7n}], []} : Observation.LearningState}
  +success = Training.train(False{}, True{}, 1, observed,
    MixModel.RecipeId{7n}, [move(1n), move(2n)], valid_catalog())
  +in_battle = Training.train(True{}, True{}, 1, observed,
    MixModel.RecipeId{7n}, [move(1n), move(2n)], valid_catalog())
  +no_trainer = Training.train(False{}, False{}, 1, observed,
    MixModel.RecipeId{7n}, [move(1n), move(2n)], valid_catalog())
  +no_token = Training.train(False{}, True{}, 0, observed,
    MixModel.RecipeId{7n}, [move(1n), move(2n)], valid_catalog())
  +not_observed = Training.train(False{}, True{}, 1,
    Observation.empty_learning(MixModel.MonsterId{2n}),
    MixModel.RecipeId{7n}, [move(1n), move(2n)], valid_catalog())
  +forgotten_source = Training.train(False{}, True{}, 1, observed,
    MixModel.RecipeId{7n}, [move(1n)], valid_catalog())
  +already_learned = Training.train(False{}, True{}, 1, learned_state(0),
    MixModel.RecipeId{7n}, [move(1n), move(2n)], valid_catalog())
  +unknown_recipe = Training.train(False{}, True{}, 1, observed,
    MixModel.RecipeId{7n}, [move(1n), move(2n)],
    MixModel.Catalog{[], [], []})
  U32.to_nat(Bool.to_u32(Bool.and(
    Nat.is_eq(training_success_code(success), 1n),
    Bool.and(Nat.is_eq(failure_unchanged(in_battle, observed, 1,
        Training.InBattle{}), 1n),
      Bool.and(Nat.is_eq(failure_unchanged(no_trainer, observed, 1,
          Training.NoTrainer{}), 1n),
        Bool.and(Nat.is_eq(failure_unchanged(no_token, observed, 0,
            Training.NoToken{}), 1n),
          Bool.and(Nat.is_eq(failure_unchanged(not_observed,
              Observation.empty_learning(MixModel.MonsterId{2n}), 1,
              Training.NotObserved{}), 1n),
            Bool.and(Nat.is_eq(failure_unchanged(forgotten_source, observed, 1,
                Training.MissingSource{}), 1n),
              Bool.and(Nat.is_eq(failure_unchanged(already_learned,
                  learned_state(0), 1, Training.AlreadyLearned{}), 1n),
                Nat.is_eq(failure_unchanged(unknown_recipe, observed, 1,
                  Training.MissingRecipe{}), 1n))))))))))

def retention_check(state: Observation.LearningState) -> Nat:
  match state:
    case Observation.LearningState{MixModel.MonsterId{2n},
         [MixModel.RecipeId{7n}],
         [Observation.LearnedRecipe{MixModel.RecipeId{7n}, 19}]}: 1n
    case _: 0n

def retention_code() -> Nat:
  retention_check(Observation.forget_move_preserves(learned_state(19),
    move(1n)))

def main() -> List<&2, Nat>:
  [witness_selection_code(staged()), terminal_matrix_code(),
   award_idempotence_code(), training_matrix_code(), retention_code()]

#| [1, 1, 1, 1, 1]
