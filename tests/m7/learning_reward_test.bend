import Base
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/progression/core.bend as Progression
import ../../engine/economy/core.bend as Economy

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{50, 100, 100, 100, 100, 100}

def zero_ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def owner() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}

def full_owner() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12, zero_ivs(),
    [3, 5, 6, 7], [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}

def owner_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{owner(), base_stats(), zero_ivs(), True{}, False{}}

def full_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{full_owner(), base_stats(), zero_ivs(), True{}, False{}}

def economy() -> Economy.State:
  Economy.State{Economy.defaults(), 0n, 0n, 0n, 0n, 0n, []}

def ledger() -> Progression.RewardLedger:
  Progression.RewardLedger{[]}

def learning() -> List<&2, Rewards.SpeciesLearning>:
  [Rewards.SpeciesLearning{4n, [Rewards.LevelMove{2, 4}]}]

def repeated_learning() -> List<&2, Rewards.SpeciesLearning>:
  [Rewards.SpeciesLearning{4n,
    [Rewards.LevelMove{2, 4}, Rewards.LevelMove{3, 4}]}]

def basic_result() -> Rewards.TransactionResult:
  Rewards.transaction_with_learning(Progression.RewardVictory{}, 81n,
    [Progression.DefeatedReward{2, 100, 5}], [owner_input()], [], economy(),
    ledger(), learning(), [])

def learned_commit(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{},
        [Progression.Individual{77n, 4n, 2, 200, 12, 14, _, [3, 4],
          [Progression.MoveLearnedRecord{3}, Progression.MoveLearnedRecord{4}],
          [8n], [9n], [2]}], _, Progression.RewardLedger{[81n]}}: 1n
    case _: 0n

def full_choice(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardChoiceRequired{+pending}:
      U32.to_nat(Bool.to_u32(Bool.and(
        Nat.is_eq(Rewards.pending_individual(pending), 77n),
        U32.is_eq(Rewards.pending_move(pending), 4))))
    case _: 0n

def full_result() -> Rewards.TransactionResult:
  Rewards.transaction_with_learning(Progression.RewardVictory{}, 82n,
    [Progression.DefeatedReward{2, 100, 5}], [full_input()], [], economy(),
    ledger(), learning(), [])

def repeated_result() -> Rewards.TransactionResult:
  Rewards.transaction_with_learning(Progression.RewardVictory{}, 86n,
    [Progression.DefeatedReward{2, 100, 5}], [full_input()], [], economy(),
    ledger(), repeated_learning(), [])

def repeated_next_level(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardChoiceRequired{pending}:
      U32.to_nat(Bool.to_u32(U32.is_eq(Rewards.pending_level(pending), 3)))
    case _: 0n

def replacement_result(pending: Rewards.PendingLearning) -> Rewards.TransactionResult:
  Rewards.resolve_learning_choice(pending, True{}, Some{3})

def replace_resolved(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{},
        [Progression.Individual{77n, 4n, 2, 200, 12, 14, _,
          [4, 5, 6, 7], _, [8n], [9n], [2]}], _, _}: 1n
    case _: 0n

def replace_pending(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardChoiceRequired{pending}:
      replace_resolved(replacement_result(pending))
    case _: 0n


def decline_result(pending: Rewards.PendingLearning) -> Rewards.TransactionResult:
  Rewards.resolve_learning_choice(pending, False{}, None{})

def decline_resolved(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{},
        [Progression.Individual{77n, 4n, 2, 200, 12, 14, _,
          [3, 5, 6, 7], history, [8n], [9n], [2]}], _, _}: 1n
    case _: 0n

def decline_pending(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardChoiceRequired{pending}:
      decline_resolved(decline_result(pending))
    case _: 0n


def stale_transaction() -> Rewards.TransactionResult:
  Rewards.transaction_with_learning(Progression.RewardVictory{}, 83n,
      [Progression.DefeatedReward{2, 100, 5}], [owner_input()], [], economy(),
      ledger(), learning(), [Rewards.LearningChoice{77n, 2, 99, True{}, Some{3}}])

def stale_choice_rejected(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{},
        [Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _, _, _, _}],
        _, Progression.RewardLedger{[]}}: 1n
    case _: 0n

def second_owner() -> Progression.Individual:
  Progression.Individual{78n, 4n, 1, 0, 10, 12, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [], [], [0]}

def second_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{second_owner(), base_stats(), zero_ivs(),
    True{}, False{}}

def multi_owner_result() -> Rewards.TransactionResult:
  Rewards.transaction_with_learning(Progression.RewardVictory{}, 84n,
    [Progression.DefeatedReward{2, 100, 5}],
    [full_input(), second_input()], [], economy(), ledger(), learning(),
    [Rewards.LearningChoice{77n, 2, 4, False{}, None{}}])

def multi_owner_one_choice(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{},
        [Progression.Individual{77n, 4n, 2, 100, hp1, max1, iv1,
          [3, 5, 6, 7], history1, observations1, unlocks1, harmony1},
         Progression.Individual{78n, 4n, 2, 100, hp2, max2, iv2,
          [3, 4], history2, observations2, unlocks2, harmony2}], economy,
        Progression.RewardLedger{[84n]}}: 1n
    case _: 0n

def unknown_owner_result() -> Rewards.TransactionResult:
  Rewards.transaction_with_learning(Progression.RewardVictory{}, 85n,
    [Progression.DefeatedReward{2, 100, 5}], [owner_input()], [], economy(),
    ledger(), learning(),
    [Rewards.LearningChoice{999n, 2, 4, False{}, None{}}])

def unknown_owner_rejected(result: Rewards.TransactionResult) -> Nat:
  match result:
    case Rewards.RewardResult{Rewards.RewardRejected{}, owned, economy,
        Progression.RewardLedger{[]}}: 1n
    case _: 0n

def main() -> List<Nat>:
  [learned_commit(basic_result()), full_choice(full_result()),
    replace_pending(full_result()), decline_pending(full_result()),
    stale_choice_rejected(stale_transaction()),
    multi_owner_one_choice(multi_owner_result()),
    unknown_owner_rejected(unknown_owner_result()),
    repeated_next_level(Rewards.transaction_with_learning(
      Progression.RewardVictory{}, 86n,
      [Progression.DefeatedReward{2, 200, 5}], [full_input()], [], economy(),
      ledger(), repeated_learning(),
      [Rewards.LearningChoice{77n, 2, 4, False{}, None{}}]))]
