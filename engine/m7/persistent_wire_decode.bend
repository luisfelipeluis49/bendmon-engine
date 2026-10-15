import Base
import ./persistent_state.bend as Persistent
import ./persistent_wire_encode.bend as Encoder
import ../economy/core.bend as Economy
import ../economy/roster.bend as Roster
import ../progression/core.bend as Progression
import ./rewards.bend as Rewards

type DecodeResult is Data:
  DecodeAccepted{state: Persistent.PersistentState}
  DecodeRejected{}

type Split is Data:
  Split{prefix: List<&2, Nat>, suffix: List<&2, Nat>}
  SplitRejected{}

type NumberRead is Data:
  NumberRead{value: Nat, rest: List<&2, Nat>}
  NumberMissing{}

type CapacityRead is Data:
  CapacityRead{value: Economy.Capacity, rest: List<&2, Nat>}
  CapacityMissing{}

type StackRead is Data:
  StackRead{value: List<&2, Economy.ItemStack>, rest: List<&2, Nat>}
  StackMissing{}

type EconomyRead is Data:
  EconomyRead{value: Economy.State, rest: List<&2, Nat>}
  EconomyMissing{}

type IdRead is Data:
  IdRead{value: List<&2, Roster.IndividualId>, rest: List<&2, Nat>}
  IdMissing{}

type RosterRead is Data:
  RosterRead{value: Roster.Roster, rest: List<&2, Nat>}
  RosterMissing{}

type StatRead is Data:
  StatRead{value: Progression.StatBlock, rest: List<&2, Nat>}
  StatMissing{}

type U32Read is Data:
  U32Read{value: U32, rest: List<&2, Nat>}
  U32Missing{}

type U32ListRead is Data:
  U32ListRead{value: List<&2, U32>, rest: List<&2, Nat>}
  U32ListMissing{}

type NatListRead is Data:
  NatListRead{value: List<&2, Nat>, rest: List<&2, Nat>}
  NatListMissing{}

type HistoryRead is Data:
  HistoryRead{value: List<&2, Progression.MoveLearningRecord>,
    rest: List<&2, Nat>}
  HistoryMissing{}

type IndividualRead is Data:
  IndividualRead{value: Progression.Individual, rest: List<&2, Nat>}
  IndividualMissing{}

type IndividualHead is Data:
  IndividualHead{id: Nat, species: Nat, level: U32, xp: U32,
    current_hp: U32, max_hp: U32, ivs: Progression.StatBlock}

type IndividualDetails is Data:
  IndividualDetails{head: IndividualHead, moves: List<&2, U32>,
    history: List<&2, Progression.MoveLearningRecord>,
    observations: List<&2, Nat>, unlocks: List<&2, Nat>,
    harmony: List<&2, U32>}

type OwnedRead is Data:
  OwnedRead{value: List<&2, Rewards.OwnedRewardInput>, rest: List<&2, Nat>}
  OwnedMissing{}

type OwnedOneRead is Data:
  OwnedOneRead{value: Rewards.OwnedRewardInput, rest: List<&2, Nat>}
  OwnedOneMissing{}

type OwnedStep is Data:
  OwnedCount{remaining: Nat, values: List<&2, Nat>,
    accumulated: List<&2, Rewards.OwnedRewardInput>}
  OwnedLength{remaining: Nat, accumulated: List<&2, Rewards.OwnedRewardInput>,
    number: NumberRead}
  OwnedSplit{remaining: Nat, accumulated: List<&2, Rewards.OwnedRewardInput>,
    split: Split}
  OwnedParsed{remaining: Nat, accumulated: List<&2, Rewards.OwnedRewardInput>,
    rest: List<&2, Nat>, parsed: OwnedOneRead}

type PayloadResult is Data:
  PayloadResult{state: Persistent.PersistentState}
  PayloadMissing{}

def reverse(values: List<&2, Nat>, result: List<&2, Nat>) -> List<&2, Nat>:
  match values:
    case Nil{}: result
    case head <> tail: reverse(tail, head <> result)

def take(count: Nat, values: List<&2, Nat>,
  result: List<&2, Nat>) -> Split:
  match count:
    case 0n: Split{reverse(result, []), values}
    case 1n+rest:
      match values:
        case Nil{}: SplitRejected{}
        case head <> tail: take(rest, tail, head <> result)

def one(values: List<&2, Nat>) -> NumberRead:
  match values:
    case Nil{}: NumberMissing{}
    case head <> tail: NumberRead{head, tail}

def read_capacity(values: List<&2, Nat>) -> CapacityRead:
  match values:
    case p <> m <> s <> k <> e <> c <> rest:
      CapacityRead{Economy.Capacity{p, m, s, k, e, c}, rest}
    case _: CapacityMissing{}

def read_nats(count: Nat, values: List<&2, Nat>,
  result: List<&2, Nat>) -> NatListRead:
  match count:
    case 0n: NatListRead{reverse(result, []), values}
    case 1n+rest:
      match values:
        case value <> tail: read_nats(rest, tail, value <> result)
        case Nil{}: NatListMissing{}


def read_nat_list(count: Nat, values: List<&2, Nat>) -> NatListRead:
  read_nats(count, values, [])

def reverse_stacks(values: List<&2, Economy.ItemStack>,
  result: List<&2, Economy.ItemStack>) -> List<&2, Economy.ItemStack>:
  match values:
    case Nil{}: result
    case head <> tail: reverse_stacks(tail, head <> result)


def item_rows(count: Nat, values: List<&2, Nat>,
  result: List<&2, Economy.ItemStack>) -> StackRead:
  match count:
    case 0n: StackRead{reverse_stacks(result, []), values}
    case 1n+rest:
      match values:
        case item_id <> quantity <> tail:
          item_rows(rest, tail,
            Economy.ItemStack{Economy.ItemId{item_id}, quantity} <> result)
        case _: StackMissing{}

def economy_stacks(capacity_value: Economy.Capacity, tier: Nat, party: Nat,
  storage: Nat, moves: Nat, currency: Nat, stacks: StackRead) -> EconomyRead:
  match stacks:
    case StackMissing{}: EconomyMissing{}
    case StackRead{items, rest}:
      EconomyRead{Economy.State{capacity_value, tier, party, storage, moves,
        currency, items}, rest}

def read_economy_tail(capacity_value: Economy.Capacity,
  values: List<&2, Nat>) -> EconomyRead:
  match values:
    case tier <> party <> storage <> moves <> currency <> count <> rest:
      economy_stacks(capacity_value, tier, party, storage, moves, currency,
        item_rows(count, rest, []))
    case _: EconomyMissing{}

def read_economy(values: List<&2, Nat>) -> EconomyRead:
  match values:
    case p <> m <> s <> k <> e <> c <> rest:
      read_economy_tail(Economy.Capacity{p, m, s, k, e, c}, rest)
    case _: EconomyMissing{}

def reverse_ids(values: List<&2, Roster.IndividualId>,
  result: List<&2, Roster.IndividualId>) -> List<&2, Roster.IndividualId>:
  match values:
    case Nil{}: result
    case head <> tail: reverse_ids(tail, head <> result)

def id_rows(count: Nat, values: List<&2, Nat>,
  result: List<&2, Roster.IndividualId>) -> IdRead:
  match count:
    case 0n: IdRead{reverse_ids(result, []), values}
    case 1n+rest:
      match values:
        case id <> tail: id_rows(rest, tail, Roster.IndividualId{id} <> result)
        case Nil{}: IdMissing{}

def read_id_section(values: List<&2, Nat>) -> IdRead:
  match values:
    case count <> rest: id_rows(count, rest, [])
    case Nil{}: IdMissing{}

def roster_storage(capacity_value: Economy.Capacity,
  party: List<&2, Roster.IndividualId>, storage: IdRead) -> RosterRead:
  match storage:
    case IdMissing{}: RosterMissing{}
    case IdRead{storage_ids, rest}:
      RosterRead{Roster.Roster{capacity_value, party, storage_ids}, rest}

def roster_party(capacity_value: Economy.Capacity, party: IdRead) -> RosterRead:
  match party:
    case IdMissing{}: RosterMissing{}
    case IdRead{party_ids, after_party}:
      match after_party:
        case storage_count <> after_count:
          roster_storage(capacity_value, party_ids,
            id_rows(storage_count, after_count, []))
        case Nil{}: RosterMissing{}

def read_roster_tail(capacity_value: Economy.Capacity,
  values: List<&2, Nat>) -> RosterRead:
  match values:
    case party_count <> after_party_count:
      roster_party(capacity_value, id_rows(party_count, after_party_count, []))
    case Nil{}: RosterMissing{}

def read_roster(values: List<&2, Nat>) -> RosterRead:
  match values:
    case p <> m <> s <> k <> e <> c <> rest:
      read_roster_tail(Economy.Capacity{p, m, s, k, e, c}, rest)
    case _: RosterMissing{}

def stat_values_valid(hp: Nat, atk: Nat, defn: Nat, spa: Nat,
  spd: Nat, spe: Nat) -> Bool:
  Bool.and(Nat.is_le(hp, 4294967295n),
  Bool.and(Nat.is_le(atk, 4294967295n),
  Bool.and(Nat.is_le(defn, 4294967295n),
  Bool.and(Nat.is_le(spa, 4294967295n),
  Bool.and(Nat.is_le(spd, 4294967295n), Nat.is_le(spe, 4294967295n))))))


def stat_range(valid: Bool, hp: Nat, atk: Nat, defn: Nat, spa: Nat,
  spd: Nat, spe: Nat, rest: List<&2, Nat>) -> StatRead:
  match valid:
    case False{}: StatMissing{}
    case True{}:
      StatRead{Progression.StatBlock{U32.from_nat(hp), U32.from_nat(atk),
        U32.from_nat(defn), U32.from_nat(spa), U32.from_nat(spd),
        U32.from_nat(spe)}, rest}

def read_stat(values: List<&2, Nat>) -> StatRead:
  match values:
    case +hp <> +atk <> +defn <> +spa <> +spd <> +spe <> rest:
      stat_range(stat_values_valid(hp, atk, defn, spa, spd, spe),
        hp, atk, defn, spa, spd, spe, rest)
    case _: StatMissing{}

def reverse_u32(values: List<&2, U32>,
  result: List<&2, U32>) -> List<&2, U32>:
  match values:
    case Nil{}: result
    case head <> tail: reverse_u32(tail, head <> result)


def read_u32_values(count: Nat, values: List<&2, Nat>,
  result: List<&2, U32>) -> U32ListRead:
  match count:
    case 0n: U32ListRead{reverse_u32(result, []), values}
    case 1n+rest:
      match values:
        case Nil{}: U32ListMissing{}
        case value <> tail:
          read_u32_values(rest, tail, U32.from_nat(value) <> result)

def read_u32_list(values: List<&2, Nat>) -> U32ListRead:
  match values:
    case count <> rest: read_u32_values(count, rest, [])
    case Nil{}: U32ListMissing{}

def read_nat_values(values: List<&2, Nat>) -> NatListRead:
  match values:
    case count <> rest: read_nats(count, rest, [])
    case Nil{}: NatListMissing{}

def reverse_history(values: List<&2, Progression.MoveLearningRecord>,
  result: List<&2, Progression.MoveLearningRecord>) ->
  List<&2, Progression.MoveLearningRecord>:
  match values:
    case Nil{}: result
    case head <> tail: reverse_history(tail, head <> result)


def history_rows(count: Nat, values: List<&2, Nat>,
  result: List<&2, Progression.MoveLearningRecord>) -> HistoryRead:
  match count:
    case 0n: HistoryRead{reverse_history(result, []), values}
    case 1n+rest:
      match values:
        case tag <> tail:
          match tag:
            case 0n:
              match tail:
                case move <> after_move:
                  history_rows(rest, after_move,
                    Progression.MoveLearnedRecord{U32.from_nat(move)} <> result)
                case Nil{}: HistoryMissing{}
            case 1n:
              match tail:
                case offered <> removed <> after_removed:
                  history_rows(rest, after_removed,
                    Progression.MoveReplacedRecord{U32.from_nat(offered),
                      U32.from_nat(removed)} <> result)
                case _: HistoryMissing{}
            case 2n:
              match tail:
                case move <> after_move:
                  history_rows(rest, after_move,
                    Progression.MoveDeclinedRecord{U32.from_nat(move)} <> result)
                case Nil{}: HistoryMissing{}
            case _: HistoryMissing{}
        case Nil{}: HistoryMissing{}

def read_history(values: List<&2, Nat>) -> HistoryRead:
  match values:
    case count <> rest: history_rows(count, rest, [])
    case Nil{}: HistoryMissing{}

def individual_harmony(id: Nat, species: Nat, level: U32, xp: U32,
  hp: U32, max_hp: U32, ivs: Progression.StatBlock,
  moves: List<&2, U32>, history: List<&2, Progression.MoveLearningRecord>,
  observations: List<&2, Nat>, unlocks: List<&2, Nat>,
  harmony: U32ListRead) -> IndividualRead:
  match harmony:
    case U32ListMissing{}: IndividualMissing{}
    case U32ListRead{harmony_values, rest}:
      IndividualRead{Progression.Individual{id, species, level, xp, hp,
        max_hp, ivs, moves, history, observations, unlocks, harmony_values}, rest}

def individual_unlocks(id: Nat, species: Nat, level: U32, xp: U32,
  hp: U32, max_hp: U32, ivs: Progression.StatBlock,
  moves: List<&2, U32>, history: List<&2, Progression.MoveLearningRecord>,
  observations: List<&2, Nat>, unlocks: NatListRead) -> IndividualRead:
  match unlocks:
    case NatListMissing{}: IndividualMissing{}
    case NatListRead{unlock_values, rest}:
      individual_harmony(id, species, level, xp, hp, max_hp, ivs, moves,
        history, observations, unlock_values, read_u32_list(rest))

def individual_observations(id: Nat, species: Nat, level: U32, xp: U32,
  hp: U32, max_hp: U32, ivs: Progression.StatBlock,
  moves: List<&2, U32>, history: List<&2, Progression.MoveLearningRecord>,
  observations: NatListRead) -> IndividualRead:
  match observations:
    case NatListMissing{}: IndividualMissing{}
    case NatListRead{observation_values, rest}:
      individual_unlocks(id, species, level, xp, hp, max_hp, ivs, moves,
        history, observation_values, read_nat_values(rest))

def individual_history(id: Nat, species: Nat, level: U32, xp: U32,
  hp: U32, max_hp: U32, ivs: Progression.StatBlock,
  moves: List<&2, U32>, history: HistoryRead) -> IndividualRead:
  match history:
    case HistoryMissing{}: IndividualMissing{}
    case HistoryRead{history_values, rest}:
      individual_observations(id, species, level, xp, hp, max_hp, ivs, moves,
        history_values, read_nat_values(rest))

def individual_moves(id: Nat, species: Nat, level: U32, xp: U32,
  hp: U32, max_hp: U32, ivs: Progression.StatBlock,
  moves: U32ListRead) -> IndividualRead:
  match moves:
    case U32ListMissing{}: IndividualMissing{}
    case U32ListRead{move_values, rest}:
      individual_history(id, species, level, xp, hp, max_hp, ivs, move_values,
        read_history(rest))

def individual_with_ivs(id: Nat, species: Nat, level: U32, xp: U32,
  hp: U32, max_hp: U32, stats: StatRead) -> IndividualRead:
  match stats:
    case StatMissing{}: IndividualMissing{}
    case StatRead{ivs, rest}:
      individual_moves(id, species, level, xp, hp, max_hp, ivs,
        read_u32_list(rest))

def individual_head_ranges(valid: Bool, id: Nat, species: Nat, level: Nat,
  xp: Nat, hp: Nat, max_hp: Nat, stats: StatRead) -> IndividualRead:
  match valid:
    case False{}: IndividualMissing{}
    case True{}:
      individual_with_ivs(id, species, U32.from_nat(level), U32.from_nat(xp),
        U32.from_nat(hp), U32.from_nat(max_hp), stats)

def read_individual(values: List<&2, Nat>) -> IndividualRead:
  match values:
    case +id <> +species <> +level <> +xp <> +hp <> +max_hp <> rest:
      individual_head_ranges(Bool.and(Nat.is_le(id, 4294967295n),
        Bool.and(Nat.is_le(species, 4294967295n),
        Bool.and(Nat.is_le(level, 4294967295n),
        Bool.and(Nat.is_le(xp, 4294967295n),
        Bool.and(Nat.is_le(hp, 4294967295n),
          Nat.is_le(max_hp, 4294967295n)))))), id, species, level, xp, hp,
        max_hp, read_stat(rest))
    case _: IndividualMissing{}

def reverse_owned(values: List<&2, Rewards.OwnedRewardInput>,
  result: List<&2, Rewards.OwnedRewardInput>) ->
  List<&2, Rewards.OwnedRewardInput>:
  match values:
    case Nil{}: result
    case head <> tail: reverse_owned(tail, head <> result)

def token_bool(value: Nat) -> Bool:
  match value:
    case 0n: False{}
    case _: True{}

def owned_flags(individual_value: Progression.Individual,
  base: Progression.StatBlock, ivs: Progression.StatBlock, alive: Nat,
  active: Nat, values: List<&2, Nat>) -> OwnedOneRead:
  OwnedOneRead{Rewards.OwnedRewardInput{individual_value, base, ivs,
    token_bool(alive), token_bool(active)}, values}

def owned_ivs(individual_value: Progression.Individual,
  base: Progression.StatBlock, ivs: StatRead) -> OwnedOneRead:
  match ivs:
    case StatMissing{}: OwnedOneMissing{}
    case StatRead{ivs_value, after_ivs}:
      match after_ivs:
        case alive <> active <> rest:
          owned_flags(individual_value, base, ivs_value, alive, active, rest)
        case _: OwnedOneMissing{}

def owned_base(individual_value: Progression.Individual,
  base: StatRead) -> OwnedOneRead:
  match base:
    case StatMissing{}: OwnedOneMissing{}
    case StatRead{base_value, after_base}:
      owned_ivs(individual_value, base_value, read_stat(after_base))

def owned_individual(parsed: IndividualRead) -> OwnedOneRead:
  match parsed:
    case IndividualMissing{}: OwnedOneMissing{}
    case IndividualRead{individual_value, rest}:
      owned_base(individual_value, read_stat(rest))

def read_owned_one(values: List<&2, Nat>) -> OwnedOneRead:
  owned_individual(read_individual(values))

# The outer header caps work at 4096 tokens; each phase either consumes a
# token, consumes a complete record, or decreases the remaining record count.
@unsafe def owned_rows(step: OwnedStep) -> OwnedRead:
  match step:
    case OwnedCount{0n, values, accumulated}:
      OwnedRead{reverse_owned(accumulated, []), values}
    case OwnedCount{1n+remaining, values, accumulated}:
      owned_rows(OwnedLength{remaining, accumulated, one(values)})
    case OwnedLength{remaining, accumulated, NumberMissing{}}:
      OwnedMissing{}
    case OwnedLength{remaining, accumulated, NumberRead{length, rest}}:
      owned_rows(OwnedSplit{remaining, accumulated,
        take(length, rest, [])})
    case OwnedSplit{remaining, accumulated, SplitRejected{}}:
      OwnedMissing{}
    case OwnedSplit{remaining, accumulated, Split{record, rest}}:
      owned_rows(OwnedParsed{remaining, accumulated, rest,
        read_owned_one(record)})
    case OwnedParsed{remaining, accumulated, rest,
        OwnedOneRead{input, Nil{}}}:
      owned_rows(OwnedCount{remaining, rest, input <> accumulated})
    case OwnedParsed{remaining, accumulated, rest, parsed}:
      OwnedMissing{}

def owned_count(count: NumberRead) -> OwnedRead:
  match count:
    case NumberMissing{}: OwnedMissing{}
    case NumberRead{count, rest}:
      owned_rows(OwnedCount{count, rest, []})

def read_owned(values: List<&2, Nat>) -> OwnedRead:
  owned_count(one(values))

def identity_value(economy: Economy.State, roster: Roster.Roster,
  owned: List<&2, Rewards.OwnedRewardInput>, encounters: List<&2, Nat>,
  ruleset: Nat, identity_result: NumberRead) -> PayloadResult:
  match identity_result:
    case NumberMissing{}: PayloadMissing{}
    case NumberRead{identity, Nil{}}:
      PayloadResult{Persistent.PersistentState{economy, roster, owned,
        Progression.RewardLedger{encounters}, ruleset, identity}}
    case _: PayloadMissing{}

def identity_ruleset(economy: Economy.State, roster: Roster.Roster,
  owned: List<&2, Rewards.OwnedRewardInput>, encounters: List<&2, Nat>,
  ruleset_result: NumberRead) -> PayloadResult:
  match ruleset_result:
    case NumberMissing{}: PayloadMissing{}
    case NumberRead{ruleset, after_ruleset}:
      identity_value(economy, roster, owned, encounters, ruleset,
        one(after_ruleset))

def payload_identity(economy: Economy.State, roster: Roster.Roster,
  owned: List<&2, Rewards.OwnedRewardInput>, encounters: List<&2, Nat>,
  values: List<&2, Nat>) -> PayloadResult:
  identity_ruleset(economy, roster, owned, encounters, one(values))

def ledger_read(economy: Economy.State, roster: Roster.Roster,
  owned: List<&2, Rewards.OwnedRewardInput>, ledger: NatListRead) ->
  PayloadResult:
  match ledger:
    case NatListMissing{}: PayloadMissing{}
    case NatListRead{encounters, rest}:
      payload_identity(economy, roster, owned, encounters, rest)

def payload_ledger(economy: Economy.State, roster: Roster.Roster,
  owned: List<&2, Rewards.OwnedRewardInput>, values: List<&2, Nat>) ->
  PayloadResult:
  ledger_read(economy, roster, owned, read_nat_values(values))

def owned_payload(economy: Economy.State, roster: Roster.Roster,
  parsed: OwnedRead) -> PayloadResult:
  match parsed:
    case OwnedMissing{}: PayloadMissing{}
    case OwnedRead{owned, rest}: payload_ledger(economy, roster, owned, rest)

def read_owned_payload(economy: Economy.State, roster: Roster.Roster,
  values: List<&2, Nat>) -> PayloadResult:
  owned_payload(economy, roster, read_owned(values))

def roster_payload(economy: Economy.State,
  parsed: RosterRead) -> PayloadResult:
  match parsed:
    case RosterMissing{}: PayloadMissing{}
    case RosterRead{roster, rest}: read_owned_payload(economy, roster, rest)

def read_roster_payload(economy: Economy.State,
  values: List<&2, Nat>) -> PayloadResult:
  roster_payload(economy, read_roster(values))

def economy_payload(parsed: EconomyRead) -> PayloadResult:
  match parsed:
    case EconomyMissing{}: PayloadMissing{}
    case EconomyRead{economy, rest}: read_roster_payload(economy, rest)

def read_payload(values: List<&2, Nat>) -> PayloadResult:
  economy_payload(read_economy(values))

def token_equal(left: List<&2, Nat>, right: List<&2, Nat>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case a <> rest_a b <> rest_b:
      Bool.and(Nat.is_eq(a, b), token_equal(rest_a, rest_b))
    case _ _: False{}

def canonical_equal(state: Persistent.PersistentState, equal: Bool) ->
  DecodeResult:
  match equal:
    case False{}: DecodeRejected{}
    case True{}: DecodeAccepted{state}

def canonical_encoded(state: Persistent.PersistentState,
  tokens: List<&2, Nat>, result: Encoder.EncodeResult) -> DecodeResult:
  match result:
    case Encoder.EncodeRejected{}: DecodeRejected{}
    case Encoder.EncodeAccepted{canonical}:
      canonical_equal(state, token_equal(tokens, canonical))

def canonical_match(valid: Bool, +state: Persistent.PersistentState,
  tokens: List<&2, Nat>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}:
      canonical_encoded(state, tokens, Encoder.encode(state))

def decode_payload(result: PayloadResult, tokens: List<&2, Nat>) ->
  DecodeResult:
  match result:
    case PayloadMissing{}: DecodeRejected{}
    case PayloadResult{+state}: canonical_match(Persistent.state_valid(state), state,
      tokens)

def valid_length(valid: Bool, values: List<&2, Nat>,
  tokens: List<&2, Nat>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}: decode_payload(read_payload(values), tokens)

def length_matches(+count: Nat, +values: List<&2, Nat>,
  tokens: List<&2, Nat>) -> DecodeResult:
  valid_length(Bool.and(Nat.is_le(count, 4096n),
    Nat.is_eq(count, List.length(&2, Nat, values))), values, tokens)

def length_result(result: NumberRead, tokens: List<&2, Nat>) -> DecodeResult:
  match result:
    case NumberMissing{}: DecodeRejected{}
    case NumberRead{count, body}: length_matches(count, body, tokens)

def version_result(valid: Bool, values: List<&2, Nat>,
  tokens: List<&2, Nat>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}: length_result(one(values), tokens)

def version_is_supported(version: Nat, values: List<&2, Nat>,
  tokens: List<&2, Nat>) -> DecodeResult:
  version_result(Nat.is_eq(version, 1n), values, tokens)

def version_read(result: NumberRead,
  tokens: List<&2, Nat>) -> DecodeResult:
  match result:
    case NumberMissing{}: DecodeRejected{}
    case NumberRead{version, rest}:
      version_is_supported(version, rest, tokens)

def decode_header(+tokens: List<&2, Nat>) -> DecodeResult:
  version_read(one(tokens), tokens)

def decode(tokens: List<&2, Nat>) -> DecodeResult:
  decode_header(tokens)
