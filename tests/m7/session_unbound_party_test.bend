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

def capacity() -> Economy.Capacity:
  Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{50, 100, 100, 100, 100, 100}

def zero_ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def owner_individual() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12, zero_ivs(), [3],
    [Progression.MoveLearnedRecord{3}], [], [], [0]}

def bench_individual() -> Progression.Individual:
  Progression.Individual{78n, 5n, 1, 0, 12, 12, zero_ivs(), [], [], [], [], [0]}

def storage_individual() -> Progression.Individual:
  Progression.Individual{79n, 6n, 1, 0, 12, 12, zero_ivs(), [], [], [], [], [0]}

def enemy_individual() -> Progression.Individual:
  Progression.Individual{88n, 9n, 1, 0, 1, 12, zero_ivs(), [], [], [], [], [0]}

def economy() -> Economy.State:
  Economy.State{capacity(), 0n, 2n, 1n, 0n, 0n, []}

def owner_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{owner_individual(), base_stats(), zero_ivs(),
    True{}, True{}}

def bench_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{bench_individual(), base_stats(), zero_ivs(),
    True{}, False{}}

def storage_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{storage_individual(), base_stats(), zero_ivs(),
    True{}, True{}}

def catalog() -> M7.CaptureCatalog:
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
    economy(),
    Roster.Roster{capacity(), [Roster.IndividualId{77n},
      Roster.IndividualId{78n}], [Roster.IndividualId{79n}]}, [], catalog()}

def context() -> Bridge.Context:
  Bridge.Context{23n, [], [owner_input(), bench_input(), storage_input()], [],
    economy(), Progression.RewardLedger{[]}}

def enemy_binding() -> Session.Enemy:
  Session.Enemy{Battle.ActorId{1n}, enemy_individual(), base_stats(),
    Progression.DefeatedReward{1, 100, 5}}

def owner_binding() -> Session.OwnerActor:
  Session.OwnerActor{Battle.ActorId{0n}, 77n, True{}}

def encounter() -> Session.State:
  Session.State{battle_state(), context(), [enemy_binding()], [owner_binding()]}

def lethal_move() -> Runtime.RuntimeCommand:
  Runtime.RuntimeMove{Battle.ActorId{0n}, Battle.ActorId{1n}, Math.MoveId{3n},
    0, 30, 60, 0n, 0n,
    Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
      Math.StageNeutral{}, 200, 100, 100, 1, 0}}

def submit() -> Session.SubmitResult:
  Session.submit(10n, encounter(), [lethal_move(),
    Runtime.RuntimeWait{Battle.ActorId{1n}}])

def victory_event(events: List<&2, Battle.TransitionEvent>) -> Bool:
  match events:
    case Nil{}: False{}
    case Battle.BattleCompleted{Battle.Victory{}, tick} <> rest: True{}
    case _ <> rest: victory_event(rest)

def updated_party_eligible(inputs: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match inputs:
    case Rewards.OwnedRewardInput{
        Progression.Individual{77n, 4n, 1, 50, 10, 12, _, [3], _, [], [], [0]},
        _, _, True{}, True{}} <>
      Rewards.OwnedRewardInput{
        Progression.Individual{78n, 5n, 1, 50, 12, 12, _, [], [], [], [], [0]},
        _, _, True{}, False{}} <>
      Rewards.OwnedRewardInput{
        Progression.Individual{79n, 6n, 1, 0, 12, 12, _, [], [], [], [], [0]},
        _, _, False{}, False{}} <> Nil{}: True{}
    case _: False{}

def victory_awards_unbound_party_not_storage(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Committed{}, state, emitted, captures}:
      match state:
        case Session.State{battle, rewards, enemies, owners}:
          match rewards:
            case Bridge.Context{23n,
                [Progression.DefeatedReward{1, 100, 5}], inputs, [],
                Economy.State{cap, 0n, 2n, 1n, 0n, 5n, []},
                Progression.RewardLedger{[23n]}}:
              Bool.and(victory_event(emitted),
                updated_party_eligible(inputs))
            case _: False{}
    case _: False{}

def check_submit(result: Session.SubmitResult) -> Bool:
  match result:
    case Session.SessionAccepted{state, emitted}:
      victory_awards_unbound_party_not_storage(Session.step(state))
    case _: False{}

def main() -> List<Bool>:
  [Session.session_valid(encounter()), check_submit(submit())]
