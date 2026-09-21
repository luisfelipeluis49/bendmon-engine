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
