import Base
import ../battle/model.bend as Battle
import ../battle/reducer.bend as Reducer
import ../battle/runtime.bend as Runtime
import ../m7/battle.bend as M7Battle
import ../m7/playable.bend as Playable
import ../m7/session.bend as M7Session
import ./battle_bridge.bend as BattleBridge
import ./playtest_world_command.bend as Commands
import ./world_session.bend as Session
import ./playtest_battle_move.bend as BattleMove
import ../m7/dynamic_species.bend as Species
import ../m7/dynamic_moves.bend as Moves

type ReplayResult is Data:
  Replayed{session: Session.WorldSession, accepted: Nat}
  ReplayRejected{session: Session.WorldSession, accepted: Nat}
  ReplayStopped{session: Session.WorldSession, accepted: Nat,
    remaining: List<&2, Commands.WorldCommand>}

type TracePoint is Data:
  TracePoint{command_index: Nat, pre_tick: Nat, post_tick: Nat,
    ai_wait: Bool}

type TracedReplay is Data:
  TracedReplay{result: ReplayResult, trace: List<&2, TracePoint>}

# M7 treats this as the per-submit interpreter budget. Each wait or escape
# receives 4096 runtime units to validate and execute its submitted command.
def ready_phase(phase: Battle.Phase) -> Bool:
  match phase:
    case Battle.Ready{}: True{}
    case _: False{}

@unsafe def enemy_ready_after_match(found: Bool, phase: Battle.Phase,
  rest: List<&2, Battle.Actor>) -> Bool:
  match found:
    case True{}: ready_phase(phase)
    case False{}: enemy_ready(rest)

def enemy_ready(actors: List<&2, Battle.Actor>) -> Bool:
  match actors:
    case Nil{}: False{}
    case Battle.Actor{id, side, hp, speed, phase, cooldown} <> rest:
      enemy_ready_after_match(Battle.ActorId.eq(id, Battle.ActorId{1n}),
        phase, rest)

def battling_runtime(session: Session.WorldSession) -> Maybe<&2, Runtime.RuntimeState>:
  match session:
    case Session.Battling{persistent,
        BattleBridge.State{world,
          Playable.PlayableSession{M7Session.State{battle, rewards, enemies,
            owners}, learning, evolution, choices, evolution_choices,
            pending, ruleset, identity}, returned}}:
      match battle:
        case M7Battle.State{runtime, economy, roster, captured, catalog}:
          Some{runtime}
    case _: None{}

def runtime_enemy_ready(found: Maybe<&2, Runtime.RuntimeState>) -> Bool:
  match found:
    case None{}: False{}
    case Some{runtime}: enemy_ready(Reducer.state_actors(
      Runtime.runtime_battle(runtime)))

def enemy_one_ready(session: Session.WorldSession) -> Bool:
  runtime_enemy_ready(battling_runtime(session))

@unsafe def player_ready_after_match(found: Bool, phase: Battle.Phase,
  rest: List<&2, Battle.Actor>) -> Bool:
  match found:
    case True{}: ready_phase(phase)
    case False{}: player_ready(rest)

def player_ready(actors: List<&2, Battle.Actor>) -> Bool:
  match actors:
    case Nil{}: False{}
    case Battle.Actor{id, side, hp, speed, phase, cooldown} <> rest:
      player_ready_after_match(Battle.ActorId.eq(id, Battle.ActorId{0n}),
        phase, rest)

def advance_needs_enemy_from_actors(+actors: List<&2, Battle.Actor>) -> Bool:
  Bool.and(enemy_ready(actors), Bool.not(player_ready(actors)))

def advance_needs_enemy(found: Maybe<&2, Runtime.RuntimeState>) -> Bool:
  match found:
    case None{}: False{}
    case Some{runtime}:
      advance_needs_enemy_from_actors(Reducer.state_actors(
        Runtime.runtime_battle(runtime)))

def runtime_player_ready(found: Maybe<&2, Runtime.RuntimeState>) -> Bool:
  match found:
    case None{}: False{}
    case Some{runtime}: player_ready(Reducer.state_actors(
      Runtime.runtime_battle(runtime)))

def battle_tick(battle: Battle.BattleState) -> Nat:
  match battle:
    case Battle.BattleState{now, wait_ticks, actors, events,
        next_sequence, status}: U32.to_nat(now)

def observed_tick(found: Maybe<&2, Runtime.RuntimeState>) -> Maybe<&2, Nat>:
  match found:
    case None{}: None{}
    case Some{runtime}: Some{battle_tick(Runtime.runtime_battle(runtime))}

def trace_tick(current: Maybe<&2, Nat>, prior: Nat) -> Nat:
  match current:
    case None{}: prior
    case Some{tick}: tick

def trace_reverse(rows: List<&2, TracePoint>) -> List<&2, TracePoint>:
  match rows:
    case Nil{}: []
    case row <> rest: List.append(&2, TracePoint,
      trace_reverse(rest), [row])

@unsafe def trace_rows(commands: List<&2, Commands.WorldCommand>,
  session: Session.WorldSession, index: Nat, prior_tick: Nat,
  +rows: List<&2, TracePoint>, +species: Species.Catalog,
  +moves: Moves.Catalog) -> List<&2, TracePoint>:
  match commands:
    case Nil{}: trace_reverse(rows)
    case command <> rest:
      trace_dispatch(command, rest, session, index, prior_tick, rows,
        species, moves)

def trace_ai_wait(command: Commands.WorldCommand,
  session: Session.WorldSession) -> Bool:
  match command:
    case Commands.PlayBattleWait{actor_id}:
      Bool.and(Nat.is_eq(actor_id, 0n), enemy_one_ready(session))
    case Commands.PlayBattleEscape{actor_id}:
      Bool.and(Nat.is_eq(actor_id, 0n), enemy_one_ready(session))
    case Commands.PlayBattleMove{actor_id, target_id, move_id}:
      Bool.and(Nat.is_eq(actor_id, 0n), enemy_one_ready(session))
    case Commands.PlayAdvanceBattle{}:
      advance_needs_enemy(battling_runtime(session))
    case _: False{}

@unsafe def trace_command(+command: Commands.WorldCommand,
  result: Session.SessionResult, rest: List<&2, Commands.WorldCommand>,
  pre_tick: Nat, ai_wait: Bool, index: Nat,
  +rows: List<&2, TracePoint>, +species: Species.Catalog,
  +moves: Moves.Catalog) -> List<&2, TracePoint>:
  match result:
    case Session.Advanced{state}:
      trace_accepted(command, rest, state, index, pre_tick, ai_wait,
        rows, species, moves)
    case Session.BattleAdvanced{state, status, events}:
      trace_accepted(command, rest, state, index, pre_tick, ai_wait,
        rows, species, moves)
    case Session.BattleReturned{state, status, events, captures}:
      trace_accepted(command, rest, state, index, pre_tick, ai_wait,
        rows, species, moves)
    case Session.BattleChoice{state}:
      trace_accepted(command, rest, state, index, pre_tick, ai_wait,
        rows, species, moves)
    case _: trace_reverse(rows)

@unsafe def trace_accepted(command: Commands.WorldCommand,
  rest: List<&2, Commands.WorldCommand>,
  +accepted_state: Session.WorldSession, +index: Nat, +prior_tick: Nat,
  ai_wait: Bool, +rows: List<&2, TracePoint>, +species: Species.Catalog,
  +moves: Moves.Catalog) -> List<&2, TracePoint>:
  +tick = trace_tick(observed_tick(battling_runtime(accepted_state)),
    prior_tick)
  trace_rows(rest, Session.resume_world(accepted_state), Nat.add(index, 1n),
    tick, TracePoint{Nat.sub(index, 1n), prior_tick, tick,
      ai_wait} <> rows, species, moves)

@unsafe def trace_dispatch(+command: Commands.WorldCommand,
  rest: List<&2, Commands.WorldCommand>, +session: Session.WorldSession,
  index: Nat, prior_tick: Nat, +rows: List<&2, TracePoint>,
  +species: Species.Catalog, +moves: Moves.Catalog) -> List<&2, TracePoint>:
  +pre_tick = trace_tick(observed_tick(battling_runtime(session)), prior_tick)
  +ai_wait = trace_ai_wait(command, session)
  trace_command(command, command_result(command, session, species, moves),
  rest, pre_tick, ai_wait, index, rows, species, moves)

def trace_checked(allowed: Bool,
  commands: List<&2, Commands.WorldCommand>, +session: Session.WorldSession,
  +species: Species.Catalog, +moves: Moves.Catalog) -> List<&2, TracePoint>:
  match allowed:
    case False{}: []
    case True{}:
      trace_rows(commands, session, 1n,
        trace_tick(observed_tick(battling_runtime(session)), 0n), [],
        species, moves)

def player_one_ready(session: Session.WorldSession) -> Bool:
  runtime_player_ready(battling_runtime(session))

def advance_enemy_result(result: Session.SessionResult) -> Session.SessionResult:
  match result:
    case Session.Advanced{state}: Session.advance_battle(state)
    case Session.Rejected{state}: Session.Rejected{state}
    case _: result

def advance_wait_enemy(needed: Bool,
  +session: Session.WorldSession) -> Session.SessionResult:
  match needed:
    case True{}:
      advance_enemy_result(Session.submit_battle(session, 4096n,
        [Runtime.RuntimeWait{Battle.ActorId{1n}}]))
    case False{}: Session.advance_battle(session)

# A ready enemy cannot be left at the command barrier while the player is in
# recovery. Feed its trusted wait before advancing; the player resumes input
# once its own authoritative phase becomes Ready.
def advance_battle(+session: Session.WorldSession) -> Session.SessionResult:
  advance_wait_enemy(Bool.and(enemy_one_ready(session),
    Bool.not(player_one_ready(session))), session)

# The dynamic M10 bootstrap assigns actor 1 to the trusted enemy. It must only
# receive an implicit wait when its authoritative phase is Ready.
def battle_barrier_commands(enemy_is_ready: Bool,
  action: Runtime.RuntimeCommand) -> List<&2, Runtime.RuntimeCommand>:
  match enemy_is_ready:
    case True{}:
      match action:
        case Runtime.RuntimeWait{source}:
          [Runtime.RuntimeWait{source},
            Runtime.RuntimeWait{Battle.ActorId{1n}}]
        case Runtime.RuntimeEscape{source}:
          [Runtime.RuntimeEscape{source},
            Runtime.RuntimeWait{Battle.ActorId{1n}}]
        case Runtime.RuntimeTypedMove{source, target, move, windup, recovery,
            cooldown, priority, recoil, attacker, program, components,
            actor_types, target_types, snapshot}:
          [action, Runtime.RuntimeWait{Battle.ActorId{1n}}]
        case Runtime.RuntimeEffectMove{source, target, move, windup, recovery,
            cooldown, priority, recoil, attacker, program, snapshot}:
          [action, Runtime.RuntimeWait{Battle.ActorId{1n}}]
        case _: [action]
    case False{}: [action]

def wait_submit(valid_actor: Bool, actor_id: Nat,
  +session: Session.WorldSession) -> Session.SessionResult:
  match valid_actor:
    case False{}: Session.Rejected{session}
    case True{}:
      Session.submit_battle(session, 4096n,
        battle_barrier_commands(enemy_one_ready(session),
          Runtime.RuntimeWait{Battle.ActorId{actor_id}}))

def escape_submit(valid_actor: Bool, actor_id: Nat,
  +session: Session.WorldSession) -> Session.SessionResult:
  match valid_actor:
    case False{}: Session.Rejected{session}
    case True{}:
      Session.submit_battle(session, 4096n,
        battle_barrier_commands(enemy_one_ready(session),
          Runtime.RuntimeEscape{Battle.ActorId{actor_id}}))

def move_submit(found: Maybe<Runtime.RuntimeCommand>,
  +session: Session.WorldSession) -> Session.SessionResult:
  match found:
    case None{}: Session.Rejected{session}
    case Some{action}:
      Session.submit_battle(session, 4096n,
        battle_barrier_commands(enemy_one_ready(session), action))

def command_result(command: Commands.WorldCommand,
  +session: Session.WorldSession, species: Species.Catalog,
  moves: Moves.Catalog) -> Session.SessionResult:
  match command:
    case Commands.PlayBattleWait{+actor_id}:
      wait_submit(Nat.is_eq(actor_id, 0n), actor_id, session)
    case Commands.PlayBattleEscape{+actor_id}:
      escape_submit(Nat.is_eq(actor_id, 0n), actor_id, session)
    case Commands.PlayBattleMove{actor_id, target_id, move_id}:
      move_submit(BattleMove.lower(command, session, species, moves), session)
    case Commands.PlayAdvanceBattle{}: advance_battle(session)
    case _: Session.Rejected{session}

def in_world(session: Session.WorldSession) -> Bool:
  match session:
    case Session.WorldSession{world, battle}: True{}
    case _: False{}

@unsafe def continue_result(result: Session.SessionResult,
  rest: List<&2, Commands.WorldCommand>, accepted_count: Nat,
  species: Species.Catalog, moves: Moves.Catalog) -> ReplayResult:
  match result:
    case Session.Advanced{state}:
      replay_rows(rest, Session.resume_world(state),
        Nat.add(accepted_count, 1n), species, moves)
    case Session.BattleAdvanced{state, status, events}:
      replay_rows(rest, Session.resume_world(state),
        Nat.add(accepted_count, 1n), species, moves)
    case Session.BattleReturned{state, status, events, captures}:
      replay_rows(rest, Session.resume_world(state),
        Nat.add(accepted_count, 1n), species, moves)
    case Session.BattleChoice{state}:
      replay_rows(rest, Session.resume_world(state),
        Nat.add(accepted_count, 1n), species, moves)
    case Session.Rejected{state}:
      ReplayRejected{Session.resume_world(state), accepted_count}
    case Session.EncounterReady{state, species, level}:
      ReplayRejected{Session.resume_world(state), accepted_count}
    case Session.EncounterPending{state, encounter_id}:
      ReplayRejected{Session.resume_world(state), accepted_count}
    case Session.EventAborted{state, diagnostic}:
      ReplayRejected{Session.resume_world(state), accepted_count}

def stop_or_reject(world: Bool,
  command: Commands.WorldCommand,
  rest: List<&2, Commands.WorldCommand>, session: Session.WorldSession,
  accepted_count: Nat) -> ReplayResult:
  match world:
    case True{}: ReplayStopped{session, accepted_count, command <> rest}
    case False{}: ReplayRejected{session, accepted_count}

@unsafe def dispatch(command: Commands.WorldCommand,
  rest: List<&2, Commands.WorldCommand>, +session: Session.WorldSession,
  accepted_count: Nat, +species: Species.Catalog, +moves: Moves.Catalog) -> ReplayResult:
  match command:
    case Commands.PlayBattleWait{actor_id}:
      continue_result(command_result(command, session, species, moves), rest,
        accepted_count, species, moves)
    case Commands.PlayBattleEscape{actor_id}:
      continue_result(command_result(command, session, species, moves), rest,
        accepted_count, species, moves)
    case Commands.PlayAdvanceBattle{}:
      continue_result(command_result(command, session, species, moves), rest,
        accepted_count, species, moves)
    case Commands.PlayBattleMove{actor_id, target_id, move_id}:
      continue_result(command_result(command, session, species, moves), rest,
        accepted_count, species, moves)
    case _: stop_or_reject(in_world(session), command, rest, session,
      accepted_count)

@unsafe def replay_rows(commands: List<&2, Commands.WorldCommand>,
  session: Session.WorldSession, accepted_count: Nat,
  species: Species.Catalog, moves: Moves.Catalog) -> ReplayResult:
  match commands:
    case Nil{}: Replayed{session, accepted_count}
    case command <> rest: dispatch(command, rest, session, accepted_count,
      species, moves)

def run_checked(allowed: Bool, +commands: List<&2, Commands.WorldCommand>,
  session: Session.WorldSession, species: Species.Catalog,
  moves: Moves.Catalog) -> ReplayResult:
  match allowed:
    case True{}: replay_rows(commands, session, 0n, species, moves)
    case False{}: ReplayRejected{session, 0n}

def run(+commands: List<&2, Commands.WorldCommand>,
  session: Session.WorldSession, species: Species.Catalog,
  moves: Moves.Catalog) -> ReplayResult:
  run_checked(Nat.is_le(List.length(&2, Commands.WorldCommand, commands),
    4096n), commands, session, species, moves)

def run_traced(+commands: List<&2, Commands.WorldCommand>,
  +session: Session.WorldSession, +species: Species.Catalog,
  +moves: Moves.Catalog) -> TracedReplay:
  TracedReplay{run(commands, session, species, moves),
    trace_checked(Nat.is_le(List.length(&2, Commands.WorldCommand,
      commands), 4096n), commands, session, species, moves)}
