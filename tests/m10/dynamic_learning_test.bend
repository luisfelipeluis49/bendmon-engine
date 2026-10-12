import Base
import ../../engine/m7/dynamic_learning.bend as Learning
import ../../engine/m7/dynamic_species.bend as Species
import ../../engine/m7/playable.bend as Playable
import ../../engine/m7/rewards.bend as Rewards

def decoded_result(result: Species.DecodeResult) -> Maybe<Species.Catalog>:
  match result:
    case Species.DecodeAccepted{catalog}: Some{catalog}
    case _: None{}

def decoded() -> Maybe<Species.Catalog>:
  decoded_result(Species.decode_tokens(
    [13, 2, 17, 1, 2, 1, 50, 51, 52, 53, 54, 55,
      500, 100, 0, 1, 1, 0, 1, 1, 2]))

def entries_ok(entries: List<&2, Rewards.LevelMove>) -> Bool:
  match entries:
    case Rewards.LevelMove{level, move} <> Nil{}:
      Bool.and(U32.is_eq(level, 1), U32.is_eq(move, 2))
    case _: False{}

def learning_ok(learning: List<&2, Rewards.SpeciesLearning>) -> Bool:
  match learning:
    case Rewards.SpeciesLearning{species, entries} <> Nil{}:
      Bool.and(Nat.is_eq(species, 1n), entries_ok(entries))
    case _: False{}

def accepted(result: Maybe<Playable.ContentCatalog>) -> Bool:
  match result:
    case Some{Playable.ContentCatalog{learning, evolution, ruleset, identity}}:
      Bool.and(Nat.is_eq(ruleset, 7n),
        Bool.and(Nat.is_eq(identity, 17n), learning_ok(learning)))
    case _: False{}

def rejected(result: Maybe<Playable.ContentCatalog>) -> Bool:
  match result:
    case None{}: True{}
    case _: False{}

def check_decoded(value: Maybe<Species.Catalog>) -> Bool:
  match value:
    case None{}: False{}
    case Some{+catalog}:
      Bool.and(accepted(Learning.playable_catalog(catalog, 17)),
        rejected(Learning.playable_catalog(catalog, 18)))

def main() -> Bool:
  check_decoded(decoded())

#| True
