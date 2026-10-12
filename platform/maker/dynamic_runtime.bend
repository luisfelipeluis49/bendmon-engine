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
import ../../engine/world/presentation_cues.bend as Cues
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/world_session.bend as Session
import ../../engine/presentation/projection.bend as Projection
import ../../engine/presentation/wire.bend as PresentationWire

type NumberRead is Data:
  NumberBad{}
  NumberDone{values: List<&2, U32>}

type RuntimeResult is Data:
  RuntimeRejected{}
  RuntimeAccepted{identity: U32, commands: Nat,
    dialogue_id: Nat, line_index: Nat, closed: Bool,
    scene: String, cues: String}
  RuntimeEncounter{identity: U32, commands: Nat, encounter_id: Nat,
    scene: String, cues: String}
  RuntimeBattle{identity: U32, commands: Nat, encounter_id: Nat,
    scene: String, cues: String}

type BattleInputs is Data:
  BattleInputs{tables: List<&2, Handoff.EncounterTable>,
    species: Species.Catalog, moves: Moves.Catalog,
    starter_species: Nat, starter_level: U32, wait_ticks: U32}

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

@unsafe def battle_replayed(result: BattleReplay.ReplayResult,
  identity: U32, +accepted: Nat, expected: Nat, encounter_id: Nat,
  +catalog: Catalog.Catalog, +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
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
              PresentationWire.serialize_cues([])}, RuntimeRejected{})
        case Session.WorldSession{world, battle}:
          Bool.pick(RuntimeResult,
            Nat.is_eq(Nat.add(accepted, count), expected),
            RuntimeAccepted{identity, Nat.add(accepted, count), 0n, 0n,
              True{}, PresentationWire.serialize(Projection.project(catalog,
                Session.WorldSession{world, battle}, Projection.North{})),
              PresentationWire.serialize_cues([])}, RuntimeRejected{})
    case BattleReplay.ReplayStopped{session, count, remaining}:
      replay_result(Replay.run_dialogue_from(remaining, catalog, session,
        records, associations, Nat.add(accepted, count)), identity, expected,
        catalog, records, associations, inputs)

@unsafe def started_battle(result: PlayableEncounter.EncounterResult,
  +identity: U32, +accepted: Nat, +expected: Nat,
  encounter_id: Nat, +catalog: Catalog.Catalog,
  cues: List<&2, Cues.Cue>,
  remaining: List<&2, Commands.WorldCommand>,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
  match result:
    case PlayableEncounter.Started{+session, species_id, level}:
      match inputs:
        case BattleInputs{tables, +species, +moves, starter_species,
            starter_level, wait_ticks}:
          battle_replayed(BattleReplay.run(remaining, session, species, moves),
            identity, accepted, expected, encounter_id, catalog, records,
            associations,
            BattleInputs{tables, species, moves, starter_species,
              starter_level, wait_ticks})
    case PlayableEncounter.Rejected{}: RuntimeRejected{}

@unsafe def encounter_result(session: Session.WorldSession, +accepted: Nat,
  +expected: Nat, encounter_id: Nat, +identity: U32,
  +catalog: Catalog.Catalog,
  cues: List<&2, Cues.Cue>,
  remaining: List<&2, Commands.WorldCommand>,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
  match inputs:
    case BattleInputs{+tables, +species, +moves, +starter_species,
        +starter_level, +wait_ticks}:
      match starter_species:
        case 0n:
          Bool.pick(RuntimeResult, Nat.is_eq(accepted, expected),
            RuntimeEncounter{identity, accepted, encounter_id,
              PresentationWire.serialize(Projection.project(catalog, session,
                Projection.North{})), PresentationWire.serialize_cues(cues)},
            RuntimeRejected{})
        case _:
          started_battle(PlayableEncounter.start(session, tables, species,
              moves, starter_species, starter_level, wait_ticks), identity,
            accepted, expected, encounter_id, catalog, cues, remaining,
            records, associations,
            BattleInputs{tables, species, moves, starter_species,
              starter_level, wait_ticks})

@unsafe def replay_result(result: Replay.ReplayResult, +identity: U32,
  +expected: Nat, +catalog: Catalog.Catalog,
  records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  inputs: BattleInputs) -> RuntimeResult:
  match result:
    case Replay.Replayed{+session, +accepted, +cues}:
      Bool.pick(RuntimeResult, Nat.is_eq(accepted, expected),
        RuntimeAccepted{identity, accepted,
          0n, 0n, True{},
          PresentationWire.serialize(Projection.project(catalog, session,
            Projection.North{})), PresentationWire.serialize_cues(cues)},
        RuntimeRejected{})
    case Replay.ReplayedDialogue{+session, +accepted, +cues,
        dialogue_id, line_index, closed}:
      Bool.pick(RuntimeResult, Nat.is_eq(accepted, expected),
        RuntimeAccepted{identity, accepted, dialogue_id, line_index, closed,
          PresentationWire.serialize(Projection.project(catalog, session,
            Projection.North{})), PresentationWire.serialize_cues(cues)},
        RuntimeRejected{})
    case Replay.ReplayEncounter{+session, encounter_id, +accepted, +cues,
        remaining}:
      encounter_result(session, accepted, expected, encounter_id,
        identity, catalog, cues, remaining, records, associations, inputs)
    case Replay.ReplayRejected{session, accepted}: RuntimeRejected{}
    case Replay.ReplayDialogueRejected{session, accepted, dialogue_id,
        line_index}: RuntimeRejected{}

def replay_boot(result: Boot.BootResult, +commands:
  List<&2, Commands.WorldCommand>, +catalog: Catalog.Catalog,
  +records: List<&2, Dialogue.Record>,
  +associations: List<&2, DialogueWire.Association>,
  identity: U32, inputs: BattleInputs) -> RuntimeResult:
  match result:
    case Boot.BootRejected{reason}: RuntimeRejected{}
    case Boot.Booted{session}:
      replay_result(Replay.run_dialogue(commands, catalog, session,
          records, associations), identity,
        List.length(&2, Commands.WorldCommand, commands), catalog,
        records, associations, inputs)

def boot_playable(boot: BootWire.DecodeResult,
  command_rows: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  identity: U32, tables: List<&2, Handoff.EncounterTable>,
  species: Species.Catalog, moves: Moves.Catalog) -> RuntimeResult:
  match boot:
    case BootWire.BootRejected{reason}: RuntimeRejected{}
    case BootWire.BootAccepted{BootWire.BootRequest{boot_identity,
        entry_map, point, rng, wait_ticks, starter_species,
        starter_level}}:
      replay_boot(Boot.boot(catalog, U32.to_nat(entry_map), point, rng,
          U32.to_nat(boot_identity)), command_rows, catalog, records,
        associations, identity,
        BattleInputs{tables, species, moves, U32.to_nat(starter_species),
          starter_level, wait_ticks})

def boot_with_extras(valid: Bool, boot: BootWire.DecodeResult,
  command_rows: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, records: List<&2, Dialogue.Record>,
  associations: List<&2, DialogueWire.Association>,
  identity: U32, tables: List<&2, Handoff.EncounterTable>,
  species: Species.Catalog, moves: Moves.Catalog) -> RuntimeResult:
  match valid:
    case False{}: RuntimeRejected{}
    case True{}:
      boot_playable(boot, command_rows, catalog, records, associations,
        identity, tables, species, moves)

def joined_extras(moves: Moves.DecodeResult,
  dialogue: DialogueWire.DecodeResult, boot: BootWire.DecodeResult,
  command_rows: List<&2, Commands.WorldCommand>,
  +catalog: Catalog.Catalog, +identity: U32,
  move_count: U32, tables: List<&2, Handoff.EncounterTable>,
  species: Species.Catalog) -> RuntimeResult:
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
        tables, species, Moves.Catalog{move_identity, rows})
    case _ _: RuntimeRejected{}

def boot_joined(boot: BootWire.DecodeResult,
  joined_result: PlaytestContent.JoinResult,
  decoded_commands: CommandWire.DecodeResult,
  moves: Moves.DecodeResult,
  dialogue_tokens: List<&2, U32>) -> RuntimeResult:
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
        Species.Catalog{species_identity, move_count, records})

def joined_world(world_result: World.DecodeResult,
  events: EventWire.DecodeResult, species: Species.DecodeResult,
  moves: Moves.DecodeResult, dialogue_tokens: List<&2, U32>,
  boot: BootWire.DecodeResult, commands: CommandWire.DecodeResult) -> RuntimeResult:
  boot_joined(boot, PlaytestContent.join(
    Content.join(world_result, events), species), commands, moves,
    dialogue_tokens)

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
        CommandWire.decode_tokens(command_tokens))
    case _ _ _ _ _ _ _: RuntimeRejected{}

def parse_rows(world: String, events: String, species: String,
  moves: String, dialogue: String, boot: String,
  commands: String) -> RuntimeResult:
  decoded_rows(row_read(world), row_read(events), row_read(species),
    row_read(moves), row_read(dialogue), row_read(boot), row_read(commands))

def parse_request(lines: List<&2, String>) -> RuntimeResult:
  match lines:
    case "M10PLAY2" <> world <> events <> species <> moves <> dialogue <>
         boot <> commands <> Nil{}:
      parse_rows(world, events, species, moves, dialogue, boot, commands)
    case "M10PLAY2" <> world <> events <> species <> moves <> dialogue <>
         boot <> commands <>
         "" <> Nil{}:
      parse_rows(world, events, species, moves, dialogue, boot, commands)
    case _: RuntimeRejected{}

def closed_number(closed: Bool) -> String:
  match closed:
    case True{}: "1"
    case False{}: "0"

def report(result: RuntimeResult) -> IO(Unit):
  match result:
    case RuntimeRejected{}: IO.print("M10PLAY2 REJECTED")
    case RuntimeAccepted{identity, commands, dialogue_id, line_index,
        closed, scene, cues}:
      IO.print("M10PLAY2 ACCEPTED\nIDENTITY " ++ U32.show(identity) ++
        "\nCOMMANDS " ++ Nat.show(commands) ++ "\nDIALOGUE " ++
        Nat.show(dialogue_id) ++ " " ++ Nat.show(line_index) ++ " " ++
        closed_number(closed) ++ "\nSCENE " ++ scene ++
        "\nCUES " ++ cues)
    case RuntimeEncounter{identity, commands, encounter_id, scene, cues}:
      IO.print("M10PLAY2 ENCOUNTER\nIDENTITY " ++ U32.show(identity) ++
        "\nCOMMANDS " ++ Nat.show(commands) ++ "\nENCOUNTER " ++
        Nat.show(encounter_id) ++ "\nDIALOGUE 0 0 1\nSCENE " ++ scene ++
        "\nCUES " ++ cues)
    case RuntimeBattle{identity, commands, encounter_id, scene, cues}:
      IO.print("M10PLAY2 BATTLE\nIDENTITY " ++ U32.show(identity) ++
        "\nCOMMANDS " ++ Nat.show(commands) ++ "\nENCOUNTER " ++
        Nat.show(encounter_id) ++ "\nDIALOGUE 0 0 1\nSCENE " ++ scene ++
        "\nCUES " ++ cues)

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
