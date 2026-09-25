import Base
import ../battle/runtime.bend as Runtime
import ../battle/model.bend as Battle
import ../battle/reducer.bend as Reducer
import ../battle/scheduler.bend as Scheduler
import ../battle/participants.bend as Participants
import ../battle/effects.bend as Effects
import ../battle/rng.bend as Rng
import ../capture/core.bend as Capture
import ../economy/core.bend as Economy
import ../economy/roster.bend as Roster

# M7 state composes the existing battle runtime with persistent bounded
# inventory and identity ownership. Legacy M3-M6 RuntimeState constructors stay
# unchanged; the M7 public command barrier uses this wrapper state.
type CaptureRecord is Data:
  CaptureRecord{id: Roster.IndividualId, species: Nat}

type SpeciesCaptureProfile is Data:
  SpeciesCaptureProfile{species: Nat, rate: U32, max_hp: U32,
    uncapturable: Bool}

type CaptureItemProfile is Data:
  CaptureItemProfile{item: Economy.ItemId,
    multiplier: Capture.ItemMultiplier}

type CaptureTargetBinding is Data:
  CaptureTargetBinding{actor: Battle.ActorId, species: Nat}

type CaptureCatalog is Data:
  CaptureCatalog{species: List<&2, SpeciesCaptureProfile>,
    items: List<&2, CaptureItemProfile>,
    targets: List<&2, CaptureTargetBinding>,
    capacity_tiers: List<&2, Economy.CapacityTier>}

type State is Data:
  State{runtime: Runtime.RuntimeState, economy: Economy.State,
    roster: Roster.Roster, captured: List<&2, CaptureRecord>,
    capture_catalog: CaptureCatalog}

type SubmitResult is Data:
  Accepted{state: State, emitted: List<&2, Battle.BattleEvent>}
  Rejected{state: State, reason: Capture.CaptureReason}
  RuntimeRejected{state: State, diagnostics: List<&2, Battle.Diagnostic>}

type CaptureEvent is Data:
  CaptureResolved{source: Battle.ActorId, target: Battle.ActorId,
    individual: Roster.IndividualId, species: Nat, success: Bool,
    destination: Maybe<&2, Capture.Destination>, chance: U32, draw: U32}

type StepResult is Data:
  Stepped{state: State, emitted: List<&2, Battle.TransitionEvent>,
    combat_events: List<&2, Runtime.RuntimeEvent>,
    capture_events: List<&2, CaptureEvent>}
  Idle{state: State}
  RejectedStep{state: State,
    diagnostics: List<&2, Effects.EffectDiagnostic>}
  Faulted{state: State, reason: Maybe<&2, Rng.RngSampleResult>}

def capacity_equal(left: Economy.Capacity, right: Economy.Capacity) -> Bool:
  match left right:
    case Economy.Capacity{ap, am, ast, ak, ae, ac}
         Economy.Capacity{bp, bm, bst, bk, be, bc}:
      Bool.and(Nat.is_eq(ap, bp), Bool.and(Nat.is_eq(am, bm),
      Bool.and(Nat.is_eq(ast, bst), Bool.and(Nat.is_eq(ak, bk),
      Bool.and(Nat.is_eq(ae, be), Nat.is_eq(ac, bc))))))

def state_roster_valid(+economy: Economy.State, +roster: Roster.Roster) -> Bool:
  match economy roster:
    case Economy.State{+capacity, tier, party, storage, equipped_moves,
        currency, inventory}
         Roster.Roster{roster_capacity, party_ids, +storage_ids}:
      Bool.and(capacity_equal(capacity, roster_capacity),
      Bool.and(Nat.is_eq(party, List.length(&2, Roster.IndividualId,
        party_ids)),
      Bool.and(Nat.is_eq(storage, List.length(&2, Roster.IndividualId,
        storage_ids)), Roster.roster_valid(roster))))

def item_quantity_or_zero(found: Maybe<Nat>) -> Nat:
  match found:
    case None{}: 0n
    case Some{quantity}: quantity

def capture_item_available(economy: Economy.State,
  item: Economy.ItemId) -> Bool:
  Nat.is_ge(item_quantity_or_zero(Economy.find_quantity(
    Economy.inventory_of(economy), item)), 1n)

def capture_eligibility_accepted(result: Capture.CaptureEligibility) -> Bool:
  match result:
    case Capture.CaptureAccepted{destination, chance}: True{}
    case _ : False{}

def capture_party_room(economy: Economy.State) -> Bool:
  match economy:
    case Economy.State{capacity, tier, party, storage, equipped_moves,
        currency, inventory}:
      Nat.is_lt(party, Economy.party_cap(capacity))

def capture_storage_room(economy: Economy.State) -> Bool:
  match economy:
    case Economy.State{capacity, tier, party, storage, equipped_moves,
        currency, inventory}:
      Nat.is_lt(storage, Economy.storage_cap(capacity))

def capture_bool_equal(left: Bool, right: Bool) -> Bool:
  match left right:
    case True{} True{}: True{}
    case False{} False{}: True{}
    case _ _: False{}

def capture_profile_match(equal: Bool, rate: U32, max_hp: U32,
  uncapturable: Bool, profile_rate: U32, profile_hp: U32,
  profile_uncapturable: Bool) -> Bool:
  match equal:
    case True{}:
      Bool.and(U32.is_eq(rate, profile_rate),
      Bool.and(U32.is_eq(max_hp, profile_hp),
        capture_bool_equal(uncapturable, profile_uncapturable)))
    case False{}: False{}

def capture_species_valid(+species: Nat, +rate: U32, +max_hp: U32,
  +uncapturable: Bool, profiles: List<&2, SpeciesCaptureProfile>) -> Bool:
  match profiles:
    case Nil{}: False{}
    case SpeciesCaptureProfile{id, profile_rate, profile_hp, restricted}
        <> rest:
      Bool.or(capture_profile_match(Nat.is_eq(species, id), rate, max_hp,
          uncapturable, profile_rate, profile_hp, restricted),
        capture_species_valid(species, rate, max_hp, uncapturable, rest))

def multiplier_equal(left: Capture.ItemMultiplier,
  right: Capture.ItemMultiplier) -> Bool:
  match left right:
    case Capture.ItemMultiplier{an, ad} Capture.ItemMultiplier{bn, bd}:
      Bool.and(Nat.is_eq(an, bn), Nat.is_eq(ad, bd))

def capture_item_valid(+item: Economy.ItemId, +multiplier: Capture.ItemMultiplier,
  profiles: List<&2, CaptureItemProfile>) -> Bool:
  match profiles:
    case Nil{}: False{}
    case CaptureItemProfile{id, profile_multiplier} <> rest:
      Bool.or(Bool.and(Economy.item_eq(item, id),
          multiplier_equal(multiplier, profile_multiplier)),
        capture_item_valid(item, multiplier, rest))

def capture_target_valid_in_catalog(+target: Battle.ActorId, +species: Nat,
  bindings: List<&2, CaptureTargetBinding>) -> Bool:
  match bindings:
    case Nil{}: False{}
    case CaptureTargetBinding{actor, target_species} <> rest:
      Bool.or(Bool.and(Battle.ActorId.eq(target, actor),
          Nat.is_eq(species, target_species)),
        capture_target_valid_in_catalog(target, species, rest))

def capture_catalog_valid(+catalog: CaptureCatalog, +target: Battle.ActorId,
  +species: Nat, +rate: U32,
  max_hp: U32, uncapturable: Bool, item: Economy.ItemId,
  multiplier: Capture.ItemMultiplier) -> Bool:
  match catalog:
    case CaptureCatalog{species_profiles, item_profiles, targets,
        capacity_tiers}:
      Bool.and(capture_target_valid_in_catalog(target, species, targets),
      Bool.and(capture_species_valid(species, rate, max_hp, uncapturable,
          species_profiles), capture_item_valid(item, multiplier, item_profiles)))

def capture_catalog_tiers(catalog: CaptureCatalog) ->
  List<&2, Economy.CapacityTier>:
  match catalog:
    case CaptureCatalog{species_profiles, item_profiles, targets,
        capacity_tiers}:
      capacity_tiers


def roster_party(roster: Roster.Roster) -> List<&2, Roster.IndividualId>:
  match roster:
    case Roster.Roster{capacity, party, storage}: party

def roster_storage(roster: Roster.Roster) -> List<&2, Roster.IndividualId>:
  match roster:
    case Roster.Roster{capacity, party, storage}: storage

def roster_id_max(ids: List<&2, Roster.IndividualId>, maximum: Nat) -> Nat:
  match ids:
    case Nil{}: maximum
    case Roster.IndividualId{id} <> rest:
      roster_id_max(rest, Nat.max(maximum, id))

def captured_id_max(records: List<&2, CaptureRecord>, maximum: Nat) -> Nat:
  match records:
    case Nil{}: maximum
    case CaptureRecord{id, species} <> rest:
      match id:
        case Roster.IndividualId{value}:
          captured_id_max(rest, Nat.max(maximum, value))

def next_capture_id(+roster: Roster.Roster,
  records: List<&2, CaptureRecord>) -> Nat:
  +party_max = roster_id_max(roster_party(roster), 0n)
  +storage_max = roster_id_max(roster_storage(roster), party_max)
  Nat.add(1n, captured_id_max(records, storage_max))

def capture_ids_valid(+commands: List<&2, Runtime.RuntimeCommand>,
  +expected: Nat) -> Bool:
  match commands:
    case Nil{}: True{}
    case Runtime.RuntimeCapture{source, target, item, species, individual,
        rate, item_multiplier, status, max_hp, uncapturable, windup, recovery,
        priority} <> rest:
      Bool.and(Nat.is_eq(individual, expected),
        capture_ids_valid(rest, Nat.add(1n, expected)))
    case _ <> rest:
      capture_ids_valid(rest, expected)

def capture_target_found(source: Maybe<&2, Battle.Actor>,
  target: Maybe<&2, Battle.Actor>) -> Bool:
  match source target:
    case Some{source_actor} Some{target_actor}:
      Scheduler.target_ok(source_actor, target_actor)
    case _ _:
      False{}

def capture_target_valid(source: Battle.ActorId, target: Battle.ActorId,
  +battle: Battle.BattleState) -> Bool:
  capture_target_found(Scheduler.find_actor(source,
      Reducer.state_actors(battle)),
    Scheduler.find_actor(target, Reducer.state_actors(battle)))

def capture_command_eligible_wild(source: Battle.ActorId,
  +target: Battle.ActorId, +item: Economy.ItemId, +species: Nat,
  +individual: Nat, +rate: U32, +multiplier: Capture.ItemMultiplier,
  status: Capture.Status, +max_hp: U32, +uncapturable: Bool,
  +battle: Battle.BattleState, +economy: Economy.State,
  +roster: Roster.Roster, +catalog: CaptureCatalog) -> Bool:
  +target_hp = U32.from_nat(Runtime.runtime_capture_target_hp(target, battle))
  +target_live = capture_target_valid(source, target, battle)
  +unique = Bool.not(Roster.id_in(roster_party(roster),
      Roster.IndividualId{individual}))
  unique = Bool.and(unique, Bool.not(Roster.id_in(roster_storage(roster),
      Roster.IndividualId{individual})))
  Bool.and(state_roster_valid(economy, roster),
    Bool.and(target_live,
    Bool.and(unique,
    Bool.and(Bool.not(uncapturable),
    Bool.and(capture_catalog_valid(catalog, target, species, rate, max_hp,
      uncapturable, item, multiplier),
    capture_eligibility_accepted(Capture.plan_capture(False{}, False{},
      uncapturable, capture_item_available(economy, item),
      capture_party_room(economy), capture_storage_room(economy), rate,
      multiplier, status, max_hp, target_hp)))))))

def capture_command_eligible(command: Runtime.RuntimeCommand,
  runtime: Runtime.RuntimeState, economy: Economy.State,
  roster: Roster.Roster, catalog: CaptureCatalog) -> Bool:
  match command:
    case Runtime.RuntimeCapture{source, target, item, species, individual,
        rate, item_multiplier, status, max_hp, uncapturable, windup, recovery,
        priority}:
      match runtime:
        case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
            reservations, trapped, defenders, effects}:
          match encounter:
            case Runtime.WildEncounter{}:
              capture_command_eligible_wild(source, target, item, species,
                individual, rate, item_multiplier, status, max_hp,
                uncapturable, battle, economy, roster, catalog)
            case _:
              False{}
    case _:
      True{}

def capture_item_increment(equal: Bool) -> Nat:
  match equal:
    case True{}: 1n
    case False{}: 0n

def capture_item_requests(commands: List<&2, Runtime.RuntimeCommand>,
  +wanted: Economy.ItemId) -> Nat:
  match commands:
    case Nil{}: 0n
    case Runtime.RuntimeCapture{source, target, item, species, individual,
        rate, item_multiplier, status, max_hp, uncapturable, windup, recovery,
        priority} <> rest:
      Nat.add(capture_item_increment(Economy.item_eq(item, wanted)),
        capture_item_requests(rest, wanted))
    case _ <> rest:
      capture_item_requests(rest, wanted)

def capture_request_count(commands: List<&2, Runtime.RuntimeCommand>) -> Nat:
  match commands:
    case Nil{}: 0n
    case Runtime.RuntimeCapture{source, target, item, species, individual,
        rate, item_multiplier, status, max_hp, uncapturable, windup, recovery,
        priority} <> rest:
      Nat.add(1n, capture_request_count(rest))
    case _ <> rest:
      capture_request_count(rest)

def item_batch_fits(+commands: List<&2, Runtime.RuntimeCommand>,
  +inventory: List<&2, Economy.ItemStack>) -> Bool:
  match commands:
    case Nil{}: True{}
    case Runtime.RuntimeCapture{source, target, item, species, individual,
        rate, item_multiplier, status, max_hp, uncapturable, windup, recovery,
        priority} <> rest:
      Bool.and(Nat.is_le(capture_item_requests(commands, item),
          item_quantity_or_zero(Economy.find_quantity(inventory, item))),
        item_batch_fits(rest, inventory))
    case _ <> rest:
      item_batch_fits(rest, inventory)

def free_capture_slots(economy: Economy.State) -> Nat:
  match economy:
    case Economy.State{+capacity, tier, party, storage, equipped_moves,
        currency, inventory}:
      Nat.add(Nat.sub(Economy.party_cap(capacity), party),
        Nat.sub(Economy.storage_cap(capacity), storage))

def capture_commands_individually_eligible(
  commands: List<&2, Runtime.RuntimeCommand>, +runtime: Runtime.RuntimeState,
  +economy: Economy.State, +roster: Roster.Roster,
  +catalog: CaptureCatalog) -> Bool:
  match commands:
    case Nil{}: True{}
    case command <> rest:
      Bool.and(capture_command_eligible(command, runtime, economy, roster,
        catalog),
        capture_commands_individually_eligible(rest, runtime, economy,
          roster, catalog))

def capture_batch_eligible(+commands: List<&2, Runtime.RuntimeCommand>,
  runtime: Runtime.RuntimeState, +economy: Economy.State,
  +roster: Roster.Roster, +captured: List<&2, CaptureRecord>,
  +catalog: CaptureCatalog) -> Bool:
  match economy:
    case Economy.State{capacity, tier, party, storage, equipped_moves,
        currency, inventory}:
      Bool.and(state_roster_valid(economy, roster),
      Bool.and(Economy.state_matches_tiers(economy,
        capture_catalog_tiers(catalog)),
      Bool.and(Nat.is_le(capture_request_count(commands),
        free_capture_slots(economy)),
      Bool.and(capture_ids_valid(commands, next_capture_id(roster, captured)),
      Bool.and(item_batch_fits(commands, inventory),
        capture_commands_individually_eligible(commands, runtime, economy,
          roster, catalog))))))

def submit_result(result: Runtime.RuntimeSubmitResult, +original: State) ->
  SubmitResult:
  match result:
    case Runtime.RuntimeAccepted{state, emitted}:
      match original:
        case State{old_runtime, +economy, +roster, captured,
            capture_catalog}:
          Accepted{State{state, economy, roster, captured, capture_catalog},
            emitted}
    case Runtime.RuntimeSubmitRejected{state, diagnostics}:
      RuntimeRejected{original, diagnostics}

def submit_checked(eligible: Bool, +fuel: Nat, +original: State,
  commands: List<&2, Runtime.RuntimeCommand>) -> SubmitResult:
  match eligible:
    case False{}:
      Rejected{original, Capture.NoDestination{}}
    case True{}:
      match original:
        case State{runtime, economy, roster, captured, capture_catalog}:
          submit_result(Runtime.runtime_submit(fuel, runtime, commands),
            original)

def submit(+fuel: Nat, +original: State,
  +commands: List<&2, Runtime.RuntimeCommand>) -> SubmitResult:
  match original:
    case State{runtime, +economy, +roster, captured, capture_catalog}:
      submit_checked(capture_batch_eligible(commands, runtime, economy,
        roster, captured, capture_catalog), fuel, original, commands)

type OwnerUpdate is Data:
  OwnerApplied{economy: Economy.State, roster: Roster.Roster,
    captured: List<&2, CaptureRecord>}
  OwnerRejected{}

def owner_capture_roster(result: Roster.RosterResult,
  economy: Economy.State, +captured: List<&2, CaptureRecord>,
  id: Roster.IndividualId, species: Nat) -> OwnerUpdate:
  match result:
    case Roster.RosterRejected{roster, reason}:
      OwnerRejected{}
    case Roster.RosterAccepted{roster}:
      OwnerApplied{economy, roster, CaptureRecord{id, species} <> captured}

def owner_capture_success(result: Economy.Transaction,
  original_roster: Roster.Roster, +captured: List<&2, CaptureRecord>,
  +id: Roster.IndividualId, species: Nat) -> OwnerUpdate:
  match result:
    case Economy.Rejected{state, reason}:
      OwnerRejected{}
    case Economy.Accepted{state}:
      owner_capture_roster(Roster.capture(original_roster, id), state,
        captured, id, species)

def owner_capture_failure(economy: Economy.State, roster: Roster.Roster,
  captured: List<&2, CaptureRecord>) -> OwnerUpdate:
  OwnerApplied{economy, roster, captured}

def owner_capture_after_item(success: Bool, result: Economy.Transaction,
  roster: Roster.Roster, captured: List<&2, CaptureRecord>,
  id: Roster.IndividualId, species: Nat) -> OwnerUpdate:
  match success:
    case False{}:
      match result:
        case Economy.Rejected{state, reason}: OwnerRejected{}
        case Economy.Accepted{state}:
          owner_capture_failure(state, roster, captured)
    case True{}:
      match result:
        case Economy.Rejected{state, reason}: OwnerRejected{}
        case Economy.Accepted{state}:
          owner_capture_success(Economy.route_captured(state), roster,
            captured, id, species)

def owner_capture_update(success: Bool, economy: Economy.State,
  roster: Roster.Roster, captured: List<&2, CaptureRecord>,
  item: Economy.ItemId, id: Roster.IndividualId, species: Nat) -> OwnerUpdate:
  owner_capture_after_item(success,
    Economy.apply_item(economy, item, 1n, False{}, Economy.ItemNotFound{}),
    roster, captured, id, species)

def capture_event(success: Bool, source: Battle.ActorId,
  target: Battle.ActorId, id: Roster.IndividualId, species: Nat,
  destination: Maybe<&2, Capture.Destination>, chance: U32, draw: U32) ->
  CaptureEvent:
  CaptureResolved{source, target, id, species, success, destination,
    chance, draw}

def capture_destination(success: Bool,
  destination: Capture.Destination) -> Maybe<&2, Capture.Destination>:
  match success:
    case True{}: Some{destination}
    case False{}: None{}

def capture_actual_destination(party_room: Bool, storage_room: Bool,
  fallback: Capture.Destination) -> Capture.Destination:
  match party_room storage_room:
    case True{} _: Capture.PartyDestination{}
    case False{} True{}: Capture.StorageDestination{}
    case False{} False{}: fallback

def capture_actual_destination_from_state(economy: Economy.State,
  fallback: Capture.Destination) -> Capture.Destination:
  match economy:
    case Economy.State{Economy.Capacity{party_limit, moves_limit,
        storage_limit, stack_limit, entry_limit, currency_limit}, tier,
        party, storage, equipped_moves,
        currency, inventory}:
      capture_actual_destination(Nat.is_lt(party, party_limit),
        Nat.is_lt(storage, storage_limit), fallback)

def committed_capture_destination(success: Bool, economy: Economy.State,
  fallback: Capture.Destination) -> Maybe<&2, Capture.Destination>:
  match success:
    case False{}: None{}
    case True{}:
      Some{capture_actual_destination_from_state(economy, fallback)}

def capture_plan_for_attempt(result: Capture.CaptureEligibility,
  source: Battle.ActorId, target: Battle.ActorId, species: Nat,
  individual: Nat) -> Maybe<Runtime.RuntimeCapturePlan>:
  match result:
    case Capture.CaptureRejected{reason}: None{}
    case Capture.CaptureAccepted{+destination, +chance}:
      Some{Runtime.RuntimeCapturePlan{source, target, destination, chance,
        species, individual}}

def owner_update_state(update: OwnerUpdate, original: State,
  next_runtime: Runtime.RuntimeState) -> Maybe<State>:
  match update:
    case OwnerRejected{}:
      None{}
    case OwnerApplied{economy, roster, captured}:
      match original:
        case State{runtime, old_economy, old_roster, old_captured,
            capture_catalog}:
          Some{State{next_runtime, economy, roster, captured, capture_catalog}}

def capture_commit_owner_state(owner_state: Maybe<State>, +original: State,
  emitted: List<&2, Battle.TransitionEvent>, source: Battle.ActorId,
  target: Battle.ActorId, id: Roster.IndividualId, species: Nat,
  destination: Maybe<&2, Capture.Destination>, +success: Bool, chance: U32,
  draw: U32) -> StepResult:
  match owner_state:
    case None{}:
      Faulted{original, None{}}
    case Some{next_state}:
      Stepped{next_state, emitted, Nil{},
        [capture_event(success, source, target, id, species,
          destination, chance, draw)]}

def capture_commit_owner(update: OwnerUpdate, next_runtime: Runtime.RuntimeState,
  +original: State, emitted: List<&2, Battle.TransitionEvent>,
  source: Battle.ActorId, target: Battle.ActorId,
  id: Roster.IndividualId, species: Nat,
  destination: Maybe<&2, Capture.Destination>, success: Bool, chance: U32,
  draw: U32) -> StepResult:
  capture_commit_owner_state(owner_update_state(update, original, next_runtime),
    original, emitted, source, target, id, species, destination, success,
    chance, draw)

def capture_commit_runtime(battle_result: Battle.AdvanceResult,
  +next_rng: Rng.RngState, source: Battle.ActorId, target: Battle.ActorId,
  sequence: Nat, +original: State, item: Economy.ItemId,
  +id: Roster.IndividualId, +species: Nat, +destination: Capture.Destination,
  +success: Bool, chance: U32, draw: U32) -> StepResult:
  match battle_result:
    case Battle.Advanced{next_battle, emitted}:
      match original:
        case State{+runtime, +economy, +roster, +captured,
            capture_catalog}:
          +update = owner_capture_update(success, economy, roster, captured,
            item, id, species)
          +next_runtime = Runtime.runtime_update(runtime, next_battle,
            next_rng, Runtime.runtime_failed(runtime),
            Runtime.runtime_sources(runtime), Runtime.remove_queued(sequence,
              Runtime.runtime_reservations(runtime)))
          capture_commit_owner(update, next_runtime, original, emitted, source,
            target, id, species,
            committed_capture_destination(success, economy, destination),
            success, chance, draw)
    case _:
      Faulted{original, None{}}

def capture_attempt_commit(result: Runtime.RuntimeCaptureTransaction,
  source: Battle.ActorId, target: Battle.ActorId, sequence: Nat,
  +original: State, item: Economy.ItemId, id: Roster.IndividualId,
  species: Nat, destination: Capture.Destination, chance: U32) -> StepResult:
  match result:
    case Runtime.RuntimeCaptureRejectedAtAttempt{battle, rng, item_quantity}:
      Faulted{original, None{}}
    case Runtime.RuntimeCaptureCommitted{battle, rng, item_quantity,
        Runtime.RuntimeCaptureFailed{}, draw, candidates}:
      capture_commit_runtime(battle, rng, source, target, sequence, original,
        item, id, species, destination, False{}, chance, draw)
    case Runtime.RuntimeCaptureCommitted{battle, rng, item_quantity,
        Runtime.RuntimeCaptureSucceeded{owned, destination}, draw, candidates}:
      capture_commit_runtime(battle, rng, source, target, sequence, original,
        item, id, species, destination, True{}, chance, draw)

def capture_attempt_eligibility(result: Capture.CaptureEligibility,
  +source: Battle.ActorId, +target: Battle.ActorId, item: Economy.ItemId,
  +species: Nat, +individual: Nat, +rate: U32,
  multiplier: Capture.ItemMultiplier, status: Capture.Status,
  +max_hp: U32, +item_quantity_now: U32, battle_result: Battle.BattleState,
  +runtime_rng: Rng.RngState, remaining: List<&2, Battle.BattleEvent>,
  +tick: U32, +recovery: U32, +sequence: Nat, +original: State
) -> StepResult:
  match result:
    case Capture.CaptureRejected{reason}:
      Faulted{original, None{}}
    case Capture.CaptureAccepted{+destination, +chance}:
      capture_attempt_commit(Runtime.runtime_capture_attempt(
        Runtime.RuntimeCapturePlan{source, target, destination, chance,
          species, individual}, True{}, battle_result, runtime_rng,
        item_quantity_now, remaining, tick, recovery, sequence), source, target,
        sequence, original, item, Roster.IndividualId{individual}, species,
        destination, chance)

def capture_commit_no_cost(result: Battle.AdvanceResult, +original: State,
  sequence: Nat) -> StepResult:
  match result:
    case Battle.Advanced{next_battle, emitted}:
      match original:
        case State{+runtime, economy, roster, captured, capture_catalog}:
          +next_runtime = Runtime.runtime_update(runtime, next_battle,
            Runtime.runtime_rng(runtime), Runtime.runtime_failed(runtime),
            Runtime.runtime_sources(runtime), Runtime.remove_queued(sequence,
              Runtime.runtime_reservations(runtime)))
          Stepped{State{next_runtime, economy, roster, captured,
            capture_catalog}, emitted,
            Nil{}, Nil{}}
    case _:
      Faulted{original, None{}}

def capture_fizzle(+original: State, +tick: U32, +source: Battle.ActorId,
  +target: Battle.ActorId, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Battle.BattleEvent>) -> StepResult:
  match original:
    case State{runtime, economy, roster, captured, capture_catalog}:
      capture_commit_no_cost(Reducer.fizzle_action(Runtime.runtime_battle(runtime),
        tick, source, target, recovery, 0, remaining), original, sequence)

def capture_attempt_target_live(live: Bool, +source: Battle.ActorId,
  +target: Battle.ActorId, +item: Economy.ItemId, +species: Nat,
  +individual: Nat, +rate: U32, +multiplier: Capture.ItemMultiplier,
  +status: Capture.Status, +max_hp: U32, uncapturable: Bool, +tick: U32,
  +recovery: U32, +sequence: Nat, remaining: List<&2, Battle.BattleEvent>,
  +original: State, runtime: Runtime.RuntimeState, +economy: Economy.State,
  +battle: Battle.BattleState) -> StepResult:
  match live:
    case False{}:
      capture_fizzle(original, tick, source, target, recovery, sequence,
        remaining)
    case True{}:
      +quantity = item_quantity_or_zero(Economy.find_quantity(
        Economy.inventory_of(economy), item))
      +quantity_u32 = U32.from_nat(quantity)
      capture_attempt_eligibility(Capture.plan_capture(False{}, False{},
        uncapturable, U32.is_ge(quantity_u32, 1),
        capture_party_room(economy), capture_storage_room(economy), rate,
        multiplier, status, max_hp,
        U32.from_nat(Runtime.runtime_capture_target_hp(target, battle))),
        source, target, item, species, individual, rate, multiplier, status,
        max_hp, quantity_u32, battle, Runtime.runtime_rng(runtime), remaining,
        tick, recovery, sequence, original)

def capture_actor_executable(found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case None{}: False{}
    case Some{actor}: Reducer.actor_can_execute(actor)

def capture_status_from_list(values: List<&2, Effects.StatusInstance>,
  fallback: Capture.Status) -> Capture.Status:
  match values:
    case Nil{}: fallback
    case Effects.StatusInstance{Effects.Sleep{}, duration, magnitude} <> rest:
      Capture.CaptureSleep{}
    case Effects.StatusInstance{Effects.Stun{}, duration, magnitude} <> rest:
      Capture.CaptureStun{}
    case Effects.StatusInstance{Effects.Burn{}, duration, magnitude} <> rest:
      Capture.CaptureBurn{}
    case Effects.StatusInstance{Effects.Poison{}, duration, magnitude} <> rest:
      Capture.CapturePoison{}
    case Effects.StatusInstance{Effects.Blind{}, duration, magnitude} <> rest:
      Capture.CaptureBlind{}
    case _ <> rest:
      capture_status_from_list(rest, fallback)

def capture_live_status_match(matches: Bool, target: Effects.EffectActor,
  fallback: Capture.Status) -> Capture.Status:
  match matches:
    case True{}:
      capture_status_from_list(Effects.actor_statuses(target), fallback)
    case False{}: Capture.CaptureOther{}

def capture_live_status_effects(target: Battle.ActorId,
  effects: Maybe<&2, Runtime.RuntimeEffectState>,
  fallback: Capture.Status) -> Capture.Status:
  match effects:
    case None{}: Capture.CaptureOther{}
    case Some{Runtime.RuntimeEffectState{source, effect_target, world}}:
      match world:
        case Effects.EffectWorld{source_actor, target_actor}:
          +matches = Battle.ActorId.eq(target, effect_target)
          capture_live_status_match(matches, target_actor, fallback)

def capture_live_status(target: Battle.ActorId, runtime: Runtime.RuntimeState,
  fallback: Capture.Status) -> Capture.Status:
  capture_live_status_effects(target, Runtime.runtime_effects(runtime),
    fallback)

def capture_attempt_now(+source: Battle.ActorId, +target: Battle.ActorId,
  +item: Economy.ItemId, +species: Nat, +individual: Nat, +rate: U32,
  +multiplier: Capture.ItemMultiplier, +status: Capture.Status, +max_hp: U32,
  +uncapturable: Bool, +tick: U32, +recovery: U32, +sequence: Nat,
  remaining: List<&2, Battle.BattleEvent>, +original: State) -> StepResult:
  match original:
    case State{+runtime, +economy, +roster, +captured, capture_catalog}:
      +battle = Runtime.runtime_battle(runtime)
      +live_status = capture_live_status(target, runtime, status)
      +catalog_valid = capture_catalog_valid(capture_catalog, target, species,
        rate, max_hp, uncapturable, item, multiplier)
      +identity_valid = Nat.is_eq(individual,
        next_capture_id(roster, captured))
      +execution_valid = Bool.and(capture_target_valid(source, target, battle),
        Bool.and(catalog_valid, identity_valid))
      capture_attempt_target_live(execution_valid,
        source, target, item, species, individual, rate, multiplier, live_status,
        max_hp, uncapturable, tick, recovery, sequence, remaining, original,
        runtime, economy, battle)

def normal_step(result: Runtime.RuntimeAdvanceResult,
  +original: State) -> StepResult:
  match result:
    case Runtime.RuntimeStep{state, emitted, combat_events}:
      match original:
        case State{old_runtime, economy, roster, captured,
            capture_catalog}:
          Stepped{State{state, economy, roster, captured, capture_catalog},
            emitted, combat_events, Nil{}}
    case Runtime.RuntimeIdle{state}:
      match original:
        case State{old_runtime, economy, roster, captured,
            capture_catalog}:
          Idle{State{state, economy, roster, captured, capture_catalog}}
    case Runtime.RuntimeEffectRejected{state, diagnostics}:
      RejectedStep{original, diagnostics}
    case Runtime.RuntimeFault{state, reason}:
      Faulted{original, reason}

def capture_attempt_actor_ready(ready: Bool, +source: Battle.ActorId,
  +target: Battle.ActorId, item: Economy.ItemId, species: Nat,
  individual: Nat, +rate: U32, multiplier: Capture.ItemMultiplier,
  status: Capture.Status, +max_hp: U32, uncapturable: Bool, +tick: U32,
  +recovery: U32, +sequence: Nat, remaining: List<&2, Battle.BattleEvent>,
  +original: State) -> StepResult:
  match ready:
    case True{}:
      capture_attempt_now(source, target, item, species, individual, rate,
        multiplier, status, max_hp, uncapturable, tick, recovery, sequence,
        remaining, original)
    case False{}:
      capture_fizzle(original, tick, source, target, recovery, sequence,
        remaining)

def capture_event_ready(due_valid: Bool, waiting_for_ready: Bool) -> Bool:
  Bool.and(due_valid, Bool.not(waiting_for_ready))

def capture_scheduled_check(ready: Bool, +due: U32, +source: Battle.ActorId,
  +target: Battle.ActorId, +recovery: U32, +sequence: Nat,
  +original: State, remaining: List<&2, Battle.BattleEvent>,
  item: Economy.ItemId, species: Nat, individual: Nat, rate: U32,
  multiplier: Capture.ItemMultiplier, status: Capture.Status,
  max_hp: U32, uncapturable: Bool,
  +runtime: Runtime.RuntimeState) -> StepResult:
  match ready:
    case False{}:
      normal_step(Runtime.runtime_step(runtime), original)
    case True{}:
      capture_attempt_actor_ready(capture_actor_executable(
        Scheduler.find_actor(source, Reducer.state_actors(
          Runtime.runtime_battle(runtime)))),
        source, target, item, species, individual, rate, multiplier, status,
        max_hp, uncapturable, due, recovery, sequence, remaining, original)

def capture_queued_sequence(matches: Bool, +tick: U32, +source: Battle.ActorId,
  +target: Battle.ActorId, +recovery: U32, +sequence: Nat,
  +original: State, remaining: List<&2, Battle.BattleEvent>,
  item: Economy.ItemId, species: Nat, individual: Nat, rate: U32,
  multiplier: Capture.ItemMultiplier, status: Capture.Status, max_hp: U32,
  uncapturable: Bool, +runtime: Runtime.RuntimeState) -> StepResult:
  match matches:
    case True{}:
      capture_scheduled_check(U32.is_le(tick, Runtime.runtime_now(runtime)),
        tick, source, target, recovery, sequence, original, remaining, item,
        species, individual, rate, multiplier, status, max_hp, uncapturable,
        runtime)
    case False{}:
      Faulted{original, None{}}

def capture_actor_windup_matches(+tick: U32, +windup: U32,
  found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case Some{Battle.Actor{actor_id, side, hp, speed,
        Battle.Windup{execution_tick}, cooldown}}:
      Bool.and(U32.is_eq(tick, windup), U32.is_eq(execution_tick, windup))
    case _: False{}

def capture_reserved_windup_matches(matches: Bool, +tick: U32,
  +windup: U32, +source: Battle.ActorId, actors: List<&2, Battle.Actor>) -> Bool:
  match matches:
    case False{}: False{}
    case True{}:
      capture_actor_windup_matches(tick, windup,
        Scheduler.find_actor(source, actors))

def capture_event_actor_matches(+accepted_now: U32, +tick: U32, +windup: U32, +speed: Nat,
  +source: Battle.ActorId, found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case Some{Battle.Actor{actor_id, side, hp, actor_speed,
        Battle.Windup{execution_tick}, cooldown}}:
      Bool.and(Nat.is_eq(speed, actor_speed),
        Bool.and(U32.is_eq(tick, U32.add(accepted_now, windup)),
          U32.is_eq(execution_tick, U32.add(accepted_now, windup))))
    case _: False{}

def capture_battle_now(battle: Battle.BattleState) -> U32:
  match battle:
    case Battle.BattleState{now, wait_ticks, actors, events, sequence, status}:
      now

def capture_runtime_now(runtime: Runtime.RuntimeState) -> U32:
  capture_battle_now(Runtime.runtime_battle(runtime))

def capture_event_key_matches(+tick: U32, +phase: Nat, +event_priority: Nat,
  +speed: Nat, +key_actor: Battle.ActorId, +event_sequence: Nat,
  +ordinal: Nat, +source: Battle.ActorId, +sequence: Nat,
  +reserved_priority: Nat, +accepted_now: U32, +windup: U32,
  actor: Maybe<&2, Battle.Actor>) -> Bool:
  Bool.and(U32.is_le(tick, 216000),
  Bool.and(Nat.is_eq(phase, 1n),
  Bool.and(Nat.is_eq(event_priority, reserved_priority),
  Bool.and(Battle.ActorId.eq(key_actor, source),
  Bool.and(Nat.is_eq(event_sequence, sequence),
  Bool.and(Nat.is_eq(ordinal, 0n),
    capture_event_actor_matches(accepted_now, tick, windup, speed, source, actor)))))))

def capture_queued_step(found: Maybe<&2, Runtime.QueuedReservation>,
  event: Battle.BattleEvent, remaining: List<&2, Battle.BattleEvent>,
  +original: State, +runtime: Runtime.RuntimeState) -> StepResult:
  match found:
    case Some{Runtime.QueuedCapture{+sequence, +source, +target, item, species,
        individual, rate, multiplier, status, max_hp, uncapturable, accepted_now,
        windup,
        +recovery, +priority}}:
      match event:
        case Battle.UtilityEvent{Battle.EventKey{+tick, phase, event_priority,
            speed, key_actor, +event_sequence, ordinal}, event_actor,
            event_target,
            +event_recovery}:
          +same_sequence = Bool.and(capture_event_key_matches(tick, phase,
            event_priority, speed, key_actor, event_sequence, ordinal, source,
            sequence, priority, accepted_now, windup,
            Scheduler.find_actor(source,
              Reducer.state_actors(Runtime.runtime_battle(runtime)))),
            Bool.and(Battle.ActorId.eq(event_actor, source),
            Bool.and(Battle.ActorId.eq(event_target, target),
              U32.is_eq(event_recovery, recovery))))
          +event_valid = same_sequence
          capture_queued_sequence(event_valid, tick, source, target,
            recovery, sequence, original, remaining, item, species,
            individual, rate, multiplier, status, max_hp, uncapturable,
            runtime)
        case _:
          Faulted{original, None{}}
    case _:
      normal_step(Runtime.runtime_step(runtime), original)

def m7_step_event(event: Battle.BattleEvent,
  remaining: List<&2, Battle.BattleEvent>, +original: State,
  +runtime: Runtime.RuntimeState) -> StepResult:
  match event:
    case Battle.UtilityEvent{Battle.EventKey{tick, phase, priority, speed,
        key_actor, +sequence, ordinal}, actor, target, recovery}:
      capture_queued_step(Runtime.find_queued(sequence,
        Runtime.runtime_reservations(runtime)), event, remaining, original,
        runtime)
    case _:
      normal_step(Runtime.runtime_step(runtime), original)

def m7_step_events(events: List<&2, Battle.BattleEvent>,
  +original: State, runtime: Runtime.RuntimeState) -> StepResult:
  match events:
    case Nil{}:
      normal_step(Runtime.runtime_step(runtime), original)
    case event <> remaining:
      m7_step_event(event, remaining, original, runtime)

def m7_step_battle(battle: Battle.BattleState, +original: State,
  runtime: Runtime.RuntimeState) -> StepResult:
  match battle:
    case Battle.BattleState{now, wait_ticks, actors, events, sequence, status}:
      m7_step_events(events, original, runtime)

def m7_step_tier_valid(valid: Bool, +original: State,
  +runtime: Runtime.RuntimeState) -> StepResult:
  match valid:
    case True{}:
      m7_step_battle(Runtime.runtime_battle(runtime), original, runtime)
    case False{}:
      Faulted{original, None{}}

def step(+original: State) -> StepResult:
  match original:
    case State{runtime, economy, roster, captured, capture_catalog}:
      m7_step_tier_valid(Bool.and(Economy.state_matches_tiers(economy,
        capture_catalog_tiers(capture_catalog)),
        state_roster_valid(economy, roster)), original, runtime)

def run_loop(+fuel: Nat, +state: State,
  previous: Maybe<&2, StepResult>) -> State:
  match fuel:
    case 0n: state
    case 1n+rest:
      match previous:
        case None{}:
          run_loop(rest, state, Some{step(state)})
        case Some{Stepped{next_state, emitted, combat_events, captures}}:
          run_loop(rest, next_state, None{})
        case Some{Idle{idle_state}}:
          run_loop(rest, idle_state, None{})
        case Some{RejectedStep{rejected_state, diagnostics}}:
          rejected_state
        case Some{Faulted{fault_state, reason}}:
          fault_state

def run(+fuel: Nat, +state: State) -> State:
  run_loop(fuel, state, None{})
