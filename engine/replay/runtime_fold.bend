import Base
import ../battle/model.bend as Model
import ../battle/runtime.bend as Runtime
import ../battle/rng.bend as Rng
import ../battle/effects.bend as Effects
import ../mixing/runtime.bend as Mixing
import ../mixing/eligibility.bend as Eligibility

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
  RuntimeReplayMixRejected{
    state: Runtime.RuntimeState,
    reason: Eligibility.MixDiagnostic
  }
  RuntimeReplayEffectRejected{
    state: Runtime.RuntimeState,
    diagnostics: List<&2, Effects.EffectDiagnostic>
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
  RuntimeFoldEffectRejected{
    state: Runtime.RuntimeState,
    diagnostics: List<&2, Effects.EffectDiagnostic>
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
    case Runtime.RuntimeRunRejected{state, diagnostics}:
      RuntimeFoldEffectRejected{state, diagnostics}
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
    case RuntimeFoldEffectRejected{state, diagnostics}:
      RuntimeFoldEffectRejected{state, diagnostics}
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
    case RuntimeFoldEffectRejected{state, diagnostics}:
      RuntimeReplayEffectRejected{state, diagnostics}
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

# Continue replay from a state whose command barrier was already accepted by
# a domain adapter such as Mixing.submit_mix. The ordinary batch API above
# remains the path for callers submitting RuntimeCommand values directly.
def run_queued(+fuel: Nat, +state: Runtime.RuntimeState) -> RuntimeReplay:
  fold_result(fold_run(Nil{}, Nil{}, fuel, Runtime.runtime_run(fuel, state)))

def finish_mixed_submit(+fuel: Nat, result: Mixing.MixSubmitResult) ->
  RuntimeReplay:
  match result:
    case Mixing.MixSubmitAccepted{state, emitted}:
      run_queued(fuel, state)
    case Mixing.MixSubmitRejected{state, reason}:
      RuntimeReplayMixRejected{state, reason}
    case Mixing.MixSubmitRuntimeRejected{state, diagnostics}:
      RuntimeReplayRejected{state, diagnostics}

# Submit one mixed command through the production eligibility and runtime
# barrier, then replay the accepted queued state through the runtime fold.
def run_mixed(+fuel: Nat, +initial: Runtime.RuntimeState,
  +request: Mixing.MixSubmitRequest,
  other_commands: List<&2, Runtime.RuntimeCommand>) -> RuntimeReplay:
  finish_mixed_submit(fuel,
    Mixing.submit_mix(fuel, initial, request, other_commands))
