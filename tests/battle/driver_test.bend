import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/driver.bend as Driver

def actor(id: Nat, side: Model.Side, phase: Model.Phase) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, 10n, 100n, phase, 0}

def stalled_code(result: Driver.DriveResult) -> Nat:
  match result:
    case Driver.DriveStalled{Model.BattleState{0, 60, actors, Nil{}, 0n,
        Model.SchedulerStalled{}}, Nil{}}:
      1n
    case _:
      0n

def timeout_code(result: Driver.DriveResult) -> Nat:
  match result:
    case Driver.DriveTerminal{Model.BattleState{216000, 60, actors, Nil{}, 0n,
        Model.Timeout{}}, Model.BattleCompleted{Model.Timeout{}, 216000} <>
        Model.BattlePendingDiscarded{1n} <> Nil{}}:
      1n
    case _:
      0n

def boundary_code(result: Driver.DriveResult) -> Nat:
  match result:
    case Driver.DriveBoundary{Model.BattleState{0, 60, actors, Nil{}, 0n,
        Model.AwaitingCommands{}}, Nil{}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  +players = {actor(0n, Model.Player{}, Model.Benched{}) <> Nil{}
    : List<&2, Model.Actor>}
  +enemies = {actor(1n, Model.Enemy{}, Model.Benched{}) <> Nil{}
    : List<&2, Model.Actor>}
  +event = {Model.ReadyEvent{Model.EventKey{216001, 0n, 0n, 0n,
    Model.ActorId{0n}, 0n, 0n}, Model.ActorId{0n}} : Model.BattleEvent}
  [stalled_code(Driver.run(Model.BattleState{0, 60,
      List.append(&2, Model.Actor, players, enemies), Nil{}, 0n,
      Model.Advancing{}}, 4n)),
   timeout_code(Driver.run(Model.BattleState{216000, 60,
      [actor(0n, Model.Player{}, Model.Recovery{216001}),
       actor(1n, Model.Enemy{}, Model.Recovery{216001})], [event], 0n,
      Model.Advancing{}}, 4n)),
   boundary_code(Driver.run(Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, Model.Ready{}),
       actor(1n, Model.Enemy{}, Model.Recovery{30})], Nil{}, 0n,
      Model.Advancing{}}, 4n))]

#| [1, 1, 1]
