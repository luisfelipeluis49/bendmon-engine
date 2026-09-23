import Base
import ./model.bend as MixModel
import ./ledger.bend as Ledger
import ./observation.bend as Learning
import ../battle/runtime.bend as Runtime
import ../battle/model.bend as Battle
import ../battle/effects.bend as Effects
import ../battle/rng.bend as Rng

# The runtime result is carried through unchanged alongside the updated
# battle-local learning ledger.
type DrivenRunResult is Data:
  DrivenRunResult{runtime_result: Runtime.RuntimeRunResult,
    ledger: Ledger.IndividualLedger}

# The host keeps one ledger for every persistent participant in the battle.
# All ledgers see the same ordered committed event stream; ownership checks in
# Ledger.apply_event decide which individual may gain Harmony.
type DrivenRosterResult is Data:
  DrivenRosterResult{runtime_result: Runtime.RuntimeRunResult,
    ledgers: List<&2, Ledger.IndividualLedger>}

def fold_events(+catalog: MixModel.Catalog,
  events: List<&2, Runtime.RuntimeEvent>,
  ledger: Ledger.IndividualLedger) -> Ledger.IndividualLedger:
  match events:
    case Nil{}: ledger
    case event <> rest:
      fold_events(catalog, rest, Ledger.apply_event(catalog, event, ledger))

def commit_battle_status(status: Battle.BattleStatus,
  ledger: Ledger.IndividualLedger) -> Ledger.IndividualLedger:
  match status:
    case Battle.Victory{}: Ledger.merge_terminal(Learning.Victory{}, ledger)
    case Battle.Defeat{}: Ledger.merge_terminal(Learning.Defeat{}, ledger)
    case Battle.Draw{}: Ledger.merge_terminal(Learning.Draw{}, ledger)
    case Battle.Timeout{}: Ledger.merge_terminal(Learning.Timeout{}, ledger)
    case Battle.Escaped{}: Ledger.merge_terminal(Learning.Escaped{}, ledger)
    case _: ledger

def run_boundary(catalog: MixModel.Catalog,
  state: Runtime.RuntimeState,
  emitted: List<&2, Battle.TransitionEvent>,
  +events: List<&2, Runtime.RuntimeEvent>,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  +after_events = fold_events(catalog, events, ledger)
  DrivenRunResult{Runtime.RuntimeRunBoundary{state, emitted, events},
    after_events}

def run_yielded(catalog: MixModel.Catalog,
  state: Runtime.RuntimeState,
  emitted: List<&2, Battle.TransitionEvent>,
  +events: List<&2, Runtime.RuntimeEvent>,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  +after_events = fold_events(catalog, events, ledger)
  DrivenRunResult{Runtime.RuntimeRunYielded{state, emitted, events},
    after_events}

def run_stalled(catalog: MixModel.Catalog,
  state: Runtime.RuntimeState,
  emitted: List<&2, Battle.TransitionEvent>,
  +events: List<&2, Runtime.RuntimeEvent>,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  +after_events = fold_events(catalog, events, ledger)
  DrivenRunResult{Runtime.RuntimeRunStalled{state, emitted, events},
    after_events}

def run_terminal(catalog: MixModel.Catalog,
  +state: Runtime.RuntimeState,
  emitted: List<&2, Battle.TransitionEvent>,
  +events: List<&2, Runtime.RuntimeEvent>,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  +after_events = fold_events(catalog, events, ledger)
  +merged = commit_battle_status(Runtime.runtime_status(state), after_events)
  DrivenRunResult{Runtime.RuntimeRunTerminal{state, emitted, events}, merged}

def run_rejected(state: Runtime.RuntimeState,
  diagnostics: List<&2, Effects.EffectDiagnostic>,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  DrivenRunResult{Runtime.RuntimeRunRejected{state, diagnostics}, ledger}

def run_fault(state: Runtime.RuntimeState,
  reason: Maybe<&2, Rng.RngSampleResult>,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  DrivenRunResult{Runtime.RuntimeRunFault{state, reason}, ledger}

def process_result(catalog: MixModel.Catalog,
  result: Runtime.RuntimeRunResult,
  ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat_events}:
      run_boundary(catalog, state, emitted, combat_events, ledger)
    case Runtime.RuntimeRunYielded{state, emitted, combat_events}:
      run_yielded(catalog, state, emitted, combat_events, ledger)
    case Runtime.RuntimeRunStalled{state, emitted, combat_events}:
      run_stalled(catalog, state, emitted, combat_events, ledger)
    case Runtime.RuntimeRunTerminal{state, emitted, combat_events}:
      run_terminal(catalog, state, emitted, combat_events, ledger)
    case Runtime.RuntimeRunRejected{state, diagnostics}:
      run_rejected(state, diagnostics, ledger)
    case Runtime.RuntimeRunFault{state, reason}:
      run_fault(state, reason, ledger)

# Run the ordinary runtime transaction and mirror its committed mix events
# into the caller-owned individual ledger.
def run(+fuel: Nat, +state: Runtime.RuntimeState,
  catalog: MixModel.Catalog, ledger: Ledger.IndividualLedger) -> DrivenRunResult:
  process_result(catalog, Runtime.runtime_run(fuel, state), ledger)

def process_all_events(+catalog: MixModel.Catalog,
  +events: List<&2, Runtime.RuntimeEvent>,
  ledgers: List<&2, Ledger.IndividualLedger>) ->
  List<&2, Ledger.IndividualLedger>:
  match ledgers:
    case Nil{}: Nil{}
    case ledger <> rest:
      fold_events(catalog, events, ledger) <>
        process_all_events(catalog, events, rest)

def commit_all(+status: Battle.BattleStatus,
  ledgers: List<&2, Ledger.IndividualLedger>) ->
  List<&2, Ledger.IndividualLedger>:
  match ledgers:
    case Nil{}: Nil{}
    case ledger <> rest:
      commit_battle_status(status, ledger) <> commit_all(status, rest)

def process_roster_result(catalog: MixModel.Catalog,
  result: Runtime.RuntimeRunResult,
  ledgers: List<&2, Ledger.IndividualLedger>) -> DrivenRosterResult:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, +combat_events}:
      DrivenRosterResult{
        Runtime.RuntimeRunBoundary{state, emitted, combat_events},
        process_all_events(catalog, combat_events, ledgers)}
    case Runtime.RuntimeRunYielded{state, emitted, +combat_events}:
      DrivenRosterResult{
        Runtime.RuntimeRunYielded{state, emitted, combat_events},
        process_all_events(catalog, combat_events, ledgers)}
    case Runtime.RuntimeRunStalled{state, emitted, +combat_events}:
      DrivenRosterResult{
        Runtime.RuntimeRunStalled{state, emitted, combat_events},
        process_all_events(catalog, combat_events, ledgers)}
    case Runtime.RuntimeRunTerminal{+state, emitted, +combat_events}:
      DrivenRosterResult{
        Runtime.RuntimeRunTerminal{state, emitted, combat_events},
        commit_all(Runtime.runtime_status(state),
          process_all_events(catalog, combat_events, ledgers))}
    case Runtime.RuntimeRunRejected{state, diagnostics}:
      DrivenRosterResult{Runtime.RuntimeRunRejected{state, diagnostics}, ledgers}
    case Runtime.RuntimeRunFault{state, reason}:
      DrivenRosterResult{Runtime.RuntimeRunFault{state, reason}, ledgers}

def run_roster(+fuel: Nat, +state: Runtime.RuntimeState,
  catalog: MixModel.Catalog,
  ledgers: List<&2, Ledger.IndividualLedger>) -> DrivenRosterResult:
  process_roster_result(catalog, Runtime.runtime_run(fuel, state), ledgers)
