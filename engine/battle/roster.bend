import Base
import ./model.bend as Model

# M3 owns the finite encounter roster. Entries stay in encounter order and
# ActorIds never change when an individual moves between active and reserve.
type RosterPhase is Data:
  RosterActive{}
  RosterQueued{}
  RosterDefeated{}

type RosterEntry is Data:
  RosterEntry{actor: Model.ActorId, phase: RosterPhase, trapped: Bool}

type SwitchResult is Data:
  SwitchCommitted{roster: List<&2, RosterEntry>}
  SwitchRejected{roster: List<&2, RosterEntry>}

def phase_active(phase: RosterPhase) -> Bool:
  match phase:
    case RosterActive{}:
      True{}
    case _:
      False{}

def phase_viable(phase: RosterPhase) -> Bool:
  match phase:
    case RosterActive{}:
      True{}
    case RosterQueued{}:
      True{}
    case RosterDefeated{}:
      False{}

def viable_put(found: Bool, fallback: Bool) -> Bool:
  match found:
    case True{}:
      True{}
    case False{}:
      fallback

def viable(roster: List<&2, RosterEntry>) -> Bool:
  match roster:
    case Nil{}:
      False{}
    case RosterEntry{actor, phase, trapped} <> rest:
      viable_put(phase_viable(phase), viable(rest))

def active_count(roster: List<&2, RosterEntry>) -> Nat:
  match roster:
    case Nil{}:
      0n
    case RosterEntry{actor, phase, trapped} <> rest:
      match phase:
        case RosterActive{}:
          1n+active_count(rest)
        case _:
          active_count(rest)

def activate_phase(
  phase: RosterPhase, +spaces: Nat
) -> RosterPhase:
  match phase spaces:
    case RosterQueued{} 1n+remaining:
      RosterActive{}
    case +other +remaining:
      other

def remaining_spaces(phase: RosterPhase, +spaces: Nat) -> Nat:
  match phase spaces:
    case RosterQueued{} 1n+remaining:
      remaining
    case other +remaining:
      remaining

def fill_with_spaces(
  roster: List<&2, RosterEntry>, +spaces: Nat
) -> List<&2, RosterEntry>:
  match roster:
    case Nil{}:
      Nil{}
    case RosterEntry{actor, +phase, trapped} <> rest:
      RosterEntry{actor, activate_phase(phase, spaces), trapped} <>
        fill_with_spaces(rest, remaining_spaces(phase, spaces))

def fill_reinforcements(+roster: List<&2, RosterEntry>) -> List<&2, RosterEntry>:
  fill_with_spaces(roster, Nat.sub(4n, Nat.min(active_count(roster), 4n)))

def outgoing_entry(
  equal: Bool, phase: RosterPhase, trapped: Bool, fallback: Bool
) -> Bool:
  match equal phase trapped:
    case True{} RosterActive{} False{}:
      True{}
    case _ _ _:
      fallback

def outgoing_ok(
  +wanted: Model.ActorId, roster: List<&2, RosterEntry>
) -> Bool:
  match roster:
    case Nil{}:
      False{}
    case RosterEntry{+actor, phase, trapped} <> rest:
      outgoing_entry(Model.ActorId.eq(wanted, actor), phase, trapped,
        outgoing_ok(wanted, rest))

def incoming_entry(equal: Bool, phase: RosterPhase, fallback: Bool) -> Bool:
  match equal phase:
    case True{} RosterQueued{}:
      True{}
    case _ _:
      fallback

def incoming_ok(
  +wanted: Model.ActorId, roster: List<&2, RosterEntry>
) -> Bool:
  match roster:
    case Nil{}:
      False{}
    case RosterEntry{+actor, phase, trapped} <> rest:
      incoming_entry(Model.ActorId.eq(wanted, actor), phase,
        incoming_ok(wanted, rest))

def switch_phase_flags(
  is_outgoing: Bool, is_incoming: Bool, phase: RosterPhase
) -> RosterPhase:
  match is_outgoing is_incoming:
    case True{} False{}:
      RosterQueued{}
    case False{} True{}:
      RosterActive{}
    case _ _:
      phase

def switch_phase(
  +actor: Model.ActorId, +outgoing: Model.ActorId, +incoming: Model.ActorId,
  phase: RosterPhase
) -> RosterPhase:
  switch_phase_flags(Model.ActorId.eq(actor, outgoing),
    Model.ActorId.eq(actor, incoming), phase)

def apply_switch(
  +outgoing: Model.ActorId, +incoming: Model.ActorId,
  roster: List<&2, RosterEntry>
) -> List<&2, RosterEntry>:
  match roster:
    case Nil{}:
      Nil{}
    case RosterEntry{+actor, phase, trapped} <> rest:
      RosterEntry{actor, switch_phase(actor, outgoing, incoming, phase), trapped}
        <> apply_switch(outgoing, incoming, rest)

def commit_switch(
  allowed: Bool, +outgoing: Model.ActorId, +incoming: Model.ActorId,
  roster: List<&2, RosterEntry>
) -> SwitchResult:
  match allowed:
    case False{}:
      SwitchRejected{roster}
    case True{}:
      SwitchCommitted{apply_switch(outgoing, incoming, roster)}

def voluntary_switch(
  +outgoing: Model.ActorId, +incoming: Model.ActorId,
  +roster: List<&2, RosterEntry>
) -> SwitchResult:
  commit_switch(Bool.and(Bool.not(Model.ActorId.eq(outgoing, incoming)),
      Bool.and(outgoing_ok(outgoing, roster), incoming_ok(incoming, roster))),
    outgoing, incoming, roster)

# Signed speed delta without signed arithmetic. Multiplication is bounded by
# effective Speed 1..9999, and failed attempts are capped before addition.
def escape_from_order(
  order: Cmp, +player_speed: U32, +enemy_speed: U32, +failed: U32
) -> U32:
  match order:
    case LT{}:
      U32.max(1000, U32.min(9500,
        U32.add(U32.sub(5000, U32.min(5000,
          U32.mul(U32.sub(enemy_speed, player_speed), 25))),
          U32.mul(U32.min(failed, 9), 1000))))
    case _:
      U32.max(1000, U32.min(9500,
        U32.add(U32.add(5000,
          U32.mul(U32.sub(player_speed, enemy_speed), 25)),
          U32.mul(U32.min(failed, 9), 1000))))

def escape_chance(
  +player_speed: U32, +enemy_speed: U32, +failed_attempts: U32
) -> U32:
  escape_from_order(U32.cmp(player_speed, enemy_speed), player_speed,
    enemy_speed, failed_attempts)
