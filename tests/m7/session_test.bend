import Base
import ../../engine/m7/session.bend as Session
import ../../engine/m7/battle.bend as M7
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/m7/reward_bridge.bend as Bridge
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/sources.bend as Sources
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/roster.bend as Roster
import ../../engine/progression/core.bend as Progression

# The production session fixture binds a live owned battler and one wild enemy
# to the same economy, then queues a zero-windup strike that defeats the enemy.
def capacity() -> Economy.Capacity:
  Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{50, 100, 100, 100, 100, 100}

def zero_ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def owner_individual() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [], [], [0]}

def enemy_individual() -> Progression.Individual:
  Progression.Individual{88n, 9n, 1, 0, 1, 12, zero_ivs(), [], [], [], [], [0]}

def economy() -> Economy.State:
  Economy.State{capacity(), 0n, 1n, 0n, 0n, 0n, []}

def owner_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{owner_individual(), base_stats(), zero_ivs(),
    True{}, True{}}

def capture_catalog() -> M7.CaptureCatalog:
  M7.CaptureCatalog{[], [], [], [Economy.CapacityTier{capacity()}]}

def battle_state() -> M7.State:
  M7.State{
    Runtime.RuntimeState{
      Battle.BattleState{0, 60,
        [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 10n, 100n,
           Battle.Ready{}, 0},
         Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 1n, 1n,
           Battle.Ready{}, 0}], [], 0n, Battle.AwaitingCommands{}},
      Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
      [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{3n}, 0, False{}}],
      [], [], [Runtime.DefenderSnapshot{Battle.ActorId{1n},
        Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
          Math.StageNeutral{}, 100, 50, 100, 100, 1875}}], None{}},
    economy(), Roster.Roster{capacity(), [Roster.IndividualId{77n}], []}, [],
    capture_catalog()}

def rewards_context() -> Bridge.Context:
  Bridge.Context{7n, [], [owner_input()], [], economy(),
    Progression.RewardLedger{[]}}

def enemy_binding() -> Session.Enemy:
  Session.Enemy{Battle.ActorId{1n}, enemy_individual(), base_stats(),
    Progression.DefeatedReward{1, 100, 5}}

def owner_binding() -> Session.OwnerActor:
  Session.OwnerActor{Battle.ActorId{0n}, 77n, True{}}

def session_state() -> Session.State:
  Session.State{battle_state(), rewards_context(), [enemy_binding()],
    [owner_binding()]}

def lethal_move() -> Runtime.RuntimeCommand:
  Runtime.RuntimeMove{Battle.ActorId{0n}, Battle.ActorId{1n}, Math.MoveId{3n},
    0, 30, 60, 0n, 0n,
    Runtime.CombatProfile{Math.AlwaysHit{},
      Math.StageNeutral{}, Math.StageNeutral{}, 200, 100, 100, 1, 0}}

def submission() -> Session.SubmitResult:
  Session.submit(10n, session_state(), [lethal_move(),
    Runtime.RuntimeWait{Battle.ActorId{1n}}])

def queued_session(result: Session.SubmitResult) -> Maybe<Session.State>:
  match result:
    case Session.SessionAccepted{state, emitted}:
      Some{state}
    case _:
      None{}

def victory_completion(events: List<&2, Battle.TransitionEvent>) -> Bool:
  match events:
    case Nil{}: False{}
    case Battle.BattleCompleted{Battle.Victory{}, tick} <> rest: True{}
    case _ <> rest: victory_completion(rest)

def committed_state_has_rewards(state: Session.State) -> Bool:
  match state:
    case Session.State{+battle, rewards, enemies, owners}:
      match rewards:
        case Bridge.Context{7n,
            [Progression.DefeatedReward{1, 100, 5}],
            [Rewards.OwnedRewardInput{
              Progression.Individual{77n, 4n, 2, 100, 12, 14, _, [3],
                [Progression.MoveLearnedRecord{3}], [], [], [0]},
              _, _, True{}, True{}}], [],
            Economy.State{_, 0n, 1n, 0n, 0n, 5n, []},
            Progression.RewardLedger{[7n]}}: True{}
        case _: False{}

def victory_reward_committed(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Committed{}, state, emitted, captures}:
      Bool.and(victory_completion(emitted), committed_state_has_rewards(state))
    case _: False{}

def check_queued(result: Maybe<Session.State>) -> Bool:
  match result:
    case Some{state}: victory_reward_committed(Session.step(state))
    case None{}: False{}

def terminal_victory_awards_rewards() -> Bool:
  check_queued(queued_session(submission()))

def invalid_snapshot_rejected_atomically(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Rejected{}, state, emitted, captures}:
      match state:
        case Session.State{+battle, rewards, enemies, owners}:
          match rewards:
            case Bridge.Context{7n, [], [Rewards.OwnedRewardInput{
                Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _, [], [], [0]},
                _, _, True{}, True{}}], [],
                Economy.State{cap, 0n, 1n, 0n, 0n, 1n, []},
                Progression.RewardLedger{[]}}: True{}
            case _: False{}
    case _: False{}

def invalid_snapshot_is_unchanged() -> Bool:
  +invalid_rewards = {Bridge.Context{7n, [], [owner_input()], [],
    Economy.State{capacity(), 0n, 1n, 0n, 0n, 1n, []},
    Progression.RewardLedger{[]}} : Bridge.Context}
  invalid_snapshot_rejected_atomically(Session.step(
    Session.State{battle_state(), invalid_rewards, [enemy_binding()],
      [owner_binding()]}))

def submit_ok(result: Session.SubmitResult) -> Bool:
  match result:
    case Session.SessionAccepted{state, emitted}: True{}
    case _: False{}

def overflow_capacity() -> Economy.Capacity:
  Economy.Capacity{6n, 4n, 100n, 999n, 20n, 20n}

def overflow_economy() -> Economy.State:
  Economy.State{overflow_capacity(), 0n, 1n, 0n, 0n, 16n, []}

def overflow_catalog() -> M7.CaptureCatalog:
  M7.CaptureCatalog{[], [], [], [Economy.CapacityTier{overflow_capacity()}]}

def overflow_roster(original: Roster.Roster) -> Roster.Roster:
  match original:
    case Roster.Roster{old_capacity, party, storage}:
      Roster.Roster{overflow_capacity(), party, storage}

def overflow_battle(original: M7.State) -> M7.State:
  match original:
    case M7.State{runtime, old_economy, roster, captured, catalog}:
      M7.State{runtime, overflow_economy(), overflow_roster(roster), captured,
        overflow_catalog()}

def overflow_context(original: Bridge.Context) -> Bridge.Context:
  match original:
    case Bridge.Context{encounter, defeated, owned, items, old_economy, ledger}:
      Bridge.Context{encounter, defeated, owned, items, overflow_economy(), ledger}

def overflow_session_state() -> Session.State:
  Session.State{overflow_battle(battle_state()),
    overflow_context(rewards_context()), [enemy_binding()], [owner_binding()]}

def overflow_submission() -> Session.SubmitResult:
  Session.submit(10n, overflow_session_state(), [lethal_move(),
    Runtime.RuntimeWait{Battle.ActorId{1n}}])

def actors_unchanged(actors: List<&2, Battle.Actor>) -> Bool:
  match actors:
    case [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 10n, 100n,
        Battle.Windup{0}, 0},
      Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 1n, 1n,
        Battle.Recovery{60}, 0}]: True{}
    case _: False{}

def events_unchanged(events: List<&2, Battle.BattleEvent>) -> Bool:
  match events:
    case [Battle.ExecuteEvent{Battle.EventKey{0, 1n, 0n, 100n,
          Battle.ActorId{0n}, 0n, 0n}, Battle.ActorId{0n},
        Battle.ActorId{1n}, 30, 60, 0n, 0n},
      Battle.ReadyEvent{Battle.EventKey{60, 0n, 0n, 0n,
        Battle.ActorId{1n}, 1n, 0n}, Battle.ActorId{1n}}]: True{}
    case _: False{}

def runtime_unchanged(state: M7.State) -> Bool:
  match state:
    case M7.State{Runtime.RuntimeState{
        Battle.BattleState{0, 60, actors, events, 2n,
          Battle.Advancing{}}, rng, encounter, failed, sources, reservations,
        trapped, defenders, effects}, old_economy, roster, captured, catalog}:
      Bool.and(actors_unchanged(actors), events_unchanged(events))
    case _: False{}

def overflow_rollback(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Rejected{}, state, emitted, captures}:
      match state:
        case Session.State{+battle, rewards, enemies, owners}:
          match rewards:
            case Bridge.Context{7n, [],
                [Rewards.OwnedRewardInput{
                  Progression.Individual{77n, 4n, 1, 0, 10, 12, _, [3], _, [], [], [0]},
                  _, _, True{}, True{}}], [],
                Economy.State{Economy.Capacity{6n, 4n, 100n, 999n, 20n, 20n},
                  0n, 1n, 0n, 0n, 16n, []},
                Progression.RewardLedger{[]}}:
              runtime_unchanged(battle)
            case _: False{}
    case _: False{}

def check_overflow_submit(result: Session.SubmitResult) -> Bool:
  match result:
    case Session.SessionAccepted{state, emitted}:
      overflow_rollback(Session.step(state))
    case _: False{}

def late_reward_overflow_rolls_back() -> Bool:
  check_overflow_submit(overflow_submission())

def main() -> List<Bool>:
  [terminal_victory_awards_rewards()]
