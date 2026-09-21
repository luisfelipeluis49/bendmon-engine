import Base
import ./model.bend as Model

def wait_setting_ok(+wait_ticks: U32) -> Bool:
  Bool.or(U32.is_eq(wait_ticks, 30),
    Bool.or(U32.is_eq(wait_ticks, 60), U32.is_eq(wait_ticks, 120)))

def deadline_ok(+now: U32, +duration: U32) -> Bool:
  Bool.and(U32.is_le(now, 216000),
    U32.is_le(duration, U32.sub(216000, now)))

def Actor.is_ready(actor: Model.Actor) -> Bool:
  match actor:
    case Model.Actor{id, side, 0n, speed, phase, cooldown}:
      False{}
    case Model.Actor{id, side, 1n+hp, speed, Model.Ready{}, cooldown}:
      True{}
    case Model.Actor{id, side, 1n+hp, speed, phase, cooldown}:
      False{}

def collect_ready_put(
  ready: Bool, id: Model.ActorId, rest: List<&2, Model.ActorId>
) -> List<&2, Model.ActorId>:
  match ready:
    case False{}:
      rest
    case True{}:
      id <> rest

def collect_ready_ids(actors: List<&2, Model.Actor>) -> List<&2, Model.ActorId>:
  match actors:
    case Nil{}:
      Nil{}
    case Model.Actor{+id, side, hp, speed, phase, cooldown} <> rest:
      collect_ready_put(
        Actor.is_ready(Model.Actor{id, side, hp, speed, phase, cooldown}),
        id, collect_ready_ids(rest))

def ids_equal(left: List<&2, Model.ActorId>, right: List<&2, Model.ActorId>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case Nil{} h <> t:
      False{}
    case h <> t Nil{}:
      False{}
    case left_id <> left_rest right_id <> right_rest:
      Bool.and(Model.ActorId.eq(left_id, right_id), ids_equal(left_rest, right_rest))

def command_ids(commands: List<&2, Model.Command>) -> List<&2, Model.ActorId>:
  match commands:
    case Nil{}:
      Nil{}
    case command <> rest:
      Model.Command.actor(command) <> command_ids(rest)

def sorted_commands(commands: List<&2, Model.Command>) -> List<&2, Model.Command>:
  List.sort(~Model.Command, ~Model.Command.le, commands)

def sorted_actor_ids(ids: List<&2, Model.ActorId>) -> List<&2, Model.ActorId>:
  List.sort(~Model.ActorId, ~Model.ActorId.le, ids)

def find_actor_put(
  equal: Bool, actor: Model.Actor, fallback: Maybe<&2, Model.Actor>
) -> Maybe<&2, Model.Actor>:
  match equal:
    case True{}:
      Some{actor}
    case False{}:
      fallback

def find_actor(+wanted: Model.ActorId, actors: List<&2, Model.Actor>) -> Maybe<&2, Model.Actor>:
  match actors:
    case Nil{}:
      None{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, side, hp, speed, phase, cooldown}:
          find_actor_put(Model.ActorId.eq(wanted, id), actor,
            find_actor(wanted, rest))

def same_side(left: Model.Side, right: Model.Side) -> Bool:
  match left right:
    case Model.Player{} Model.Player{}:
      True{}
    case Model.Enemy{} Model.Enemy{}:
      True{}
    case _ _:
      False{}

def target_phase_ok(phase: Model.Phase) -> Bool:
  match phase:
    case Model.Benched{}:
      False{}
    case Model.Defeated{}:
      False{}
    case _:
      True{}

def target_ok(attacker: Model.Actor, target: Model.Actor) -> Bool:
  match attacker target:
    case Model.Actor{a_id, a_side, a_hp, a_speed, a_phase, a_cooldown}
        Model.Actor{t_id, t_side, 0n, t_speed, t_phase, t_cooldown}:
      False{}
    case Model.Actor{a_id, a_side, a_hp, a_speed, a_phase, a_cooldown}
        Model.Actor{t_id, t_side, 1n+t_hp, t_speed, t_phase, t_cooldown}:
      Bool.and(target_phase_ok(t_phase),
        Bool.and(Bool.not(same_side(a_side, t_side)),
          Bool.not(Model.ActorId.eq(a_id, t_id))))

def timing_ok(+windup: U32, +recovery: U32, +cooldown: U32, +priority: Nat) -> Bool:
  Bool.and(U32.is_le(windup, 600), Bool.and(
    Bool.and(U32.is_ge(recovery, 30), U32.is_le(recovery, 600)),
    Bool.and(Bool.and(U32.is_ge(cooldown, 60), U32.is_le(cooldown, 3600)),
      Nat.is_le(priority, 16n))))

def move_deadlines_ok(+now: U32, +windup: U32, +recovery: U32, +cooldown: U32) -> Bool:
  +execution = U32.add(now, windup)
  Bool.and(deadline_ok(now, windup),
    Bool.and(deadline_ok(execution, recovery),
      deadline_ok(execution, cooldown)))

def validate_wait_deadline(
  ok: Bool, actor_id: Model.ActorId
) -> List<&2, Model.Diagnostic>:
  Nil{}

def validate_wait_ready(
  ready: Bool, actor_id: Model.ActorId, +now: U32, +wait_ticks: U32
) -> List<&2, Model.Diagnostic>:
  match ready:
    case True{}:
      validate_wait_deadline(deadline_ok(now, wait_ticks), actor_id)
    case False{}:
      [Model.ActorNotReady{actor_id}]

def validate_wait_actor(
  found: Maybe<&2, Model.Actor>, actor_id: Model.ActorId, +now: U32,
  +wait_ticks: U32
) -> List<&2, Model.Diagnostic>:
  match found:
    case None{}:
      [Model.ActorMissing{actor_id}]
    case Some{actor}:
      validate_wait_ready(Actor.is_ready(actor), actor_id, now, wait_ticks)

def validate_move_deadline(ok: Bool, actor_id: Model.ActorId) ->
  List<&2, Model.Diagnostic>:
  Nil{}

def validate_move_target(
  ok: Bool, actor_id: Model.ActorId, target_id: Model.ActorId,
  +now: U32, +windup: U32, +recovery: U32, +cooldown: U32
) -> List<&2, Model.Diagnostic>:
  match ok:
    case False{}:
      [Model.TargetInvalid{actor_id, target_id}]
    case True{}:
      validate_move_deadline(move_deadlines_ok(now, windup, recovery, cooldown),
        actor_id)

def validate_move_target_found(
  found: Maybe<&2, Model.Actor>, actor: Model.Actor,
  actor_id: Model.ActorId, target_id: Model.ActorId, +now: U32,
  +windup: U32, +recovery: U32, +cooldown: U32
) -> List<&2, Model.Diagnostic>:
  match found:
    case None{}:
      [Model.TargetInvalid{actor_id, target_id}]
    case Some{target}:
      validate_move_target(target_ok(actor, target), actor_id, target_id,
        now, windup, recovery, cooldown)

def validate_move_timing(
  ok: Bool, actor: Model.Actor, actor_id: Model.ActorId,
  +target_id: Model.ActorId, +now: U32, +windup: U32, +recovery: U32,
  +cooldown: U32, +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match ok:
    case False{}:
      [Model.TimingInvalid{actor_id}]
    case True{}:
      validate_move_target_found(find_actor(target_id, actors), actor,
        actor_id, target_id, now, windup, recovery, cooldown)

def validate_move_cooldown(
  ok: Bool, actor: Model.Actor, actor_id: Model.ActorId,
  target_id: Model.ActorId, +now: U32, +windup: U32, +recovery: U32,
  +cooldown: U32, +priority: Nat, +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match ok:
    case False{}:
      [Model.CooldownActive{actor_id}]
    case True{}:
      validate_move_timing(timing_ok(windup, recovery, cooldown, priority),
        actor, actor_id, target_id, now, windup, recovery, cooldown, actors)

def validate_move_ready(
  ready: Bool, actor: Model.Actor, actor_id: Model.ActorId,
  target_id: Model.ActorId, +now: U32, +windup: U32, +recovery: U32,
  +cooldown: U32, +priority: Nat, +cooldown_deadline: U32,
  +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match ready:
    case False{}:
      [Model.ActorNotReady{actor_id}]
    case True{}:
      validate_move_cooldown(U32.is_ge(now, cooldown_deadline), actor,
        actor_id, target_id, now, windup, recovery, cooldown, priority, actors)

def validate_move_actor(
  found: Maybe<&2, Model.Actor>, actor_id: Model.ActorId,
  target_id: Model.ActorId, +now: U32, +windup: U32, +recovery: U32,
  +cooldown: U32, +priority: Nat, +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match found:
    case None{}:
      [Model.ActorMissing{actor_id}]
    case Some{+actor}:
      match actor:
        case Model.Actor{id, side, hp, speed, phase, +cooldown_deadline}:
          validate_move_ready(Actor.is_ready(actor), actor, actor_id, target_id,
            now, windup, recovery, cooldown, priority, cooldown_deadline, actors)

def utility_timing_ok(
  +windup: U32, +recovery: U32, +priority: Nat
) -> Bool:
  Bool.and(U32.is_le(windup, 600),
    Bool.and(Bool.and(U32.is_ge(recovery, 30), U32.is_le(recovery, 600)),
      Nat.is_le(priority, 16n)))

def validate_utility_timing(
  valid: Bool, actor_id: Model.ActorId, +now: U32, +windup: U32,
  +recovery: U32
) -> List<&2, Model.Diagnostic>:
  match valid:
    case False{}:
      [Model.TimingInvalid{actor_id}]
    case True{}:
      validate_move_deadline(Bool.and(deadline_ok(now, windup),
        deadline_ok(U32.add(now, windup), recovery)), actor_id)

def validate_utility_ready(
  ready: Bool, actor_id: Model.ActorId, +now: U32, +windup: U32,
  +recovery: U32, +priority: Nat
) -> List<&2, Model.Diagnostic>:
  match ready:
    case False{}:
      [Model.ActorNotReady{actor_id}]
    case True{}:
      validate_utility_timing(utility_timing_ok(windup, recovery, priority),
        actor_id, now, windup, recovery)

def validate_utility_actor(
  found: Maybe<&2, Model.Actor>, actor_id: Model.ActorId, +now: U32,
  +windup: U32, +recovery: U32, +priority: Nat
) -> List<&2, Model.Diagnostic>:
  match found:
    case None{}:
      [Model.ActorMissing{actor_id}]
    case Some{actor}:
      validate_utility_ready(Actor.is_ready(actor), actor_id, now, windup,
        recovery, priority)

def validate_command(
  +now: U32, +wait_ticks: U32, command: Model.Command,
  +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match command:
    case Model.BattleWait{+actor_id}:
      validate_wait_actor(find_actor(actor_id, actors), actor_id, now,
        wait_ticks)
    case Model.BattleMove{+actor_id, +target_id, +windup, +recovery, +cooldown,
        +priority, damage, recoil}:
      validate_move_actor(find_actor(actor_id, actors), actor_id, target_id,
        now, windup, recovery, cooldown, priority, actors)
    case Model.BattleUtility{+actor_id, target_id, +windup, +recovery,
        +priority}:
      validate_utility_actor(find_actor(actor_id, actors), actor_id, now,
        windup, recovery, priority)

def validate_commands(
  +now: U32, +wait_ticks: U32, commands: List<&2, Model.Command>,
  +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match commands:
    case Nil{}:
      Nil{}
    case command <> rest:
      List.append(&2, Model.Diagnostic,
        validate_command(now, wait_ticks, command, actors),
        validate_commands(now, wait_ticks, rest, actors))

def replace_actor_put(
  equal: Bool, updated: Model.Actor, original: Model.Actor,
  rest: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match equal:
    case True{}:
      updated <> rest
    case False{}:
      original <> rest

def mark_waiting(
  +wanted: Model.ActorId, +ready_tick: U32, actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, +side, +hp, +speed, +phase, +cooldown}:
          replace_actor_put(Model.ActorId.eq(wanted, id),
            Model.Actor{id, side, hp, speed, Model.Recovery{ready_tick}, cooldown},
            actor, mark_waiting(wanted, ready_tick, rest))

def mark_windup(
  +wanted: Model.ActorId, +execution_tick: U32,
  actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, +side, +hp, +speed, +phase, +cooldown}:
          replace_actor_put(Model.ActorId.eq(wanted, id),
            Model.Actor{id, side, hp, speed, Model.Windup{execution_tick}, cooldown},
            actor, mark_windup(wanted, execution_tick, rest))

def actor_speed_put(equal: Bool, +speed: Nat, +fallback: Nat) -> Nat:
  match equal:
    case True{}:
      speed
    case False{}:
      fallback

def actor_speed(+wanted: Model.ActorId, actors: List<&2, Model.Actor>) -> Nat:
  match actors:
    case Nil{}:
      0n
    case Model.Actor{+id, side, hp, +speed, phase, cooldown} <> rest:
      actor_speed_put(Model.ActorId.eq(wanted, id), speed,
        actor_speed(wanted, rest))

type CommitPart is Data:
  CommitPart{
    actors: List<&2, Model.Actor>,
    events: List<&2, Model.BattleEvent>,
    next_sequence: Nat
  }

def commit_commands(
  +now: U32, +wait_ticks: U32, commands: List<&2, Model.Command>,
  +actors: List<&2, Model.Actor>, events: List<&2, Model.BattleEvent>,
  +sequence: Nat
) -> CommitPart:
  match commands:
    case Nil{}:
      CommitPart{actors, events, sequence}
    case Model.BattleWait{+actor_id} <> rest:
      +ready_tick = U32.add(now, wait_ticks)
      key = {Model.EventKey{ready_tick, 0n, 0n, 0n,
        actor_id, sequence, 0n} : Model.EventKey}
      event = {Model.ReadyEvent{key, actor_id} : Model.BattleEvent}
      commit_commands(now, wait_ticks, rest,
        mark_waiting(actor_id, ready_tick, actors), event <> events,
        1n+sequence)
    case Model.BattleMove{+actor_id, +target_id, +windup, +recovery, +cooldown,
        +priority, +damage, +recoil} <> rest:
      +execution_tick = U32.add(now, windup)
      key = {Model.EventKey{execution_tick, 1n, priority,
        actor_speed(actor_id, actors), actor_id, sequence, 0n} : Model.EventKey}
      event = {Model.ExecuteEvent{key, actor_id, target_id, recovery,
        cooldown, damage, recoil} : Model.BattleEvent}
      commit_commands(now, wait_ticks, rest,
        mark_windup(actor_id, execution_tick, actors), event <> events,
        1n+sequence)
    case Model.BattleUtility{+actor_id, +target_id, +windup, +recovery,
        +priority} <> rest:
      +execution_tick = U32.add(now, windup)
      key = {Model.EventKey{execution_tick, 1n, priority,
        actor_speed(actor_id, actors), actor_id, sequence, 0n} : Model.EventKey}
      event = {Model.UtilityEvent{key, actor_id, target_id, recovery}
        : Model.BattleEvent}
      commit_commands(now, wait_ticks, rest,
        mark_windup(actor_id, execution_tick, actors), event <> events,
        1n+sequence)

def submit_commit(
  part: CommitPart, +now: U32, +wait_ticks: U32,
  events: List<&2, Model.BattleEvent>
) -> Model.SubmitResult:
  match part:
    case CommitPart{next_actors, +added_events, following_sequence}:
      +combined = List.append(&2, Model.BattleEvent, added_events, events)
      Model.Accepted{Model.BattleState{now, wait_ticks, next_actors,
        List.sort(~Model.BattleEvent, ~Model.BattleEvent.le, combined),
        following_sequence, Model.Advancing{}},
        List.sort(~Model.BattleEvent, ~Model.BattleEvent.le, added_events)}

def submit_diagnostics(
  diagnostics: List<&2, Model.Diagnostic>, +state: Model.BattleState,
  +now: U32, +wait_ticks: U32, ordered: List<&2, Model.Command>,
  actors: List<&2, Model.Actor>, events: List<&2, Model.BattleEvent>,
  +next_sequence: Nat
) -> Model.SubmitResult:
  match diagnostics:
    case diagnostic <> rest:
      Model.Rejected{state, diagnostic <> rest}
    case Nil{}:
      submit_commit(commit_commands(now, wait_ticks, ordered, actors, Nil{},
        next_sequence), now, wait_ticks, events)

def submit_complete(
  complete: Bool, +state: Model.BattleState, +now: U32, +wait_ticks: U32,
  +ordered: List<&2, Model.Command>, +actors: List<&2, Model.Actor>,
  events: List<&2, Model.BattleEvent>, +next_sequence: Nat
) -> Model.SubmitResult:
  match complete:
    case False{}:
      Model.Rejected{state, [Model.IncompleteBarrier{}]}
    case True{}:
      submit_diagnostics(validate_commands(now, wait_ticks, ordered, actors), state, now,
        wait_ticks, ordered, actors, events, next_sequence)

def submit_wait_valid(
  valid: Bool, +state: Model.BattleState, +now: U32, +wait_ticks: U32,
  +ordered: List<&2, Model.Command>, +actors: List<&2, Model.Actor>,
  events: List<&2, Model.BattleEvent>, +next_sequence: Nat
) -> Model.SubmitResult:
  match valid:
    case False{}:
      Model.Rejected{state, [Model.InvalidWaitSetting{}]}
    case True{}:
      +ready_ids = sorted_actor_ids(collect_ready_ids(actors))
      +submitted_ids = command_ids(ordered)
      submit_complete(ids_equal(ready_ids, submitted_ids), state, now,
        wait_ticks, ordered, actors, events, next_sequence)

def submit_ready(
  +state: Model.BattleState, commands: List<&2, Model.Command>
) -> Model.SubmitResult:
  Model.BattleState{+now, +wait_ticks, +actors, +events, +next_sequence,
    status} = state
  submit_wait_valid(wait_setting_ok(wait_ticks), state, now, wait_ticks,
    sorted_commands(commands), actors, events, next_sequence)

def submit(+state: Model.BattleState, commands: List<&2, Model.Command>) ->
  Model.SubmitResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        Model.AwaitingCommands{}}:
      submit_ready(state, commands)
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      Model.Rejected{state, [Model.BattleNotAwaiting{}]}
