import Base
import ../../engine/m7/session.bend as Session
import ../../engine/m7/battle.bend as M7
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/m7/reward_bridge.bend as Bridge
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/combat_math.bend as Math
import ../../engine/capture/core.bend as Capture
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

def wild_individual(id: Nat) -> Progression.Individual:
  Progression.Individual{id, 9n, 1, 0, 1, 12, zero_ivs(), [], [], [], [], [0]}

def economy() -> Economy.State:
  Economy.State{capacity(), 0n, 1n, 0n, 0n, 0n,
    [Economy.ItemStack{Economy.ItemId{1n}, 1n}]}

def owner_input() -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{owner_individual(), base_stats(), zero_ivs(),
    True{}, True{}}

def catalog() -> M7.CaptureCatalog:
  M7.CaptureCatalog{
    [M7.SpeciesCaptureProfile{9n, 9000, 12, False{}}],
    [M7.CaptureItemProfile{Economy.ItemId{1n}, Capture.ItemMultiplier{1n, 1n}}],
    [M7.CaptureTargetBinding{Battle.ActorId{1n}, 9n},
     M7.CaptureTargetBinding{Battle.ActorId{2n}, 9n}],
    [Economy.CapacityTier{capacity()}]}

def battle_state() -> M7.State:
  M7.State{
    Runtime.RuntimeState{
      Battle.BattleState{0, 60,
        [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 10n, 100n,
           Battle.Ready{}, 0},
         Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 1n, 1n,
           Battle.Ready{}, 0},
         Battle.Actor{Battle.ActorId{2n}, Battle.Enemy{}, 10n, 1n,
           Battle.Ready{}, 0}], [], 0n, Battle.AwaitingCommands{}},
      Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0, [], [], [], [],
      None{}},
    economy(), Roster.Roster{capacity(), [Roster.IndividualId{77n}], []}, [],
    catalog()}

def context() -> Bridge.Context:
  Bridge.Context{19n, [], [owner_input()], [], economy(),
    Progression.RewardLedger{[]}}

def enemy_one() -> Session.Enemy:
  Session.Enemy{Battle.ActorId{1n}, wild_individual(88n), base_stats(),
    Progression.DefeatedReward{1, 100, 5}}

def enemy_two() -> Session.Enemy:
  Session.Enemy{Battle.ActorId{2n}, wild_individual(89n), base_stats(),
    Progression.DefeatedReward{1, 100, 5}}

def owner() -> Session.OwnerActor:
  Session.OwnerActor{Battle.ActorId{0n}, 77n, True{}}

def encounter() -> Session.State:
  Session.State{battle_state(), context(), [enemy_one(), enemy_two()], [owner()]}

def capture_command() -> Runtime.RuntimeCommand:
  Runtime.RuntimeCapture{Battle.ActorId{0n}, Battle.ActorId{1n},
    Economy.ItemId{1n}, 9n, 78n, 9000, Capture.ItemMultiplier{1n, 1n},
    Capture.CaptureSleep{}, 12, False{}, 0, 30, 0n}

def captured_encounter_submit() -> Session.SubmitResult:
  Session.submit(10n, encounter(), [capture_command(),
    Runtime.RuntimeWait{Battle.ActorId{1n}},
    Runtime.RuntimeWait{Battle.ActorId{2n}}])

def after_submit(result: Session.SubmitResult) -> Maybe<Session.State>:
  match result:
    case Session.SessionAccepted{state, emitted}: Some{state}
    case _: None{}

def saved_capture_individual(inputs: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match inputs:
    case Rewards.OwnedRewardInput{
        Progression.Individual{78n, 9n, 1, 0, 1, 12,
          Progression.StatBlock{0, 0, 0, 0, 0, 0}, [], [], [], [], [0]},
        Progression.StatBlock{50, 100, 100, 100, 100, 100},
        Progression.StatBlock{0, 0, 0, 0, 0, 0}, False{}, False{}} <> rest:
      True{}
    case _: False{}

def captured_roster_contains_new_id(roster: Roster.Roster) -> Bool:
  match roster:
    case Roster.Roster{old_capacity,
        [Roster.IndividualId{77n}, Roster.IndividualId{78n}], []}: True{}
    case _: False{}

def battle_roster(state: M7.State) -> Roster.Roster:
  match state:
    case M7.State{runtime, old_economy, roster, captured, old_catalog}: roster

def capture_enemy_binding_removed(enemies: List<&2, Session.Enemy>) -> Bool:
  match enemies:
    case [Session.Enemy{Battle.ActorId{2n},
        Progression.Individual{89n, 9n, 1, 0, 1, 12, _, [], [], [], [], [0]},
        Progression.StatBlock{50, 100, 100, 100, 100, 100},
        Progression.DefeatedReward{1, 100, 5}}]: True{}
    case _: False{}

def persisted_capture_state(state: Session.State) -> Bool:
  match state:
    case Session.State{battle, rewards, enemies, owners}:
      match rewards:
        case Bridge.Context{19n, [Progression.DefeatedReward{1, 100, 5}],
            inputs, items,
            Economy.State{cap, 0n, 2n, 0n, 0n, 0n, []},
            Progression.RewardLedger{[]}}:
          Bool.and(capture_enemy_binding_removed(enemies),
          Bool.and(saved_capture_individual(inputs),
            captured_roster_contains_new_id(battle_roster(battle))))
        case _: False{}

def followup_not_rejected(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Rejected{}, state, emitted, captures}:
      False{}
    case Session.SessionStep{status, +state, emitted, captures}:
      Session.session_valid(state)

def capture_event_succeeded(events: List<&2, M7.CaptureEvent>) -> Bool:
  match events:
    case [M7.CaptureResolved{Battle.ActorId{0n}, Battle.ActorId{1n},
        Roster.IndividualId{78n}, 9n, True{}, _, _, _}]: True{}
    case _: False{}

def capture_step_and_followup(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Advancing{}, +state, emitted, captures}:
      Bool.and(capture_event_succeeded(captures),
      Bool.and(persisted_capture_state(state),
        Bool.and(Session.session_valid(state),
          followup_not_rejected(Session.step(state)))))
    case _: False{}

def check_captured_submit(result: Maybe<Session.State>) -> Bool:
  match result:
    case Some{state}:
      capture_step_and_followup(Session.step(state))
    case None{}: False{}

def capture_survives_nonterminal_step_and_followup() -> Bool:
  check_captured_submit(after_submit(captured_encounter_submit()))

def terminal_battle() -> M7.State:
  M7.State{
    Runtime.RuntimeState{
      Battle.BattleState{0, 60,
        [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 10n, 100n,
           Battle.Ready{}, 0},
         Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 1n, 1n,
           Battle.Ready{}, 0}], [], 0n, Battle.AwaitingCommands{}},
      Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0, [], [], [], [],
      None{}},
    economy(), Roster.Roster{capacity(), [Roster.IndividualId{77n}], []}, [],
    catalog()}

def terminal_encounter() -> Session.State:
  Session.State{terminal_battle(), context(), [enemy_one()], [owner()]}

def has_victory(events: List<&2, Battle.TransitionEvent>) -> Bool:
  match events:
    case Nil{}: False{}
    case Battle.BattleCompleted{Battle.Victory{}, tick} <> rest: True{}
    case _ <> rest: has_victory(rest)

def terminal_capture_result(result: Session.StepResult) -> Bool:
  match result:
    case Session.SessionStep{Session.Committed{}, +state, emitted, captures}:
      match state:
        case Session.State{battle, +rewards, enemies, owners}:
          match rewards:
            case Bridge.Context{19n,
                [Progression.DefeatedReward{1, 100, 5}], inputs, items,
                Economy.State{cap, 0n, 2n, 0n, 0n, 5n, []},
                Progression.RewardLedger{[19n]}}:
              Bool.and(has_victory(emitted),
                Bool.and(saved_capture_individual(inputs),
                  Session.session_valid(state)))
            case _: False{}
    case _: False{}

def terminal_capture_from_submit(result: Session.SubmitResult) -> Bool:
  match result:
    case Session.SessionAccepted{state, emitted}:
      terminal_capture_result(Session.step(state))
    case _: False{}

def terminal_capture_awards_once() -> Bool:
  terminal_capture_from_submit(Session.submit(10n, terminal_encounter(),
    [capture_command(), Runtime.RuntimeWait{Battle.ActorId{1n}}]))

def main() -> List<Bool>:
  [capture_survives_nonterminal_step_and_followup()]
