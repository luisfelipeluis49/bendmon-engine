import Base
import ../battle/model.bend as Model
import ../battle/reducer.bend as Reducer
import ../battle/scheduler.bend as Scheduler
import ../battle/driver.bend as Driver

# A replay record is one complete scheduler barrier. The scheduler owns
# command ordering and validation; this adapter only folds its result through
# the reducer until the next command boundary or a terminal status.
type ReplayRun is Data:
  ReplayFinished{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  ReplayRejected{state: Model.BattleState, diagnostics: List<&2, Model.Diagnostic>}
  ReplayFuelExhausted{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}

def append_events(
  +left: List<&2, Model.TransitionEvent>,
  +right: List<&2, Model.TransitionEvent>
) -> List<&2, Model.TransitionEvent>:
  List.append(&2, Model.TransitionEvent, left, right)

def status_is_terminal(status: Model.BattleStatus) -> Bool:
  match status:
    case Model.Victory{}:
      True{}
    case Model.Defeat{}:
      True{}
    case Model.Draw{}:
      True{}
    case Model.Timeout{}:
      True{}
    case Model.Escaped{}:
      True{}
    case _:
      False{}

def status_is_boundary(status: Model.BattleStatus) -> Bool:
  match status:
    case Model.AwaitingCommands{}:
      True{}
    case _:
      status_is_terminal(status)

type DrainState is Data:
  DrainActive{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  DrainFinished{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}
  DrainExhausted{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}

def drain_advance(
  emitted: List<&2, Model.TransitionEvent>, result: Model.AdvanceResult
) -> DrainState:
  match result:
    case Model.AdvanceIdle{state}:
      DrainFinished{state, emitted}
    case Model.Advanced{next_state, step_events}:
      DrainActive{next_state, append_events(emitted, step_events)}

def drain_state(
  boundary: Bool, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> DrainState:
  match boundary:
    case True{}:
      DrainFinished{state, emitted}
    case False{}:
      drain_advance(emitted, Reducer.step(state))

def drain_one(current: DrainState, ignored: Nat) -> DrainState:
  match current:
    case DrainActive{+state, emitted}:
      match state:
        case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
            +status}:
          drain_state(status_is_boundary(status), state, emitted)
    case DrainFinished{state, emitted}:
      DrainFinished{state, emitted}
    case DrainExhausted{state, emitted}:
      DrainExhausted{state, emitted}

def drain_result(current: DrainState) -> ReplayRun:
  match current:
    case DrainActive{state, emitted}:
      ReplayFuelExhausted{state, emitted}
    case DrainFinished{state, emitted}:
      ReplayFinished{state, emitted}
    case DrainExhausted{state, emitted}:
      ReplayFuelExhausted{state, emitted}

def drain(
  +fuel: Nat, +state: Model.BattleState,
  emitted: List<&2, Model.TransitionEvent>
) -> ReplayRun:
  drain_result(List.foldl(~&2, ~Nat, ~DrainState, ~drain_one,
    List.range(fuel), DrainActive{state, emitted}))

def drive_result(result: Driver.DriveResult) -> ReplayRun:
  match result:
    case Driver.DriveBoundary{state, emitted}:
      ReplayFinished{state, emitted}
    case Driver.DriveTerminal{state, emitted}:
      ReplayFinished{state, emitted}
    case Driver.DriveStalled{state, emitted}:
      ReplayFinished{state, emitted}
    case Driver.DriveYielded{state, emitted}:
      ReplayFuelExhausted{state, emitted}

def submit_result(
  +fuel: Nat, result: Model.SubmitResult
) -> ReplayRun:
  match result:
    case Model.Rejected{state, diagnostics}:
      ReplayRejected{state, diagnostics}
    case Model.Accepted{state, emitted}:
      drive_result(Driver.run(state, fuel))

def submit_batch(
  +fuel: Nat, +state: Model.BattleState,
  commands: List<&2, Model.Command>
) -> ReplayRun:
  submit_result(fuel, Scheduler.submit(state, commands))

type FoldState is Data:
  FoldActive{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>, fuel: Nat}
  FoldRejected{state: Model.BattleState, diagnostics: List<&2, Model.Diagnostic>}
  FoldExhausted{state: Model.BattleState, emitted: List<&2, Model.TransitionEvent>}

def fold_submit(
  current: FoldState, result: ReplayRun
) -> FoldState:
  match current:
    case FoldActive{state, emitted, fuel}:
      match result:
        case ReplayFinished{next_state, step_events}:
          FoldActive{next_state, append_events(emitted, step_events), fuel}
        case ReplayRejected{rejected_state, diagnostics}:
          FoldRejected{rejected_state, diagnostics}
        case ReplayFuelExhausted{exhausted_state, step_events}:
          FoldExhausted{exhausted_state,
            append_events(emitted, step_events)}
    case FoldRejected{state, diagnostics}:
      FoldRejected{state, diagnostics}
    case FoldExhausted{state, emitted}:
      FoldExhausted{state, emitted}

def fold_active_status(
  status: Model.BattleStatus, +state: Model.BattleState,
  +emitted: List<&2, Model.TransitionEvent>, +fuel: Nat,
  batch: List<&2, Model.Command>
) -> FoldState:
  match status:
    case Model.Victory{}:
      FoldActive{state, emitted, fuel}
    case Model.Defeat{}:
      FoldActive{state, emitted, fuel}
    case Model.Draw{}:
      FoldActive{state, emitted, fuel}
    case Model.Timeout{}:
      FoldActive{state, emitted, fuel}
    case Model.Escaped{}:
      FoldActive{state, emitted, fuel}
    case _:
      fold_submit(FoldActive{state, emitted, fuel},
        submit_batch(fuel, state, batch))

def fold_one(
  current: FoldState, batch: List<&2, Model.Command>
) -> FoldState:
  match current:
    case FoldActive{+state, +emitted, +fuel}:
      match state:
        case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
            +status}:
          fold_active_status(status, state, emitted, fuel, batch)
    case FoldRejected{state, diagnostics}:
      FoldRejected{state, diagnostics}
    case FoldExhausted{state, emitted}:
      FoldExhausted{state, emitted}

def fold_result(current: FoldState) -> ReplayRun:
  match current:
    case FoldActive{state, emitted, fuel}:
      ReplayFinished{state, emitted}
    case FoldRejected{state, diagnostics}:
      ReplayRejected{state, diagnostics}
    case FoldExhausted{state, emitted}:
      ReplayFuelExhausted{state, emitted}

def fold_batches(
  +fuel: Nat, +state: Model.BattleState,
  batches: List<&2, List<&2, Model.Command>>
) -> ReplayRun:
  fold_result(List.foldl(~&2, ~List<&2, Model.Command>, ~FoldState,
    ~fold_one, batches, FoldActive{state, Nil{}, fuel}))

def run(
  +fuel: Nat, +initial: Model.BattleState,
  batches: List<&2, List<&2, Model.Command>>
) -> ReplayRun:
  fold_batches(fuel, initial, batches)
