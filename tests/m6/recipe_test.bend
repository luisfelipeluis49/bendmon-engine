import Base
import ../../engine/mixing/model.bend as Model
import ../../engine/mixing/recipe.bend as Recipe
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/multi_type.bend as Multi

# M6-A core fixtures focus on canonical identity, catalog validation and
# registered M4/M5 descriptors. Authored timing/accuracy metadata is deferred
# to the later content-authoring slice.
def move(value: Nat) -> Math.MoveId:
  Math.MoveId{value}

def catalog_with_components(components: List<&2, Multi.TypeId>) -> Model.Catalog:
  Model.Catalog{
    [Model.Recipe{Model.RecipeId{7n}, move(2n), move(1n), Model.ResultId{3n}}],
    [Model.BaseMoveMeta{move(1n), [Multi.TypeId{1n}], 60, False{}},
     Model.BaseMoveMeta{move(2n), [Multi.TypeId{2n}], 3600, False{}}],
    [Model.ResultDescriptor{Model.ResultId{3n},
      Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Target{}, 1}}]},
      components, True{}}]}

def valid_catalog() -> Model.Catalog:
  catalog_with_components([Multi.TypeId{3n}])

def accepted_bool(result: Recipe.CatalogResult) -> Bool:
  match result:
    case Recipe.CatalogAccepted{catalog}: True{}
    case _: False{}

def valid_result_sizes_code() -> Nat:
  U32.to_nat(Bool.to_u32(Bool.and(
    Bool.and(accepted_bool(Recipe.validate_catalog(catalog_with_components(
      [Multi.TypeId{1n}, Multi.TypeId{2n}]))),
      accepted_bool(Recipe.validate_catalog(catalog_with_components(
        [Multi.TypeId{1n}, Multi.TypeId{2n}, Multi.TypeId{3n}])))),
    accepted_bool(Recipe.validate_catalog(catalog_with_components(
      [Multi.TypeId{1n}, Multi.TypeId{2n}, Multi.TypeId{3n},
       Multi.TypeId{4n}]))))))

def reversed_lookup_code(result: Maybe<Model.Recipe>) -> Nat:
  match result:
    case Some{Model.Recipe{Model.RecipeId{7n}, move_a, move_b,
        Model.ResultId{3n}}}: 1n
    case _: 0n

def accepted_code(result: Recipe.CatalogResult) -> Nat:
  match result:
    case Recipe.CatalogAccepted{catalog}: 1n
    case _: 0n

def self_pair_code(result: Recipe.CatalogResult) -> Nat:
  match result:
    case Recipe.CatalogRejected{
        Recipe.SelfPair{Model.RecipeId{7n}} <> rest}: 1n
    case _: 0n

def reversed_duplicate_catalog() -> Model.Catalog:
  Model.Catalog{
    [Model.Recipe{Model.RecipeId{7n}, move(2n), move(1n), Model.ResultId{3n}},
     Model.Recipe{Model.RecipeId{8n}, move(1n), move(2n), Model.ResultId{3n}}],
    [Model.BaseMoveMeta{move(1n), [Multi.TypeId{1n}], 60, False{}},
     Model.BaseMoveMeta{move(2n), [Multi.TypeId{2n}], 60, False{}}],
    [Model.ResultDescriptor{Model.ResultId{3n},
      Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Target{}, 1}}]},
      [Multi.TypeId{3n}, Multi.TypeId{4n}, Multi.TypeId{5n},
       Multi.TypeId{6n}, Multi.TypeId{7n}], True{}}]}

def duplicate_metadata_catalog() -> Model.Catalog:
  Model.Catalog{
    [],
    [Model.BaseMoveMeta{move(1n), [Multi.TypeId{1n}], 60, False{}},
     Model.BaseMoveMeta{move(1n), [Multi.TypeId{2n}], 60, False{}}],
    [Model.ResultDescriptor{Model.ResultId{3n},
      Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Target{}, 1}}]},
      [Multi.TypeId{3n}], True{}},
     Model.ResultDescriptor{Model.ResultId{3n},
      Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Target{}, 1}}]},
      [Multi.TypeId{4n}], True{}}]}

def duplicate_metadata_code(result: Recipe.CatalogResult) -> Nat:
  match result:
    case Recipe.CatalogRejected{diagnostics}:
      match diagnostics:
        case Recipe.DuplicateSourceId{Math.MoveId{1n}, Math.MoveId{1n}} <>
            Recipe.DuplicateResultId{Model.ResultId{3n},
              Model.ResultId{3n}} <> rest: 1n
        case _: 0n
    case _: 0n

def bad_cooldown_code(result: Recipe.CatalogResult) -> Nat:
  match result:
    case Recipe.CatalogRejected{diagnostics}:
      match diagnostics:
        case Recipe.InvalidSourceCooldown{Model.RecipeId{7n},
            Math.MoveId{1n}} <>
            rest: 1n
        case _: 0n
    case _: 0n

def duplicate_and_multi_result_code(result: Recipe.CatalogResult) -> Nat:
  match result:
    case Recipe.CatalogRejected{diagnostics}:
      match diagnostics:
        case Recipe.InvalidResultComponents{Model.RecipeId{7n},
              Model.ResultId{3n}, _} <>
            Recipe.DuplicatePair{Model.RecipeId{8n}, Model.RecipeId{7n}} <>
            rest: 1n
        case _: 0n
    case _: 0n

def main() -> List<&2, Nat>:
  [accepted_code(Recipe.validate_catalog(valid_catalog())),
   reversed_lookup_code(Recipe.lookup(valid_catalog(), move(1n), move(2n))),
   valid_result_sizes_code(),
   self_pair_code(Recipe.validate_catalog(Model.Catalog{
     [Model.Recipe{Model.RecipeId{7n}, move(1n), move(1n), Model.ResultId{3n}}],
     [Model.BaseMoveMeta{move(1n), [Multi.TypeId{1n}], 60, False{}}],
     [Model.ResultDescriptor{Model.ResultId{3n},
       Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Target{}, 1}}]},
       [Multi.TypeId{3n}], True{}}]})),
   duplicate_and_multi_result_code(Recipe.validate_catalog(
     reversed_duplicate_catalog())),
   duplicate_metadata_code(Recipe.validate_catalog(duplicate_metadata_catalog())),
   bad_cooldown_code(Recipe.validate_catalog(Model.Catalog{
     [Model.Recipe{Model.RecipeId{7n}, move(1n), move(2n),
       Model.ResultId{3n}}],
     [Model.BaseMoveMeta{move(1n), [Multi.TypeId{1n}], 59, False{}},
      Model.BaseMoveMeta{move(2n), [Multi.TypeId{2n}], 60, False{}}],
     [Model.ResultDescriptor{Model.ResultId{3n},
       Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Target{}, 1}}]},
       [Multi.TypeId{3n}], True{}}]}))]
