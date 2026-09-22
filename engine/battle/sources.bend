import Base
import ./model.bend as Model
import ./combat_math.bend as Math
import ./scheduler.bend as Scheduler

type MoveSource is Data:
  MoveSource{
    owner: Model.ActorId,
    move: Math.MoveId,
    cooldown_deadline: U32,
    reserved: Bool
  }

type SourceRequest is Data:
  SourceRequest{owner: Model.ActorId, move: Math.MoveId}

type ReserveResult is Data:
  SourcesReserved{sources: List<&2, MoveSource>}
  SourcesRejected{sources: List<&2, MoveSource>}

type ChargeResult is Data:
  SourceCharged{sources: List<&2, MoveSource>}
  SourceChargeRejected{sources: List<&2, MoveSource>}

def MoveId.eq(left: Math.MoveId, right: Math.MoveId) -> Bool:
  match left right:
    case Math.MoveId{left_value} Math.MoveId{right_value}:
      Nat.is_eq(left_value, right_value)

def key_eq(
  left_owner: Model.ActorId, left_move: Math.MoveId,
  right_owner: Model.ActorId, right_move: Math.MoveId
) -> Bool:
  Bool.and(Model.ActorId.eq(left_owner, right_owner),
    MoveId.eq(left_move, right_move))

def source_available(
  +now: U32, +wanted_owner: Model.ActorId, +wanted_move: Math.MoveId,
  sources: List<&2, MoveSource>
) -> Bool:
  match sources:
    case Nil{}:
      False{}
    case MoveSource{+owner, +move, +deadline, reserved} <> rest:
      Bool.or(Bool.and(key_eq(wanted_owner, wanted_move, owner, move),
        Bool.and(Bool.not(reserved), U32.is_ge(now, deadline))),
        source_available(now, wanted_owner, wanted_move, rest))

def request_exists(
  +wanted_owner: Model.ActorId, +wanted_move: Math.MoveId,
  requests: List<&2, SourceRequest>
) -> Bool:
  match requests:
    case Nil{}:
      False{}
    case SourceRequest{+owner, +move} <> +rest:
      Bool.or(key_eq(wanted_owner, wanted_move, owner, move),
        request_exists(wanted_owner, wanted_move, rest))

def requests_unique(requests: List<&2, SourceRequest>) -> Bool:
  match requests:
    case Nil{}:
      True{}
    case SourceRequest{+owner, +move} <> +rest:
      Bool.and(Bool.not(request_exists(owner, move, rest)),
        requests_unique(rest))

def requests_available(
  +now: U32, requests: List<&2, SourceRequest>,
  +sources: List<&2, MoveSource>
) -> Bool:
  match requests:
    case Nil{}:
      True{}
    case SourceRequest{+owner, +move} <> rest:
      Bool.and(source_available(now, owner, move, sources),
        requests_available(now, rest, sources))

def requested(
  +owner: Model.ActorId, +move: Math.MoveId,
  requests: List<&2, SourceRequest>
) -> Bool:
  request_exists(owner, move, requests)

def reserve_sources(
  +requests: List<&2, SourceRequest>, sources: List<&2, MoveSource>
) -> List<&2, MoveSource>:
  match sources:
    case Nil{}:
      Nil{}
    case MoveSource{+owner, +move, deadline, reserved} <> rest:
      MoveSource{owner, move, deadline,
        Bool.or(reserved, requested(owner, move, requests))} <>
        reserve_sources(requests, rest)

def reserve_decide(
  valid: Bool, +requests: List<&2, SourceRequest>,
  +sources: List<&2, MoveSource>
) -> ReserveResult:
  match valid:
    case True{}:
      SourcesReserved{reserve_sources(requests, sources)}
    case False{}:
      SourcesRejected{sources}

def reserve_batch(
  +now: U32, +requests: List<&2, SourceRequest>,
  +sources: List<&2, MoveSource>
) -> ReserveResult:
  reserve_decide(Bool.and(requests_unique(requests),
      requests_available(now, requests, sources)), requests, sources)

def release_flag(equal: Bool, reserved: Bool) -> Bool:
  match equal:
    case True{}:
      False{}
    case False{}:
      reserved

def release(
  +wanted_owner: Model.ActorId, +wanted_move: Math.MoveId,
  sources: List<&2, MoveSource>
) -> List<&2, MoveSource>:
  match sources:
    case Nil{}:
      Nil{}
    case MoveSource{+owner, +move, deadline, reserved} <> rest:
      MoveSource{owner, move, deadline,
        release_flag(key_eq(wanted_owner, wanted_move, owner, move), reserved)} <>
        release(wanted_owner, wanted_move, rest)

def charge_source_put(
  equal: Bool, owner: Model.ActorId, move: Math.MoveId, +old_deadline: U32,
  reserved: Bool, +deadline: U32, rest: List<&2, MoveSource>,
  charged_rest: List<&2, MoveSource>
) -> List<&2, MoveSource>:
  match equal:
    case True{}:
      MoveSource{owner, move, U32.max(old_deadline, deadline), False{}} <> rest
    case False{}:
      MoveSource{owner, move, old_deadline, reserved} <> charged_rest

def charge_source(
  +wanted_owner: Model.ActorId, +wanted_move: Math.MoveId, +deadline: U32,
  sources: List<&2, MoveSource>
) -> List<&2, MoveSource>:
  match sources:
    case Nil{}:
      Nil{}
    case MoveSource{+owner, +move, +old_deadline, reserved} <> +rest:
      charge_source_put(key_eq(wanted_owner, wanted_move, owner, move), owner,
        move, old_deadline, reserved, deadline, rest,
        charge_source(wanted_owner, wanted_move, deadline, rest))

def charge_decide(
  valid: Bool, +owner: Model.ActorId, +move: Math.MoveId, +deadline: U32,
  +sources: List<&2, MoveSource>
) -> ChargeResult:
  match valid:
    case True{}:
      SourceCharged{charge_source(owner, move, deadline, sources)}
    case False{}:
      SourceChargeRejected{sources}

def charge(
  +now: U32, +duration: U32, +owner: Model.ActorId, +move: Math.MoveId,
  +sources: List<&2, MoveSource>
) -> ChargeResult:
  charge_decide(Scheduler.deadline_ok(now, duration), owner, move,
    U32.add(now, duration), sources)

# Mixed-source charging is one checked transaction. The ordinary source list
# remains the authority for both reservations; no first-source write is visible
# until both durations and deadline additions have been validated.
type MixedChargeResult is Data:
  MixedSourcesCharged{sources: List<&2, MoveSource>}
  MixedSourcesRejected{sources: List<&2, MoveSource>}

def mixed_duration(+ordinary: U32) -> U32:
  U32.add(U32.add(ordinary, U32.div(ordinary, 2)),
    U32.mod(ordinary, 2))

def count_if(valid: Bool) -> Nat:
  match valid:
    case True{}: 1n
    case False{}: 0n

def reserved_matches(
  +now: U32, +wanted_owner: Model.ActorId, +wanted_move: Math.MoveId,
  sources: List<&2, MoveSource>
) -> Nat:
  match sources:
    case Nil{}:
      0n
    case MoveSource{+owner, +move, +deadline, reserved} <> rest:
      Nat.add(count_if(Bool.and(key_eq(wanted_owner, wanted_move, owner,
        move), Bool.and(reserved, U32.is_ge(now, deadline)))),
        reserved_matches(now, wanted_owner, wanted_move, rest))

def key_count(
  +wanted_owner: Model.ActorId, +wanted_move: Math.MoveId,
  sources: List<&2, MoveSource>
) -> Nat:
  match sources:
    case Nil{}:
      0n
    case MoveSource{+owner, +move, deadline, reserved} <> rest:
      Nat.add(count_if(key_eq(wanted_owner, wanted_move, owner, move)),
        key_count(wanted_owner, wanted_move, rest))

def mixed_reservations_valid(
  +now: U32, +owner: Model.ActorId, +first: Math.MoveId,
  +second: Math.MoveId, +sources: List<&2, MoveSource>
) -> Bool:
  Bool.and(Bool.and(Nat.is_eq(key_count(owner, first, sources), 1n),
      Nat.is_eq(key_count(owner, second, sources), 1n)),
    Bool.and(Nat.is_eq(reserved_matches(now, owner, first, sources), 1n),
      Nat.is_eq(reserved_matches(now, owner, second, sources), 1n)))

def mixed_sources_valid(
  +now: U32, +owner: Model.ActorId, +first: Math.MoveId,
  +second: Math.MoveId, +first_cooldown: U32, +second_cooldown: U32,
  +sources: List<&2, MoveSource>
) -> Bool:
  Bool.and(Bool.not(MoveId.eq(first, second)),
    Bool.and(Bool.and(U32.is_ge(first_cooldown, 60),
      U32.is_le(first_cooldown, 3600)),
    Bool.and(Bool.and(U32.is_ge(second_cooldown, 60),
      U32.is_le(second_cooldown, 3600)),
    Bool.and(mixed_reservations_valid(now, owner, first, second, sources),
    Bool.and(Scheduler.deadline_ok(now, mixed_duration(first_cooldown)),
      Scheduler.deadline_ok(now, mixed_duration(second_cooldown)))))))

def mixed_charge_decide(
  valid: Bool, +now: U32, +owner: Model.ActorId,
  +first: Math.MoveId, +second: Math.MoveId,
  +first_cooldown: U32, +second_cooldown: U32,
  +sources: List<&2, MoveSource>
) -> MixedChargeResult:
  match valid:
    case False{}:
      MixedSourcesRejected{sources}
    case True{}:
      MixedSourcesCharged{charge_source(owner, second,
        U32.add(now, mixed_duration(second_cooldown)),
        charge_source(owner, first,
          U32.add(now, mixed_duration(first_cooldown)), sources))}

def charge_mixed_pair(
  +now: U32, +owner: Model.ActorId, +first: Math.MoveId,
  +second: Math.MoveId, +first_cooldown: U32, +second_cooldown: U32,
  +sources: List<&2, MoveSource>
) -> MixedChargeResult:
  mixed_charge_decide(mixed_sources_valid(now, owner, first, second,
    first_cooldown, second_cooldown, sources), now, owner, first, second,
    first_cooldown, second_cooldown, sources)
