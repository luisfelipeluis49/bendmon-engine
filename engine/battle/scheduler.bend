import Base
import ./model.bend as Model

def wait_setting_ok(wait_ticks: Nat) -> Bool:
  Bool.or(Nat.is_eq(wait_ticks, 30n),
    Bool.or(Nat.is_eq(wait_ticks, 60n), Nat.is_eq(wait_ticks, 120n)))

def deadline(+now: Nat, +duration: Nat) -> Maybe<&2, Nat>:
  +result = Nat.add(now, duration)
  match Nat.is_le(result, 216000n):
    case False{}:
      None{}
    case True{}:
      Some{result}

def Actor.is_ready(actor: Model.Actor) -> Bool:
  match actor:
    case Model.Actor{id, side, hp, speed, phase, cooldown}:
      match hp:
        case 0n:
          False{}
        case 1n+p:
          match phase:
            case Model.Ready{}:
              True{}
            case _:
              False{}

def collect_ready_ids(actors: List<&2, Model.Actor>) -> List<&2, Model.ActorId>:
  match actors:
    case Nil{}:
      Nil{}
    case +actor <> rest:
      ready = Actor.is_ready(actor)
      match ready:
        case False{}:
          collect_ready_ids(rest)
        case True{}:
          match actor:
            case Model.Actor{id, side, hp, speed, phase, cooldown}:
              id <> collect_ready_ids(rest)

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

def find_actor(+wanted: Model.ActorId, actors: List<&2, Model.Actor>) -> Maybe<&2, Model.Actor>:
  match actors:
    case Nil{}:
      None{}
    case +actor <> rest:
      match actor:
        case Model.Actor{+id, side, hp, speed, phase, cooldown}:
          equal = Model.ActorId.eq(wanted, id)
          match equal:
            case True{}:
              Some{actor}
            case False{}:
              find_actor(wanted, rest)

def same_side(left: Model.Side, right: Model.Side) -> Bool:
  match left right:
    case Model.Player{} Model.Player{}:
      True{}
    case Model.Enemy{} Model.Enemy{}:
      True{}
    case _ _:
      False{}

def target_ok(attacker: Model.Actor, target: Model.Actor) -> Bool:
  match attacker target:
    case Model.Actor{a_id, a_side, a_hp, a_speed, a_phase, a_cooldown}
        Model.Actor{t_id, t_side, t_hp, t_speed, t_phase, t_cooldown}:
      match t_hp:
        case 0n:
          False{}
        case 1n+p:
          Bool.and(Bool.not(same_side(a_side, t_side)),
            Bool.not(Model.ActorId.eq(a_id, t_id)))

def timing_ok(+windup: Nat, +recovery: Nat, +cooldown: Nat, +priority: Nat) -> Bool:
  Bool.and(Nat.is_le(windup, 600n), Bool.and(
    Bool.and(Nat.is_ge(recovery, 30n), Nat.is_le(recovery, 600n)),
    Bool.and(Bool.and(Nat.is_ge(cooldown, 60n), Nat.is_le(cooldown, 3600n)),
      Nat.is_le(priority, 16n))))

def validate_move_deadlines(
  actor_id: Model.ActorId, +now: Nat, +windup: Nat, +recovery: Nat,
  +cooldown: Nat
) -> List<&2, Model.Diagnostic>:
  execution_result = deadline(now, windup)
  match execution_result:
    case None{}:
      [Model.DeadlineOverflow{actor_id}]
    case Some{+execution}:
      ready_result = deadline(execution, recovery)
      match ready_result:
        case None{}:
          [Model.DeadlineOverflow{actor_id}]
        case Some{ready}:
          cooldown_result = deadline(execution, cooldown)
          match cooldown_result:
            case None{}:
              [Model.DeadlineOverflow{actor_id}]
            case Some{cooldown_deadline}:
              Nil{}

def validate_command(
  +now: Nat, command: Model.Command, +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match command:
    case Model.BattleWait{+actor_id}:
      actor_result = find_actor(actor_id, actors)
      match actor_result:
        case None{}:
          [Model.ActorMissing{actor_id}]
        case Some{actor}:
          ready = Actor.is_ready(actor)
          match ready:
            case False{}:
              [Model.ActorNotReady{actor_id}]
            case True{}:
              Nil{}
    case Model.BattleMove{+actor_id, +target_id, +windup, +recovery, +cooldown,
        +priority, damage, recoil}:
      actor_result = find_actor(actor_id, actors)
      match actor_result:
        case None{}:
          [Model.ActorMissing{actor_id}]
        case Some{+actor}:
          ready = Actor.is_ready(actor)
          match ready:
            case False{}:
              [Model.ActorNotReady{actor_id}]
            case True{}:
              match actor:
                case Model.Actor{id, side, hp, speed, phase, +cooldown_deadline}:
                  cooldown_ready = Nat.is_ge(now, cooldown_deadline)
                  match cooldown_ready:
                    case False{}:
                      [Model.CooldownActive{actor_id}]
                    case True{}:
                      timing_valid = timing_ok(windup, recovery, cooldown, priority)
                      match timing_valid:
                        case False{}:
                          [Model.TimingInvalid{actor_id}]
                        case True{}:
                          target_result = find_actor(target_id, actors)
                          match target_result:
                            case None{}:
                              [Model.TargetInvalid{actor_id, target_id}]
                            case Some{target}:
                              target_valid = target_ok(actor, target)
                              match target_valid:
                                case False{}:
                                  [Model.TargetInvalid{actor_id, target_id}]
                                case True{}:
                                  validate_move_deadlines(actor_id, now, windup,
                                    recovery, cooldown)

def validate_commands(
  +now: Nat, commands: List<&2, Model.Command>, +actors: List<&2, Model.Actor>
) -> List<&2, Model.Diagnostic>:
  match commands:
    case Nil{}:
      Nil{}
    case command <> rest:
      List.append(&2, Model.Diagnostic,
        validate_command(now, command, actors),
        validate_commands(now, rest, actors))

def mark_waiting(
  wanted: Model.ActorId, ready_tick: Nat, actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case actor <> rest:
      match actor:
        case Model.Actor{+id, side, hp, speed, phase, cooldown}:
          equal = Model.ActorId.eq(wanted, id)
          match equal:
            case False{}:
              actor <> mark_waiting(wanted, ready_tick, rest)
            case True{}:
              Model.Actor{id, side, hp, speed, Model.Recovery{ready_tick}, cooldown} <> rest

def mark_windup(
  wanted: Model.ActorId, execution_tick: Nat, actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case actor <> rest:
      match actor:
        case Model.Actor{+id, side, hp, speed, phase, cooldown}:
          equal = Model.ActorId.eq(wanted, id)
          match equal:
            case False{}:
              actor <> mark_windup(wanted, execution_tick, rest)
            case True{}:
              Model.Actor{id, side, hp, speed, Model.Windup{execution_tick}, cooldown} <> rest

type CommitPart is Data:
  CommitPart{
    actors: List<&2, Model.Actor>,
    events: List<&2, Model.Event>,
    next_sequence: Nat
  }

def actor_speed(actor: Model.Actor) -> Nat:
  match actor:
    case Model.Actor{id, side, hp, speed, phase, cooldown}:
      speed

def commit_commands(
  +now: Nat, +wait_ticks: Nat, commands: List<&2, Model.Command>,
  actors: List<&2, Model.Actor>, events: List<&2, Model.Event>,
  sequence: Nat
) -> CommitPart:
  match commands:
    case Nil{}:
      CommitPart{actors, events, sequence}
    case Model.BattleWait{+actor_id} <> rest:
      ready_result = deadline(now, wait_ticks)
      match ready_result:
        case None{}:
          CommitPart{actors, events, sequence}
        case Some{ready_tick}:
          key = Model.EventKey{ready_tick, 0n, 0n, 0n, actor_id, sequence, 0n}
          event = Model.ReadyEvent{key, actor_id}
          commit_commands(now, wait_ticks, rest,
            mark_waiting(actor_id, ready_tick, actors), event <> events,
            1n+sequence)
    case Model.BattleMove{+actor_id, +target_id, +windup, +recovery, +cooldown,
        +priority, +damage, +recoil} <> rest:
      execution_result = deadline(now, windup)
      match execution_result:
        case None{}:
          CommitPart{actors, events, sequence}
        case Some{execution_tick}:
          actor_result = find_actor(actor_id, actors)
          match actor_result:
            case None{}:
              CommitPart{actors, events, sequence}
            case Some{actor}:
              key = Model.EventKey{execution_tick, 1n, priority,
                actor_speed(actor), actor_id, sequence, 0n}
              event = Model.ExecuteEvent{key, actor_id, target_id, recovery,
                cooldown, damage, recoil}
              commit_commands(now, wait_ticks, rest,
                mark_windup(actor_id, execution_tick, actors), event <> events,
                1n+sequence)

def reject_for_status(+state: Model.BattleState) -> Model.SubmitResult:
  Model.Rejected{state, [Model.BattleNotAwaiting{}]}

def submit_ready(
  +state: Model.BattleState, commands: List<&2, Model.Command>
) -> Model.SubmitResult:
  Model.BattleState{+now, +wait_ticks, +actors, +events, +next_sequence,
    status} = state
  +ordered = sorted_commands(commands)
  +ready_ids = sorted_actor_ids(collect_ready_ids(actors))
  +submitted_ids = command_ids(ordered)
  wait_valid = wait_setting_ok(wait_ticks)
  match wait_valid:
    case False{}:
      Model.Rejected{state, [Model.InvalidWaitSetting{}]}
    case True{}:
      barrier_complete = ids_equal(ready_ids, submitted_ids)
      match barrier_complete:
        case False{}:
          Model.Rejected{state, [Model.IncompleteBarrier{}]}
        case True{}:
          +diagnostics = validate_commands(now, ordered, actors)
          match diagnostics:
            case diagnostic <> rest:
              Model.Rejected{state, diagnostic <> rest}
            case Nil{}:
              CommitPart{next_actors, added_events, following_sequence} =
                commit_commands(now, wait_ticks, ordered, actors, Nil{},
                  next_sequence)
              +combined = List.append(&2, Model.Event, added_events, events)
              Model.Accepted{Model.BattleState{now, wait_ticks, next_actors,
                List.sort(~Model.Event, ~Model.Event.le, combined),
                following_sequence, Model.Advancing{}},
                List.sort(~Model.Event, ~Model.Event.le, added_events)}

def submit(+state: Model.BattleState, commands: List<&2, Model.Command>) ->
  Model.SubmitResult:
  match state:
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        Model.AwaitingCommands{}}:
      submit_ready(state, commands)
    case Model.BattleState{now, wait_ticks, actors, events, next_sequence,
        status}:
      reject_for_status(state)
