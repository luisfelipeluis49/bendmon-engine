import Base
import ../../engine/battle/model.bend as Battle
import ../../engine/capture/core.bend as Capture
import ../../engine/economy/core.bend as Economy
import ../../engine/progression/core.bend as Progression
import ../../engine/economy/roster.bend as Roster
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/m7/reward_bridge.bend as Bridge

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{50, 100, 100, 100, 100, 100}

def zero_ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def individual() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]}

def reward_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{individual(), base_stats(), zero_ivs(),
    True{}, False{}}

def initial_economy() -> Economy.State:
  Economy.State{Economy.defaults(), 0n, 0n, 0n, 0n, 0n, []}

def context() -> Bridge.Context:
  Bridge.Context{7n, [Progression.DefeatedReward{2, 100, 5}],
    [reward_input()], [Rewards.EncounterItem{10n, 2n}], initial_economy(),
    Progression.RewardLedger{[]}}

def victory_event() -> Battle.TransitionEvent:
  Battle.BattleCompleted{Battle.Victory{}, 12}

def terminal_victory_event() -> Bridge.RewardEvent:
  Bridge.Transition{victory_event()}

def successful_capture() -> Bridge.RewardEvent:
  Bridge.CaptureSucceeded{}

def committed(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeCommitted{},
        Bridge.Context{7n, [Progression.DefeatedReward{2, 100, 5}],
          [Rewards.OwnedRewardInput{
            Progression.Individual{77n, 4n, 2, 200, 12, 14, _, [3],
              [Progression.MoveLearnedRecord{3}], [8n], [9n], [2]},
            _, _, True{}, False{}}],
          [Rewards.EncounterItem{10n, 2n}],
          Economy.State{_, 0n, 0n, 0n, 0n, 5n,
            [Economy.ItemStack{Economy.ItemId{10n}, 2n}]},
          Progression.RewardLedger{[7n]}}}: 1n
    case _: 0n

def victory_commits_once() -> Nat:
  committed(Bridge.resolve([terminal_victory_event()], context()))

def capture_terminal_result() -> Bridge.BridgeResult:
  Bridge.resolve([terminal_victory_event(), successful_capture()], context())

def capture_terminal_result_ok(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeCommitted{},
        Bridge.Context{7n, _, _, _, _, Progression.RewardLedger{[7n]}}}: 1n
    case _: 0n

def capture_commits_on_terminal_victory() -> Nat:
  capture_terminal_result_ok(capture_terminal_result())

def intermediate_capture_result() -> Bridge.BridgeResult:
  Bridge.resolve([Bridge.Transition{Battle.BattleActionExecuted{
    Battle.ActorId{1n}, Battle.ActorId{2n}, 1n, 0n}}, successful_capture()],
    context())

def intermediate_capture_result_ok(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeNotTerminal{}, unchanged}:
      match unchanged:
        case Bridge.Context{7n, _, _, _, Economy.State{_, _, _, _, _, 0n, []},
            Progression.RewardLedger{[]}}: 1n
        case _: 0n
    case _: 0n

def intermediate_capture_is_ignored() -> Nat:
  intermediate_capture_result_ok(intermediate_capture_result())

def noneligible_result(status: Battle.BattleStatus) -> Bridge.BridgeResult:
  Bridge.resolve([Bridge.Transition{Battle.BattleCompleted{status, 12}}],
    context())

def noneligible_result_ok(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeSkipped{}, unchanged}:
      match unchanged:
        case Bridge.Context{7n, _, _, _, Economy.State{_, _, _, _, _, 0n, []},
            Progression.RewardLedger{[]}}: 1n
        case _: 0n
    case _: 0n

def noneligible_is_skipped(status: Battle.BattleStatus) -> Nat:
  noneligible_result_ok(noneligible_result(status))

def duplicate_rejected_result(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeRejected{},
        Bridge.Context{7n, _, _, _,
          Economy.State{_, 0n, 0n, 0n, 0n, 5n,
            [Economy.ItemStack{Economy.ItemId{10n}, 2n}]},
          Progression.RewardLedger{[7n]}}}: 1n
    case _: 0n

def first_victory_result() -> Bridge.BridgeResult:
  Bridge.resolve([terminal_victory_event()], context())

def duplicate_first_result(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeCommitted{}, next}:
      duplicate_rejected_result(Bridge.resolve([terminal_victory_event()], next))
    case _: 0n

def duplicate_rejected() -> Nat:
  duplicate_first_result(first_victory_result())

def limited_context() -> Bridge.Context:
  +limited = {Economy.State{Economy.Capacity{6n, 4n, 1000n, 999n, 512n,
      20n}, 0n, 0n, 0n, 0n, 16n, []} : Economy.State}
  Bridge.Context{8n, [Progression.DefeatedReward{2, 100, 5}],
    [reward_input()], [Rewards.EncounterItem{10n, 2n}], limited,
    Progression.RewardLedger{[]}}

def rollback_result() -> Bridge.BridgeResult:
  Bridge.resolve([terminal_victory_event()], limited_context())

def rollback_result_ok(result: Bridge.BridgeResult) -> Nat:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeRejected{}, unchanged}:
      match unchanged:
        case Bridge.Context{8n, _,
            [Rewards.OwnedRewardInput{
              Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _,
                [8n], [9n], [2]}, _, _, True{}, False{}}], _,
            Economy.State{Economy.Capacity{6n, 4n, 1000n, 999n, 512n, 20n},
              0n, 0n, 0n, 0n, 16n, []}, Progression.RewardLedger{[]}}: 1n
        case _: 0n
    case _: 0n

def rollback_after_currency_failure() -> Nat:
  rollback_result_ok(rollback_result())

def main() -> List<Nat>:
  [victory_commits_once(), capture_commits_on_terminal_victory(),
    intermediate_capture_is_ignored(),
    noneligible_is_skipped(Battle.Defeat{}),
    noneligible_is_skipped(Battle.Draw{}),
    noneligible_is_skipped(Battle.Timeout{}),
    noneligible_is_skipped(Battle.Escaped{}),
    duplicate_rejected(), rollback_after_currency_failure()]
