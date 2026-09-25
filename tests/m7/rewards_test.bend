import Base
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/progression/core.bend as Progression
import ../../engine/economy/core.bend as Economy

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{50, 100, 100, 100, 100, 100}

def zero_ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def original_individual() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}

def participant() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{original_individual(), base_stats(), zero_ivs(),
    True{}, False{}}

def initial_economy() -> Economy.State:
  Economy.State{Economy.defaults(), 0n, 0n, 0n, 0n, 0n, []}

def initial_ledger() -> Progression.RewardLedger:
  Progression.RewardLedger{[]}

def success() -> Rewards.TransactionResult:
  Rewards.transaction(Progression.RewardVictory{}, 31n,
    [Progression.DefeatedReward{2, 100, 5}], [participant()], [],
    initial_economy(), initial_ledger())

def success_golden(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{},
        [Progression.Individual{77n, 4n, 2, 200, 12, 14,
          _, [3], [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}],
        Economy.State{_, 0n, 0n, 0n, 0n, 5n, []},
        Progression.RewardLedger{[31n]}}: 1n
    case _: 0n

def duplicate_result(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{},
        [Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _, [8n], [9n], [2]}],
        Economy.State{_, 0n, 0n, 0n, 0n, 5n, []},
        Progression.RewardLedger{[31n]}}: 1n
    case _: 0n

def duplicate_golden(first: Rewards.TransactionResult) -> Nat:
  match first:
    case Rewards.RewardResult{Rewards.RewardCommitted{}, owned, economy, ledger}:
      duplicate_result(Rewards.transaction(Progression.RewardVictory{}, 31n,
        [Progression.DefeatedReward{2, 100, 5}], [participant()], [],
        economy, ledger))
    case _: 0n

def failure_result(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{},
        [Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _, [8n], [9n], [2]}],
        Economy.State{Economy.Capacity{6n, 4n, 1000n, 1n, 1n, 20n},
          0n, 0n, 0n, 0n, 0n, []}, Progression.RewardLedger{[]}}: 1n
    case _: 0n

def failure_rollback() -> Nat:
  +limited = {Economy.State{Economy.Capacity{6n, 4n, 1000n, 1n, 1n, 20n},
    0n, 0n, 0n, 0n, 0n, []} : Economy.State}
  failure_result(Rewards.transaction(Progression.RewardVictory{}, 32n,
    [Progression.DefeatedReward{2, 100, 5}], [participant()],
    [Rewards.EncounterItem{10n, 2n}], limited, initial_ledger()))

def skipped_result(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardSkipped{},
        [Progression.Individual{77n, 4n, 1, 0, 10, 12, _, _, _, _, _, _}],
        Economy.State{_, _, _, _, _, 0n, []}, Progression.RewardLedger{[]}}: 1n
    case _: 0n

def skipped_outcome() -> Nat:
  skipped_result(Rewards.transaction(Progression.RewardDraw{}, 33n,
      [Progression.DefeatedReward{2, 100, 5}], [participant()], [],
      initial_economy(), initial_ledger()))

def multi_reward_result(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{}, _, _, _}: 1n
    case _: 0n

def multiple_rewards_commit() -> Nat:
  multi_reward_result(Rewards.transaction(Progression.RewardVictory{}, 34n,
    [Progression.DefeatedReward{2, 100, 5},
     Progression.DefeatedReward{1, 50, 7}], [participant()],
    [Rewards.EncounterItem{10n, 2n}, Rewards.EncounterItem{11n, 3n}],
    initial_economy(), initial_ledger()))

def multiple_owned_ok(owned: List<&2, Progression.Individual>) -> Bool:
  match owned:
    case [Progression.Individual{77n, 4n, 2, 250, 12, 14, _, [3],
        [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}]: True{}
    case _: False{}

def multiple_economy_ok(economy: Economy.State) -> Bool:
  match economy:
    case Economy.State{_, 0n, 0n, 0n, 0n, 12n,
        [Economy.ItemStack{Economy.ItemId{10n}, 2n},
         Economy.ItemStack{Economy.ItemId{11n}, 3n}]}: True{}
    case _: False{}

def multiple_ledger_ok(ledger: Progression.RewardLedger) -> Bool:
  match ledger:
    case Progression.RewardLedger{[34n]}: True{}
    case _: False{}

def multiple_rewards_golden(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{},
        owned, economy, ledger}:
      U32.to_nat(Bool.to_u32(Bool.and(multiple_owned_ok(owned),
        Bool.and(multiple_economy_ok(economy), multiple_ledger_ok(ledger)))))
    case _: 0n

def late_failure_result(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{},
        [Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _,
          [8n], [9n], [2]}],
        Economy.State{Economy.Capacity{6n, 4n, 1000n, 999n, 512n, 20n},
          0n, 0n, 0n, 0n, 16n, []}, Progression.RewardLedger{[]}}: 1n
    case _: 0n

def late_currency_failure_is_atomic() -> Nat:
  +economy = {Economy.State{Economy.Capacity{6n, 4n, 1000n, 999n, 512n,
    20n}, 0n, 0n, 0n, 0n, 16n, []} : Economy.State}
  late_failure_result(Rewards.transaction(Progression.RewardVictory{}, 35n,
    [Progression.DefeatedReward{2, 100, 5}], [participant()],
    [Rewards.EncounterItem{10n, 2n}], economy, initial_ledger()))

def invalid_growth_rejected(result: Rewards.TransactionResult,
  expected_max: U32) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{},
        [Progression.Individual{77n, 4n, 1, 0, 10, stored_max, _, [3],
          [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}],
        Economy.State{_, 0n, 0n, 0n, 0n, 0n, []},
        Progression.RewardLedger{[]}}:
      U32.to_nat(Bool.to_u32(U32.is_eq(stored_max, expected_max)))
    case _: 0n

def reject_ivs_mismatch() -> Nat:
  +bad_input = {Rewards.OwnedRewardInput{original_individual(), base_stats(),
    Progression.StatBlock{1, 0, 0, 0, 0, 0}, True{}, False{}} :
      Rewards.OwnedRewardInput}
  invalid_growth_rejected(Rewards.transaction(Progression.RewardVictory{},
    36n, [Progression.DefeatedReward{2, 100, 5}], [bad_input], [],
    initial_economy(), initial_ledger()), 12)

def malformed_max_individual() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 99, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}

def reject_stored_max_mismatch() -> Nat:
  +bad_input = {Rewards.OwnedRewardInput{malformed_max_individual(),
    base_stats(), zero_ivs(), True{}, False{}} : Rewards.OwnedRewardInput}
  invalid_growth_rejected(Rewards.transaction(Progression.RewardVictory{},
    37n, [Progression.DefeatedReward{2, 100, 5}], [bad_input], [],
    initial_economy(), initial_ledger()), 99)

def duplicate_owned_ids_rejected(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{},
        [first, second], Economy.State{_, 0n, 0n, 0n, 0n, 0n, []},
        Progression.RewardLedger{[]}}:
      U32.to_nat(Bool.to_u32(Bool.and(
        Nat.is_eq(Rewards.individual_id(first), 77n),
        Nat.is_eq(Rewards.individual_id(second), 77n))))
    case _: 0n

def reject_duplicate_owned_ids() -> Nat:
  duplicate_owned_ids_rejected(Rewards.transaction(Progression.RewardVictory{},
    38n, [Progression.DefeatedReward{2, 100, 5}],
    [participant(), participant()], [], initial_economy(), initial_ledger()))

def main() -> List<Nat>:
  +committed = success()
  [success_golden(committed), duplicate_golden(committed), failure_rollback(),
    skipped_outcome(), multiple_rewards_commit(),
    multiple_rewards_golden(Rewards.transaction(Progression.RewardVictory{}, 34n,
      [Progression.DefeatedReward{2, 100, 5},
       Progression.DefeatedReward{1, 50, 7}], [participant()],
      [Rewards.EncounterItem{10n, 2n}, Rewards.EncounterItem{11n, 3n}],
      initial_economy(), initial_ledger())),
    late_currency_failure_is_atomic(), reject_ivs_mismatch(),
    reject_stored_max_mismatch(), reject_duplicate_owned_ids()]
