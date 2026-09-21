import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/roster.bend as Roster

def id(value: Nat) -> Model.ActorId:
  Model.ActorId{value}

def roster() -> List<&2, Roster.RosterEntry>:
  [Roster.RosterEntry{id(0n), Roster.RosterActive{}, False{}},
   Roster.RosterEntry{id(1n), Roster.RosterDefeated{}, False{}},
   Roster.RosterEntry{id(2n), Roster.RosterQueued{}, False{}},
   Roster.RosterEntry{id(3n), Roster.RosterQueued{}, False{}},
   Roster.RosterEntry{id(4n), Roster.RosterQueued{}, False{}},
   Roster.RosterEntry{id(5n), Roster.RosterQueued{}, False{}}]

def fill_code(xs: List<&2, Roster.RosterEntry>) -> Nat:
  match xs:
    case Roster.RosterEntry{a, Roster.RosterActive{}, t0} <>
        Roster.RosterEntry{b, Roster.RosterDefeated{}, t1} <>
        Roster.RosterEntry{c, Roster.RosterActive{}, t2} <>
        Roster.RosterEntry{d, Roster.RosterActive{}, t3} <>
        Roster.RosterEntry{e, Roster.RosterActive{}, t4} <>
        Roster.RosterEntry{f, Roster.RosterQueued{}, t5} <> Nil{}:
      1n
    case _:
      0n

def switch_code(result: Roster.SwitchResult) -> Nat:
  match result:
    case Roster.SwitchCommitted{
        Roster.RosterEntry{a, Roster.RosterQueued{}, t0} <>
        Roster.RosterEntry{b, Roster.RosterDefeated{}, t1} <>
        Roster.RosterEntry{c, Roster.RosterActive{}, t2} <> rest}:
      1n
    case _:
      0n

def reject_code(result: Roster.SwitchResult) -> Nat:
  match result:
    case Roster.SwitchRejected{xs}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  [fill_code(Roster.fill_reinforcements(roster())),
   switch_code(Roster.voluntary_switch(id(0n), id(2n), roster())),
   reject_code(Roster.voluntary_switch(id(1n), id(2n), roster())),
   U32.to_nat(Roster.escape_chance(100, 100, 0)),
   U32.to_nat(Roster.escape_chance(1, 9999, 0)),
   U32.to_nat(Roster.escape_chance(9999, 1, 0))]

#| [1, 1, 1, 5000, 1000, 9500]
