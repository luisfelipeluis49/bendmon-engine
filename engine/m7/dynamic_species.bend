import Base
import ../progression/core.bend as Progression
import ./rewards.bend as Rewards

# M10's species bridge contains only inert progression values. Formulas and
# executable move effects remain selected by the trusted M7 ruleset.
type SpeciesProgressionRecord is Data:
  SpeciesProgressionRecord{species: Nat, base: Progression.StatBlock,
    capture_rate: U32, xp_yield: U32, currency_yield: U32,
    combat_types: List<&2, U32>, learning: Rewards.SpeciesLearning}

type Catalog is Data:
  Catalog{identity: U32, move_count: U32,
    species: List<&2, SpeciesProgressionRecord>}

type DecodeResult is Data:
  DecodeRejected{reason: String}
  DecodeAccepted{catalog: Catalog}

type MovesRead is Data:
  MovesBad{}
  MovesDone{moves: List<&2, Rewards.LevelMove>, rest: List<&2, U32>}

@unsafe def read_move_valid(valid: Bool, count: Nat, move_count: U32,
  +level: U32, move: U32, tokens: List<&2, U32>,
  acc: List<&2, Rewards.LevelMove>) -> MovesRead:
  match valid:
    case False{}: MovesBad{}
    case True{}:
      read_moves(count, move_count, level, tokens,
        Rewards.LevelMove{level, move} <> acc)

def stat_valid(+value: U32) -> Bool:
  Bool.and(U32.is_le(1, value), U32.is_le(value, 500))

def type_ids_valid(+count: U32, +first: U32, +second: U32) -> Bool:
  Bool.and(U32.is_le(1, count), Bool.and(U32.is_le(count, 2),
  Bool.and(U32.is_le(first, 9), Bool.and(U32.is_le(second, 9),
  Bool.and(Bool.or(U32.is_eq(count, 2), U32.is_eq(second, 0)),
    Bool.or(U32.is_eq(count, 1), Bool.not(U32.is_eq(first, second))))))))

def keep_type_ids(+count: U32, +first: U32, +second: U32) -> List<&2, U32>:
  match count:
    case 1: [first]
    case _: [first, second]

def stats_valid(+hp: U32, +attack: U32, +defense: U32, +special_attack: U32,
  +special_defense: U32, +speed: U32) -> Bool:
  Bool.and(stat_valid(hp), Bool.and(stat_valid(attack),
  Bool.and(stat_valid(defense), Bool.and(stat_valid(special_attack),
  Bool.and(stat_valid(special_defense),
    stat_valid(speed))))))

@unsafe def read_moves(count: Nat, +move_count: U32, previous_level: U32,
  tokens: List<&2, U32>, acc: List<&2, Rewards.LevelMove>) -> MovesRead:
  match count:
    case 0n: MovesDone{List.reverse(&2, Rewards.LevelMove, acc), tokens}
    case 1n+rest:
      match tokens:
        case +level <> +move <> tail:
          read_move_valid(Bool.and(U32.is_le(1, level),
            Bool.and(U32.is_le(previous_level, level),
            Bool.and(U32.is_le(level, 200),
              Bool.and(U32.is_le(1, move), U32.is_le(move, move_count))))),
            rest, move_count, level, move, tail, acc)
        case _: MovesBad{}

type SpeciesRead is Data:
  SpeciesBad{}
  SpeciesDone{species: List<&2, SpeciesProgressionRecord>,
    rest: List<&2, U32>}

@unsafe def species_rows(count: Nat, +expected_id: U32, +move_count: U32,
  +references: Nat,
  tokens: List<&2, U32>, acc: List<&2, SpeciesProgressionRecord>) -> SpeciesRead:
  match count:
    case 0n: SpeciesDone{List.reverse(&2, SpeciesProgressionRecord, acc), tokens}
    case 1n+rest:
      match tokens:
        case id <> +hp <> +attack <> +defense <> +special_attack <>
             +special_defense <> +speed <> +capture <> +xp <> +currency <>
             +type_count <> +type1 <> +type2 <> +learn_count <> tail:
          species_row_valid(Bool.and(U32.is_eq(id, expected_id),
            Bool.and(stats_valid(hp, attack, defense, special_attack,
              special_defense, speed),
            Bool.and(U32.is_le(500, capture), Bool.and(U32.is_le(capture, 9000),
              Bool.and(U32.is_le(1, xp), Bool.and(U32.is_le(xp, 1000),
              Bool.and(U32.is_le(currency, 100000),
                Bool.and(type_ids_valid(type_count, type1, type2),
                Bool.and(U32.is_le(learn_count, 256),
                  Nat.is_le(Nat.add(references, U32.to_nat(learn_count)),
                    4096n)))))))))), rest, expected_id, move_count, references,
            hp, attack, defense, special_attack, special_defense,
            speed, capture, xp, currency, type_count, type1, type2,
            learn_count, tail, acc)
        case _: SpeciesBad{}

@unsafe def species_row_valid(valid: Bool, count: Nat, expected_id: U32,
  +move_count: U32, +references: Nat, hp: U32, attack: U32, defense: U32,
  special_attack: U32, special_defense: U32, speed: U32, capture: U32,
  xp: U32, currency: U32, +type_count: U32, +type1: U32, +type2: U32,
  +learn_count: U32, tokens: List<&2, U32>,
  acc: List<&2, SpeciesProgressionRecord>) -> SpeciesRead:
  match valid:
    case False{}: SpeciesBad{}
    case True{}:
      species_moves_read(count, expected_id, move_count, references,
        hp, attack, defense, special_attack, special_defense, speed, capture, xp, currency,
        type_count, type1, type2,
        learn_count, read_moves(U32.to_nat(learn_count), move_count, 0,
          tokens, Nil{}), acc)

@unsafe def species_moves_read(count: Nat, +expected_id: U32, +move_count: U32,
  +references: Nat,
  hp: U32, attack: U32, defense: U32, special_attack: U32,
  special_defense: U32, speed: U32, capture: U32, xp: U32, currency: U32,
  type_count: U32, type1: U32, type2: U32, learn_count: U32, result: MovesRead,
  acc: List<&2, SpeciesProgressionRecord>) -> SpeciesRead:
  match result:
    case MovesBad{}: SpeciesBad{}
    case MovesDone{moves, rest}:
      species_rows(count, U32.add(expected_id, 1), move_count,
        Nat.add(references, U32.to_nat(learn_count)), rest,
        SpeciesProgressionRecord{U32.to_nat(expected_id),
          Progression.StatBlock{hp, attack, defense, special_attack,
            special_defense, speed}, capture, xp, currency,
          keep_type_ids(type_count, type1, type2),
          Rewards.SpeciesLearning{U32.to_nat(expected_id), moves}} <> acc)

def species_read_result(result: SpeciesRead, identity: U32,
  +move_count: U32) -> DecodeResult:
  match result:
    case SpeciesBad{}: DecodeRejected{"species-record"}
    case SpeciesDone{species, Nil{}}:
      DecodeAccepted{Catalog{identity, move_count, species}}
    case SpeciesDone{species, rest}: DecodeRejected{"species-trailing-data"}

def header(identity: U32, species_count: U32, +move_count: U32,
  tokens: List<&2, U32>) -> DecodeResult:
  species_read_result(species_rows(U32.to_nat(species_count), 1,
    move_count, 0n, tokens, Nil{}), identity, move_count)

def header_valid(valid: Bool, identity: U32, species_count: U32,
  +move_count: U32, rest: List<&2, U32>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{"species-wire-count"}
    case True{}: header(identity, species_count, move_count, rest)

# Rows are dense and canonical because IDs are assigned by the validated host
# binding in sorted order. Every learned move must refer to a bounded move ID.
def decode_tokens(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 13 <> 2 <> identity <> +species_count <> +move_count <> rest:
      header_valid(Bool.and(U32.is_le(1, species_count),
        Bool.and(U32.is_le(species_count, 256),
        U32.is_le(move_count, 256))),
        identity, species_count, move_count, rest)
    case _: DecodeRejected{"species-wire-header"}
