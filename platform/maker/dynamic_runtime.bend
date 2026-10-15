import Base
import ../../engine/content/wire.bend as Numeric
import ../../engine/world/dynamic_catalog.bend as World
import ../../engine/world/dynamic_events.bend as EventWire
import ../../engine/m7/dynamic_species.bend as Species
import ../../engine/m7/dynamic_moves.bend as Moves
import ../../engine/world/dialogue_wire.bend as DialogueWire
import ../../engine/world/dialogue.bend as Dialogue
import ../../engine/world/dynamic_dialogue_join.bend as DialogueJoin
import ../../engine/world/dynamic_playable_encounter.bend as PlayableEncounter
import ../../engine/world/dynamic_content.bend as Content
import ../../engine/world/dynamic_battle_content.bend as PlaytestContent
import ../../engine/world/playtest_boot_wire.bend as BootWire
import ../../engine/world/playtest_boot.bend as Boot
import ../../engine/world/playtest_world_command.bend as Commands
import ../../engine/world/playtest_command_wire.bend as CommandWire
import ../../engine/world/playtest_replay.bend as Replay
import ../../engine/world/playtest_battle_replay.bend as BattleReplay
import ../../engine/world/encounter_handoff.bend as Handoff
import ../../engine/world/save_boundary.bend as Save
import ../../engine/world/full_save_boundary.bend as FullSave
import ../../engine/world/save_wire.bend as SaveWire
import ../../engine/world/save_wire_decode.bend as SaveWireDecode
import ../../engine/world/full_restore_wire_decode.bend as FullRestoreWire
import ../../engine/m7/persistent_state.bend as Persistent
import ../../engine/m7/persistent_wire_text.bend as PersistentText
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng
import ../../engine/world/presentation_cues.bend as Cues
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/world_session.bend as Session
import ../../engine/presentation/projection.bend as Projection
import ../../engine/presentation/wire.bend as PresentationWire

type NumberRead is Data:
  NumberBad{}
  NumberDone{values: List<&2, U32>}

type RestoreInput is Data:
  NoRestore{}
  HasRestore{snapshot: Save.Snapshot,
    progression: Maybe<&2, Persistent.PersistentState>}
  InvalidRestore{}

type RuntimeResult is Data:
  RuntimeRejected{}
  RuntimeAccepted{identity: U32, commands: Nat,
    dialogue_id: Nat, line_index: Nat, closed: Bool,
    scene: String, cues: String, save: String, progression: String,
    trace: TraceState}
  RuntimeEncounter{identity: U32, commands: Nat, encounter_id: Nat,
    scene: String, cues: String, trace: TraceState}
  RuntimeBattle{identity: U32, commands: Nat, encounter_id: Nat,
    scene: String, cues: String, trace: TraceState}

type TraceState is Data:
  TraceState{rows: String, count: Nat, last_tick: Nat}

type BattleInputs is Data:
  BattleInputs{tables: List<&2, Handoff.EncounterTable>,
    species: Species.Catalog, moves: Moves.Catalog,
    starter_species: Nat, starter_level: U32, wait_ticks: U32}

def empty_trace() -> TraceState:
  TraceState{"", 0n, 0n}

def trace_ai_bit(ai_wait: Bool) -> Nat:
  match ai_wait:
    case False{}: 0n
    case True{}: 1n

def trace_step(rows: String, index: Nat, pre_tick: Nat, post_tick: Nat,
  ai_wait: Bool) -> String:
  rows ++ "\nTRACE_STEP " ++ Nat.show(index) ++ "," ++ Nat.show(pre_tick) ++
    "," ++ Nat.show(post_tick) ++ "," ++ Nat.show(trace_ai_bit(ai_wait))

def world_trace(points: List<&2, Replay.TracePoint>,
  prior: TraceState) -> TraceState:
  match points prior:
    case Nil{} _: prior
    case Replay.TracePoint{index, paused_tick} <> rest
         TraceState{rows, count, +last_tick}:
      world_trace(rest, TraceState{trace_step(rows, index, last_tick,
        last_tick, False{}), Nat.add(count, 1n), last_tick})

def battle_trace_from(points: List<&2, BattleReplay.TracePoint>,
  prior: TraceState, +offset: Nat, +base_tick: Nat) -> TraceState:
  match points prior:
    case Nil{} _: prior
    case BattleReplay.TracePoint{index, local_pre_tick, local_post_tick,
        ai_wait} <> rest
         TraceState{rows, count, last_tick}:
      +pre_tick = Nat.add(base_tick, local_pre_tick)
      +post_tick = Nat.add(base_tick, local_post_tick)
      battle_trace_from(rest,
        TraceState{trace_step(rows, Nat.add(offset, index), pre_tick,
          post_tick, ai_wait), Nat.add(count, 1n), post_tick}, offset,
        base_tick)

def battle_trace(points: List<&2, BattleReplay.TracePoint>,
  prior: TraceState) -> TraceState:
  match prior:
    case TraceState{rows, +count, +last_tick}:
      battle_trace_from(points, prior, count, last_tick)

def trace_suffix(trace: TraceState) -> String:
  match trace:
    case TraceState{rows, count, last_tick}:
      "\nTRACE 2," ++ Nat.show(count) ++ rows

def numbers_read(values: List<&2, Maybe<&2, U32>>,
  acc: List<&2, U32>) -> NumberRead:
  match values:
    case Nil{}: NumberDone{List.reverse(&2, U32, acc)}
    case None{} <> rest: NumberBad{}
    case Some{value} <> rest:
      numbers_read(rest, value <> acc)

def numbers(result: Numeric.TokenResult) -> NumberRead:
  match result:
    case Numeric.TokenFail{reason}: NumberBad{}
    case Numeric.TokenDone{values}:
      numbers_read(values, Nil{})

def row_read(row: String) -> NumberRead:
  numbers(Numeric.scan(row, Numeric.ScanRun{0n, Nil{}, 0, False{}}))

def full_save_row(result: FullSave.FullSnapshotResult) -> String:
  match result:
    case FullSave.FullSnapshotRejected{}: "0"
    case FullSave.FullSnapshotReady{FullSave.FullSnapshot{world,
        progression}}:
      SaveWire.serialize(Save.SnapshotReady{world})

def save_row(session: Session.WorldSession) -> String:
  match session:
    case Session.WorldSession{world, None{}}:
      SaveWire.serialize(Save.project_world(world))
    case Session.WorldSession{world, Some{progression}}:
      full_save_row(FullSave.project(session))
    case _: "0"

def save_when_dialogue_closed(closed: Bool,
  session: Session.WorldSession) -> String:
  match closed:
    case False{}: "0"
    case True{}: save_row(session)

def progression_row(session: Session.WorldSession) -> String:
  match session:
    case Session.WorldSession{world, Some{state}}:
      PersistentText.serialize(Some{state})
    case _: "0"

def progression_when_dialogue_closed(closed: Bool,
  session: Session.WorldSession) -> String:
  match closed:
    case False{}: "0"
    case True{}: progression_row(session)

@unsafe def battle_replayed(result: BattleReplay.ReplayResult,
  identity: U32, +accepted: Nat, expected: Nat, encounter_id: Nat,
  +catalog: Catalog.Catalog, +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs, trace: TraceState) -> RuntimeResult:
  match result:
    case BattleReplay.ReplayRejected{session, count}:
      RuntimeRejected{}
    case BattleReplay.Replayed{session, +count}:
      match session:
        case Session.Battling{persistent, battle}:
          Bool.pick(RuntimeResult,
            Nat.is_eq(Nat.add(accepted, count), expected),
            RuntimeBattle{identity, Nat.add(accepted, count), encounter_id,
              PresentationWire.serialize(Projection.project(catalog,
                Session.Battling{persistent, battle}, Projection.North{})),
              PresentationWire.serialize_cues([]), trace}, RuntimeRejected{})
        case Session.WorldSession{+world, +battle}:
          Bool.pick(RuntimeResult,
            Nat.is_eq(Nat.add(accepted, count), expected),
            RuntimeAccepted{identity, Nat.add(accepted, count), 0n, 0n,
              True{}, PresentationWire.serialize(Projection.project(catalog,
                Session.WorldSession{world, battle}, Projection.North{})),
              PresentationWire.serialize_cues([]),
              save_row(Session.WorldSession{world, battle}),
              progression_row(Session.WorldSession{world, battle}), trace},
            RuntimeRejected{})
    case BattleReplay.ReplayStopped{session, count, remaining}:
      replay_traced(Replay.run_dialogue_from_traced(remaining, catalog, session,
        records, associations, Nat.add(accepted, count)), identity, expected,
        catalog, records, associations, inputs, trace)

@unsafe def battle_traced(result: BattleReplay.TracedReplay,
  identity: U32, accepted: Nat, expected: Nat, encounter_id: Nat,
  catalog: Catalog.Catalog, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs, prior: TraceState) -> RuntimeResult:
  match result:
    case BattleReplay.TracedReplay{replayed, points}:
      battle_replayed(replayed, identity, accepted, expected, encounter_id,
        catalog, records, associations, inputs, battle_trace(points, prior))

@unsafe def started_battle(result: PlayableEncounter.EncounterResult,
  +identity: U32, +accepted: Nat, +expected: Nat,
  encounter_id: Nat, +catalog: Catalog.Catalog,
  cues: List<&2, Cues.Cue>,
  remaining: List<&2, Commands.WorldCommand>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs, trace: TraceState) -> RuntimeResult:
  match result:
    case PlayableEncounter.Started{+session, species_id, level}:
      match inputs:
        case BattleInputs{tables, +species, +moves, starter_species,
            starter_level, wait_ticks}:
          battle_traced(BattleReplay.run_traced(remaining, session, species, moves),
            identity, accepted, expected, encounter_id, catalog, records,
            associations,
            BattleInputs{tables, species, moves, starter_species,
              starter_level, wait_ticks}, trace)
    case PlayableEncounter.Rejected{}: RuntimeRejected{}

def start_from_party(session: Session.WorldSession,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, starter_species: Nat, starter_level: U32,
  wait_ticks: U32) -> PlayableEncounter.EncounterResult:
  match session:
    case Session.WorldSession{world, None{}}:
      PlayableEncounter.start(session, tables, species, moves,
        starter_species, starter_level, wait_ticks)
    case Session.WorldSession{world, Some{progression}}:
      PlayableEncounter.start_persistent(session, tables, species, moves,
        wait_ticks)
    case _: PlayableEncounter.Rejected{}

@unsafe def encounter_result(session: Session.WorldSession, +accepted: Nat,
  +expected: Nat, encounter_id: Nat, +identity: U32,
  +catalog: Catalog.Catalog,
  cues: List<&2, Cues.Cue>,
  remaining: List<&2, Commands.WorldCommand>,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs, trace: TraceState) -> RuntimeResult:
  match inputs:
    case BattleInputs{+tables, +species, +moves, +starter_species,
        +starter_level, +wait_ticks}:
      match starter_species:
        case 0n:
          Bool.pick(RuntimeResult, Nat.is_eq(accepted, expected),
            RuntimeEncounter{identity, accepted, encounter_id,
              PresentationWire.serialize(Projection.project(catalog, session,
                Projection.North{})), PresentationWire.serialize_cues(cues),
              trace},
            RuntimeRejected{})
        case _:
          started_battle(start_from_party(session, tables, species, moves,
              starter_species, starter_level, wait_ticks), identity,
            accepted, expected, encounter_id, catalog, cues, remaining,
            records, associations,
            BattleInputs{tables, species, moves, starter_species,
              starter_level, wait_ticks}, trace)

@unsafe def replay_result(result: Replay.ReplayResult, +identity: U32,
  +expected: Nat, +catalog: Catalog.Catalog,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs, trace: TraceState) -> RuntimeResult:
  match result:
    case Replay.Replayed{+session, +accepted, +cues}:
      Bool.pick(RuntimeResult, Nat.is_eq(accepted, expected),
        RuntimeAccepted{identity, accepted,
          0n, 0n, True{},
          PresentationWire.serialize(Projection.project(catalog, session,
            Projection.North{})), PresentationWire.serialize_cues(cues),
          save_row(session), progression_row(session), trace},
        RuntimeRejected{})
    case Replay.ReplayedDialogue{+session, +accepted, +cues,
        dialogue_id, line_index, +closed}:
      Bool.pick(RuntimeResult, Nat.is_eq(accepted, expected),
        RuntimeAccepted{identity, accepted, dialogue_id, line_index, closed,
          PresentationWire.serialize(Projection.project(catalog, session,
            Projection.North{})), PresentationWire.serialize_cues(cues),
          save_when_dialogue_closed(closed, session),
          progression_when_dialogue_closed(closed, session), trace},
        RuntimeRejected{})
    case Replay.ReplayEncounter{+session, encounter_id, +accepted, +cues,
        remaining}:
      encounter_result(session, accepted, expected, encounter_id,
        identity, catalog, cues, remaining, records, associations, inputs,
        trace)
    case Replay.ReplayRejected{session, accepted}: RuntimeRejected{}
    case Replay.ReplayDialogueRejected{session, accepted, dialogue_id,
        line_index}: RuntimeRejected{}

@unsafe def replay_traced(result: Replay.TracedReplay, identity: U32,
  expected: Nat, catalog: Catalog.Catalog,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs, prior: TraceState) -> RuntimeResult:
  match result:
    case Replay.TracedReplay{replayed, points}:
      replay_result(replayed, identity, expected, catalog, records,
        associations, inputs, world_trace(points, prior))

def replay_boot(result: Boot.BootResult, +commands:
  List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  identity: U32, inputs: BattleInputs) -> RuntimeResult:
  match result:
    case Boot.BootRejected{reason}: RuntimeRejected{}
    case Boot.Booted{session}:
      replay_traced(Replay.run_dialogue_traced(commands, catalog, session,
          records, associations), identity,
        List.length(&2, Commands.WorldCommand, commands), catalog,
        records, associations, inputs, empty_trace())

@unsafe def restored_playtest(result: Save.RestoreResult,
  commands: List<&2, Commands.WorldCommand>, identity: U32,
  expected: Nat, +catalog: Catalog.Catalog,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
  match result:
    case Save.RestoreRejected{}: RuntimeRejected{}
    case Save.Restored{session}:
      replay_traced(Replay.run_dialogue_traced(commands, catalog, session,
        records, associations), identity, expected, catalog, records,
        associations, inputs, empty_trace())

@unsafe def restored_full_playtest(result: FullSave.FullRestoreResult,
  commands: List<&2, Commands.WorldCommand>, identity: U32,
  expected: Nat, +catalog: Catalog.Catalog,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
  match result:
    case FullSave.FullRestoreRejected{}: RuntimeRejected{}
    case FullSave.FullRestored{session}:
      replay_traced(Replay.run_dialogue_traced(commands, catalog, session,
        records, associations), identity, expected, catalog, records,
        associations, inputs, empty_trace())

@unsafe def restore_optional(snapshot: Save.Snapshot,
  progression: Maybe<&2, Persistent.PersistentState>,
  commands: List<&2, Commands.WorldCommand>, identity: U32,
  expected: Nat, +catalog: Catalog.Catalog,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
  match progression:
    case None{}:
      restored_playtest(Save.restore(catalog, snapshot), commands, identity,
        expected, catalog, records, associations, inputs)
    case Some{state}:
      restored_full_playtest(FullSave.restore(catalog,
          FullSave.FullSnapshot{snapshot, state}), commands, identity,
        expected, catalog, records, associations, inputs)

@unsafe def boot_or_restore(restore: RestoreInput,
  +commands: List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>, identity: U32,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, boot_identity: U32, entry_map: U32,
  point: Geometry.Point, rng: Rng.RngState, wait_ticks: U32,
  starter_species: U32, starter_level: U32) -> RuntimeResult:
  match restore:
    case InvalidRestore{}: RuntimeRejected{}
    case NoRestore{}:
      replay_boot(Boot.boot(catalog, U32.to_nat(entry_map), point, rng,
        U32.to_nat(boot_identity)), commands, catalog, records, associations,
        identity, BattleInputs{tables, species, moves,
          U32.to_nat(starter_species), starter_level, wait_ticks})
    case HasRestore{snapshot, progression}:
      restore_optional(snapshot, progression, commands, identity,
        List.length(&2, Commands.WorldCommand, commands), catalog, records,
        associations, BattleInputs{tables, species, moves,
          U32.to_nat(starter_species), starter_level, wait_ticks})

def boot_playable(boot: BootWire.DecodeResult,
  command_rows: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  identity: U32, tables: List<&2, Handoff.EncounterTable>,
  species: Species.Catalog, moves: Moves.Catalog,
  restore: RestoreInput) -> RuntimeResult:
  match boot:
    case BootWire.BootRejected{reason}: RuntimeRejected{}
    case BootWire.BootAccepted{BootWire.BootRequest{boot_identity,
        entry_map, point, rng, wait_ticks, starter_species,
        starter_level}}:
      boot_or_restore(restore, command_rows, catalog, records, associations,
        identity, tables, species, moves, boot_identity, entry_map, point,
        rng, wait_ticks, starter_species, starter_level)

def boot_with_extras(valid: Bool, boot: BootWire.DecodeResult,
  command_rows: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  identity: U32, tables: List<&2, Handoff.EncounterTable>,
  species: Species.Catalog, moves: Moves.Catalog,
  restore: RestoreInput) -> RuntimeResult:
  match valid:
    case False{}: RuntimeRejected{}
    case True{}:
      boot_playable(boot, command_rows, catalog, records, associations,
        identity, tables, species, moves, restore)

def joined_extras(moves: Moves.DecodeResult,
  dialogue: DialogueWire.DecodeResult, boot: BootWire.DecodeResult,
  command_rows: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +identity: U32,
  move_count: U32, tables: List<&2, Handoff.EncounterTable>,
  species: Species.Catalog, restore: RestoreInput) -> RuntimeResult:
  match moves dialogue:
    case Moves.DecodeAccepted{Moves.Catalog{+move_identity, +rows}}
         DialogueWire.DecodeAccepted{+dialogue_identity, +records,
           +associations}:
      boot_with_extras(Bool.and(U32.is_eq(identity, move_identity),
        Bool.and(U32.is_eq(identity, dialogue_identity),
          Bool.and(DialogueJoin.validate(
            DialogueWire.DecodeAccepted{dialogue_identity, records,
              associations}, catalog),
            Nat.is_eq(U32.to_nat(move_count),
              List.length(&2, Moves.MoveRecord, rows))))),
        boot, command_rows, catalog, records, associations, identity,
        tables, species, Moves.Catalog{move_identity, rows}, restore)
    case _ _: RuntimeRejected{}

def boot_joined(boot: BootWire.DecodeResult,
  joined_result: PlaytestContent.JoinResult,
  decoded_commands: CommandWire.DecodeResult,
  moves: Moves.DecodeResult,
  dialogue_tokens: List<&2, U32>, restore: RestoreInput) -> RuntimeResult:
  match joined_result decoded_commands:
    case PlaytestContent.JoinRejected{reason} _:
      RuntimeRejected{}
    case _ CommandWire.DecodeRejected{reason}:
      RuntimeRejected{}
    case PlaytestContent.JoinAccepted{PlaytestContent.PlaytestContent{
        Content.BoundContent{+identity, entry_map, +catalog, encounter_tables},
        Species.Catalog{species_identity, +move_count, records}}}
         CommandWire.DecodeAccepted{command_rows}:
      joined_extras(moves,
        DialogueWire.decode_tokens(identity, dialogue_tokens), boot,
        command_rows, catalog, identity, move_count, encounter_tables,
        Species.Catalog{species_identity, move_count, records}, restore)

def joined_world(world_result: World.DecodeResult,
  events: EventWire.DecodeResult, species: Species.DecodeResult,
  moves: Moves.DecodeResult, dialogue_tokens: List<&2, U32>,
  boot: BootWire.DecodeResult, commands: CommandWire.DecodeResult,
  restore: RestoreInput) -> RuntimeResult:
  boot_joined(boot, PlaytestContent.join(
    Content.join(world_result, events), species), commands, moves,
    dialogue_tokens, restore)

def restore_decode_result(result: SaveWireDecode.DecodeResult) -> RestoreInput:
  match result:
    case SaveWireDecode.DecodeRejected{}: InvalidRestore{}
    case SaveWireDecode.DecodeAccepted{snapshot}:
      HasRestore{snapshot, None{}}

def full_restore_decode_result(result: FullRestoreWire.DecodeResult) ->
  RestoreInput:
  match result:
    case FullRestoreWire.DecodeRejected{}: InvalidRestore{}
    case FullRestoreWire.DecodeAccepted{snapshot, progression}:
      HasRestore{snapshot, progression}

def restore_tokens(tokens: List<&2, U32>) -> RestoreInput:
  match tokens:
    case 18 <> 2 <> rest:
      full_restore_decode_result(FullRestoreWire.decode_tokens(tokens))
    case _:
      restore_decode_result(SaveWireDecode.decode_tokens(tokens))

def restore_row_read(result: NumberRead) -> RestoreInput:
  match result:
    case NumberBad{}: InvalidRestore{}
    case NumberDone{tokens}:
      restore_tokens(tokens)

def decoded_rows(world: NumberRead, events: NumberRead,
  species: NumberRead, moves: NumberRead, dialogue: NumberRead,
  boot: NumberRead, commands: NumberRead) -> RuntimeResult:
  match world events species moves dialogue boot commands:
    case NumberDone{world_tokens} NumberDone{event_tokens}
         NumberDone{species_tokens} NumberDone{move_tokens}
         NumberDone{dialogue_tokens} NumberDone{boot_tokens}
         NumberDone{command_tokens}:
      joined_world(World.decode_tokens(world_tokens),
        EventWire.decode_tokens(event_tokens),
        Species.decode_tokens(species_tokens),
        Moves.decode_tokens(move_tokens), dialogue_tokens,
        BootWire.decode_tokens(boot_tokens),
        CommandWire.decode_tokens(command_tokens), NoRestore{})
    case _ _ _ _ _ _ _: RuntimeRejected{}

def restored_rows_result(restore: RestoreInput,
  world_tokens: List<&2, U32>, event_tokens: List<&2, U32>,
  species_tokens: List<&2, U32>, move_tokens: List<&2, U32>,
  dialogue_tokens: List<&2, U32>, boot_tokens: List<&2, U32>,
  command_tokens: List<&2, U32>) -> RuntimeResult:
  match restore:
    case InvalidRestore{}: RuntimeRejected{}
    case NoRestore{}: RuntimeRejected{}
    case HasRestore{snapshot, progression}:
      joined_world(World.decode_tokens(world_tokens),
        EventWire.decode_tokens(event_tokens),
        Species.decode_tokens(species_tokens),
        Moves.decode_tokens(move_tokens), dialogue_tokens,
        BootWire.decode_tokens(boot_tokens),
        CommandWire.decode_tokens(command_tokens),
        HasRestore{snapshot, progression})

def decoded_restore_rows(world: NumberRead, events: NumberRead,
  species: NumberRead, moves: NumberRead, dialogue: NumberRead,
  boot: NumberRead, commands: NumberRead, restore: NumberRead) -> RuntimeResult:
  match world events species moves dialogue boot commands:
    case NumberDone{world_tokens} NumberDone{event_tokens}
         NumberDone{species_tokens} NumberDone{move_tokens}
         NumberDone{dialogue_tokens} NumberDone{boot_tokens}
         NumberDone{command_tokens}:
      restore_option = restore_row_read(restore)
      restored_rows_result(restore_option, world_tokens, event_tokens,
        species_tokens, move_tokens, dialogue_tokens, boot_tokens,
        command_tokens)
    case _ _ _ _ _ _ _: RuntimeRejected{}

def parse_rows(world: String, events: String, species: String,
  moves: String, dialogue: String, boot: String,
  commands: String) -> RuntimeResult:
  decoded_rows(row_read(world), row_read(events), row_read(species),
    row_read(moves), row_read(dialogue), row_read(boot), row_read(commands))

def parse_restore_rows(world: String, events: String, species: String,
  moves: String, dialogue: String, boot: String, commands: String,
  restore: String) -> RuntimeResult:
  decoded_restore_rows(row_read(world), row_read(events), row_read(species),
    row_read(moves), row_read(dialogue), row_read(boot), row_read(commands),
    row_read(restore))

def parse_request(lines: List<&2, String>) -> RuntimeResult:
  match lines:
    case "M10PLAY2" <> world <> events <> species <> moves <> dialogue <>
         boot <> commands <> Nil{}:
      parse_rows(world, events, species, moves, dialogue, boot, commands)
    case "M10PLAY2" <> world <> events <> species <> moves <> dialogue <>
         boot <> commands <>
         "" <> Nil{}:
      parse_rows(world, events, species, moves, dialogue, boot, commands)
    case "M10PLAY2" <> world <> events <> species <> moves <> dialogue <>
         boot <> commands <> restore <> Nil{}:
      parse_restore_rows(world, events, species, moves, dialogue, boot,
        commands, restore)
    case "M10PLAY2" <> world <> events <> species <> moves <> dialogue <>
         boot <> commands <> restore <> "" <> Nil{}:
      parse_restore_rows(world, events, species, moves, dialogue, boot,
        commands, restore)
    case _: RuntimeRejected{}

def closed_number(closed: Bool) -> String:
  match closed:
    case True{}: "1"
    case False{}: "0"

def report(result: RuntimeResult) -> IO(Unit):
  match result:
    case RuntimeRejected{}: IO.print("M10PLAY2 REJECTED")
    case RuntimeAccepted{identity, commands, dialogue_id, line_index,
        closed, scene, cues, save, progression, trace}:
      IO.print("M10PLAY2 ACCEPTED\nIDENTITY " ++ U32.show(identity) ++
        "\nCOMMANDS " ++ Nat.show(commands) ++ "\nDIALOGUE " ++
        Nat.show(dialogue_id) ++ " " ++ Nat.show(line_index) ++ " " ++
        closed_number(closed) ++ "\nSCENE " ++ scene ++
        "\nCUES " ++ cues ++ "\nSAVE " ++ save ++
        "\nPROGRESSION " ++ progression ++ trace_suffix(trace))
    case RuntimeEncounter{identity, commands, encounter_id, scene, cues,
        trace}:
      IO.print("M10PLAY2 ENCOUNTER\nIDENTITY " ++ U32.show(identity) ++
        "\nCOMMANDS " ++ Nat.show(commands) ++ "\nENCOUNTER " ++
        Nat.show(encounter_id) ++ "\nDIALOGUE 0 0 1\nSCENE " ++ scene ++
        "\nCUES " ++ cues ++ "\nSAVE 0" ++ trace_suffix(trace))
    case RuntimeBattle{identity, commands, encounter_id, scene, cues,
        trace}:
      IO.print("M10PLAY2 BATTLE\nIDENTITY " ++ U32.show(identity) ++
        "\nCOMMANDS " ++ Nat.show(commands) ++ "\nENCOUNTER " ++
        Nat.show(encounter_id) ++ "\nDIALOGUE 0 0 1\nSCENE " ++ scene ++
        "\nCUES " ++ cues ++ "\nSAVE 0" ++ trace_suffix(trace))

def finish_read(pair: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match pair:
    case Tuple{file, Fail{Tuple{code, message}}}:
      do IO<Unit>:
        File.close(file)
        IO.print("M10PLAY2 REJECTED")
    case Tuple{file, Done{+text}}:
      do IO<Unit>:
        File.close(file)
        report(parse_request(String.lines(text)))

def read_sized(file: File, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      do IO<Unit>:
        File.close(file)
        IO.print("M10PLAY2 REJECTED")
    case True{}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, String> <-
          File.read(file, 2097153)
        finish_read(pair)

def finish_size(pair: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  match pair:
    case Tuple{file, Fail{Tuple{code, message}}}:
      do IO<Unit>:
        File.close(file)
        IO.print("M10PLAY2 REJECTED")
    case Tuple{file, Done{size}}:
      read_sized(file, U32.is_le(size, 2097152))

def open_request(result: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match result:
    case Fail{Tuple{code, message}}: IO.print("M10PLAY2 REJECTED")
    case Done{file}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
        finish_size(pair)

def accept_args(args: List<String>) -> IO(Unit):
  match args:
    case path <> Nil{}:
      do IO<Unit>:
        result : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
        open_request(result)
    case _: IO.print("M10PLAY2 REJECTED")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    accept_args(args)
