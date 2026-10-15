import Base
import ./persistent_state.bend as Persistent
import ../economy/core.bend as Economy
import ../economy/roster.bend as Roster
import ../progression/core.bend as Progression
import ./rewards.bend as Rewards

def concat(left: List<&2, Nat>, right: List<&2, Nat>) -> List<&2, Nat>:
  match left:
    case Nil{}: right
    case head <> rest: head <> concat(rest, right)

# Wire v1 is [version, payload-token-count, payload...]. Every list starts with
# its element count; records have a fixed field order documented by these defs.
type EncodeResult is Data:
  EncodeAccepted{tokens: List<&2, Nat>}
  EncodeRejected{}

def bool_token(value: Bool) -> Nat:
  match value:
    case False{}: 0n
    case True{}: 1n

def capacity(value: Economy.Capacity) -> List<&2, Nat>:
  match value:
    case Economy.Capacity{party, moves, storage, stack, entries, currency}:
      [party, moves, storage, stack, entries, currency]

def stacks(rows: List<&2, Economy.ItemStack>) -> List<&2, Nat>:
  match rows:
    case Nil{}: []
    case Economy.ItemStack{Economy.ItemId{item}, quantity} <> rest:
      concat([item, quantity], stacks(rest))


def economy(value: Economy.State) -> List<&2, Nat>:
  match value:
    case Economy.State{capacity_value, tier, party, storage, moves,
        currency, +inventory}:
      concat(capacity(capacity_value), concat([tier, party, storage, moves, currency],
        concat([List.length(&2, Economy.ItemStack, inventory)], stacks(inventory))))

def ids(rows: List<&2, Roster.IndividualId>) -> List<&2, Nat>:
  match rows:
    case Nil{}: []
    case Roster.IndividualId{id} <> rest: id <> ids(rest)


def roster(value: Roster.Roster) -> List<&2, Nat>:
  match value:
    case Roster.Roster{capacity_value, +party, +storage}:
      concat(capacity(capacity_value), concat(
        [List.length(&2, Roster.IndividualId, party)], concat(ids(party), concat(
        [List.length(&2, Roster.IndividualId, storage)], ids(storage)))))

def stat_block(value: Progression.StatBlock) -> List<&2, Nat>:
  match value:
    case Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}:
      [U32.to_nat(hp), U32.to_nat(attack), U32.to_nat(defense),
        U32.to_nat(special_attack), U32.to_nat(special_defense),
        U32.to_nat(speed)]

def move_history(rows: List<&2, Progression.MoveLearningRecord>) ->
  List<&2, Nat>:
  match rows:
    case Nil{}: []
    case Progression.MoveLearnedRecord{move} <> rest:
      concat([0n, U32.to_nat(move)], move_history(rest))
    case Progression.MoveReplacedRecord{offered, removed} <> rest:
      concat([1n, U32.to_nat(offered), U32.to_nat(removed)], move_history(rest))
    case Progression.MoveDeclinedRecord{move} <> rest:
      concat([2n, U32.to_nat(move)], move_history(rest))

def u32_values(rows: List<&2, U32>) -> List<&2, Nat>:
  match rows:
    case Nil{}: []
    case value <> rest: U32.to_nat(value) <> u32_values(rest)

def nat_values(rows: List<&2, Nat>) -> List<&2, Nat>:
  rows

def u32_list(+rows: List<&2, U32>) -> List<&2, Nat>:
  List.length(&2, U32, rows) <> u32_values(rows)

def nat_list(+rows: List<&2, Nat>) -> List<&2, Nat>:
  List.length(&2, Nat, rows) <> nat_values(rows)

def individual(value: Progression.Individual) -> List<&2, Nat>:
  match value:
    case Progression.Individual{id, species, level, xp, current_hp, max_hp,
        ivs, +moves, +history, +observations, +unlocks, +harmony}:
      concat([id, species, U32.to_nat(level), U32.to_nat(xp),
          U32.to_nat(current_hp), U32.to_nat(max_hp)],
        concat(stat_block(ivs), concat(u32_list(moves),
        concat([List.length(&2, Progression.MoveLearningRecord, history)],
        concat(move_history(history), concat(nat_list(observations),
        concat(nat_list(unlocks), u32_list(harmony))))))))

def owned_record(individual_value: Progression.Individual,
  base: Progression.StatBlock, ivs: Progression.StatBlock, alive: Bool,
  previously_active: Bool) -> List<&2, Nat>:
  concat(individual(individual_value), concat(stat_block(base),
    concat(stat_block(ivs), [bool_token(alive), bool_token(previously_active)])))


def owned_rows(rows: List<&2, Rewards.OwnedRewardInput>) -> List<&2, Nat>:
  match rows:
    case Nil{}: []
    case Rewards.OwnedRewardInput{individual_value, base, ivs, alive,
        previously_active} <> rest:
      +row = owned_record(individual_value, base, ivs, alive, previously_active)
      concat(List.length(&2, Nat, row) <> row, owned_rows(rest))

def owned(+value: List<&2, Rewards.OwnedRewardInput>) -> List<&2, Nat>:
  List.length(&2, Rewards.OwnedRewardInput, value) <> owned_rows(value)

def ledger(value: Progression.RewardLedger) -> List<&2, Nat>:
  match value:
    case Progression.RewardLedger{completed_encounters}:
      nat_list(completed_encounters)

def payload(value: Persistent.PersistentState) -> List<&2, Nat>:
  match value:
    case Persistent.PersistentState{economy_value, roster_value, owned_value,
        reward_ledger, ruleset, identity}:
      concat(economy(economy_value), concat(roster(roster_value),
        concat(owned(owned_value), concat(ledger(reward_ledger),
          concat([ruleset, identity], [])))))

def encode_size(valid: Bool, +body: List<&2, Nat>) -> EncodeResult:
  match valid:
    case False{}: EncodeRejected{}
    case True{}:
      EncodeAccepted{1n <> List.length(&2, Nat, body) <> body}


def encode_body(valid: Bool, +body: List<&2, Nat>) -> EncodeResult:
  match valid:
    case False{}: EncodeRejected{}
    case True{}:
      encode_size(Nat.is_le(List.length(&2, Nat, body), 4096n), body)

def encode_valid(valid: Bool, value: Persistent.PersistentState) -> EncodeResult:
  encode_body(valid, payload(value))

def owned_inputs_valid(rows: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match rows:
    case Nil{}: True{}
    case input <> rest:
      Bool.and(Rewards.reward_input_valid(input), owned_inputs_valid(rest))

def state_valid(value: Persistent.PersistentState) -> Bool:
  match value:
    case Persistent.PersistentState{+economy_value, +roster_value, +owned_value,
        +reward_ledger, ruleset, identity}:
      Bool.and(Persistent.persistent_fields_valid(economy_value, roster_value,
        owned_value, reward_ledger), Bool.and(Nat.is_eq(ruleset, 7n),
        Nat.is_le(identity, 4294967295n)))

def encode(+value: Persistent.PersistentState) -> EncodeResult:
  encode_valid(state_valid(value), value)
