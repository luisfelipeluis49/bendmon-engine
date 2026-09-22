import Base
import ./model.bend as MixModel
import ./recipe.bend as Recipe
import ./observation.bend as Learning
import ../battle/model.bend as Battle
import ../battle/combat_math.bend as Math
import ../battle/sources.bend as Sources

# A MixPlan is the complete command-barrier result. The two source reservations
# are obtained in one batch only after every recipe, knowledge and target guard
# succeeds. Execution uses the registered descriptor carried by this plan.
type MixPlan is Data:
  MixPlan{
    recipe: MixModel.Recipe,
    descriptor: MixModel.ResultDescriptor,
    first: Math.MoveId,
    second: Math.MoveId,
    first_cooldown: U32,
    second_cooldown: U32,
    reserved_sources: List<&2, Sources.MoveSource>
  }

type MixDiagnostic is Data:
  InvalidCatalog{}
  ActorNotReady{}
  TargetInvalid{}
  WrongIndividual{}
  SourceNotKnown{source: Math.MoveId}
  RecipeMissing{}
  RecipeNotLearned{recipe: MixModel.RecipeId}
  ResultMissing{result: MixModel.ResultId}
  SourceMetadataMissing{source: Math.MoveId}
  SourceUnavailable{}

type MixEligibility is Data:
  MixEligible{plan: MixPlan}
  MixRejected{reason: MixDiagnostic}

def learned_has(+wanted: MixModel.RecipeId,
  learned: List<&2, Learning.LearnedRecipe>) -> Bool:
  match learned:
    case Nil{}: False{}
    case Learning.LearnedRecipe{recipe, progress} <> rest:
      Bool.or(Recipe.recipe_id_eq(wanted, recipe), learned_has(wanted, rest))

def cooldown_of(source: MixModel.BaseMoveMeta) -> U32:
  match source:
    case MixModel.BaseMoveMeta{id, components, cooldown, is_recipe_result}:
      cooldown

def reserve_result(result: Sources.ReserveResult,
  recipe: MixModel.Recipe, descriptor: MixModel.ResultDescriptor,
  first: Math.MoveId, second: Math.MoveId,
  first_cooldown: U32, second_cooldown: U32) -> MixEligibility:
  match result:
    case Sources.SourcesRejected{sources}:
      MixRejected{SourceUnavailable{}}
    case Sources.SourcesReserved{sources}:
      MixEligible{MixPlan{recipe, descriptor, first, second,
        first_cooldown, second_cooldown, sources}}

def reserve_known(+now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  recipe: MixModel.Recipe, descriptor: MixModel.ResultDescriptor,
  first_meta: MixModel.BaseMoveMeta,
  second_meta: MixModel.BaseMoveMeta,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  reserve_result(Sources.reserve_batch(now,
    [Sources.SourceRequest{actor, first},
      Sources.SourceRequest{actor, second}], sources),
    recipe, descriptor, first, second, cooldown_of(first_meta),
    cooldown_of(second_meta))

def source_metadata(+now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  recipe: MixModel.Recipe, descriptor: MixModel.ResultDescriptor,
  first_meta: Maybe<MixModel.BaseMoveMeta>,
  second_meta: Maybe<MixModel.BaseMoveMeta>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match first_meta second_meta:
    case None{} _:
      MixRejected{SourceMetadataMissing{first}}
    case _ None{}:
      MixRejected{SourceMetadataMissing{second}}
    case Some{first_value} Some{second_value}:
      reserve_known(now, actor, first, second, recipe, descriptor,
        first_value, second_value, sources)

def result_metadata(+now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  recipe: MixModel.Recipe,
  descriptor: Maybe<MixModel.ResultDescriptor>,
  catalog: MixModel.Catalog,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match recipe:
    case MixModel.Recipe{id, source_a, source_b, result}:
      match descriptor:
        case None{}:
          MixRejected{ResultMissing{result}}
        case Some{value}:
          match catalog:
            case MixModel.Catalog{recipes, +source_meta, result_meta}:
              source_metadata(now, actor, first, second, recipe, value,
                Recipe.find_source(first, source_meta),
                Recipe.find_source(second, source_meta), sources)

def recipe_learned_decide(known: Bool, +now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  recipe: MixModel.Recipe, +catalog: MixModel.Catalog,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match known recipe:
    case False{} MixModel.Recipe{id, source_a, source_b, result}:
      MixRejected{RecipeNotLearned{id}}
    case True{} MixModel.Recipe{+id, +source_a, +source_b, +result}:
      match catalog:
        case MixModel.Catalog{recipes, source_meta, +result_meta}:
          result_metadata(now, actor, first, second, recipe,
            Recipe.find_result(result, result_meta), catalog, sources)

def recipe_learned(+now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  recipe: MixModel.Recipe, catalog: MixModel.Catalog,
  learned: List<&2, Learning.LearnedRecipe>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match recipe:
    case MixModel.Recipe{+id, +source_a, +source_b, result}:
      recipe_learned_decide(learned_has(id, learned), now, actor, first,
        second, recipe, catalog, sources)

def recipe_found(+now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  found: Maybe<MixModel.Recipe>, catalog: MixModel.Catalog,
  learned: List<&2, Learning.LearnedRecipe>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match found:
    case None{}: MixRejected{RecipeMissing{}}
    case Some{recipe}:
      recipe_learned(now, actor, first, second, recipe, catalog,
        learned, sources)

def current_sources_decide(first_known: Bool, second_known: Bool,
  +now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  +catalog: MixModel.Catalog,
  learned: List<&2, Learning.LearnedRecipe>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match first_known:
    case False{}: MixRejected{SourceNotKnown{first}}
    case True{}:
      match second_known:
        case False{}: MixRejected{SourceNotKnown{second}}
        case True{}:
          recipe_found(now, actor, first, second,
            Recipe.lookup(catalog, first, second), catalog, learned, sources)

def current_sources(+now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  catalog: MixModel.Catalog, +current_moves: List<&2, Math.MoveId>,
  learned: List<&2, Learning.LearnedRecipe>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  current_sources_decide(Learning.has_move(first, current_moves),
    Learning.has_move(second, current_moves), now, actor, first, second,
    catalog, learned, sources)

def individual_decide(same: Bool, +now: U32, +actor: Battle.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  catalog: MixModel.Catalog,
  current_moves: List<&2, Math.MoveId>,
  learned: List<&2, Learning.LearnedRecipe>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match same:
    case False{}: MixRejected{WrongIndividual{}}
    case True{}:
      current_sources(now, actor, first, second, catalog,
        current_moves, learned, sources)

def valid_individual(+now: U32, +actor: Battle.ActorId,
  +individual: MixModel.MonsterId,
  +first: Math.MoveId, +second: Math.MoveId,
  catalog: MixModel.Catalog, learning: Learning.LearningState,
  current_moves: List<&2, Math.MoveId>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match learning:
    case Learning.LearningState{owner, observed, learned}:
      individual_decide(Learning.monster_id_eq(individual, owner), now,
        actor, first, second, catalog, current_moves, learned, sources)

def validated_catalog(validated: Recipe.CatalogResult,
  +now: U32, +actor: Battle.ActorId,
  +individual: MixModel.MonsterId,
  +first: Math.MoveId, +second: Math.MoveId,
  learning: Learning.LearningState,
  current_moves: List<&2, Math.MoveId>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match validated:
    case Recipe.CatalogRejected{diagnostics}:
      MixRejected{InvalidCatalog{}}
    case Recipe.CatalogAccepted{catalog}:
      valid_individual(now, actor, individual, first, second,
        catalog, learning, current_moves, sources)

def accepted_target(target_valid: Bool,
  +now: U32, +actor: Battle.ActorId,
  +individual: MixModel.MonsterId,
  +first: Math.MoveId, +second: Math.MoveId,
  catalog: MixModel.Catalog, learning: Learning.LearningState,
  current_moves: List<&2, Math.MoveId>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match target_valid:
    case False{}: MixRejected{TargetInvalid{}}
    case True{}:
      validated_catalog(Recipe.validate_catalog(catalog), now, actor,
        individual, first, second, learning, current_moves, sources)

def plan_pair(pair: MixModel.SourcePair, target_valid: Bool, +now: U32,
  +actor: Battle.ActorId, +individual: MixModel.MonsterId,
  catalog: MixModel.Catalog, learning: Learning.LearningState,
  current_moves: List<&2, Math.MoveId>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match pair:
    case MixModel.SourcePair{first, second}:
      accepted_target(target_valid, now, actor, individual, first, second,
        catalog, learning, current_moves, sources)

def plan_ready(ready: Bool, target_valid: Bool, +now: U32,
  +actor: Battle.ActorId, +individual: MixModel.MonsterId,
  +first: Math.MoveId, +second: Math.MoveId,
  catalog: MixModel.Catalog, learning: Learning.LearningState,
  current_moves: List<&2, Math.MoveId>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  match ready:
    case False{}: MixRejected{ActorNotReady{}}
    case True{}:
      plan_pair(Recipe.canonical_pair(first, second), target_valid, now,
        actor, individual, catalog, learning, current_moves, sources)

def plan(ready: Bool, target_valid: Bool, +now: U32,
  +actor: Battle.ActorId, +individual: MixModel.MonsterId,
  +first: Math.MoveId, +second: Math.MoveId,
  catalog: MixModel.Catalog, learning: Learning.LearningState,
  current_moves: List<&2, Math.MoveId>,
  sources: List<&2, Sources.MoveSource>) -> MixEligibility:
  plan_ready(ready, target_valid, now, actor, individual, first, second,
    catalog, learning, current_moves, sources)
