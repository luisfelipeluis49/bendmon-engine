import Base
import ./model.bend as MixModel
import ./recipe.bend as MixRecipe
import ./observation.bend as Observation
import ./harmony.bend as Harmony
import ../battle/combat_math.bend as Math
import ../battle/multi_type.bend as Multi

type TrainingFailure is Data:
  InBattle{}
  NoTrainer{}
  NoToken{}
  NotObserved{}
  AlreadyLearned{}
  MissingSource{}
  MissingRecipe{}
  InvalidCatalog{}

type TrainingResult is Data:
  TrainingAccepted{state: Observation.LearningState,
    tokens_remaining: U32}
  TrainingRejected{state: Observation.LearningState,
    tokens_remaining: U32, reason: TrainingFailure}

def recipe_id_eq(left: MixModel.RecipeId, right: MixModel.RecipeId) -> Bool:
  MixModel.RecipeId{left_value} = left
  MixModel.RecipeId{right_value} = right
  Nat.is_eq(left_value, right_value)

def catalog_result_is_valid(result: MixRecipe.CatalogResult) -> Bool:
  match result:
    case MixRecipe.CatalogAccepted{accepted}: True{}
    case MixRecipe.CatalogRejected{diagnostics}: False{}

def catalog_is_valid(catalog: MixModel.Catalog) -> Bool:
  catalog_result_is_valid(MixRecipe.validate_catalog(catalog))

def source_ok(source: Maybe<MixModel.BaseMoveMeta>) -> Bool:
  match source:
    case None{}: False{}
    case Some{MixModel.BaseMoveMeta{id, components, ordinary_cooldown,
         is_recipe_result}}:
      Bool.and(Bool.not(is_recipe_result),
        Nat.is_eq(List.length(&2, Multi.TypeId, components), 1n))

def recipe_sources_ok(catalog: MixModel.Catalog,
  recipe: MixModel.Recipe) -> Bool:
  match catalog recipe:
    case MixModel.Catalog{recipes, +sources, results}
         MixModel.Recipe{id, source_a, source_b, result}:
      a = MixRecipe.find_source(source_a, sources)
      b = MixRecipe.find_source(source_b, sources)
      Bool.and(source_ok(a), source_ok(b))

def state_observed(recipe: MixModel.RecipeId,
  state: Observation.LearningState) -> Bool:
  match state:
    case Observation.LearningState{individual, observed, learned}:
      Observation.observed_has(recipe, observed)

def state_learned(+recipe: MixModel.RecipeId,
  learned: List<&2, Observation.LearnedRecipe>) -> Bool:
  match learned:
    case Nil{}: False{}
    case item <> rest:
      match item:
        case Observation.LearnedRecipe{known, progress}:
          Bool.or(recipe_id_eq(recipe, known), state_learned(recipe, rest))

def known_sources(+recipe: MixModel.Recipe, +moves: List<&2, Math.MoveId>) -> Bool:
  match recipe:
    case MixModel.Recipe{id, source_a, source_b, result}:
      Bool.and(Observation.has_move(source_a, moves),
        Observation.has_move(source_b, moves))

def learned_le(left: Observation.LearnedRecipe,
  right: Observation.LearnedRecipe) -> Bool:
  match left right:
    case Observation.LearnedRecipe{recipe_a, progress_a}
         Observation.LearnedRecipe{recipe_b, progress_b}:
      Observation.recipe_id_le(recipe_a, recipe_b)

def learned_present(+recipe: MixModel.RecipeId,
  learned: List<&2, Observation.LearnedRecipe>) -> Bool:
  match learned:
    case Nil{}: False{}
    case item <> rest:
      match item:
        case Observation.LearnedRecipe{known, progress}:
          Bool.or(recipe_id_eq(recipe, known), learned_present(recipe, rest))

def learned_insert_if(present: Bool, +recipe: MixModel.RecipeId,
  learned: List<&2, Observation.LearnedRecipe>) ->
  List<&2, Observation.LearnedRecipe>:
  match present:
    case True{}: learned
    case False{}:
      List.sort(~Observation.LearnedRecipe, ~learned_le,
        Observation.LearnedRecipe{recipe, Harmony.harmony_zero()} <> learned)

def learned_insert(+recipe: MixModel.RecipeId,
  +learned: List<&2, Observation.LearnedRecipe>) ->
  List<&2, Observation.LearnedRecipe>:
  learned_insert_if(learned_present(recipe, learned), recipe, learned)

def guard_after_token(has_token: Bool, observed: Bool,
  already_learned: Bool, source_present: Bool, recipe_present: Bool,
  catalog_valid: Bool) -> Maybe<TrainingFailure>:
  match has_token observed already_learned source_present recipe_present
        catalog_valid:
    case False{} _ _ _ _ _: Some{NoToken{}}
    case True{} False{} _ _ _ _: Some{NotObserved{}}
    case True{} True{} True{} _ _ _: Some{AlreadyLearned{}}
    case True{} True{} False{} _ False{} _: Some{MissingRecipe{}}
    case True{} True{} False{} False{} True{} _: Some{MissingSource{}}
    case True{} True{} False{} True{} True{} False{}:
      Some{InvalidCatalog{}}
    case True{} True{} False{} True{} True{} True{}: None{}

def train_guard(in_battle: Bool, designated_trainer: Bool, tokens: U32,
  observed: Bool, already_learned: Bool, source_present: Bool,
  recipe_present: Bool, catalog_valid: Bool) -> Maybe<TrainingFailure>:
  match in_battle designated_trainer:
    case True{} _: Some{InBattle{}}
    case False{} False{}: Some{NoTrainer{}}
    case False{} True{}:
      guard_after_token(U32.is_gt(tokens, 0), observed, already_learned,
        source_present, recipe_present, catalog_valid)

def finish_train(guard: Maybe<TrainingFailure>, tokens: U32,
  state: Observation.LearningState, recipe_id: MixModel.RecipeId) ->
  TrainingResult:
  match guard:
    case Some{reason}: TrainingRejected{state, tokens, reason}
    case None{}:
      match state:
        case Observation.LearningState{individual, observed, learned}:
          TrainingAccepted{
            Observation.LearningState{individual, observed,
              learned_insert(recipe_id, learned)}, U32.sub(tokens, 1)}

def requested_recipe(recipe_id: MixModel.RecipeId,
  catalog: MixModel.Catalog) -> Maybe<MixModel.Recipe>:
  match catalog:
    case MixModel.Catalog{recipes, sources, results}:
      MixRecipe.find_recipe_by_id(recipe_id, recipes)

def recipe_id_of(recipe: MixModel.Recipe) -> MixModel.RecipeId:
  match recipe:
    case MixModel.Recipe{id, source_a, source_b, result}: id

def train_resolved(recipe: Maybe<MixModel.Recipe>, in_battle: Bool,
  designated_trainer: Bool, +tokens: U32, +state: Observation.LearningState,
  +recipe_id: MixModel.RecipeId, current_moves: List<&2, Math.MoveId>,
  +catalog: MixModel.Catalog) -> TrainingResult:
  match recipe:
    case None{}:
      finish_train(train_guard(in_battle, designated_trainer, tokens,
        state_observed(recipe_id, state), False{}, False{}, False{},
        catalog_is_valid(catalog)), tokens, state, recipe_id)
    case Some{+value}:
      match state:
        case Observation.LearningState{individual, observed, learned}:
          +catalog_valid = catalog_is_valid(catalog)
          +compatible = recipe_sources_ok(catalog, value)
          +recipe_present = Bool.and(catalog_valid,
            Bool.and(compatible, recipe_id_eq(recipe_id, recipe_id_of(value))))
          finish_train(train_guard(in_battle, designated_trainer, tokens,
            Observation.observed_has(recipe_id, observed),
            state_learned(recipe_id, learned), known_sources(value,
              current_moves), recipe_present, catalog_valid), tokens, state,
            recipe_id)

# Pure post-battle training transaction. Every rejection preserves both input
# state and token balance; successful training adds progress zero atomically.
def train(in_battle: Bool, designated_trainer: Bool, tokens: U32,
  state: Observation.LearningState, +recipe_id: MixModel.RecipeId,
  current_moves: List<&2, Math.MoveId>, +catalog: MixModel.Catalog) ->
  TrainingResult:
  train_resolved(requested_recipe(recipe_id, catalog), in_battle,
    designated_trainer, tokens, state, recipe_id, current_moves, catalog)
