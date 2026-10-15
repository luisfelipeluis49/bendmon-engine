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
import ../m7/persistent_state.bend as Persistent

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
        case Exploration.State{map_id, point, meter, pending, +identity}:
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

# This builder can only create the initial starter/wild party. After M7 returns,
# rejecting here prevents a later encounter from silently replacing ownership.
def starter_boot_allowed(session: Session.WorldSession) -> Bool:
  match session:
    case Session.WorldSession{world, None{}}: True{}
    case _: False{}

def start_checked(allowed: Bool, +session: Session.WorldSession,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  wait_ticks: U32) -> EncounterResult:
  match allowed:
    case True{}:
      preparation(Session.prepare_encounter(tables, session), species, moves,
        starter_id, starter_level, wait_ticks)
    case False{}: Rejected{}

# Selects an encounter once, builds the trusted starter/wild M7 snapshot from
# identity-matched inert catalogs, then lets WorldSession validate the handoff.
def start(+session: Session.WorldSession,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  wait_ticks: U32) -> EncounterResult:
  start_checked(starter_boot_allowed(session), session, tables, species, moves,
    starter_id, starter_level, wait_ticks)

# Continuation starts from the settled progression snapshot left by M7. The
# persistent builder reconstructs the active owner from the roster and carries
# economy, owned inputs, and ledger into the next battle.
def continuation_allowed(session: Session.WorldSession) -> Bool:
  match session:
    case Session.WorldSession{world, Some{progression}}:
      Persistent.state_valid(progression)
    case _: False{}

def continuation_playable(playable: Maybe<Playable.PlayableSession>,
  prepared: Session.PreparedSession, wild_id: Nat,
  wild_level: Nat) -> EncounterResult:
  match playable:
    case None{}: Rejected{}
    case Some{playable}:
      started_result(Session.begin_encounter(prepared, playable), wild_id,
        wild_level)

def completed_from_continuation(progression: Persistent.PersistentState,
  pair: BattleBoot.BootPair, species: Species.Catalog,
  moves: Moves.Catalog, prepared: Session.PreparedSession,
  wild_id: Nat, wild_level: Nat) -> EncounterResult:
  continuation_playable(PlayableBoot.build_continuation(pair, progression,
    species, moves), prepared, wild_id, wild_level)

def continuation_result(pair: BattleBoot.BootResult,
  progression: Persistent.PersistentState,
  species: Species.Catalog, moves: Moves.Catalog,
  prepared: Session.PreparedSession, wild_id: Nat, wild_level: Nat) -> EncounterResult:
  match pair:
    case BattleBoot.BootRejected{}: Rejected{}
    case BattleBoot.BootReady{value}:
      completed_from_continuation(progression, value, species, moves,
        prepared, wild_id, wild_level)

def continuation_built(result: Session.PrepareResult,
  pair: BattleBoot.BootPair, progression: Persistent.PersistentState,
  species: Species.Catalog, moves: Moves.Catalog) -> EncounterResult:
  match result:
    case Session.PrepareRejected{state}: Rejected{}
    case Session.Prepared{value, species_id, level}:
      continuation_result(BattleBoot.BootReady{pair}, progression, species,
        moves, value, species_id, level)

def continuation_session(allowed: Bool, +session: Session.WorldSession,
  progression: Persistent.PersistentState,
  tables: List<&2, Handoff.EncounterTable>, +pair: BattleBoot.BootPair,
  species: Species.Catalog, moves: Moves.Catalog) -> EncounterResult:
  match allowed:
    case False{}: Rejected{}
    case True{}:
      continuation_built(Session.prepare_encounter(tables, session), pair,
        progression, species, moves)

# The host supplies the selected pair from this prepared encounter. Handoff
# validation still checks its encounter, selected species, identity, and RNG.
def start_continuation(+session: Session.WorldSession,
  tables: List<&2, Handoff.EncounterTable>, +pair: BattleBoot.BootPair,
  species: Species.Catalog, moves: Moves.Catalog) -> EncounterResult:
  match session:
    case Session.WorldSession{world, Some{progression}}:
      continuation_session(continuation_allowed(session), session,
        progression, tables, pair, species, moves)
    case _: Rejected{}

def persistent_pair_ready(pair: BattleBoot.BootResult,
  progression: Persistent.PersistentState, species: Species.Catalog,
  moves: Moves.Catalog, prepared: Session.PreparedSession, wild_id: Nat,
  level: Nat) -> EncounterResult:
  continuation_result(pair, progression, species, moves, prepared, wild_id,
    level)

def persistent_prepared(+progression: Persistent.PersistentState,
  prepared: Session.PreparedSession, +species: Species.Catalog,
  moves: Moves.Catalog, wait_ticks: U32) -> EncounterResult:
  match prepared:
    case Session.PreparedSession{world,
        Handoff.Prepared{selected_world, +encounter_id, +wild_id, +level,
          +source_rng}}:
      match selected_world:
        case Exploration.State{map_id, point, meter, pending, +identity}:
          persistent_pair_ready(PlayableBoot.build_continuation_pair(
            progression, species, wild_id, level, encounter_id,
            U32.from_nat(identity), source_rng, wait_ticks), progression,
            species, moves, prepared, wild_id, level)

def persistent_preparation(result: Session.PrepareResult,
  progression: Persistent.PersistentState, species: Species.Catalog,
  moves: Moves.Catalog, wait_ticks: U32) -> EncounterResult:
  match result:
    case Session.PrepareRejected{state}: Rejected{}
    case Session.Prepared{value, species_id, level}:
      persistent_prepared(progression, value, species, moves, wait_ticks)

def persistent_start_checked(allowed: Bool, +session: Session.WorldSession,
  progression: Persistent.PersistentState,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, wait_ticks: U32) -> EncounterResult:
  match allowed:
    case False{}: Rejected{}
    case True{}:
      persistent_preparation(Session.prepare_encounter(tables, session),
        progression, species, moves, wait_ticks)

# Starts the selected encounter directly from the returned progression
# snapshot, preserving the saved first-party member and reward state.
def start_persistent(+session: Session.WorldSession,
  tables: List<&2, Handoff.EncounterTable>, species: Species.Catalog,
  moves: Moves.Catalog, wait_ticks: U32) -> EncounterResult:
  match session:
    case Session.WorldSession{world, Some{progression}}:
      persistent_start_checked(continuation_allowed(session), session,
        progression, tables, species, moves, wait_ticks)
    case _: Rejected{}
