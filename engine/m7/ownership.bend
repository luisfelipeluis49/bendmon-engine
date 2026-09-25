import Base
import ../progression/core.bend as Progression

# Ownership preserves the already-generated opponent individual. Capture does
# not generate new IVs or reroll moves: it only changes the stable owner ID and
# the HP observed when the capture action executes.
type CaptureResult is Data:
  CaptureOwned{individual: Progression.Individual}
  CaptureRejected{original: Progression.Individual}

def captured_stats_match(stats: Maybe<&2, Progression.StatBlock>,
  max_hp: U32) -> Bool:
  match stats:
    case None{}: False{}
    case Some{Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}}:
      U32.is_eq(hp, max_hp)

def capture_inputs_valid(new_id: Nat, expected_species: Nat,
  +target_hp: U32, original: Progression.Individual,
  +base_stats: Progression.StatBlock) -> Bool:
  match original:
    case Progression.Individual{old_id, species, +level, +xp, +current_hp,
        +max_hp, +ivs, moves, move_history, observations, unlocks, harmony}:
      +new_identity = Bool.not(Nat.is_eq(new_id, old_id))
      +species_matches = Nat.is_eq(species, expected_species)
      +level_matches_xp = U32.is_eq(level, Progression.level_for_xp(xp))
      +xp_bounded = U32.is_le(xp, Progression.xp_cap())
      +snapshot_hp_positive = U32.is_ge(current_hp, 1)
      +snapshot_hp_valid = U32.is_le(current_hp, max_hp)
      +captured_hp_positive = U32.is_ge(target_hp, 1)
      +captured_hp_bounded = U32.is_le(target_hp, max_hp)
      +valid_stats = Progression.stats_valid(base_stats, ivs, level)
      +stats_match = captured_stats_match(
        Progression.calculate_stats(base_stats, ivs, level), max_hp)
      +owner_valid = Bool.and(new_identity, species_matches)
      +progress_valid = Bool.and(level_matches_xp, xp_bounded)
      +snapshot_valid = Bool.and(snapshot_hp_positive, snapshot_hp_valid)
      +execution_valid = Bool.and(captured_hp_positive, captured_hp_bounded)
      +stats_valid = Bool.and(valid_stats, stats_match)
      Bool.and(owner_valid, Bool.and(progress_valid,
        Bool.and(snapshot_valid, Bool.and(execution_valid, stats_valid))))

def capture_checked(valid: Bool, new_id: Nat, target_hp: U32,
  +original: Progression.Individual) -> CaptureResult:
  match valid:
    case False{}:
      CaptureRejected{original}
    case True{}:
      match original:
        case Progression.Individual{old_id, species, level, xp, current_hp,
            max_hp, ivs, moves, move_history, observations, unlocks, harmony}:
          CaptureOwned{Progression.Individual{new_id, species, level, xp,
            target_hp, max_hp, ivs, moves, move_history, observations, unlocks,
            harmony}}

def capture(+new_id: Nat, expected_species: Nat, +target_hp: U32,
  +original: Progression.Individual, +trusted_base_stats: Progression.StatBlock
) -> CaptureResult:
  capture_checked(capture_inputs_valid(new_id, expected_species, target_hp,
    original, trusted_base_stats), new_id, target_hp, original)
