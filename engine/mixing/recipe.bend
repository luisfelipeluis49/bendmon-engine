import Base
import ./model.bend as Model
import ../battle/combat_math.bend as Math
import ../battle/effects.bend as Effects
import ../battle/multi_type.bend as Multi

type RecipeDiagnostic is Data:
  SelfPair{recipe: Model.RecipeId}
  DuplicateRecipeId{recipe: Model.RecipeId, earlier: Model.RecipeId}
  DuplicatePair{recipe: Model.RecipeId, earlier: Model.RecipeId}
  DuplicateSourceId{source: Math.MoveId, earlier: Math.MoveId}
  DuplicateResultId{result: Model.ResultId, earlier: Model.ResultId}
  UnknownSource{recipe: Model.RecipeId, source: Math.MoveId}
  InvalidSourceComponents{recipe: Model.RecipeId, source: Math.MoveId, count: Nat}
  InvalidSourceCooldown{recipe: Model.RecipeId, source: Math.MoveId}
  ResultUsedAsSource{recipe: Model.RecipeId, source: Math.MoveId}
  UnknownResult{recipe: Model.RecipeId, result: Model.ResultId}
  UnregisteredResult{recipe: Model.RecipeId, result: Model.ResultId}
  InvalidResultComponents{recipe: Model.RecipeId, result: Model.ResultId,
    reason: Multi.AllocationDiagnostic}
  InvalidEffectDescriptor{recipe: Model.RecipeId, result: Model.ResultId}
  CatalogTooLarge{count: Nat}

type CatalogResult is Data:
  CatalogAccepted{catalog: Model.Catalog}
  CatalogRejected{diagnostics: List<&2, RecipeDiagnostic>}

def move_eq(left: Math.MoveId, right: Math.MoveId) -> Bool:
  Math.MoveId{left_value} = left
  Math.MoveId{right_value} = right
  Nat.is_eq(left_value, right_value)

def result_eq(left: Model.ResultId, right: Model.ResultId) -> Bool:
  Model.ResultId{left_value} = left
  Model.ResultId{right_value} = right
  Nat.is_eq(left_value, right_value)

def recipe_id_eq(left: Model.RecipeId, right: Model.RecipeId) -> Bool:
  Model.RecipeId{left_value} = left
  Model.RecipeId{right_value} = right
  Nat.is_eq(left_value, right_value)

def move_lt(left: Math.MoveId, right: Math.MoveId) -> Bool:
  Math.MoveId{left_value} = left
  Math.MoveId{right_value} = right
  Nat.is_lt(left_value, right_value)

def canonical_pair_select(ordered: Bool, +left: Math.MoveId,
  +right: Math.MoveId) -> Model.SourcePair:
  match ordered:
    case True{}: Model.SourcePair{left, right}
    case False{}: Model.SourcePair{right, left}

def canonical_pair(+left: Math.MoveId, +right: Math.MoveId) -> Model.SourcePair:
  canonical_pair_select(move_lt(left, right), left, right)

def pair_eq(left: Model.SourcePair, right: Model.SourcePair) -> Bool:
  Model.SourcePair{left_low, left_high} = left
  Model.SourcePair{right_low, right_high} = right
  Bool.and(move_eq(left_low, right_low), move_eq(left_high, right_high))

def find_source_step(rest: List<&2, Model.BaseMoveMeta>, found: Bool,
  +wanted: Math.MoveId, source: Model.BaseMoveMeta) -> Maybe<Model.BaseMoveMeta>:
  match rest found:
    case Nil{} True{}: Some{source}
    case Nil{} False{}: None{}
    case next <> tail True{}: Some{source}
    case Model.BaseMoveMeta{+id, components, ordinary_cooldown,
        is_recipe_result} <> tail False{}:
      find_source_step(tail, move_eq(wanted, id), wanted,
        Model.BaseMoveMeta{id, components, ordinary_cooldown, is_recipe_result})

def find_source(+wanted: Math.MoveId,
  sources: List<&2, Model.BaseMoveMeta>) -> Maybe<Model.BaseMoveMeta>:
  match sources:
    case Nil{}: None{}
    case source <> +rest:
      match source:
        case Model.BaseMoveMeta{+id, components, ordinary_cooldown,
            is_recipe_result}:
          find_source_step(rest, move_eq(wanted, id), wanted, source)

def duplicate_source_value(found: Maybe<Model.BaseMoveMeta>,
  +source_id: Math.MoveId) -> List<&2, RecipeDiagnostic>:
  match found:
    case None{}: []
    case Some{source}: [DuplicateSourceId{source_id, source_id}]

def duplicate_sources(sources: List<&2, Model.BaseMoveMeta>) ->
  List<&2, RecipeDiagnostic>:
  match sources:
    case Nil{}: []
    case source <> +rest:
      match source:
        case Model.BaseMoveMeta{+id, components, ordinary_cooldown,
            is_recipe_result}:
          List.append(&2, RecipeDiagnostic,
            duplicate_source_value(find_source(id, rest), id),
            duplicate_sources(rest))

def find_result_step(rest: List<&2, Model.ResultDescriptor>, found: Bool,
  +wanted: Model.ResultId, result: Model.ResultDescriptor) ->
  Maybe<Model.ResultDescriptor>:
  match rest found:
    case Nil{} True{}: Some{result}
    case Nil{} False{}: None{}
    case next <> tail True{}: Some{result}
    case Model.ResultDescriptor{+id, program, components, is_registered} <>
        tail False{}:
      find_result_step(tail, result_eq(wanted, id), wanted,
        Model.ResultDescriptor{id, program, components, is_registered})

def find_result(+wanted: Model.ResultId,
  results: List<&2, Model.ResultDescriptor>) -> Maybe<Model.ResultDescriptor>:
  match results:
    case Nil{}: None{}
    case result <> +rest:
      match result:
        case Model.ResultDescriptor{+id, program, components, is_registered}:
          find_result_step(rest, result_eq(wanted, id), wanted, result)

def duplicate_result_value(found: Maybe<Model.ResultDescriptor>,
  +result_id: Model.ResultId) -> List<&2, RecipeDiagnostic>:
  match found:
    case None{}: []
    case Some{result}: [DuplicateResultId{result_id, result_id}]

def duplicate_results(results: List<&2, Model.ResultDescriptor>) ->
  List<&2, RecipeDiagnostic>:
  match results:
    case Nil{}: []
    case result <> +rest:
      match result:
        case Model.ResultDescriptor{+id, program, components, is_registered}:
          List.append(&2, RecipeDiagnostic,
            duplicate_result_value(find_result(id, rest), id),
            duplicate_results(rest))

def metadata_id_diagnostics(catalog: Model.Catalog) ->
  List<&2, RecipeDiagnostic>:
  Model.Catalog{recipes, +sources, +results} = catalog
  List.append(&2, RecipeDiagnostic, duplicate_sources(sources),
    duplicate_results(results))

def find_recipe_pair_step(rest: List<&2, Model.Recipe>, found: Bool,
  +wanted: Model.SourcePair, recipe: Model.Recipe) -> Maybe<Model.Recipe>:
  match rest found:
    case Nil{} True{}: Some{recipe}
    case Nil{} False{}: None{}
    case next <> tail True{}: Some{recipe}
    case Model.Recipe{+id, +source_a, +source_b, result} <> tail False{}:
      find_recipe_pair_step(tail, pair_eq(wanted,
        canonical_pair(source_a, source_b)), wanted,
        Model.Recipe{id, source_a, source_b, result})

def find_recipe_pair(+wanted: Model.SourcePair,
  recipes: List<&2, Model.Recipe>) -> Maybe<Model.Recipe>:
  match recipes:
    case Nil{}: None{}
    case recipe <> rest:
      match recipe:
        case Model.Recipe{+id, +source_a, +source_b, result}:
          find_recipe_pair_step(rest, pair_eq(wanted,
            canonical_pair(source_a, source_b)), wanted, recipe)

def lookup(catalog: Model.Catalog, left: Math.MoveId,
  right: Math.MoveId) -> Maybe<Model.Recipe>:
  Model.Catalog{+recipes, sources, results} = catalog
  find_recipe_pair(canonical_pair(left, right), recipes)

def find_recipe_id_step(rest: List<&2, Model.Recipe>, found: Bool,
  +wanted: Model.RecipeId, recipe: Model.Recipe) -> Maybe<Model.Recipe>:
  match rest found:
    case Nil{} True{}: Some{recipe}
    case Nil{} False{}: None{}
    case next <> tail True{}: Some{recipe}
    case Model.Recipe{+id, source_a, source_b, result} <> tail False{}:
      find_recipe_id_step(tail, recipe_id_eq(wanted, id), wanted,
        Model.Recipe{id, source_a, source_b, result})

def find_recipe_by_id(+wanted: Model.RecipeId,
  recipes: List<&2, Model.Recipe>) -> Maybe<Model.Recipe>:
  match recipes:
    case Nil{}: None{}
    case recipe <> rest:
      match recipe:
        case Model.Recipe{+id, source_a, source_b, result}:
          find_recipe_id_step(rest, recipe_id_eq(wanted, id), wanted, recipe)

def source_components_valid(single: Bool,
  allocation: Multi.AllocationResult) -> Bool:
  match single allocation:
    case True{} Multi.Allocated{_}: True{}
    case _ _: False{}

def source_diagnostic_value(valid: Bool, recipe_id: Model.RecipeId,
  source_id: Math.MoveId, count: Nat) -> Maybe<RecipeDiagnostic>:
  match valid:
    case True{}: None{}
    case False{}: Some{InvalidSourceComponents{recipe_id, source_id, count}}

def cooldown_valid(+cooldown: U32) -> Bool:
  Bool.and(U32.is_ge(cooldown, 60), U32.is_le(cooldown, 3600))

def source_diagnostic(recipe_id: Model.RecipeId, source_id: Math.MoveId,
  source: Maybe<Model.BaseMoveMeta>) -> Maybe<RecipeDiagnostic>:
  match source:
    case None{}: Some{UnknownSource{recipe_id, source_id}}
    case Some{Model.BaseMoveMeta{id, +components, ordinary_cooldown,
        is_recipe_result}}:
      match is_recipe_result:
        case True{}: Some{ResultUsedAsSource{recipe_id, source_id}}
        case False{}:
          source_diagnostic_value(source_components_valid(Nat.is_eq(
            List.length(&2, Multi.TypeId, components), 1n),
            Multi.allocate(1, components)), recipe_id, source_id,
            List.length(&2, Multi.TypeId, components))

def source_cooldown_diagnostic_value(valid: Bool, recipe_id: Model.RecipeId,
  source_id: Math.MoveId) -> Maybe<RecipeDiagnostic>:
  match valid:
    case True{}: None{}
    case False{}: Some{InvalidSourceCooldown{recipe_id, source_id}}

def source_cooldown_diagnostic(recipe_id: Model.RecipeId,
  source_id: Math.MoveId, source: Maybe<Model.BaseMoveMeta>) ->
  Maybe<RecipeDiagnostic>:
  match source:
    case None{}: None{}
    case Some{Model.BaseMoveMeta{id, components, ordinary_cooldown,
        is_recipe_result}}:
      source_cooldown_diagnostic_value(cooldown_valid(ordinary_cooldown),
        recipe_id, source_id)

def neutral_stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def neutral_actor() -> Effects.EffectActor:
  Effects.EffectActor{1, 1, 1, 1, neutral_stages(), [], False{}, []}

def descriptor_validation_ok(validation: Effects.Validation) -> Bool:
  match validation:
    case Effects.Validation{[], seen, damage_count, cost}: True{}
    case _: False{}

def descriptor_valid(program: Effects.EffectProgram) -> Bool:
  descriptor_validation_ok(Effects.validate(program,
    Effects.EffectWorld{neutral_actor(), neutral_actor()},
    Effects.ActionSnapshot{1, 1, 1, Math.StageNeutral{},
      Math.OrdinaryAccuracy{10000}, Effects.NormalPhysical{}, 0}))

def result_effect_valid(valid: Bool, recipe_id: Model.RecipeId,
  result_id: Model.ResultId) -> Maybe<RecipeDiagnostic>:
  match valid:
    case True{}: None{}
    case False{}: Some{InvalidEffectDescriptor{recipe_id, result_id}}

def result_components_valid(allocation: Multi.AllocationResult,
  recipe_id: Model.RecipeId, result_id: Model.ResultId,
  program: Effects.EffectProgram) -> Maybe<RecipeDiagnostic>:
  match allocation:
    case Multi.AllocationRejectedResult{reason}:
      Some{InvalidResultComponents{recipe_id, result_id, reason}}
    case Multi.Allocated{_}:
      result_effect_valid(descriptor_valid(program), recipe_id, result_id)

def result_diagnostic(recipe_id: Model.RecipeId, result_id: Model.ResultId,
  result: Maybe<Model.ResultDescriptor>) -> Maybe<RecipeDiagnostic>:
  match result:
    case None{}: Some{UnknownResult{recipe_id, result_id}}
    case Some{Model.ResultDescriptor{id, program, components, is_registered}}:
      match is_registered:
        case False{}: Some{UnregisteredResult{recipe_id, result_id}}
        case True{}:
          result_components_valid(Multi.allocate(1, components), recipe_id,
            result_id, program)

def push_optional(value: Maybe<RecipeDiagnostic>,
  out: List<&2, RecipeDiagnostic>) -> List<&2, RecipeDiagnostic>:
  match value:
    case None{}: out
    case Some{diagnostic}: diagnostic <> out

def duplicate_pair_continue(rest: List<&2, Model.Recipe>, same: Bool,
  current: Model.RecipeId, earlier: Model.RecipeId,
  +wanted: Model.SourcePair) -> Maybe<RecipeDiagnostic>:
  match rest same:
    case Nil{} True{}: Some{DuplicatePair{current, earlier}}
    case Nil{} False{}: None{}
    case Model.Recipe{id, source_a, source_b, result} <> tail True{}:
      Some{DuplicatePair{current, earlier}}
    case Model.Recipe{+id, +source_a, +source_b, result} <> tail False{}:
      duplicate_pair_continue(tail, pair_eq(wanted,
        canonical_pair(source_a, source_b)), current, id, wanted)

def duplicate_pair_scan(current: Model.RecipeId, +source_a: Math.MoveId,
  +source_b: Math.MoveId, recipe: Model.Recipe,
  previous: List<&2, Model.Recipe>) -> Maybe<RecipeDiagnostic>:
  match previous:
    case Nil{}: None{}
    case earlier <> rest:
      match earlier:
        case Model.Recipe{earlier_id, earlier_a, earlier_b, earlier_result}:
          duplicate_pair_continue(rest,
            pair_eq(canonical_pair(source_a, source_b),
              canonical_pair(earlier_a, earlier_b)), current, earlier_id,
            canonical_pair(source_a, source_b))

def same_pair_recipe(+recipe: Model.Recipe,
  previous: List<&2, Model.Recipe>) -> Maybe<RecipeDiagnostic>:
  Model.Recipe{+id, +source_a, +source_b, result} = recipe
  duplicate_pair_scan(id, source_a, source_b, recipe, previous)

def duplicate_recipe_id_continue(rest: List<&2, Model.Recipe>, same: Bool,
  +current: Model.RecipeId, earlier: Model.RecipeId) ->
  Maybe<RecipeDiagnostic>:
  match rest same:
    case Nil{} True{}: Some{DuplicateRecipeId{current, earlier}}
    case Nil{} False{}: None{}
    case Model.Recipe{id, source_a, source_b, result} <> tail True{}:
      Some{DuplicateRecipeId{current, earlier}}
    case Model.Recipe{+id, source_a, source_b, result} <> tail False{}:
      duplicate_recipe_id_continue(tail, recipe_id_eq(current, id), current, id)

def duplicate_recipe_id_scan(+current: Model.RecipeId,
  previous: List<&2, Model.Recipe>) -> Maybe<RecipeDiagnostic>:
  match previous:
    case Nil{}: None{}
    case earlier <> rest:
      match earlier:
        case Model.Recipe{+earlier_id, source_a, source_b, result}:
          duplicate_recipe_id_continue(rest,
            recipe_id_eq(current, earlier_id), current, earlier_id)

def duplicate_recipe_id(recipe: Model.Recipe,
  previous: List<&2, Model.Recipe>) -> Maybe<RecipeDiagnostic>:
  Model.Recipe{id, source_a, source_b, result} = recipe
  duplicate_recipe_id_scan(id, previous)

def validate_one_pair(self_pair: Bool, +recipe: Model.Recipe,
  catalog: Model.Catalog, +previous: List<&2, Model.Recipe>,
  out: List<&2, RecipeDiagnostic>) -> List<&2, RecipeDiagnostic>:
  match self_pair:
    case True{}:
      Model.Recipe{id, source_a, source_b, result} = recipe
      SelfPair{id} <> out
    case False{}:
      Model.Recipe{+id, +source_a, +source_b, result} = recipe
      Model.Catalog{recipes, +sources, +results} = catalog
      +start = push_optional(duplicate_recipe_id(recipe, previous), out)
      +after_pair = push_optional(same_pair_recipe(recipe, previous), start)
      +after_a = push_optional(source_diagnostic(id, source_a,
        find_source(source_a, sources)), after_pair)
      +after_a_cooldown = push_optional(source_cooldown_diagnostic(id,
        source_a, find_source(source_a, sources)), after_a)
      +after_b = push_optional(source_diagnostic(id, source_b,
        find_source(source_b, sources)), after_a_cooldown)
      +after_b_cooldown = push_optional(source_cooldown_diagnostic(id,
        source_b, find_source(source_b, sources)), after_b)
      push_optional(result_diagnostic(id, result, find_result(result, results)),
        after_b_cooldown)

def validate_one(+recipe: Model.Recipe, catalog: Model.Catalog,
  previous: List<&2, Model.Recipe>,
  out: List<&2, RecipeDiagnostic>) -> List<&2, RecipeDiagnostic>:
  Model.Recipe{+id, +source_a, +source_b, result} = recipe
  validate_one_pair(move_eq(source_a, source_b), recipe, catalog, previous, out)

def validate_recipes(+catalog: Model.Catalog,
  recipes: List<&2, Model.Recipe>, +previous: List<&2, Model.Recipe>,
  +out: List<&2, RecipeDiagnostic>) -> List<&2, RecipeDiagnostic>:
  match recipes:
    case Nil{}: out
    case +recipe <> rest:
      validate_recipes(catalog, rest, recipe <> previous,
        validate_one(recipe, catalog, previous, out))

def validate_diagnostics(diagnostics: List<&2, RecipeDiagnostic>,
  catalog: Model.Catalog) -> CatalogResult:
  match diagnostics:
    case Nil{}: CatalogAccepted{catalog}
    case _: CatalogRejected{diagnostics}

def validate_catalog_size(too_large: Bool, +catalog: Model.Catalog,
  count: Nat, +recipes: List<&2, Model.Recipe>) -> CatalogResult:
  match too_large:
    case True{}: CatalogRejected{[CatalogTooLarge{count}]}
    case False{}:
      validate_diagnostics(List.append(&2, RecipeDiagnostic,
        metadata_id_diagnostics(catalog), List.reverse(&2, RecipeDiagnostic,
          validate_recipes(catalog, recipes, [], []))), catalog)

def validate_catalog(catalog: Model.Catalog) -> CatalogResult:
  Model.Catalog{+recipes, sources, results} = catalog
  +count = List.length(&2, Model.Recipe, recipes)
  validate_catalog_size(Nat.is_gt(count, 256n), catalog, count, recipes)
