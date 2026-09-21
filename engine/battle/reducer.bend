import Base
import ./model.bend as Model
import ./scheduler.bend as Scheduler
import ./participants.bend as Participants

def event_due(event: Model.BattleEvent) -> U32:
  match event:
    case Model.ReadyEvent{Model.EventKey{due, phase, priority, speed, actor,
        sequence, ordinal}, ready_actor}:
      due
    case Model.ExecuteEvent{Model.EventKey{due, phase, priority, speed, actor,
        sequence, ordinal}, executing_actor, target, recovery, cooldown, damage,
        recoil}:
      due
    case Model.UtilityEvent{Model.EventKey{due, phase, priority, speed, actor,
        sequence, ordinal}, executing_actor, target, recovery}:
      due

def phase_is_windup(phase: Model.Phase) -> Bool:
  match phase:
    case Model.Windup{tick}:
      True{}
    case _:
      False{}

def actor_can_execute(actor: Model.Actor) -> Bool:
  match actor:
    case Model.Actor{id, side, 0n, speed, phase, cooldown}:
      False{}
    case Model.Actor{id, side, 1n+hp, speed, phase, cooldown}:
      phase_is_windup(phase)

def select_actor(
  equal: Bool, updated: Model.Actor, original: Model.Actor,
  rest: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match equal:
    case True{}:
      updated <> rest
    case False{}:
      original <> rest

def ready_phase(+hp: Nat) -> Model.Phase:
  match hp:
    case 0n:
      Model.Defeated{}
    case 1n+rest:
      Model.Ready{}

def set_ready(
  +wanted: Model.ActorId, actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, +side, +hp, +speed, +phase, +cooldown}:
          select_actor(Model.ActorId.eq(wanted, id),
            Model.Actor{id, side, hp, speed, ready_phase(hp), cooldown}, actor,
            set_ready(wanted, rest))

def damage_phase(+remaining: Nat, phase: Model.Phase) -> Model.Phase:
  match remaining:
    case 0n:
      Model.Defeated{}
    case 1n+hp:
      phase

def damage_actor(
  +wanted: Model.ActorId, +amount: Nat, actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, +side, +hp, +speed, +phase, +cooldown}:
          +remaining = Nat.sub(hp, amount)
          select_actor(Model.ActorId.eq(wanted, id),
            Model.Actor{id, side, remaining, speed,
              damage_phase(remaining, phase), cooldown}, actor,
            damage_actor(wanted, amount, rest))

def recovery_phase(+hp: Nat, +ready_tick: U32) -> Model.Phase:
  match hp:
    case 0n:
      Model.Defeated{}
    case 1n+rest:
      Model.Recovery{ready_tick}

def set_recovery(
  +wanted: Model.ActorId, +ready_tick: U32, +cooldown_deadline: U32,
  actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, +side, +hp, +speed, +phase, +cooldown}:
          select_actor(Model.ActorId.eq(wanted, id),
            Model.Actor{id, side, hp, speed, recovery_phase(hp, ready_tick),
              U32.max(cooldown, cooldown_deadline)}, actor,
            set_recovery(wanted, ready_tick, cooldown_deadline, rest))

def side_equal(left: Model.Side, right: Model.Side) -> Bool:
  match left right:
    case Model.Player{} Model.Player{}:
      True{}
    case Model.Enemy{} Model.Enemy{}:
      True{}
    case _ _:
      False{}

def alive_on_side_put(alive: Bool, fallback: Bool) -> Bool:
  match alive:
    case True{}:
      True{}
    case False{}:
      fallback

def actor_alive_on_side(actor: Model.Actor, side: Model.Side) -> Bool:
  match actor:
    case Model.Actor{id, actor_side, 0n, speed, phase, cooldown}:
      False{}
    case Model.Actor{id, actor_side, 1n+hp, speed, phase, cooldown}:
      side_equal(actor_side, side)

def alive_on_side(+side: Model.Side, actors: List<&2, Model.Actor>) -> Bool:
  match actors:
    case Nil{}:
      False{}
    case actor <> rest:
      alive_on_side_put(actor_alive_on_side(actor, side),
        alive_on_side(side, rest))

def completion_status(player_alive: Bool, enemy_alive: Bool) -> Model.BattleStatus:
  match player_alive enemy_alive:
    case True{} True{}:
      Model.Advancing{}
    case True{} False{}:
      Model.Victory{}
    case False{} True{}:
      Model.Defeat{}
    case False{} False{}:
      Model.Draw{}

def battle_status(+actors: List<&2, Model.Actor>) -> Model.BattleStatus:
  completion_status(alive_on_side(Model.Player{}, actors),
    alive_on_side(Model.Enemy{}, actors))

def terminal(status: Model.BattleStatus) -> Bool:
  match status:
    case Model.Victory{}:
      True{}
    case Model.Defeat{}:
      True{}
    case Model.Draw{}:
      True{}
    case Model.Timeout{}:
      True{}
    case Model.Escaped{}:
      True{}
    case _:
      False{}

def same_tick_event(event: Model.BattleEvent, +tick: U32) -> Bool:
  match event:
    case Model.ReadyEvent{Model.EventKey{due, phase, priority, speed, actor,
        sequence, ordinal}, ready_actor}:
      U32.is_eq(due, tick)
    case Model.ExecuteEvent{key, actor, target, recovery, cooldown, damage,
        recoil}:
      U32.is_eq(event_due(Model.ExecuteEvent{key, actor, target, recovery,
        cooldown, damage, recoil}), tick)
    case Model.UtilityEvent{key, actor, target, recovery}:
      U32.is_eq(event_due(Model.UtilityEvent{key, actor, target, recovery}), tick)

def awaiting_after_ready_put(more: Bool) -> Model.BattleStatus:
  match more:
    case True{}:
      Model.Advancing{}
    case False{}:
      Model.AwaitingCommands{}

def awaiting_after_ready(events: List<&2, Model.BattleEvent>, +tick: U32) ->
  Model.BattleStatus:
  match events:
    case Nil{}:
      Model.AwaitingCommands{}
    case event <> rest:
      awaiting_after_ready_put(same_tick_event(event, tick))

def ready_transition(
  +state: Model.BattleState, +tick: U32, +actor: Model.ActorId,
  +remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      Model.Advanced{Model.BattleState{tick, wait_ticks,
        set_ready(actor, actors), remaining, next_sequence,
        awaiting_after_ready(remaining, tick)},
        [Model.BattleBecameReady{actor, tick}]}

def cancelled_transition(
  +state: Model.BattleState, +tick: U32, actor: Model.ActorId,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      Model.Advanced{Model.BattleState{tick, wait_ticks, actors, remaining,
        next_sequence, Model.Advancing{}},
        [Model.BattleActionCancelled{actor}]}

def schedule_ready(
  +tick: U32, +actor: Model.ActorId, +recovery: U32, +sequence: Nat
) -> Model.BattleEvent:
  +ready_tick = U32.add(tick, recovery)
  Model.ReadyEvent{Model.EventKey{ready_tick, 0n, 0n, 0n, actor, sequence,
    0n}, actor}

def finish_action(
  +status: Model.BattleStatus, +tick: U32, +wait_ticks: U32,
  actors: List<&2, Model.Actor>, remaining: List<&2, Model.BattleEvent>,
  +next_sequence: Nat, action_event: Model.TransitionEvent,
  ready_event: Model.BattleEvent
) -> Model.AdvanceResult:
  match status:
    case Model.Advancing{}:
      +queued = {ready_event <> remaining : List<&2, Model.BattleEvent>}
      Model.Advanced{Model.BattleState{tick, wait_ticks, actors,
        List.sort(~Model.BattleEvent, ~Model.BattleEvent.le, queued),
        1n+next_sequence, Model.Advancing{}}, [action_event]}
    case +terminal_status:
      Model.Advanced{Model.BattleState{tick, wait_ticks, actors, Nil{},
        next_sequence, terminal_status},
        [action_event, Model.BattleCompleted{terminal_status, tick},
          Model.BattlePendingDiscarded{
            List.length(&2, Model.BattleEvent, remaining)}]}

def valid_action(
  +state: Model.BattleState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +cooldown: U32, +damage: Nat,
  +recoil: Nat, remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, +next_sequence,
        status}:
      +damaged_target = damage_actor(target, damage, actors)
      +damaged_both = damage_actor(actor, recoil, damaged_target)
      +reinforced = Participants.fill_reinforcements(damaged_both)
      +ready_tick = U32.add(tick, recovery)
      +recovered = set_recovery(actor, ready_tick, U32.add(tick, cooldown),
        reinforced)
      finish_action(battle_status(recovered), tick, wait_ticks, recovered,
        remaining, next_sequence,
        Model.BattleActionExecuted{actor, target, damage, recoil},
        schedule_ready(tick, actor, recovery, next_sequence))

def fizzle_action(
  +state: Model.BattleState, +tick: U32, +actor: Model.ActorId,
  +target: Model.ActorId, +recovery: U32, +cooldown: U32,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, +next_sequence,
        status}:
      +reinforced = Participants.fill_reinforcements(actors)
      +recovered = set_recovery(actor, U32.add(tick, recovery),
        U32.add(tick, cooldown), reinforced)
      finish_action(battle_status(recovered), tick, wait_ticks, recovered,
        remaining, next_sequence, Model.BattleActionFizzled{actor, target},
        schedule_ready(tick, actor, recovery, next_sequence))

def execute_target_valid(
  valid: Bool, +state: Model.BattleState, +tick: U32,
  actor: Model.ActorId, target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +damage: Nat, +recoil: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match valid:
    case True{}:
      valid_action(state, tick, actor, target, recovery, cooldown, damage,
        recoil, remaining)
    case False{}:
      fizzle_action(state, tick, actor, target, recovery, cooldown, remaining)

def execute_target(
  found: Maybe<&2, Model.Actor>, attacker: Model.Actor,
  +state: Model.BattleState, +tick: U32, actor: Model.ActorId,
  target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +damage: Nat, +recoil: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match found:
    case None{}:
      fizzle_action(state, tick, actor, target, recovery, cooldown, remaining)
    case Some{target_actor}:
      execute_target_valid(Scheduler.target_ok(attacker, target_actor), state,
        tick, actor, target, recovery, cooldown, damage, recoil, remaining)

def state_actors(state: Model.BattleState) -> List<&2, Model.Actor>:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      actors

def execute_actor_ready(
  ready: Bool, attacker: Model.Actor, +state: Model.BattleState, +tick: U32,
  actor: Model.ActorId, +target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +damage: Nat, +recoil: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match ready:
    case False{}:
      cancelled_transition(state, tick, actor, remaining)
    case True{}:
      execute_target(Scheduler.find_actor(target, state_actors(state)), attacker,
        state, tick, actor, target, recovery, cooldown, damage, recoil, remaining)

def execute_actor(
  found: Maybe<&2, Model.Actor>, +state: Model.BattleState, +tick: U32,
  actor: Model.ActorId, target: Model.ActorId, +recovery: U32,
  +cooldown: U32, +damage: Nat, +recoil: Nat,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match found:
    case None{}:
      cancelled_transition(state, tick, actor, remaining)
    case Some{+actor_state}:
      execute_actor_ready(actor_can_execute(actor_state), actor_state, state,
        tick, actor, target, recovery, cooldown, damage, recoil, remaining)

def step_event(
  event: Model.BattleEvent, +state: Model.BattleState,
  remaining: List<&2, Model.BattleEvent>
) -> Model.AdvanceResult:
  match event:
    case Model.ReadyEvent{Model.EventKey{+tick, phase, priority, speed, key_actor,
        sequence, ordinal}, actor}:
      ready_transition(state, tick, actor, remaining)
    case Model.ExecuteEvent{Model.EventKey{+tick, phase, priority, speed,
        key_actor, sequence, ordinal}, +actor, target, +recovery, +cooldown,
        +damage, +recoil}:
      execute_actor(Scheduler.find_actor(actor, state_actors(state)), state,
        tick, actor, target, recovery, cooldown, damage, recoil, remaining)
    case Model.UtilityEvent{Model.EventKey{+tick, phase, priority, speed,
        key_actor, sequence, ordinal}, actor, target, recovery}:
      cancelled_transition(state, tick, actor, remaining)

def step(+state: Model.BattleState) -> Model.AdvanceResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, Nil{}, next_sequence,
        status}:
      Model.AdvanceIdle{state}
    case Model.BattleState{now, wait_ticks, actors, event <> remaining,
        next_sequence, Model.Advancing{}}:
      step_event(event, state, remaining)
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      Model.AdvanceIdle{state}
