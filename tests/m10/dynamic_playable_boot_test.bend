import Base
import ../../engine/m7/dynamic_battle_boot.bend as Boot
import ../../engine/m7/dynamic_species.bend as Species
import ../../engine/m7/dynamic_moves.bend as Moves
import ../../engine/m7/dynamic_playable_boot.bend as PlayableBoot
import ../../engine/m7/playable.bend as Playable
import ../../engine/m7/session.bend as Session
import ../../engine/battle/rng.bend as Rng

def species_tokens() -> List<&2, U32>:
  [13, 2, 123, 2, 2,
   1, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 1, 0, 1, 1, 1,
   2, 45, 46, 47, 48, 49, 50, 500, 80, 5, 1, 2, 0, 1, 1, 2]

def boot_result(catalog: Species.Catalog) -> Boot.BootResult:
  match catalog:
    case Species.Catalog{identity, move_count,
        Species.SpeciesProgressionRecord{starter_id, starter_base,
          capture, xp, currency, starter_types, learning} <>
        Species.SpeciesProgressionRecord{wild_id, wild_base,
          wild_capture, wild_xp, wild_currency, wild_types, wild_learning} <> Nil{}}:
      Boot.build(Species.SpeciesProgressionRecord{starter_id, starter_base,
          capture, xp, currency, starter_types, learning}, 1,
        Species.SpeciesProgressionRecord{wild_id, wild_base, wild_capture,
          wild_xp, wild_currency, wild_types, wild_learning}, 5, 77n, identity,
        Rng.RngState{1, 2, 3, 4}, 60)
    case _: Boot.BootRejected{}

def decoded_species() -> Species.DecodeResult:
  Species.decode_tokens(species_tokens())

def decoded_moves() -> Moves.DecodeResult:
  Moves.decode_tokens([15, 3, 123, 2,
    1, 10, 1, 0, 0, 30, 60, 1, 1, 0, 0, 0, 0, 8, 0,
    2, 0, 0, 1000, 0, 30, 60, 0, 0, 0, 0, 0, 0, 8, 0])

def build_if_ready(result: Boot.BootResult, catalog: Species.Catalog,
  moves: Moves.Catalog) -> Maybe<Playable.PlayableSession>:
  match result:
    case Boot.BootReady{pair}:
      PlayableBoot.build(pair, catalog, moves, 1n, 1, 2n, 5)
    case _: None{}

def is_rejected(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: True{}
    case _: False{}

def reject_bad_id(result: Boot.BootResult, catalog: Species.Catalog,
  moves: Moves.Catalog) -> Bool:
  match result:
    case Boot.BootReady{pair}:
      is_rejected(PlayableBoot.build(pair, catalog, moves, 1n, 1, 9n, 5))
    case _: False{}

def build_from_moves(result: Moves.DecodeResult,
  +catalog: Species.Catalog) -> Maybe<Playable.PlayableSession>:
  match result:
    case Moves.DecodeAccepted{moves}:
      build_if_ready(boot_result(catalog), catalog, moves)
    case _: None{}

def build_from_species(result: Species.DecodeResult) ->
  Maybe<Playable.PlayableSession>:
  match result:
    case Species.DecodeAccepted{catalog}:
      build_from_moves(decoded_moves(), catalog)
    case _: None{}

def built() -> Maybe<Playable.PlayableSession>:
  build_from_species(decoded_species())

def valid_fresh(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{Playable.PlayableSession{state, learning, evolution,
        Nil{}, Nil{}, Playable.NoPending{}, 7n, 123n}}:
      Session.session_valid(state)
    case _: False{}

def reject_from_moves(result: Moves.DecodeResult,
  +catalog: Species.Catalog) -> Bool:
  match result:
    case Moves.DecodeAccepted{moves}:
      reject_bad_id(boot_result(catalog), catalog, moves)
    case _: False{}

def reject_from_species(result: Species.DecodeResult) -> Bool:
  match result:
    case Species.DecodeAccepted{catalog}:
      reject_from_moves(decoded_moves(), catalog)
    case _: False{}

def identity_mismatch_rejected() -> Bool:
  reject_from_species(decoded_species())

def main() -> Bool:
  Bool.and(valid_fresh(built()), identity_mismatch_rejected())

#| True
