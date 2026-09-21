import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/scheduler.bend as Scheduler

def actor(id: Nat, side: Model.Side, speed: Nat) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, 10n, speed, Model.Ready{}, 0}

def recovering_actor(id: Nat, side: Model.Side, speed: Nat) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, 10n, speed, Model.Recovery{30}, 0}

def base_state() -> Model.BattleState:
  Model.BattleState{0, 60,
    [actor(0n, Model.Player{}, 90n), actor(1n, Model.Player{}, 120n),
      recovering_actor(2n, Model.Enemy{}, 80n)],
    Nil{}, 0n, Model.AwaitingCommands{}}

def wait_code(result: Model.SubmitResult) -> Nat:
  match result:
    case Model.Rejected{state, diagnostics}:
      0n
    case Model.Accepted{state,
        Model.ReadyEvent{Model.EventKey{60, 0n, priority0, speed0,
          Model.ActorId{0n}, sequence0, ordinal0}, actor0} <>
        Model.ReadyEvent{Model.EventKey{60, 0n, priority1, speed1,
          Model.ActorId{1n}, sequence1, ordinal1}, actor1} <> Nil{}}:
      1n
    case Model.Accepted{state, emitted}:
      0n

def wait_test() -> Nat:
  wait_code(Scheduler.submit(base_state(),
    [Model.BattleWait{Model.ActorId{1n}},
      Model.BattleWait{Model.ActorId{0n}}]))

def ordering_code(result: Model.SubmitResult) -> Nat:
  match result:
    case Model.Rejected{state, diagnostics}:
      0n
    case Model.Accepted{state,
        Model.ExecuteEvent{Model.EventKey{0, 1n, 0n, speed0,
          Model.ActorId{0n}, sequence0, ordinal0}, actor0, target0,
          recovery0, cooldown0, damage0, recoil0} <>
        Model.ExecuteEvent{Model.EventKey{0, 1n, 1n, speed1,
          Model.ActorId{1n}, sequence1, ordinal1}, actor1, target1,
          recovery1, cooldown1, damage1, recoil1} <> Nil{}}:
      1n
    case Model.Accepted{state, emitted}:
      0n

def ordering_test() -> Nat:
  ordering_code(Scheduler.submit(base_state(),
    [Model.BattleMove{Model.ActorId{1n}, Model.ActorId{2n}, 0, 30,
      60, 1n, 3n, 0n},
     Model.BattleMove{Model.ActorId{0n}, Model.ActorId{2n}, 0, 30,
      60, 0n, 3n, 0n}]))

def rejected_code(result: Model.SubmitResult) -> Nat:
  match result:
    case Model.Rejected{
        Model.BattleState{0, 60,
          Model.Actor{Model.ActorId{0n}, player0, hp0, speed0,
            Model.Ready{}, cooldown0} <>
          Model.Actor{Model.ActorId{1n}, player1, hp1, speed1,
            Model.Ready{}, cooldown1} <> rest,
          Nil{}, 0n, Model.AwaitingCommands{}},
        Model.IncompleteBarrier{} <> Nil{}}:
      1n
    case Model.Rejected{state, diagnostics}:
      0n
    case Model.Accepted{state, emitted}:
      0n

def rejected_test() -> Nat:
  rejected_code(Scheduler.submit(base_state(),
    [Model.BattleWait{Model.ActorId{0n}}]))

def overflow_state() -> Model.BattleState:
  Model.BattleState{215990, 30,
    [actor(0n, Model.Player{}, 90n),
      recovering_actor(1n, Model.Enemy{}, 80n)],
    Nil{}, 0n, Model.AwaitingCommands{}}

def overflow_code(result: Model.SubmitResult) -> Nat:
  match result:
    case Model.Accepted{
        Model.BattleState{215990, 30, actors,
          Model.ReadyEvent{Model.EventKey{216020, 0n, 0n, 0n,
            Model.ActorId{0n}, 0n, 0n}, Model.ActorId{0n}} <> Nil{}, 1n,
          Model.Advancing{}}, emitted}:
      1n
    case _:
      0n

def overflow_test() -> Nat:
  overflow_code(Scheduler.submit(overflow_state(),
    [Model.BattleWait{Model.ActorId{0n}}]))

def main() -> List<&2, Nat>:
  [wait_test(), ordering_test(), rejected_test(), overflow_test()]

#| [1, 1, 1, 1]
