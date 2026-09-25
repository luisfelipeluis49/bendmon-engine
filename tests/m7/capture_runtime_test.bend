import Base
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/model.bend as Model
import ../../engine/battle/rng.bend as Rng
import ../../engine/capture/core.bend as Capture

def fixture_battle() -> Model.BattleState:
  Model.BattleState{0, 60,
    [Model.Actor{Model.ActorId{0n}, Model.Player{}, 50n, 20n,
       Model.Ready{}, 0},
     Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 10n,
       Model.Ready{}, 0}], [], 0n, Model.Advancing{}}

def fixture_battle_with_reinforcement() -> Model.BattleState:
  Model.BattleState{0, 60,
    [Model.Actor{Model.ActorId{0n}, Model.Player{}, 50n, 20n,
       Model.Ready{}, 0},
     Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 10n,
       Model.Ready{}, 0},
     Model.Actor{Model.ActorId{2n}, Model.Enemy{}, 30n, 8n,
       Model.Benched{}, 0}], [], 0n, Model.Advancing{}}

def plan_with_chance(chance: U32) -> Runtime.RuntimeCapturePlan:
  Runtime.RuntimeCapturePlan{Model.ActorId{0n}, Model.ActorId{1n},
    Capture.PartyDestination{}, chance, 7n, 42n}

def accepted_plan(result: Runtime.RuntimeCapturePlanResult) -> Bool:
  match result:
    case Runtime.RuntimeCaptureAccepted{plan}:
      True{}
    case _:
      False{}

def rejected_plan(result: Runtime.RuntimeCapturePlanResult) -> Bool:
  match result:
    case Runtime.RuntimeCaptureRejected{reason}:
      True{}
    case _:
      False{}

def attempt_rejected(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureRejectedAtAttempt{battle, rng, item_quantity}:
      True{}
    case _:
      False{}

def success_committed(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureCommitted{battle, rng, item_quantity,
        Runtime.RuntimeCaptureSucceeded{
          Runtime.RuntimeCapturedIndividual{individual, species},
          Capture.PartyDestination{}}, draw, candidates}:
      Bool.and(Nat.is_eq(individual, 42n),
        Bool.and(Nat.is_eq(species, 7n), U32.is_eq(item_quantity, 0)))
    case _:
      False{}

def failure_committed(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureCommitted{battle, rng, item_quantity,
        Runtime.RuntimeCaptureFailed{}, draw, candidates}:
      U32.is_eq(item_quantity, 0)
    case _:
      False{}

def success_removes_target(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureCommitted{
        Model.Advanced{Model.BattleState{now, wait_ticks,
          [Model.Actor{Model.ActorId{0n}, Model.Player{}, hp, speed,
             Model.Recovery{ready_tick}, cooldown}], events, sequence,
             Model.Victory{}},
          emitted}, rng, quantity, outcome, draw, candidates}:
      True{}
    case _:
      False{}

def exact_one_draw(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureCommitted{battle,
        Rng.RngState{7, 0, 1026, 12288}, item_quantity, outcome, 1520, 1n}:
      True{}
    case _:
      False{}

def invalidated_target_preserves(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureRejectedAtAttempt{
        Model.BattleState{now, wait_ticks, actors, events, sequence, status},
        Rng.RngState{1, 2, 3, 4}, 1}:
      Nat.is_eq(List.length(&2, Model.Actor, actors), 2n)
    case _:
      False{}

def reinforcement_filled(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureCommitted{
        Model.Advanced{Model.BattleState{now, wait_ticks,
          [Model.Actor{Model.ActorId{0n}, Model.Player{}, hp, speed,
             Model.Recovery{ready_tick}, cooldown},
           Model.Actor{Model.ActorId{2n}, Model.Enemy{}, 30n, 8n,
             Model.Ready{}, _}], events, sequence, Model.Advancing{}},
          emitted}, rng, quantity,
        Runtime.RuntimeCaptureSucceeded{owned, destination}, draw, candidates}:
      True{}
    case _:
      False{}

def failed_keeps_target(result: Runtime.RuntimeCaptureTransaction) -> Bool:
  match result:
    case Runtime.RuntimeCaptureCommitted{
        Model.Advanced{Model.BattleState{now, wait_ticks, actors, events,
          sequence, status}, emitted}, rng, quantity,
        Runtime.RuntimeCaptureFailed{}, draw, candidates}:
      Nat.is_eq(List.length(&2, Model.Actor, actors), 2n)
    case _:
      False{}

def main() -> List<&2, Bool>:
  [accepted_plan(Runtime.runtime_capture_accept(True{}, False{}, False{},
      False{}, True{}, True{}, False{}, Model.ActorId{0n},
      Model.ActorId{1n}, 7n, 42n, 500, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, 50)),
   rejected_plan(Runtime.runtime_capture_accept(True{}, True{}, False{},
      False{}, True{}, True{}, True{}, Model.ActorId{0n},
      Model.ActorId{1n}, 7n, 42n, 500, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, 50)),
   invalidated_target_preserves(Runtime.runtime_capture_attempt(
      Runtime.RuntimeCapturePlan{Model.ActorId{0n}, Model.ActorId{9n},
        Capture.PartyDestination{}, 9500, 7n, 42n}, True{}, fixture_battle(),
      Rng.RngState{1, 2, 3, 4}, 1, [], 0, 30, 0n)),
   success_committed(Runtime.runtime_capture_attempt(plan_with_chance(9500),
      True{}, fixture_battle(), Rng.RngState{1, 2, 3, 4}, 1,
      [], 0, 30, 0n)),
   exact_one_draw(Runtime.runtime_capture_attempt(plan_with_chance(9500),
      True{}, fixture_battle(), Rng.RngState{1, 2, 3, 4}, 1,
      [], 0, 30, 0n)),
   success_removes_target(Runtime.runtime_capture_attempt(
      plan_with_chance(9500), True{}, fixture_battle(),
      Rng.RngState{1, 2, 3, 4}, 1, [], 0, 30, 0n)),
   reinforcement_filled(Runtime.runtime_capture_attempt(
      plan_with_chance(9500), True{}, fixture_battle_with_reinforcement(),
      Rng.RngState{1, 2, 3, 4}, 1, [], 0, 30, 0n)),
   failure_committed(Runtime.runtime_capture_attempt(plan_with_chance(100),
      True{}, fixture_battle(), Rng.RngState{1, 2, 3, 4}, 1,
      [], 0, 30, 0n)),
   failed_keeps_target(Runtime.runtime_capture_attempt(plan_with_chance(100),
      True{}, fixture_battle(), Rng.RngState{1, 2, 3, 4}, 1,
      [], 0, 30, 0n))]

#| [True, True, True, True, True, True, True, True, True]
