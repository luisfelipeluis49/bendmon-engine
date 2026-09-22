import Base
import ../battle/combat_math.bend as Math
import ../battle/effects.bend as Effects
import ../battle/multi_type.bend as Multi

# M6 uses independent persistent identities while reusing the engine's typed
# move identity for ordinary sources.
type RecipeId is Data:
  RecipeId{value: Nat}

type MonsterId is Data:
  MonsterId{value: Nat}

type ResultId is Data:
  ResultId{value: Nat}

type SourcePair is Data:
  SourcePair{low: Math.MoveId, high: Math.MoveId}

type Recipe is Data:
  Recipe{id: RecipeId, source_a: Math.MoveId, source_b: Math.MoveId,
    result: ResultId}

type BaseMoveMeta is Data:
  BaseMoveMeta{id: Math.MoveId, components: List<&2, Multi.TypeId>,
    ordinary_cooldown: U32, is_recipe_result: Bool}

# A registered descriptor carries the closed M4 program and authored M5
# components. `is_registered` is supplied by the engine content registry; a
# recipe can only refer to a descriptor present in the catalog's result list.
type ResultDescriptor is Data:
  ResultDescriptor{id: ResultId, program: Effects.EffectProgram,
    components: List<&2, Multi.TypeId>, is_registered: Bool}

type Catalog is Data:
  Catalog{recipes: List<&2, Recipe>, sources: List<&2, BaseMoveMeta>,
    results: List<&2, ResultDescriptor>}
