import Base
import ../battle/rng.bend as Rng
import ../progression/core.bend as Progression
import ./rewards.bend as Rewards
import ./dynamic_species.bend as Species

# The first bootstrap boundary builds progression-valid combatants from
# already validated catalog rows. Runtime bindings remain the caller's job.
type BootPair is Data:
  BootPair{starter: Progression.Individual,
    wild: Progression.Individual, encounter_id: Nat, content_identity: U32,
    rng: Rng.RngState, wait_ticks: U32}

type BootResult is Data:
  BootRejected{}
  BootReady{pair: BootPair}

def individual_from_threshold(threshold: Maybe<&2, U32>, id: Nat,
  species: Nat, level: U32, ivs: Progression.StatBlock,
  moves: List<&2, U32>, +hp: U32) -> Maybe<Progression.Individual>:
  match threshold:
    case None{}: None{}
    case Some{xp}:
      Some{Progression.Individual{id, species, level, xp, hp, hp,
        ivs, moves, [], [], [], [0]}}

def individual_from_stats(valid: Bool, id: Nat, species: Nat,
  +level: U32, ivs: Progression.StatBlock,
  moves: List<&2, U32>, stats: Maybe<&2, Progression.StatBlock>) -> Maybe<Progression.Individual>:
  match valid stats:
    case False{} _: None{}
    case True{} None{}: None{}
    case True{} Some{Progression.StatBlock{hp, _, _, _, _, _}}:
      individual_from_threshold(Progression.xp_threshold(level), id,
        species, level, ivs, moves, hp)

def collect_level_moves(+level: U32, entries: List<&2, Rewards.LevelMove>,
  +acc: List<&2, U32>) -> List<&2, U32>:
  match entries:
    case Nil{}: acc
    case Rewards.LevelMove{entry_level, move} <> tail:
      next = Bool.pick(List<&2, U32>, U32.is_le(entry_level, level),
        move <> acc, acc)
      collect_level_moves(level, tail, next)

def last_four_moves(moves: List<&2, U32>, +acc: List<&2, U32>) ->
  List<&2, U32>:
  match moves:
    case Nil{}: acc
    case +move <> rest:
      next = Bool.pick(List<&2, U32>,
        Nat.is_lt(List.length(&2, U32, acc), 4n), move <> acc, acc)
      last_four_moves(rest, next)

def initial_moves(learning: Rewards.SpeciesLearning, level: U32) ->
  List<&2, U32>:
  match learning:
    case Rewards.SpeciesLearning{species_id, entries}:
      last_four_moves(collect_level_moves(level, entries, []), [])

def make_individual(id: Nat, species_record: Species.SpeciesProgressionRecord,
  +level: U32, +ivs: Progression.StatBlock) -> Maybe<Progression.Individual>:
  match species_record:
    case Species.SpeciesProgressionRecord{species, +base, capture_rate,
        xp_yield, currency_yield, combat_types, learning}:
      individual_from_stats(Progression.stats_valid(base, ivs, level), id,
        species, level, ivs, initial_moves(learning, level),
        Progression.calculate_stats(base, ivs, level))

def result(starter: Maybe<Progression.Individual>,
  wild: Maybe<Progression.Individual>, encounter_id: Nat,
  content_identity: U32, rng: Rng.RngState, wait_ticks: U32) -> BootResult:
  match starter wild:
    case Some{starter_value} Some{wild_value}:
      BootReady{BootPair{starter_value, wild_value, encounter_id,
        content_identity, rng, wait_ticks}}
    case _ _ : BootRejected{}

# Produces full-health individuals with the legal level-up moves available at
# their starting level. Runtime move behavior stays bound by the trusted layer.
def build(starter: Species.SpeciesProgressionRecord, starter_level: U32,
  wild: Species.SpeciesProgressionRecord, wild_level: U32,
  encounter_id: Nat, content_identity: U32, rng: Rng.RngState,
  wait_ticks: U32) -> BootResult:
  result(make_individual(1n, starter, starter_level,
      Progression.StatBlock{0, 0, 0, 0, 0, 0}),
    make_individual(2n, wild, wild_level,
      Progression.StatBlock{0, 0, 0, 0, 0, 0}), encounter_id,
    content_identity, rng, wait_ticks)
