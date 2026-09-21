import Base
import ../battle/model.bend as Model
import ../battle/runtime.bend as Runtime
import ../battle/rng.bend as Rng

type RuntimeReplay is Data:
  RuntimeReplayFinished{
    state: Runtime.RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, Runtime.RuntimeEvent>
  }
  RuntimeReplayRejected{
    state: Runtime.RuntimeState,
    diagnostics: List<&2, Model.Diagnostic>
  }
  RuntimeReplayFault{
    state: Runtime.RuntimeState,
    reason: Maybe<&2, Rng.RngSampleResult>
  }
  RuntimeReplayFuelExhausted{
    state: Runtime.RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, Runtime.RuntimeEvent>
  }

type RuntimeFold is Data:
  RuntimeFoldActive{
    state: Runtime.RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, Runtime.RuntimeEvent>,
    fuel: Nat
  }
  RuntimeFoldFinished{
    state: Runtime.RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, Runtime.RuntimeEvent>
  }
  RuntimeFoldRejected{
    state: Runtime.RuntimeState,
    diagnostics: List<&2, Model.Diagnostic>
  }
  RuntimeFoldFault{
    state: Runtime.RuntimeState,
    reason: Maybe<&2, Rng.RngSampleResult>
  }
  RuntimeFoldExhausted{
    state: Runtime.RuntimeState,
    emitted: List<&2, Model.TransitionEvent>,
    combat_events: List<&2, Runtime.RuntimeEvent>
  }

def append_transition(
  +left: List<&2, Model.TransitionEvent>,
  +right: List<&2, Model.TransitionEvent>
) -> List<&2, Model.TransitionEvent>:
  List.append(&2, Model.TransitionEvent, left, right)

def append_combat(
  +left: List<&2, Runtime.RuntimeEvent>,
  +right: List<&2, Runtime.RuntimeEvent>
) -> List<&2, Runtime.RuntimeEvent>:
  List.append(&2, Runtime.RuntimeEvent, left, right)

def fold_run(
  +prior_emitted: List<&2, Model.TransitionEvent>,
  +prior_combat: List<&2, Runtime.RuntimeEvent>, +fuel: Nat,
  result: Runtime.RuntimeRunResult
) -> RuntimeFold:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat}:
      RuntimeFoldActive{state, append_transition(prior_emitted, emitted),
        append_combat(prior_combat, combat), fuel}
    case Runtime.RuntimeRunTerminal{state, emitted, combat}:
      RuntimeFoldFinished{state, append_transition(prior_emitted, emitted),
        append_combat(prior_combat, combat)}
    case Runtime.RuntimeRunStalled{state, emitted, combat}:
      RuntimeFoldFinished{state, append_transition(prior_emitted, emitted),
        append_combat(prior_combat, combat)}
    case Runtime.RuntimeRunYielded{state, emitted, combat}:
      RuntimeFoldExhausted{state, append_transition(prior_emitted, emitted),
        append_combat(prior_combat, combat)}
    case Runtime.RuntimeRunFault{state, reason}:
      RuntimeFoldFault{state, reason}

def fold_submit(
  prior_emitted: List<&2, Model.TransitionEvent>,
  prior_combat: List<&2, Runtime.RuntimeEvent>, +fuel: Nat,
  result: Runtime.RuntimeSubmitResult
) -> RuntimeFold:
  match result:
    case Runtime.RuntimeSubmitRejected{state, diagnostics}:
      RuntimeFoldRejected{state, diagnostics}
    case Runtime.RuntimeAccepted{state, scheduled}:
      fold_run(prior_emitted, prior_combat, fuel,
        Runtime.runtime_run(fuel, state))

def fold_one(
  current: RuntimeFold, batch: List<&2, Runtime.RuntimeCommand>
) -> RuntimeFold:
  match current:
    case RuntimeFoldActive{state, emitted, combat, +fuel}:
      fold_submit(emitted, combat, fuel,
        Runtime.runtime_submit(fuel, state, batch))
    case RuntimeFoldFinished{state, emitted, combat}:
      RuntimeFoldFinished{state, emitted, combat}
    case RuntimeFoldRejected{state, diagnostics}:
      RuntimeFoldRejected{state, diagnostics}
    case RuntimeFoldFault{state, reason}:
      RuntimeFoldFault{state, reason}
    case RuntimeFoldExhausted{state, emitted, combat}:
      RuntimeFoldExhausted{state, emitted, combat}

def fold_result(current: RuntimeFold) -> RuntimeReplay:
  match current:
    case RuntimeFoldActive{state, emitted, combat, fuel}:
      RuntimeReplayFinished{state, emitted, combat}
    case RuntimeFoldFinished{state, emitted, combat}:
      RuntimeReplayFinished{state, emitted, combat}
    case RuntimeFoldRejected{state, diagnostics}:
      RuntimeReplayRejected{state, diagnostics}
    case RuntimeFoldFault{state, reason}:
      RuntimeReplayFault{state, reason}
    case RuntimeFoldExhausted{state, emitted, combat}:
      RuntimeReplayFuelExhausted{state, emitted, combat}

def run(
  +fuel: Nat, initial: Runtime.RuntimeState,
  batches: List<&2, List<&2, Runtime.RuntimeCommand>>
) -> RuntimeReplay:
  fold_result(List.foldl(~&2, ~List<&2, Runtime.RuntimeCommand>, ~RuntimeFold,
    ~fold_one, batches, RuntimeFoldActive{initial, Nil{}, Nil{}, fuel}))
