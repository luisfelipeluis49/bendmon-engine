import Base
import ./catalog.bend as Catalog
import ./playtest_world_command.bend as Commands
import ./world_session.bend as Session
import ./presentation_cues.bend as Presentation
import ./dialogue.bend as Dialogue
import ./dialogue_wire.bend as DialogueWire
import ./commands.bend as WorldCommands
import ./event_bridge.bend as EventBridge
import ./exploration.bend as Exploration
import ./geometry.bend as Geometry

type ReplayResult is Data:
  Replayed{session: Session.WorldSession, accepted: Nat,
    cues: List<&2, Presentation.Cue>}
  ReplayRejected{session: Session.WorldSession, accepted: Nat}
  ReplayEncounter{session: Session.WorldSession,
    encounter_id: Nat, accepted: Nat,
    cues: List<&2, Presentation.Cue>,
    remaining: List<&2, Commands.WorldCommand>}
  ReplayedDialogue{session: Session.WorldSession, accepted: Nat,
    cues: List<&2, Presentation.Cue>, dialogue_id: Nat,
    line_index: Nat, closed: Bool}
  ReplayDialogueRejected{session: Session.WorldSession, accepted: Nat,
    dialogue_id: Nat, line_index: Nat}

type TracePoint is Data:
  TracePoint{command_index: Nat, logical_tick: Nat}

type TracedReplay is Data:
  TracedReplay{result: ReplayResult, trace: List<&2, TracePoint>}

type DialogueProgress is Data:
  DialogueProgress{cursor: Dialogue.Cursor, dialogue_id: Nat,
    line_index: Nat, closed: Bool}

def result_accepted(result: ReplayResult) -> Nat:
  match result:
    case Replayed{session, accepted, cues}: accepted
    case ReplayRejected{session, accepted}: accepted
    case ReplayEncounter{session, encounter_id, accepted, cues, remaining}:
      accepted
    case ReplayedDialogue{session, accepted, cues, dialogue_id, line_index,
        closed}: accepted
    case ReplayDialogueRejected{session, accepted, dialogue_id, line_index}:
      accepted

@unsafe def world_trace_rows(count: Nat, +index: Nat) ->
  List<&2, TracePoint>:
  match count:
    case 0n: []
    case 1n+rest:
      TracePoint{index, 0n} <> world_trace_rows(rest, Nat.add(index, 1n))

def traced_from(+result: ReplayResult, +index: Nat) -> TracedReplay:
  TracedReplay{result,
    world_trace_rows(Nat.sub(result_accepted(result), index), index)}

def traced(result: ReplayResult) -> TracedReplay:
  traced_from(result, 0n)

@unsafe def trace_reverse(rows: List<&2, TracePoint>,
  acc: List<&2, TracePoint>) -> List<&2, TracePoint>:
  match rows:
    case Nil{}: acc
    case row <> rest: trace_reverse(rest, row <> acc)

@unsafe def world_trace_fold(commands: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, session: Session.WorldSession, accepted: Nat,
  +index: Nat, +rows: List<&2, TracePoint>,
  cues: List<&2, Presentation.Cue>) -> TracedReplay:
  match commands:
    case Nil{}:
      TracedReplay{Replayed{session, accepted, cues}, trace_reverse(rows, [])}
    case command <> rest:
      +count = Nat.add(accepted, 1n)
      world_trace_route(Commands.run(catalog, session, command, count),
        rest, catalog, count, index, rows)

@unsafe def world_trace_route(result: Session.PresentedResult,
  rest: List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  count: Nat, +index: Nat, rows: List<&2, TracePoint>) -> TracedReplay:
  match result:
    case Session.PresentedResult{Session.Advanced{state}, cues}:
      world_trace_fold(rest, catalog, state, count, Nat.add(index, 1n),
        TracePoint{index, 0n} <> rows, cues)
    case Session.PresentedResult{Session.EncounterPending{state, encounter_id}, cues}:
      TracedReplay{ReplayEncounter{state, encounter_id, count, cues, rest},
        trace_reverse(TracePoint{index, 0n} <> rows, [])}
    case Session.PresentedResult{Session.Rejected{state}, cues}:
      TracedReplay{ReplayRejected{state, Nat.sub(count, 1n)},
        trace_reverse(rows, [])}
    case Session.PresentedResult{Session.EventAborted{state, diagnostic}, cues}:
      TracedReplay{ReplayRejected{state, Nat.sub(count, 1n)}, trace_reverse(rows, [])}
    case Session.PresentedResult{Session.EncounterReady{state, species, level}, cues}:
      TracedReplay{ReplayRejected{state, Nat.sub(count, 1n)}, trace_reverse(rows, [])}
    case Session.PresentedResult{Session.BattleAdvanced{state, status, events}, cues}:
      TracedReplay{ReplayRejected{state, Nat.sub(count, 1n)}, trace_reverse(rows, [])}
    case Session.PresentedResult{Session.BattleReturned{state, status, events, captures}, cues}:
      TracedReplay{ReplayRejected{state, Nat.sub(count, 1n)}, trace_reverse(rows, [])}
    case Session.PresentedResult{Session.BattleChoice{state}, cues}:
      TracedReplay{ReplayRejected{state, Nat.sub(count, 1n)}, trace_reverse(rows, [])}

def association_dialogue(+map_id: Nat, +npc_id: Nat,
  associations: List<&2, DialogueWire.Association>) -> Maybe<&2, Nat>:
  match associations:
    case Nil{}: None{}
    case DialogueWire.Association{+row_map, +row_npc, +dialogue_id} <> rest:
      Bool.pick(Maybe<&2, Nat>, Bool.and(Nat.is_eq(map_id, row_map),
        Nat.is_eq(npc_id, row_npc)), Some{dialogue_id},
        association_dialogue(map_id, npc_id, rest))

def dialogue_record(+id: Nat, records: List<&2, Dialogue.Record>) ->
  Maybe<&2, Dialogue.Record>:
  match records:
    case Nil{}: None{}
    case Dialogue.Record{+row_id, +lines} <> rest:
      Bool.pick(Maybe<&2, Dialogue.Record>, Nat.is_eq(id, row_id),
        Some{Dialogue.Record{row_id, lines}}, dialogue_record(id, rest))

def session_map(session: Session.WorldSession) -> Maybe<&2, Nat>:
  match session:
    case Session.WorldSession{EventBridge.State{
        Exploration.State{map_id, point, meter, pending, identity},
        persistent, active}, battle}:
      Some{map_id}
    case _: None{}

def dialogue_for_interaction(valid: Bool, map: Maybe<&2, Nat>, npc_id: Nat,
  associations: List<&2, DialogueWire.Association>) -> Maybe<&2, Nat>:
  match valid map:
    case True{} Some{map_id}: association_dialogue(map_id, npc_id,
      associations)
    case _ _: None{}

def interaction_dialogue(catalog: Catalog.Catalog,
  session: Session.WorldSession, +npc_id: Nat,
  +facing_x: Geometry.Coord, +facing_z: Geometry.Coord,
  associations: List<&2, DialogueWire.Association>) -> Maybe<&2, Nat>:
  match session:
    case Session.WorldSession{+world, progression}:
      dialogue_for_interaction(WorldCommands.interaction_valid(catalog,
        world, npc_id, facing_x, facing_z), session_map(session), npc_id,
        associations)
    case _: None{}

def started_progress(id: Nat, action: Dialogue.Action) ->
  Maybe<&2, DialogueProgress>:
  match action:
    case Dialogue.Started{cursor, line}:
      Some{DialogueProgress{cursor, id, 0n, False{}}}
    case _: None{}

def record_started(id: Nat, found: Maybe<&2, Dialogue.Record>) ->
  Maybe<&2, DialogueProgress>:
  match found:
    case None{}: None{}
    case Some{record}: started_progress(id, Dialogue.start(record))

def record_progress(+id: Nat, records: List<&2, Dialogue.Record>) ->
  Maybe<&2, DialogueProgress>:
  record_started(id, dialogue_record(id, records))

def interaction_progress(result: Maybe<&2, Nat>,
  records: List<&2, Dialogue.Record>) -> Maybe<&2, DialogueProgress>:
  match result:
    case None{}: None{}
    case Some{id}: record_progress(id, records)

def event_bridge(session: Session.WorldSession) -> Maybe<&2, EventBridge.State>:
  match session:
    case Session.WorldSession{world, progression}: Some{world}
    case _: None{}

def start_interaction_command(session: Session.WorldSession,
  catalog: Catalog.Catalog, +npc_id: Nat, +facing_x: Geometry.Coord,
  +facing_z: Geometry.Coord, associations: List<&2, DialogueWire.Association>,
  records: List<&2, Dialogue.Record>) -> Maybe<&2, DialogueProgress>:
  interaction_progress(interaction_dialogue(catalog, session, npc_id,
    facing_x, facing_z, associations), records)

def advanced_progress(id: Nat, line_index: Nat, action: Dialogue.Action) ->
  Maybe<&2, DialogueProgress>:
  match action:
    case Dialogue.Advanced{cursor, line}:
      Some{DialogueProgress{cursor, id, Nat.add(line_index, 1n), False{}}}
    case Dialogue.Completed{cursor}:
      Some{DialogueProgress{Dialogue.Closed{}, id, line_index, True{}}}
    case _: None{}

def dialogue_advance_progress(progress: DialogueProgress) ->
  Maybe<&2, DialogueProgress>:
  match progress:
    case DialogueProgress{Dialogue.Showing{+id, +remaining}, old_id,
        line_index, closed}:
      advanced_progress(id, line_index,
        Dialogue.advance(Dialogue.Showing{id, remaining}))
    case _: None{}

def progress_closed(progress: DialogueProgress) -> Bool:
  match progress:
    case DialogueProgress{cursor, id, line_index, closed}: closed

def progress_id(progress: DialogueProgress) -> Nat:
  match progress:
    case DialogueProgress{cursor, id, line_index, closed}: id

def progress_index(progress: DialogueProgress) -> Nat:
  match progress:
    case DialogueProgress{cursor, id, line_index, closed}: line_index

def final_dialogue(session: Session.WorldSession, accepted: Nat,
  cues: List<&2, Presentation.Cue>, +progress: DialogueProgress) -> ReplayResult:
  ReplayedDialogue{session, accepted, cues, progress_id(progress),
    progress_index(progress), progress_closed(progress)}

def final_closed(session: Session.WorldSession, accepted: Nat,
  cues: List<&2, Presentation.Cue>) -> ReplayResult:
  ReplayedDialogue{session, accepted, cues, 0n, 0n, True{}}

@unsafe def normal_result(result: Session.PresentedResult,
  rest: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  count: Nat, +progress: DialogueProgress,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>) -> ReplayResult:
  match result:
    case Session.PresentedResult{Session.Advanced{state}, cues}:
      dialogue_rows(rest, catalog, state, count, progress, cues,
        records, associations)
    case Session.PresentedResult{Session.EncounterPending{state,
        encounter_id}, cues}:
      ReplayEncounter{state, encounter_id, count, cues, rest}
    case Session.PresentedResult{Session.Rejected{state}, cues}:
      ReplayDialogueRejected{state, Nat.sub(count, 1n),
        progress_id(progress), progress_index(progress)}
    case Session.PresentedResult{Session.EventAborted{state, diagnostic}, cues}:
      ReplayDialogueRejected{state, Nat.sub(count, 1n),
        progress_id(progress), progress_index(progress)}
    case Session.PresentedResult{Session.EncounterReady{state,
        species, level}, cues}:
      ReplayDialogueRejected{state, Nat.sub(count, 1n),
        progress_id(progress), progress_index(progress)}
    case Session.PresentedResult{Session.BattleAdvanced{state,
        status, events}, cues}:
      ReplayDialogueRejected{state, Nat.sub(count, 1n),
        progress_id(progress), progress_index(progress)}
    case Session.PresentedResult{Session.BattleReturned{state,
        status, events, captures}, cues}:
      ReplayDialogueRejected{state, Nat.sub(count, 1n),
        progress_id(progress), progress_index(progress)}
    case Session.PresentedResult{Session.BattleChoice{state}, cues}:
      ReplayDialogueRejected{state, Nat.sub(count, 1n),
        progress_id(progress), progress_index(progress)}

@unsafe def dialogue_rows(commands: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +session: Session.WorldSession, +count: Nat,
  +progress: DialogueProgress, +cues: List<&2, Presentation.Cue>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>) -> ReplayResult:
  match commands:
    case Nil{}: final_dialogue(session, count, cues, progress)
    case command <> rest:
      dialogue_command(rest, catalog, session, Nat.add(count, 1n), progress,
        cues, records, associations, command)

@unsafe def dialogue_command(rest: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +session: Session.WorldSession, +count: Nat,
  +progress: DialogueProgress, +cues: List<&2, Presentation.Cue>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  command: Commands.WorldCommand) -> ReplayResult:
  match progress command:
    case DialogueProgress{Dialogue.Showing{+id, +remaining}, +active_id,
        +line_index, closed} Commands.PlayAdvanceDialogue{}:
      advance_or_reject(dialogue_advance_progress(progress), rest, catalog,
        session, count, active_id, line_index, records, associations)
    case DialogueProgress{Dialogue.Showing{+id, +remaining}, +active_id,
        +line_index, closed} _:
      ReplayDialogueRejected{session, Nat.sub(count, 1n), active_id,
        line_index}
    case DialogueProgress{cursor, +active_id, +line_index, closed}
         Commands.PlayAdvanceDialogue{}:
      ReplayDialogueRejected{session, Nat.sub(count, 1n), active_id,
        line_index}
    case DialogueProgress{cursor, +active_id, +line_index, closed}
         Commands.PlayInteract{+npc_id, +facing_x, +facing_z}:
      start_or_run(rest, catalog, session, count, progress, cues, records,
        associations, Commands.PlayInteract{npc_id, facing_x, facing_z},
        start_interaction_command(session, catalog,
          npc_id, facing_x, facing_z, associations, records))
    case DialogueProgress{cursor, active_id, line_index, closed} _:
      normal_result(Commands.run(catalog, session, command, count), rest,
        catalog, count, progress, records, associations)

@unsafe def advance_or_reject(result: Maybe<&2, DialogueProgress>,
  rest: List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  session: Session.WorldSession, count: Nat, dialogue_id: Nat,
  line_index: Nat, +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>) -> ReplayResult:
  match result:
    case None{}:
      ReplayDialogueRejected{session, Nat.sub(count, 1n), dialogue_id,
        line_index}
    case Some{next}:
      dialogue_rows(rest, catalog, session, count, next, [], records,
        associations)

@unsafe def start_or_run(rest: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +session: Session.WorldSession, +count: Nat,
  +progress: DialogueProgress, +cues: List<&2, Presentation.Cue>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  command: Commands.WorldCommand,
  started: Maybe<&2, DialogueProgress>) -> ReplayResult:
  match started:
    case Some{next}:
      dialogue_rows(rest, catalog, session, count, next, [], records,
        associations)
    case None{}:
      normal_result(Commands.run(catalog, session, command, count), rest,
        catalog, count, progress, records, associations)

@unsafe def dialogue_trace_rows(commands: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +session: Session.WorldSession, +accepted: Nat,
  +progress: DialogueProgress, +cues: List<&2, Presentation.Cue>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  +rows: List<&2, TracePoint>) -> TracedReplay:
  match commands:
    case Nil{}:
      TracedReplay{final_dialogue(session, accepted, cues, progress),
        trace_reverse(rows, [])}
    case command <> rest:
      dialogue_trace_command(rest, catalog, session,
        Nat.add(accepted, 1n), progress, cues, records, associations,
        rows, command)

@unsafe def dialogue_trace_command(rest: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +session: Session.WorldSession, +count: Nat,
  +progress: DialogueProgress, +cues: List<&2, Presentation.Cue>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  +rows: List<&2, TracePoint>, command: Commands.WorldCommand) -> TracedReplay:
  match progress command:
    case DialogueProgress{Dialogue.Showing{+id, +remaining}, +active_id,
        +line_index, closed} Commands.PlayAdvanceDialogue{}:
      dialogue_trace_advance(dialogue_advance_progress(progress), rest,
        catalog, session, count, active_id, line_index, records,
        associations, rows)
    case DialogueProgress{Dialogue.Showing{+id, +remaining}, +active_id,
        +line_index, closed} _:
      dialogue_trace_reject(session, Nat.sub(count, 1n), active_id,
        line_index, rows)
    case DialogueProgress{cursor, +active_id, +line_index, closed}
         Commands.PlayAdvanceDialogue{}:
      dialogue_trace_reject(session, Nat.sub(count, 1n), active_id,
        line_index, rows)
    case DialogueProgress{cursor, +active_id, +line_index, closed}
         Commands.PlayInteract{+npc_id, +facing_x, +facing_z}:
      dialogue_trace_start(rest, catalog, session, count, progress, cues,
        records, associations, rows,
        start_interaction_command(session, catalog, npc_id, facing_x,
          facing_z, associations, records),
        Commands.PlayInteract{npc_id, facing_x, facing_z})
    case DialogueProgress{cursor, active_id, line_index, closed} _:
      dialogue_trace_route(Commands.run(catalog, session, command, count),
        rest, catalog, count, progress, records, associations, rows)

@unsafe def dialogue_trace_advance(result: Maybe<&2, DialogueProgress>,
  rest: List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  +session: Session.WorldSession, +count: Nat, dialogue_id: Nat,
  line_index: Nat, +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  +rows: List<&2, TracePoint>) -> TracedReplay:
  match result:
    case None{}:
      dialogue_trace_reject(session, Nat.sub(count, 1n), dialogue_id,
        line_index, rows)
    case Some{next}:
      dialogue_trace_rows(rest, catalog, session, count, next, [], records,
        associations, TracePoint{Nat.sub(count, 1n), 0n} <> rows)

@unsafe def dialogue_trace_start(rest: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +session: Session.WorldSession, +count: Nat,
  +progress: DialogueProgress, +cues: List<&2, Presentation.Cue>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  +rows: List<&2, TracePoint>, started: Maybe<&2, DialogueProgress>,
  command: Commands.WorldCommand) -> TracedReplay:
  match started:
    case Some{next}:
      dialogue_trace_rows(rest, catalog, session, count, next, [], records,
        associations, TracePoint{Nat.sub(count, 1n), 0n} <> rows)
    case None{}:
      dialogue_trace_route(Commands.run(catalog, session, command, count),
        rest, catalog, count, progress, records, associations, rows)

@unsafe def dialogue_trace_route(result: Session.PresentedResult,
  rest: List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  +count: Nat, +progress: DialogueProgress,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  +rows: List<&2, TracePoint>) -> TracedReplay:
  match result:
    case Session.PresentedResult{Session.Advanced{state}, cues}:
      dialogue_trace_rows(rest, catalog, state, count, progress, cues,
        records, associations, TracePoint{Nat.sub(count, 1n), 0n} <> rows)
    case Session.PresentedResult{Session.EncounterPending{state,
        encounter_id}, cues}:
      TracedReplay{ReplayEncounter{state, encounter_id, count, cues, rest},
        trace_reverse(TracePoint{Nat.sub(count, 1n), 0n} <> rows, [])}
    case Session.PresentedResult{Session.Rejected{state}, cues}:
      dialogue_trace_reject(state, Nat.sub(count, 1n), progress_id(progress),
        progress_index(progress), rows)
    case Session.PresentedResult{Session.EventAborted{state, diagnostic}, cues}:
      dialogue_trace_reject(state, Nat.sub(count, 1n), progress_id(progress),
        progress_index(progress), rows)
    case Session.PresentedResult{Session.EncounterReady{state, species, level}, cues}:
      dialogue_trace_reject(state, Nat.sub(count, 1n), progress_id(progress),
        progress_index(progress), rows)
    case Session.PresentedResult{Session.BattleAdvanced{state, status, events}, cues}:
      dialogue_trace_reject(state, Nat.sub(count, 1n), progress_id(progress),
        progress_index(progress), rows)
    case Session.PresentedResult{Session.BattleReturned{state, status, events, captures}, cues}:
      dialogue_trace_reject(state, Nat.sub(count, 1n), progress_id(progress),
        progress_index(progress), rows)
    case Session.PresentedResult{Session.BattleChoice{state}, cues}:
      dialogue_trace_reject(state, Nat.sub(count, 1n), progress_id(progress),
        progress_index(progress), rows)

def dialogue_trace_reject(session: Session.WorldSession, accepted: Nat,
  dialogue_id: Nat, line_index: Nat,
  rows: List<&2, TracePoint>) -> TracedReplay:
  TracedReplay{ReplayDialogueRejected{session, accepted, dialogue_id,
    line_index}, trace_reverse(rows, [])}

@unsafe def next(rest: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  state: Session.WorldSession, count: Nat,
  cues: List<&2, Presentation.Cue>) -> ReplayResult:
  replay_rows(rest, catalog, state, count, cues)

def accepted_result(rest: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, state: Session.WorldSession, count: Nat,
  prior: List<&2, Presentation.Cue>,
  current: List<&2, Presentation.Cue>) -> ReplayResult:
  next(rest, catalog, state, count, current)

@unsafe def route(result: Session.PresentedResult,
  rest: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  count: Nat, cues: List<&2, Presentation.Cue>) -> ReplayResult:
  match result:
    case Session.PresentedResult{Session.Advanced{state}, current}:
      accepted_result(rest, catalog, state, count, cues, current)
    case Session.PresentedResult{Session.Rejected{state}, current}:
      ReplayRejected{state, Nat.sub(count, 1n)}
    case Session.PresentedResult{Session.EventAborted{state, diagnostic},
        current}:
      ReplayRejected{state, Nat.sub(count, 1n)}
    case Session.PresentedResult{Session.EncounterPending{state,
        encounter_id}, current}:
      ReplayEncounter{state, encounter_id, count, current, rest}
    case Session.PresentedResult{Session.EncounterReady{state,
        species, level}, current}:
      ReplayRejected{state, Nat.sub(count, 1n)}
    case Session.PresentedResult{Session.BattleAdvanced{state,
        status, events}, current}:
      ReplayRejected{state, Nat.sub(count, 1n)}
    case Session.PresentedResult{Session.BattleReturned{state,
        status, events, captures}, current}:
      ReplayRejected{state, Nat.sub(count, 1n)}
    case Session.PresentedResult{Session.BattleChoice{state}, current}:
      ReplayRejected{state, Nat.sub(count, 1n)}

# The staged recursion shrinks the command list. A public bound below keeps the
# compiler's unproved helper from consuming unbounded creator input.
@unsafe def replay_rows(commands: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, session: Session.WorldSession,
  +accepted: Nat, cues: List<&2, Presentation.Cue>) -> ReplayResult:
  match commands:
    case Nil{}: Replayed{session, accepted, cues}
    case command <> rest:
      +next_count = Nat.add(accepted, 1n)
      route(Commands.run(catalog, session, command,
        next_count), rest, catalog, next_count, cues)

def replay_checked(allowed: Bool,
  commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession) -> ReplayResult:
  match allowed:
    case False{}: ReplayRejected{session, 0n}
    case True{}: replay_rows(commands, catalog, session, 0n, [])

# Replaying a bounded accepted log starts from a fresh boot. Only the final
# command's cues are returned, so old effects are never presented a second time.
# On rejection, the caller leaves the candidate out of its canonical log.
def run(+commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession) -> ReplayResult:
  replay_checked(Nat.is_le(List.length(&2, Commands.WorldCommand,
    commands), 4096n), commands, catalog, session)

# World, event and dialogue clocks pause between battles, so their authoritative
# post-command tick is zero. Indices identify accepted replay commands only.
def traced_checked(allowed: Bool,
  commands: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  session: Session.WorldSession) -> TracedReplay:
  match allowed:
    case False{}: TracedReplay{ReplayRejected{session, 0n}, []}
    case True{}: world_trace_fold(commands, catalog, session, 0n, 0n, [], [])

def run_traced(+commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession) -> TracedReplay:
  traced_checked(Nat.is_le(List.length(&2, Commands.WorldCommand,
    commands), 4096n), commands, catalog, session)

# Dialogue-aware replay is used by M10 after the host has identity-checked the
# authored dialogue payload. It keeps dialogue state local to one replay.
def dialogue_run_checked(allowed: Bool,
  +commands: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  session: Session.WorldSession, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>) -> ReplayResult:
  match allowed:
    case False{}: ReplayDialogueRejected{session, 0n, 0n, 0n}
    case True{}:
      dialogue_rows(commands, catalog, session, 0n,
        DialogueProgress{Dialogue.Closed{}, 0n, 0n, True{}}, [], records,
        associations)

def run_dialogue(+commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>) -> ReplayResult:
  dialogue_run_checked(Nat.is_le(List.length(&2, Commands.WorldCommand,
    commands), 4096n), commands, catalog, session, records, associations)

def dialogue_trace_checked(allowed: Bool,
  +commands: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  session: Session.WorldSession, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>, accepted_before: Nat)
  -> TracedReplay:
  match allowed:
    case False{}:
      TracedReplay{ReplayDialogueRejected{session, 0n, 0n, 0n}, []}
    case True{}:
      dialogue_trace_rows(commands, catalog, session, accepted_before,
        DialogueProgress{Dialogue.Closed{}, 0n, 0n, True{}}, [], records,
        associations, [])

def dialogue_trace_from_checked(allowed: Bool,
  +commands: List<&2, Commands.WorldCommand>, catalog: Catalog.Catalog,
  session: Session.WorldSession, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>, accepted_before: Nat)
  -> TracedReplay:
  match allowed:
    case False{}:
      TracedReplay{ReplayDialogueRejected{session, accepted_before, 0n, 0n}, []}
    case True{}:
      dialogue_trace_rows(commands, catalog, session, accepted_before,
        DialogueProgress{Dialogue.Closed{}, 0n, 0n, True{}}, [], records,
        associations, [])


def run_dialogue_traced(+commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>) -> TracedReplay:
  dialogue_trace_checked(Nat.is_le(List.length(&2, Commands.WorldCommand,
    commands), 4096n), commands, catalog, session, records, associations,
    0n)

def dialogue_from_checked(allowed: Bool,
  +commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  accepted_before: Nat) -> ReplayResult:
  match allowed:
    case False{}:
      ReplayDialogueRejected{session, accepted_before, 0n, 0n}
    case True{}:
      dialogue_rows(commands, catalog, session, accepted_before,
        DialogueProgress{Dialogue.Closed{}, 0n, 0n, True{}}, [], records,
        associations)

# Continues the same ordered command log after a battle returned to the world.
# The offset preserves cue ordinals and accepted-prefix counts across phases.
def run_dialogue_from(+commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  +accepted_before: Nat) -> ReplayResult:
  dialogue_from_checked(Nat.is_le(Nat.add(accepted_before,
    List.length(&2, Commands.WorldCommand, commands)), 4096n),
    commands, catalog, session, records, associations, accepted_before)

def run_dialogue_from_traced(+commands: List<&2, Commands.WorldCommand>,
  catalog: Catalog.Catalog, session: Session.WorldSession,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  +accepted_before: Nat) -> TracedReplay:
  dialogue_trace_from_checked(Nat.is_le(Nat.add(accepted_before,
    List.length(&2, Commands.WorldCommand, commands)), 4096n), commands,
    catalog, session, records, associations, accepted_before)
