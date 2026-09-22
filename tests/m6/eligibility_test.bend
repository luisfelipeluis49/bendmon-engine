import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/eligibility.bend as Eligibility
import ../../engine/mixing/observation.bend as Learning
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/multi_type.bend as Multi
import ../../engine/battle/sources.bend as Sources

def recipe() -> MixModel.Recipe:
  MixModel.Recipe{MixModel.RecipeId{3n}, Math.MoveId{7n},
    Math.MoveId{8n}, MixModel.ResultId{4n}}

def descriptor() -> MixModel.ResultDescriptor:
  MixModel.ResultDescriptor{MixModel.ResultId{4n},
    Effects.EffectProgram{[Effects.Leaf{Effects.Heal{Effects.Source{}, 1}}]},
    [Multi.TypeId{1n}, Multi.TypeId{2n}], True{}}

def catalog() -> MixModel.Catalog:
  MixModel.Catalog{[recipe()],
    [MixModel.BaseMoveMeta{Math.MoveId{7n}, [Multi.TypeId{1n}], 60, False{}},
     MixModel.BaseMoveMeta{Math.MoveId{8n}, [Multi.TypeId{2n}], 61, False{}}],
    [descriptor()]}

def learning(learned: Bool) -> Learning.LearningState:
  match learned:
    case True{}:
      Learning.LearningState{MixModel.MonsterId{1n},
        [MixModel.RecipeId{3n}],
        [Learning.LearnedRecipe{MixModel.RecipeId{3n}, 0}]}
    case False{}:
      Learning.LearningState{MixModel.MonsterId{1n},
        [MixModel.RecipeId{3n}], []}

def sources(second_reserved: Bool) -> List<&2, Sources.MoveSource>:
  [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 0, False{}},
   Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 0,
     second_reserved}]

def accepted(result: Eligibility.MixEligibility) -> Bool:
  match result:
    case Eligibility.MixEligible{Eligibility.MixPlan{recipe, descriptor,
        first, second, 60, 61,
        Sources.MoveSource{owner_a, move_a, 0, True{}} <>
        Sources.MoveSource{owner_b, move_b, 0, True{}} <> Nil{}}}:
      True{}
    case _:
      False{}

def missing_learning(result: Eligibility.MixEligibility) -> Bool:
  match result:
    case Eligibility.MixRejected{Eligibility.RecipeNotLearned{
        MixModel.RecipeId{3n}}}: True{}
    case _: False{}

def unavailable(result: Eligibility.MixEligibility) -> Bool:
  match result:
    case Eligibility.MixRejected{Eligibility.SourceUnavailable{}}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  +actor = {Battle.ActorId{0n} : Battle.ActorId}
  +individual = {MixModel.MonsterId{1n} : MixModel.MonsterId}
  +a = {Math.MoveId{7n} : Math.MoveId}
  +b = {Math.MoveId{8n} : Math.MoveId}
  +moves = {[a, b] : List<&2, Math.MoveId>}
  [accepted(Eligibility.plan(True{}, True{}, 100, actor, individual,
      a, b, catalog(), learning(True{}), moves, sources(False{}))),
   accepted(Eligibility.plan(True{}, True{}, 100, actor, individual,
      b, a, catalog(), learning(True{}), moves, sources(False{}))),
   missing_learning(Eligibility.plan(True{}, True{}, 100, actor, individual,
      a, b, catalog(), learning(False{}), moves, sources(False{}))),
   unavailable(Eligibility.plan(True{}, True{}, 100, actor, individual,
      a, b, catalog(), learning(True{}), moves, sources(True{})))]

#| [True, True, True, True]
