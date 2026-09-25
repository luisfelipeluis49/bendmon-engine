import Base
import ./core.bend as Economy

type IndividualId is Data:
  IndividualId{value: Nat}

type Roster is Data:
  Roster{capacity: Economy.Capacity, party: List<&2, IndividualId>,
    storage: List<&2, IndividualId>}

type RosterDiagnostic is Data:
  InvalidRoster{}
  DuplicateIndividual{id: IndividualId}
  IndividualNotFound{id: IndividualId}
  PartyFull{}
  StorageFull{}

type RosterResult is Data:
  RosterAccepted{roster: Roster}
  RosterRejected{roster: Roster, reason: RosterDiagnostic}

def id_eq(left: IndividualId, right: IndividualId) -> Bool:
  match left right:
    case IndividualId{a} IndividualId{b}: Nat.is_eq(a, b)

def id_in(ids: List<&2, IndividualId>, +wanted: IndividualId) -> Bool:
  match ids:
    case Nil{}: False{}
    case id <> +rest:
      Bool.or(id_eq(id, wanted), id_in(rest, wanted))

def overlap(left: List<&2, IndividualId>,
  +right: List<&2, IndividualId>) -> Bool:
  match left:
    case Nil{}: False{}
    case id <> rest:
      Bool.or(id_in(right, id), overlap(rest, right))

def unique_ids(ids: List<&2, IndividualId>) -> Bool:
  match ids:
    case Nil{}: True{}
    case id <> +rest:
      Bool.and(Bool.not(id_in(rest, id)), unique_ids(rest))

def roster_valid(roster: Roster) -> Bool:
  match roster:
    case Roster{+capacity, +party, +storage}:
      Bool.and(Economy.within_hard_limits(capacity),
      Bool.and(Nat.is_le(List.length(&2, IndividualId, party),
          Economy.party_cap(capacity)),
      Bool.and(Nat.is_le(List.length(&2, IndividualId, storage),
          Economy.storage_cap(capacity)),
      Bool.and(unique_ids(party), Bool.and(unique_ids(storage),
        Bool.not(overlap(party, storage)))))))

def rejected(roster: Roster, reason: RosterDiagnostic) -> RosterResult:
  RosterRejected{roster, reason}

def accepted(roster: Roster) -> RosterResult:
  RosterAccepted{roster}

def remove_id_step(rest: List<&2, IndividualId>, found: Bool,
  +wanted: IndividualId, current: IndividualId) -> List<&2, IndividualId>:
  match rest found:
    case Nil{} True{}: []
    case Nil{} False{}: [current]
    case next <> tail True{}: rest
    case +next <> tail False{}:
      current <> remove_id_step(tail, id_eq(next, wanted), wanted, next)

def remove_id(ids: List<&2, IndividualId>,
  +wanted: IndividualId) -> List<&2, IndividualId>:
  match ids:
    case Nil{}: []
    case +current <> rest:
      remove_id_step(rest, id_eq(current, wanted), wanted, current)

def transfer_party_storage_capacity(room: Bool,
  capacity: Economy.Capacity, party: List<&2, IndividualId>,
  storage: List<&2, IndividualId>, id: IndividualId, original: Roster) ->
  RosterResult:
  match room:
    case False{}: rejected(original, StorageFull{})
    case True{}: accepted(Roster{capacity, party,
      List.append(&2, IndividualId, storage, [id])})

def transfer_party_storage_removed(found: Bool,
  party: List<&2, IndividualId>, roster: Roster, id: IndividualId) ->
  RosterResult:
  match found:
    case False{}: rejected(roster, IndividualNotFound{id})
    case True{}:
      match roster:
        case Roster{+capacity, original_party, +storage}:
          transfer_party_storage_capacity(
            Nat.is_lt(List.length(&2, IndividualId, storage),
              Economy.storage_cap(capacity)), capacity, party, storage, id,
            roster)

def transfer_party_storage_valid(valid: Bool, roster: Roster,
  +id: IndividualId) -> RosterResult:
  match valid:
    case False{}: rejected(roster, InvalidRoster{})
    case True{}:
      match roster:
        case Roster{+capacity, +party, storage}:
          transfer_party_storage_removed(id_in(party, id), remove_id(party, id),
            roster, id)

def transfer_to_storage(+roster: Roster, id: IndividualId) -> RosterResult:
  transfer_party_storage_valid(roster_valid(roster), roster, id)

def transfer_storage_party_capacity(room: Bool,
  capacity: Economy.Capacity, party: List<&2, IndividualId>,
  storage: List<&2, IndividualId>, id: IndividualId, original: Roster) ->
  RosterResult:
  match room:
    case False{}: rejected(original, PartyFull{})
    case True{}: accepted(Roster{capacity,
      List.append(&2, IndividualId, party, [id]), storage})

def transfer_storage_party_removed(found: Bool,
  storage: List<&2, IndividualId>, roster: Roster, id: IndividualId) ->
  RosterResult:
  match found:
    case False{}: rejected(roster, IndividualNotFound{id})
    case True{}:
      match roster:
        case Roster{+capacity, +party, original_storage}:
          transfer_storage_party_capacity(
            Nat.is_lt(List.length(&2, IndividualId, party),
              Economy.party_cap(capacity)), capacity, party, storage, id,
            roster)

def transfer_storage_party_valid(valid: Bool, roster: Roster,
  +id: IndividualId) -> RosterResult:
  match valid:
    case False{}: rejected(roster, InvalidRoster{})
    case True{}:
      match roster:
        case Roster{capacity, party, +storage}:
          transfer_storage_party_removed(id_in(storage, id),
            remove_id(storage, id), roster, id)

def transfer_to_party(+roster: Roster, id: IndividualId) -> RosterResult:
  transfer_storage_party_valid(roster_valid(roster), roster, id)

def capture_room(storage_room: Bool, capacity: Economy.Capacity,
  party: List<&2, IndividualId>, storage: List<&2, IndividualId>,
  id: IndividualId, original: Roster) -> RosterResult:
  match storage_room:
    case False{}: rejected(original, StorageFull{})
    case True{}: accepted(Roster{capacity, party,
      List.append(&2, IndividualId, storage, [id])})

def capture_party_room(party_room: Bool, roster: Roster,
  id: IndividualId) -> RosterResult:
  match party_room:
    case True{}:
      match roster:
        case Roster{+capacity, +party, +storage}:
          accepted(Roster{capacity, List.append(&2, IndividualId, party, [id]),
            storage})
    case False{}:
      match roster:
        case Roster{+capacity, +party, +storage}:
          capture_room(Nat.is_lt(List.length(&2, IndividualId, storage),
            Economy.storage_cap(capacity)), capacity, party, storage, id, roster)

def capture_duplicate(duplicate: Bool, roster: Roster,
  id: IndividualId) -> RosterResult:
  match duplicate:
    case True{}: rejected(roster, DuplicateIndividual{id})
    case False{}:
      match roster:
        case Roster{+capacity, +party, storage}:
          capture_party_room(Nat.is_lt(List.length(&2, IndividualId, party),
            Economy.party_cap(capacity)), roster, id)

def capture_valid(valid: Bool, roster: Roster, +id: IndividualId) -> RosterResult:
  match valid:
    case False{}: rejected(roster, InvalidRoster{})
    case True{}:
      match roster:
        case Roster{capacity, +party, +storage}:
          capture_duplicate(Bool.or(id_in(party, id), id_in(storage, id)),
            roster, id)

def capture(+roster: Roster, id: IndividualId) -> RosterResult:
  capture_valid(roster_valid(roster), roster, id)
