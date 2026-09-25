import Base
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/roster.bend as Roster

def id(value: Nat) -> Roster.IndividualId:
  Roster.IndividualId{value}

def capacity() -> Economy.Capacity:
  Economy.Capacity{2n, 4n, 2n, 999n, 20n, 9999n}

def source_roster() -> Roster.Roster:
  Roster.Roster{capacity(), [id(1n), id(2n)], [id(3n)]}

def transfer_out_order(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterAccepted{Roster.Roster{cap,
        [Roster.IndividualId{1n}],
        [Roster.IndividualId{3n}, Roster.IndividualId{2n}]}}: True{}
    case _: False{}

def transfer_in_order(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterAccepted{Roster.Roster{cap,
        [Roster.IndividualId{1n}, Roster.IndividualId{2n}],
        [Roster.IndividualId{3n}]}}: True{}
    case _: False{}

def capture_party_order(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterAccepted{Roster.Roster{cap,
        [Roster.IndividualId{1n}, Roster.IndividualId{4n}], []}}: True{}
    case _: False{}

def capture_storage_order(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterAccepted{Roster.Roster{cap,
        [Roster.IndividualId{1n}, Roster.IndividualId{2n}],
        [Roster.IndividualId{3n}, Roster.IndividualId{4n}]}}: True{}
    case _: False{}

def duplicate_rejected_unchanged(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterRejected{
        Roster.Roster{cap, [Roster.IndividualId{1n}, Roster.IndividualId{2n}],
          [Roster.IndividualId{3n}]},
        Roster.DuplicateIndividual{Roster.IndividualId{1n}}}: True{}
    case _: False{}

def missing_rejected_unchanged(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterRejected{
        Roster.Roster{cap, [Roster.IndividualId{1n}, Roster.IndividualId{2n}],
          [Roster.IndividualId{3n}]},
        Roster.IndividualNotFound{Roster.IndividualId{9n}}}: True{}
    case _: False{}

def storage_full_unchanged(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterRejected{
        Roster.Roster{cap, [Roster.IndividualId{1n}],
          [Roster.IndividualId{3n}, Roster.IndividualId{4n}]},
        Roster.StorageFull{}}: True{}
    case _: False{}

def duplicate_roster_rejected(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterRejected{roster, Roster.InvalidRoster{}}: True{}
    case _: False{}

def party_full_unchanged(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterRejected{
        Roster.Roster{cap, [Roster.IndividualId{1n}, Roster.IndividualId{2n}],
          [Roster.IndividualId{3n}]},
        Roster.PartyFull{}}: True{}
    case _: False{}

def capture_full_unchanged(result: Roster.RosterResult) -> Bool:
  match result:
    case Roster.RosterRejected{
        Roster.Roster{cap, [Roster.IndividualId{1n}, Roster.IndividualId{2n}],
          [Roster.IndividualId{3n}, Roster.IndividualId{4n}]},
        Roster.StorageFull{}}: True{}
    case _: False{}

def main() -> List<Bool>:
  [Roster.roster_valid(source_roster()),
   transfer_out_order(Roster.transfer_to_storage(source_roster(), id(2n))),
   transfer_in_order(Roster.transfer_to_party(Roster.Roster{capacity(),
     [id(1n)], [id(2n), id(3n)]}, id(2n))),
   capture_party_order(Roster.capture(Roster.Roster{capacity(), [id(1n)], []},
     id(4n))),
   capture_storage_order(Roster.capture(source_roster(), id(4n))),
   duplicate_rejected_unchanged(Roster.capture(source_roster(), id(1n))),
   missing_rejected_unchanged(Roster.transfer_to_storage(source_roster(),
     id(9n))),
   storage_full_unchanged(Roster.transfer_to_storage(Roster.Roster{capacity(),
     [id(1n)], [id(3n), id(4n)]}, id(1n))),
   party_full_unchanged(Roster.transfer_to_party(source_roster(), id(3n))),
   capture_full_unchanged(Roster.capture(Roster.Roster{capacity(),
     [id(1n), id(2n)], [id(3n), id(4n)]}, id(5n))),
   duplicate_roster_rejected(Roster.capture(Roster.Roster{capacity(),
     [id(1n), id(1n)], []}, id(2n))),
   duplicate_roster_rejected(Roster.capture(Roster.Roster{capacity(),
     [id(1n)], [id(1n)]}, id(2n)))]
