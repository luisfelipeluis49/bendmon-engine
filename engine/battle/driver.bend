import Base
import ./model.bend as Model
import ./scheduler.bend as Scheduler
import ./reducer.bend as Reducer

type DriveResult is Data:
  DriveBoundary{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  DriveTerminal{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  DriveStalled{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  DriveYielded{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}

type DriveCursor is Data:
  CursorActive{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  CursorBoundary{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  CursorTerminal{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  CursorStalled{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}

def append_events(
  +left: List<&2, Model.TransitionEvent>,
  +right: List<&2, Model.TransitionEvent>
) -> List<&2, Model.TransitionEvent>:
  List.append(&2, Model.TransitionEvent, left, right)

def with_status(+state: Model.BattleState, status: Model.BattleStatus) ->
  Model.BattleState:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence, old}:
      Model.BattleState{now, wait_ticks, actors, events, next_sequence, status}

def state_actors(state: Model.BattleState) -> List<&2, Model.Actor>:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      actors

def state_tick(state: Model.BattleState) -> U32:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      now

def timeout_state(+state: Model.BattleState) -> Model.BattleState:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      Model.BattleState{216000, wait_ticks, actors, Nil{}, next_sequence,
        Model.Timeout{}}

def timeout_events(+state: Model.BattleState) -> List<&2, Model.TransitionEvent>:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      [Model.BattleCompleted{Model.Timeout{}, 216000},
       Model.BattlePendingDiscarded{List.length(&2, Model.BattleEvent, events)}]

def after_step(
  prior: List<&2, Model.TransitionEvent>, result: Model.AdvanceResult
) -> DriveCursor:
  match result:
    case Model.Advanced{state, emitted}:
      CursorActive{state, append_events(prior, emitted)}
    case Model.AdvanceIdle{state}:
      CursorActive{state, prior}

def empty_ready(
  ready: List<&2, Model.ActorId>, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match ready:
    case Nil{}:
      CursorStalled{with_status(state, Model.SchedulerStalled{}), emitted}
    case actor <> rest:
      CursorBoundary{with_status(state, Model.AwaitingCommands{}), emitted}

def empty_status(
  status: Model.BattleStatus, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match status:
    case Model.Advancing{}:
      empty_ready(Scheduler.collect_ready_ids(state_actors(state)), state,
        emitted)
    case Model.Victory{}:
      CursorTerminal{with_status(state, Model.Victory{}), emitted}
    case Model.Defeat{}:
      CursorTerminal{with_status(state, Model.Defeat{}), emitted}
    case Model.Draw{}:
      CursorTerminal{with_status(state, Model.Draw{}), emitted}
    case +other:
      CursorBoundary{with_status(state, other), emitted}

def due_check(
  within_clock: Bool, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match within_clock:
    case True{}:
      after_step(emitted, Reducer.step(state))
    case False{}:
      +terminal = timeout_state(state)
      CursorTerminal{terminal, append_events(emitted, timeout_events(state))}

def future_ready(
  ready: List<&2, Model.ActorId>, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match ready:
    case Nil{}:
      after_step(emitted, Reducer.step(state))
    case actor <> rest:
      CursorBoundary{with_status(state, Model.AwaitingCommands{}), emitted}

def due_or_boundary(
  future: Bool, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match future:
    case False{}:
      after_step(emitted, Reducer.step(state))
    case True{}:
      future_ready(Scheduler.collect_ready_ids(state_actors(state)), state,
        emitted)

def within_clock(
  valid: Bool, +due: U32, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match valid:
    case False{}:
      +terminal = timeout_state(state)
      CursorTerminal{terminal, append_events(emitted, timeout_events(state))}
    case True{}:
      due_or_boundary(U32.is_gt(due, state_tick(state)), state, emitted)

def active_events(
  events: List<&2, Model.BattleEvent>, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match events:
    case Nil{}:
      empty_status(Reducer.battle_status(state_actors(state)), state, emitted)
    case event <> rest:
      +due = Reducer.event_due(event)
      within_clock(U32.is_le(due, 216000), due, state, emitted)

def active_status(
  status: Model.BattleStatus, events: List<&2, Model.BattleEvent>,
  +state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match status:
    case Model.Advancing{}:
      active_events(events, state, emitted)
    case Model.AwaitingCommands{}:
      CursorBoundary{state, emitted}
    case Model.SchedulerStalled{}:
      CursorStalled{state, emitted}
    case _:
      CursorTerminal{state, emitted}

def active_one(
  +state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>
) -> DriveCursor:
  match state:
    case Model.BattleState{now, wait_ticks, actors, +events, next_sequence,
        +status}:
      active_status(status, events, state, emitted)

def drive_one(cursor: DriveCursor, ignored: Nat) -> DriveCursor:
  match cursor:
    case CursorActive{state, emitted}:
      active_one(state, emitted)
    case CursorBoundary{state, emitted}:
      CursorBoundary{state, emitted}
    case CursorTerminal{state, emitted}:
      CursorTerminal{state, emitted}
    case CursorStalled{state, emitted}:
      CursorStalled{state, emitted}

def drive_result(cursor: DriveCursor) -> DriveResult:
  match cursor:
    case CursorActive{state, emitted}:
      DriveYielded{state, emitted}
    case CursorBoundary{state, emitted}:
      DriveBoundary{state, emitted}
    case CursorTerminal{state, emitted}:
      DriveTerminal{state, emitted}
    case CursorStalled{state, emitted}:
      DriveStalled{state, emitted}

def run(+state: Model.BattleState, +fuel: Nat) -> DriveResult:
  drive_result(List.foldl(~&2, ~Nat, ~DriveCursor, ~drive_one,
    List.range(fuel), CursorActive{state, Nil{}}))
