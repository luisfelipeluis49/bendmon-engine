import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/reducer.bend as Reducer

def execute_event(
  +actor: Nat, +target: Nat, damage: Nat, recoil: Nat
) -> Model.BattleEvent:
  Model.ExecuteEvent{Model.EventKey{0, 1n, 0n, 100n,
    Model.ActorId{actor}, 0n, 0n}, Model.ActorId{actor},
    Model.ActorId{target}, 30, 60, damage, recoil}

def victory_state() -> Model.BattleState:
  Model.BattleState{0, 60,
    [Model.Actor{Model.ActorId{0n}, Model.Player{}, 10n, 100n,
      Model.Windup{0}, 0},
     Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 3n, 80n,
      Model.Recovery{30}, 0}],
    [execute_event(0n, 1n, 3n, 0n)], 1n, Model.Advancing{}}

def victory_code(result: Model.AdvanceResult) -> Nat:
  match result:
    case Model.Advanced{
        Model.BattleState{0, 60, actors, Nil{}, sequence, Model.Victory{}},
        Model.BattleActionExecuted{Model.ActorId{0n}, Model.ActorId{1n},
          3n, 0n} <>
        Model.BattleCompleted{Model.Victory{}, 0} <>
        Model.BattlePendingDiscarded{0n} <> Nil{}}:
      1n
    case _:
      0n

def victory_test() -> Nat:
  victory_code(Reducer.step(victory_state()))

def draw_state() -> Model.BattleState:
  Model.BattleState{0, 60,
    [Model.Actor{Model.ActorId{0n}, Model.Player{}, 2n, 100n,
      Model.Windup{0}, 0},
     Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 3n, 80n,
      Model.Recovery{30}, 0}],
    [execute_event(0n, 1n, 3n, 2n)], 1n, Model.Advancing{}}

def draw_code(result: Model.AdvanceResult) -> Nat:
  match result:
    case Model.Advanced{
        Model.BattleState{0, 60, actors, Nil{}, sequence, Model.Draw{}},
        Model.BattleActionExecuted{Model.ActorId{0n}, Model.ActorId{1n},
          3n, 2n} <>
        Model.BattleCompleted{Model.Draw{}, 0} <>
        Model.BattlePendingDiscarded{0n} <> Nil{}}:
      1n
    case _:
      0n

def draw_test() -> Nat:
  draw_code(Reducer.step(draw_state()))

def fizzle_state() -> Model.BattleState:
  Model.BattleState{0, 60,
    [Model.Actor{Model.ActorId{0n}, Model.Player{}, 10n, 100n,
      Model.Windup{0}, 0},
     Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 0n, 80n,
      Model.Defeated{}, 0},
     Model.Actor{Model.ActorId{2n}, Model.Enemy{}, 10n, 70n,
      Model.Recovery{30}, 0}],
    [execute_event(0n, 1n, 3n, 0n)], 1n, Model.Advancing{}}

def fizzle_code(result: Model.AdvanceResult) -> Nat:
  match result:
    case Model.Advanced{
        Model.BattleState{0, 60,
          Model.Actor{Model.ActorId{0n}, player, hp, speed,
            Model.Recovery{30}, 60} <> rest,
          Model.ReadyEvent{key, Model.ActorId{0n}} <> Nil{}, 2n,
          Model.Advancing{}},
        Model.BattleActionFizzled{Model.ActorId{0n}, Model.ActorId{1n}}
          <> Nil{}}:
      1n
    case _:
      0n

def fizzle_test() -> Nat:
  fizzle_code(Reducer.step(fizzle_state()))

def defeated_ready_state() -> Model.BattleState:
  Model.BattleState{30, 60,
    [Model.Actor{Model.ActorId{0n}, Model.Player{}, 0n, 100n,
      Model.Recovery{30}, 0},
     Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 10n, 80n,
      Model.Recovery{60}, 0}],
    [Model.ReadyEvent{Model.EventKey{30, 0n, 0n, 0n,
      Model.ActorId{0n}, 0n, 0n}, Model.ActorId{0n}}],
    1n, Model.Advancing{}}

def defeated_ready_code(result: Model.AdvanceResult) -> Nat:
  match result:
    case Model.Advanced{
        Model.BattleState{30, 60,
          Model.Actor{Model.ActorId{0n}, player, 0n, speed,
            Model.Defeated{}, cooldown} <> rest,
          Nil{}, sequence, Model.AwaitingCommands{}}, emitted}:
      1n
    case _:
      0n

def defeated_ready_test() -> Nat:
  defeated_ready_code(Reducer.step(defeated_ready_state()))

def main() -> List<&2, Nat>:
  [victory_test(), draw_test(), fizzle_test(), defeated_ready_test()]

#| [1, 1, 1, 1]
