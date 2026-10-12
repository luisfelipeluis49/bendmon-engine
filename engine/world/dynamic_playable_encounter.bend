import Base
import ../battle/rng.bend as Rng
import ../m7/dynamic_species.bend as Species
import ../m7/dynamic_moves.bend as Moves
import ../m7/dynamic_battle_boot.bend as BattleBoot
import ../m7/dynamic_playable_boot.bend as PlayableBoot
import ../m7/playable.bend as Playable
import ./exploration.bend as Exploration
import ./encounter_handoff.bend as Handoff
import ./world_session.bend as Session

type EncounterResult is Data:
  Started{session: Session.WorldSession, species_id: Nat, level: Nat}
  Rejected{}

def keep_species(equal: Bool, row: Species.SpeciesProgressionRecord,
  found: Maybe<Species.SpeciesProgressionRecord>) ->
  Maybe<Species.SpeciesProgressionRecord>:
  match equal:
    case True{}: Some{row}
    case False{}: found

def species_record(+wanted: Nat,
  rows: List<&2, Species.SpeciesProgressionRecord>,
  found: Maybe<Species.SpeciesProgressionRecord>) ->
  Maybe<Species.SpeciesProgressionRecord>:
  match rows:
    case Nil{}: found
    case row <> rest:
      match row:
        case Species.SpeciesProgressionRecord{+species, base, capture_rate,
            xp_yield, currency_yield, combat_types, learning}:
          species_record(wanted, rest,
            keep_species(Nat.is_eq(wanted, species), row, found))

def species_by_id(wanted: Nat,
  rows: List<&2, Species.SpeciesProgressionRecord>) ->
  Maybe<Species.SpeciesProgressionRecord>:
  species_record(wanted, rows, None{})

def species_rows(catalog: Species.Catalog) ->
  List<&2, Species.SpeciesProgressionRecord>:
  match catalog:
    case Species.Catalog{identity, move_count, species}: species

def started_result(result: Session.SessionResult, species_id: Nat,
  level: Nat) -> EncounterResult:
  match result:
    case Session.EncounterReady{state, species, actual_level}:
      Started{state, species, actual_level}
    case _: Rejected{}

def completed(prepared: Session.PreparedSession,
  battle: Maybe<&1, Playable.PlayableSession>, species_id: Nat,
  level: Nat) -> EncounterResult:
  match battle:
    case None{}: Rejected{}
    case Some{playable}:
      started_result(Session.begin_encounter(prepared, playable),
        species_id, level)

def built_playable(ok: Bool, pair: BattleBoot.BootPair,
  prepared: Session.PreparedSession, species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  +wild_id: Nat, +wild_level: U32) -> EncounterResult:
  match ok:
    case False{}: Rejected{}
    case True{}:
      completed(prepared, PlayableBoot.build(pair, species, moves,
        1n, starter_level, 2n, wild_level), wild_id,
        U32.to_nat(wild_level))

def boot_result(result: BattleBoot.BootResult,
  prepared: Session.PreparedSession, species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  wild_id: Nat, wild_level: U32) -> EncounterResult:
  match result:
    case BattleBoot.BootRejected{}: Rejected{}
    case BattleBoot.BootReady{pair}:
      built_playable(True{}, pair, prepared, species, moves, starter_id,
        starter_level, wild_id, wild_level)

def build_pair(+prepared: Session.PreparedSession,
  starter: Species.SpeciesProgressionRecord,
  wild: Species.SpeciesProgressionRecord, +species: Species.Catalog,
  +moves: Moves.Catalog, starter_id: Nat, +starter_level: U32,
  wait_ticks: U32) -> EncounterResult:
  match prepared:
    case Session.PreparedSession{+world,
        Handoff.Prepared{+selected_world, +encounter_id, +wild_id, +level,
          +source_rng}}:
      match selected_world:
        case Exploration.State{map_id, point, meter, pending, +identity}:
          boot_result(BattleBoot.build(starter, starter_level, wild,
            U32.from_nat(level), encounter_id, U32.from_nat(identity),
            source_rng, wait_ticks), prepared, species, moves, starter_id,
            starter_level, wild_id, U32.from_nat(level))

def paired_records(starter: Maybe<Species.SpeciesProgressionRecord>,
  wild: Maybe<Species.SpeciesProgressionRecord>,
  prepared: Session.PreparedSession, species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  wait_ticks: U32) -> EncounterResult:
  match starter wild:
    case Some{starter_row} Some{wild_row}:
      build_pair(prepared, starter_row, wild_row, species, moves,
        starter_id, starter_level, wait_ticks)
    case _ _: Rejected{}

def prepared_parts(prepared: Session.PreparedSession,
  +species: Species.Catalog, +moves: Moves.Catalog, +starter_id: Nat,
  starter_level: U32, wait_ticks: U32) -> EncounterResult:
  match prepared:
    case Session.PreparedSession{world,
        Handoff.Prepared{selected_world, encounter_id, +wild_id, level,
          source_rng}}:
      match selected_world:
        case Exploration.State{map_id, point, meter, pending, identity}:
          paired_records(species_by_id(starter_id, species_rows(species)),
            species_by_id(wild_id, species_rows(species)), prepared, species,
            moves, starter_id, starter_level, wait_ticks)

def preparation(result: Session.PrepareResult,
  species: Species.Catalog, moves: Moves.Catalog, starter_id: Nat,
  starter_level: U32, wait_ticks: U32) -> EncounterResult:
  match result:
    case Session.PrepareRejected{state}: Rejected{}
    case Session.Prepared{value, species_id, level}:
      prepared_parts(value, species, moves, starter_id, starter_level,
        wait_ticks)

# Selects an encounter once, builds the trusted starter/wild M7 snapshot from
# identity-matched inert catalogs, then lets WorldSession validate the handoff.
def start(+session: Session.WorldSession,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  wait_ticks: U32) -> EncounterResult:
  preparation(Session.prepare_encounter(tables, session), species, moves,
    starter_id, starter_level, wait_ticks)
