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

def wait_command() -> Runtime.RuntimeCommand:
  Runtime.RuntimeWait{Battle.ActorId{1n}}

def capture_rejected(result: M7.SubmitResult) -> Bool:
  match result:
    case M7.Rejected{state, reason}: True{}
    case _: False{}

def capture_accepted(result: M7.SubmitResult) -> Bool:
  match result:
    case M7.Accepted{state, emitted}: True{}
    case _: False{}

def malformed_step_result(result: M7.StepResult) -> Bool:
  match result:
    case M7.Faulted{fault_state, reason}: True{}
    case _: False{}

def malformed_roster_step(original: M7.State) -> Bool:
  match original:
    case M7.State{runtime, economy, roster, captured, catalog}:
      match economy:
        case Economy.State{capacity, tier, party, storage, moves, currency,
            inventory}:
          malformed_step_result(M7.step(M7.State{runtime,
            Economy.State{capacity, tier, 1n+party, storage, moves, currency,
              inventory}, roster, captured, catalog}))

def malformed_roster_step_faults() -> Bool:
  malformed_roster_step(initial())

def committed_destination_result(result: Maybe<&2, Capture.Destination>) -> Bool:
  match result:
    case Some{Capture.StorageDestination{}}: True{}
    case _: False{}

def committed_destination_full_party() -> Bool:
  committed_destination_result(M7.committed_capture_destination(True{},
    Economy.State{cap(), 0n, 6n, 0n, 0n, 0n, []},
    Capture.PartyDestination{}))

def committed_destination_is_party(
  result: Maybe<&2, Capture.Destination>) -> Bool:
  match result:
    case Some{Capture.PartyDestination{}}: True{}
    case _: False{}

def committed_destination_accounts_for_prior_capture() -> Bool:
  Bool.and(committed_destination_is_party(M7.committed_capture_destination(
    True{}, Economy.State{cap(), 0n, 5n, 0n, 0n, 0n, []},
    Capture.PartyDestination{})), committed_destination_full_party())


def reserved_capture_key_exact() -> Bool:
  M7.capture_event_key_matches(5, 1n, 2n, 20n, Battle.ActorId{0n},
    3n, 0n, Battle.ActorId{0n}, 3n, 2n, 0, 5,
    Some{Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 50n, 20n,
      Battle.Windup{5}, 0}})

def reserved_capture_key_rejects_tamper() -> Bool:
  Bool.not(M7.capture_event_key_matches(5, 2n, 2n, 20n,
    Battle.ActorId{0n}, 3n, 0n, Battle.ActorId{0n}, 3n, 2n, 0, 5,
    Some{Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 50n, 20n,
      Battle.Windup{5}, 0}}))

def reserved_capture_due_uses_acceptance_time() -> Bool:
  M7.capture_event_key_matches(15, 1n, 2n, 20n, Battle.ActorId{0n},
    3n, 0n, Battle.ActorId{0n}, 3n, 2n, 10, 5,
    Some{Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 50n, 20n,
      Battle.Windup{15}, 0}})

def main() -> List<&2, Bool>:
  [capture_rejected(M7.submit(10n, initial(),
     [Runtime.RuntimeCapture{Battle.ActorId{0n}, Battle.ActorId{1n},
       Economy.ItemId{1n}, 7n, 99n, 9000, Capture.ItemMultiplier{1n, 1n},
       Capture.CaptureOther{}, 100, False{}, 0, 30, 0n}, wait_command()])),
   capture_rejected(M7.submit(10n, initial(),
     [Runtime.RuntimeCapture{Battle.ActorId{0n}, Battle.ActorId{1n},
       Economy.ItemId{1n}, 8n, 1n, 9000, Capture.ItemMultiplier{1n, 1n},
        Capture.CaptureOther{}, 100, False{}, 0, 30, 0n}, wait_command()]))]
