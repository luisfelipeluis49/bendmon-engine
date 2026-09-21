import Base

# M3 battle identifiers are allocated before combat and remain stable.
type ActorId is Data:
  ActorId{value: Nat}

type Side is Data:
  Player{}
  Enemy{}

type Phase is Data:
  Ready{}
  Windup{execution_tick: U32}
  Recovery{ready_tick: U32}
  Benched{}
  Defeated{}

# This first M3 slice carries one minimal damaging source per actor.  Later
# content integration replaces the scalar cooldown with typed MoveId entries
# without changing the scheduler or event key.
type Actor is Data:
  Actor{
    id: ActorId,
    side: Side,
    hp: Nat,
    speed: Nat,
    phase: Phase,
    cooldown_deadline: U32
  }

type Command is Data:
  BattleWait{actor: ActorId}
  BattleMove{
    actor: ActorId,
    target: ActorId,
    windup: U32,
    recovery: U32,
    cooldown: U32,
    priority_rank: Nat,
    damage: Nat,
    recoil: Nat
  }
  BattleUtility{
    actor: ActorId,
    target: ActorId,
    windup: U32,
    recovery: U32,
    priority_rank: Nat
  }

# Smaller keys execute first. priority_rank is the canonical 0..16 encoding
# for authored priority +8..-8; speed itself is compared in descending order.
type EventKey is Data:
  EventKey{
    due_tick: U32,
    phase_rank: Nat,
    priority_rank: Nat,
    accepted_speed: Nat,
    actor: ActorId,
    action_sequence: Nat,
    event_ordinal: Nat
  }

type BattleEvent is Data:
  ReadyEvent{key: EventKey, actor: ActorId}
  ExecuteEvent{
    key: EventKey,
    actor: ActorId,
    target: ActorId,
    recovery: U32,
    cooldown: U32,
    damage: Nat,
    recoil: Nat
  }
  UtilityEvent{
    key: EventKey,
    actor: ActorId,
    target: ActorId,
    recovery: U32
  }

type BattleStatus is Data:
  AwaitingCommands{}
  Advancing{}
  Victory{}
  Defeat{}
  Draw{}
  Timeout{}
  Escaped{}
  SchedulerStalled{}

type BattleState is Data:
  BattleState{
    now: U32,
    wait_ticks: U32,
    actors: List<&2, Actor>,
    events: List<&2, BattleEvent>,
    next_sequence: Nat,
    status: BattleStatus
  }

type Diagnostic is Data:
  BattleNotAwaiting{}
  InvalidWaitSetting{}
  IncompleteBarrier{}
  DuplicateActor{actor: ActorId}
  ActorMissing{actor: ActorId}
  ActorNotReady{actor: ActorId}
  TargetInvalid{actor: ActorId, target: ActorId}
  TimingInvalid{actor: ActorId}
  CooldownActive{actor: ActorId}
  DeadlineOverflow{actor: ActorId}
  SwitchInvalid{actor: ActorId, incoming: ActorId}
  EscapeUnavailable{actor: ActorId}
  SourceReserved{actor: ActorId}

type SubmitResult is Data:
  Accepted{state: BattleState, emitted: List<&2, BattleEvent>}
  Rejected{state: BattleState, diagnostics: List<&2, Diagnostic>}

type TransitionEvent is Data:
  BattleBecameReady{actor: ActorId, tick: U32}
  BattleActionExecuted{actor: ActorId, target: ActorId, damage: Nat, recoil: Nat}
  BattleActionCancelled{actor: ActorId}
  BattleActionFizzled{actor: ActorId, target: ActorId}
  BattleActorSwitched{actor: ActorId, incoming: ActorId}
  BattleEscapeFailed{actor: ActorId}
  BattleEscapeSucceeded{actor: ActorId}
  BattleCompleted{status: BattleStatus, tick: U32}
  BattlePendingDiscarded{count: Nat}

type AdvanceResult is Data:
  Advanced{state: BattleState, emitted: List<&2, TransitionEvent>}
  AdvanceIdle{state: BattleState}

def ActorId.eq(a: ActorId, b: ActorId) -> Bool:
  ActorId{a_value} = a
  ActorId{b_value} = b
  Nat.is_eq(a_value, b_value)

def ActorId.le(a: ActorId, b: ActorId) -> Bool:
  ActorId{a_value} = a
  ActorId{b_value} = b
  Nat.is_le(a_value, b_value)

def Command.actor(command: Command) -> ActorId:
  match command:
    case BattleWait{actor}:
      actor
    case BattleMove{actor, target, windup, recovery, cooldown, priority_rank,
        damage, recoil}:
      actor
    case BattleUtility{actor, target, windup, recovery, priority_rank}:
      actor

def Command.le(left: Command, right: Command) -> Bool:
  ActorId.le(Command.actor(left), Command.actor(right))

def BattleEvent.key(event: BattleEvent) -> EventKey:
  match event:
    case ReadyEvent{key, actor}:
      key
    case ExecuteEvent{key, actor, target, recovery, cooldown, damage, recoil}:
      key
    case UtilityEvent{key, actor, target, recovery}:
      key

def compare_actor(left: ActorId, right: ActorId) -> Cmp:
  ActorId{left_value} = left
  ActorId{right_value} = right
  Nat.cmp(left_value, right_value)

def compare_event_sequence(
  order: Cmp, +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  match order:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      Nat.is_le(left_ordinal, right_ordinal)

def compare_event_actor_order(
  order: Cmp, +left_sequence: Nat, +right_sequence: Nat,
  +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  match order:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      compare_event_sequence(Nat.cmp(left_sequence, right_sequence),
        left_ordinal, right_ordinal)

def compare_event_actor(
  left: ActorId, right: ActorId, +left_sequence: Nat, +right_sequence: Nat,
  +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  compare_event_actor_order(compare_actor(left, right), left_sequence,
    right_sequence, left_ordinal, right_ordinal)

def compare_event_speed_order(
  order: Cmp, left_actor: ActorId, right_actor: ActorId,
  +left_sequence: Nat, +right_sequence: Nat, +left_ordinal: Nat,
  +right_ordinal: Nat
) -> Bool:
  match order:
    case GT{}:
      True{}
    case LT{}:
      False{}
    case EQ{}:
      compare_event_actor(left_actor, right_actor, left_sequence,
        right_sequence, left_ordinal, right_ordinal)

def compare_event_speed(
  +left_speed: Nat, +right_speed: Nat, left_actor: ActorId,
  right_actor: ActorId, +left_sequence: Nat, +right_sequence: Nat,
  +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  compare_event_speed_order(Nat.cmp(left_speed, right_speed), left_actor,
    right_actor, left_sequence, right_sequence, left_ordinal, right_ordinal)

def compare_event_priority_order(
  order: Cmp, +left_speed: Nat, +right_speed: Nat, left_actor: ActorId,
  right_actor: ActorId, +left_sequence: Nat, +right_sequence: Nat,
  +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  match order:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      compare_event_speed(left_speed, right_speed, left_actor, right_actor,
        left_sequence, right_sequence, left_ordinal, right_ordinal)

def compare_event_priority(
  +left_priority: Nat, +right_priority: Nat, +left_speed: Nat,
  +right_speed: Nat, left_actor: ActorId, right_actor: ActorId,
  +left_sequence: Nat, +right_sequence: Nat, +left_ordinal: Nat,
  +right_ordinal: Nat
) -> Bool:
  compare_event_priority_order(Nat.cmp(left_priority, right_priority),
    left_speed, right_speed, left_actor, right_actor, left_sequence,
    right_sequence, left_ordinal, right_ordinal)

def compare_event_phase_order(
  order: Cmp, +left_priority: Nat, +right_priority: Nat, +left_speed: Nat,
  +right_speed: Nat, left_actor: ActorId, right_actor: ActorId,
  +left_sequence: Nat, +right_sequence: Nat, +left_ordinal: Nat,
  +right_ordinal: Nat
) -> Bool:
  match order:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      compare_event_speed(left_speed, right_speed, left_actor, right_actor,
        left_sequence, right_sequence, left_ordinal, right_ordinal)

def compare_event_phase(
  +left_phase: Nat, +right_phase: Nat, +left_priority: Nat,
  +right_priority: Nat, +left_speed: Nat, +right_speed: Nat,
  left_actor: ActorId, right_actor: ActorId, +left_sequence: Nat,
  +right_sequence: Nat, +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  compare_event_phase_order(Nat.cmp(left_phase, right_phase), left_priority,
    right_priority, left_speed, right_speed, left_actor, right_actor,
    left_sequence, right_sequence, left_ordinal, right_ordinal)

def compare_event_due_order(
  order: Cmp, +left_phase: Nat, +right_phase: Nat, +left_priority: Nat,
  +right_priority: Nat, +left_speed: Nat, +right_speed: Nat,
  left_actor: ActorId, right_actor: ActorId, +left_sequence: Nat,
  +right_sequence: Nat, +left_ordinal: Nat, +right_ordinal: Nat
) -> Bool:
  match order:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      compare_event_priority(left_priority, right_priority, left_speed,
        right_speed, left_actor, right_actor, left_sequence, right_sequence,
        left_ordinal, right_ordinal)

def EventKey.le(left: EventKey, right: EventKey) -> Bool:
  EventKey{+left_due, +left_phase, +left_priority, +left_speed, left_actor,
    +left_sequence, +left_ordinal} = left
  EventKey{+right_due, +right_phase, +right_priority, +right_speed, right_actor,
    +right_sequence, +right_ordinal} = right
  compare_event_due_order(U32.cmp(left_due, right_due), left_phase,
    right_phase, left_priority, right_priority, left_speed, right_speed,
    left_actor, right_actor, left_sequence, right_sequence, left_ordinal,
    right_ordinal)

def BattleEvent.le(left: BattleEvent, right: BattleEvent) -> Bool:
  EventKey.le(BattleEvent.key(left), BattleEvent.key(right))
