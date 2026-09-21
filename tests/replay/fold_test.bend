import Base
import ../../engine/battle/model.bend as Model
import ../../engine/replay/fold.bend as Replay

def actor(id: Nat, side: Model.Side, speed: Nat) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, 10n, speed, Model.Ready{}, 0}

def base_state() -> Model.BattleState:
  Model.BattleState{0, 60,
    [actor(0n, Model.Player{}, 90n), actor(1n, Model.Enemy{}, 80n)],
    Nil{}, 0n, Model.AwaitingCommands{}}

def finished_code(result: Replay.ReplayRun) -> Nat:
  match result:
    case Replay.ReplayFinished{
        Model.BattleState{60, 60, actors, Nil{}, sequence,
          Model.AwaitingCommands{}}, emitted}:
      1n
    case _:
      0n

def rejected_code(result: Replay.ReplayRun) -> Nat:
  match result:
    case Replay.ReplayRejected{state, Model.IncompleteBarrier{} <> Nil{}}:
      1n
    case _:
      0n

def fuel_code(result: Replay.ReplayRun) -> Nat:
  match result:
    case Replay.ReplayFuelExhausted{state, emitted}:
      1n
    case _:
      0n

def finish_test() -> Nat:
  finished_code(Replay.run(16n, base_state(),
    [[Model.BattleWait{Model.ActorId{0n}},
      Model.BattleWait{Model.ActorId{1n}}]]))

def rejected_test() -> Nat:
  rejected_code(Replay.run(16n, base_state(),
    [[Model.BattleWait{Model.ActorId{0n}},
      Model.BattleWait{Model.ActorId{1n}}],
     [Model.BattleWait{Model.ActorId{0n}}]]))

def fuel_test() -> Nat:
  fuel_code(Replay.run(1n, base_state(),
    [[Model.BattleWait{Model.ActorId{0n}},
      Model.BattleWait{Model.ActorId{1n}}]]))

def terminal_extra_code(result: Replay.ReplayRun) -> Nat:
  match result:
    case Replay.ReplayFinished{Model.BattleState{0, 60, actors, Nil{}, 0n,
        Model.Victory{}}, Nil{}}:
      1n
    case _:
      0n

def terminal_extra_test() -> Nat:
  terminal_extra_code(Replay.run(16n,
    Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, 90n),
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 0n, 80n,
         Model.Defeated{}, 0}], Nil{}, 0n, Model.Victory{}},
    [[Model.BattleWait{Model.ActorId{0n}}]]))

def main() -> List<&2, Nat>:
  [finish_test(), rejected_test(), fuel_test(), terminal_extra_test()]

#| [1, 1, 1, 1]
