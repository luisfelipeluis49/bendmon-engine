import Base
import ../../engine/m7/battle.bend as M7
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/rng.bend as Rng
import ../../engine/capture/core.bend as Capture
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/roster.bend as Roster

def cap() -> Economy.Capacity:
  Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}

def initial() -> M7.State:
  M7.State{
    Runtime.RuntimeState{
      Battle.BattleState{0, 60,
        [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 50n, 20n,
           Battle.Ready{}, 0},
         Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 50n, 10n,
           Battle.Ready{}, 0}], [], 0n, Battle.AwaitingCommands{}},
      Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0, [], [], [], [],
      None{}},
    Economy.State{cap(), 0n, 0n, 0n, 0n, 0n,
      [Economy.ItemStack{Economy.ItemId{1n}, 1n}]},
    Roster.Roster{cap(), [], []}, [],
    M7.CaptureCatalog{[M7.SpeciesCaptureProfile{7n, 9000, 100, False{}},
      M7.SpeciesCaptureProfile{8n, 9000, 100, False{}}],
      [M7.CaptureItemProfile{Economy.ItemId{1n},
        Capture.ItemMultiplier{1n, 1n}}],
      [M7.CaptureTargetBinding{Battle.ActorId{1n}, 7n}],
      [Economy.CapacityTier{cap()}]}}

def command() -> Runtime.RuntimeCommand:
  Runtime.RuntimeCapture{Battle.ActorId{0n}, Battle.ActorId{1n},
    Economy.ItemId{1n}, 7n, 1n, 9000, Capture.ItemMultiplier{1n, 1n},
    Capture.CaptureSleep{}, 100, False{}, 0, 30, 0n}

def wait_command() -> Runtime.RuntimeCommand:
  Runtime.RuntimeWait{Battle.ActorId{1n}}

def capture_accepted(result: M7.SubmitResult) -> Bool:
  match result:
    case M7.Accepted{state, emitted}: True{}
    case _: False{}

def capture_rejected(result: M7.SubmitResult) -> Bool:
  match result:
    case M7.Rejected{state, reason}: True{}
    case _: False{}

def captured_once(result: M7.StepResult) -> Bool:
  match result:
    case M7.Stepped{state, emitted, combat_events,
        [M7.CaptureResolved{source, target, Roster.IndividualId{id}, species, success,
          destination, chance, draw}]}:
      Bool.and(success, Bool.and(Nat.is_eq(id, 1n),
        Nat.is_eq(species, 7n)))
    case _: False{}

def capture_terminal_battle(battle: Battle.BattleState) -> Bool:
  match battle:
    case Battle.BattleState{now, wait_ticks,
        [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, hp, speed,
          phase, cooldown}], events, sequence, Battle.Victory{}}:
      True{}
    case _: False{}

def capture_terminal_and_target_removed(runtime: Runtime.RuntimeState) -> Bool:
  capture_terminal_battle(Runtime.runtime_battle(runtime))

def capture_owner_committed(state: M7.State) -> Bool:
  match state:
    case M7.State{runtime, economy, roster, captured, catalog}:
      match roster:
        case Roster.Roster{capacity, [Roster.IndividualId{1n}], []}:
          Bool.and(Nat.is_eq(List.length(&2, M7.CaptureRecord, captured), 1n),
          Bool.and(Nat.is_eq(M7.item_quantity_or_zero(Economy.find_quantity(
              Economy.inventory_of(economy), Economy.ItemId{1n})), 0n),
            capture_terminal_and_target_removed(runtime)))
        case _: False{}

def capture_draw_exact(events: List<&2, M7.CaptureEvent>) -> Bool:
  match events:
    case [M7.CaptureResolved{source, target, individual, species, success,
        destination, 6000, 1520}]:
      success
    case _: False{}

def capture_rng_value(rng: Rng.RngState) -> Bool:
  match rng:
    case Rng.RngState{7, 0, 1026, 12288}: True{}
    case _: False{}

def capture_rng_exact(state: M7.State) -> Bool:
  match state:
    case M7.State{runtime, economy, roster, captured, catalog}:
      capture_rng_value(Runtime.runtime_rng(runtime))

def capture_step_loop(+fuel: Nat, +state: M7.State,
  previous: Maybe<&2, M7.StepResult>) -> Bool:
  match fuel:
    case 0n: False{}
    case 1n+rest:
      match previous:
        case None{}:
          capture_step_loop(rest, state, Some{M7.step(state)})
        case Some{M7.Stepped{+next_state, emitted, combat_events,
            capture_events}}:
          Bool.or(Bool.and(capture_draw_exact(capture_events),
              capture_rng_exact(next_state)),
            capture_step_loop(rest, next_state, None{}))
        case Some{M7.Idle{idle_state}}:
          capture_step_loop(rest, idle_state, None{})
        case Some{M7.RejectedStep{rejected_state, diagnostics}}: False{}
        case Some{M7.Faulted{fault_state, reason}}: False{}

def submitted_capture_once(result: M7.SubmitResult) -> Bool:
  match result:
    case M7.Accepted{+state, emitted}:
      Bool.and(capture_owner_committed(M7.run(20n, state)),
        capture_step_loop(20n, state, None{}))
    case _: False{}

def submit_battle() -> M7.SubmitResult:
  M7.submit(10n, initial(), [command(), wait_command()])

def duplicate_catalog_rejected(result: M7.SubmitResult) -> Bool:
  match result:
    case M7.Rejected{state, reason}: True{}
    case _: False{}

def forged_id_rejected() -> Bool:
  capture_rejected(M7.submit(10n, initial(),
    [Runtime.RuntimeCapture{Battle.ActorId{0n}, Battle.ActorId{1n},
      Economy.ItemId{1n}, 7n, 99n, 9000, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, False{}, 0, 30, 0n}, wait_command()]))

def forged_target_species_rejected() -> Bool:
  capture_rejected(M7.submit(10n, initial(),
    [Runtime.RuntimeCapture{Battle.ActorId{0n}, Battle.ActorId{1n},
      Economy.ItemId{1n}, 8n, 1n, 9000, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, False{}, 0, 30, 0n}, wait_command()]))

def main() -> List<&2, Bool>:
  [submitted_capture_once(submit_battle())]
