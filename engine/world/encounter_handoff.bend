import Base
import ./encounters.bend as Encounters
import ./exploration.bend as Exploration
import ./battle_bridge.bend as Bridge
import ../m7/playable.bend as Playable
import ../m7/session.bend as Session
import ../m7/battle.bend as M7
import ../progression/core.bend as Progression
import ../battle/rng.bend as Rng
import ../battle/runtime.bend as Runtime
import ../battle/model.bend as Battle

# Selection is a distinct pure phase because the host builds the M7 combat
# snapshot from the chosen wild species and saved owned roster.
type EncounterTable is Data:
  EncounterTable{id: Nat, entries: List<&2, Encounters.EncounterEntry>}

type Prepared is Data:
  Prepared{world: Exploration.State, encounter_id: Nat,
    species_id: Nat, level: Nat, source_rng: Rng.RngState}

type PrepareResult is Data:
  EncounterPrepared{value: Prepared}
  PrepareRejected{}

type HandoffResult is Data:
  HandoffStarted{state: Bridge.State, species_id: Nat, level: Nat}
  HandoffRejected{}

def table_by_id(tables: List<&2, EncounterTable>, +id: Nat) ->
  Maybe<&2, EncounterTable>:
  match tables:
    case Nil{}: None{}
    case EncounterTable{+row_id, +entries} <> rest:
      Bool.pick(Maybe<&2, EncounterTable>, Nat.is_eq(row_id, id),
        Some{EncounterTable{row_id, entries}}, table_by_id(rest, id))

def selected_world(old: Exploration.State, rng: Rng.RngState) ->
  Exploration.State:
  match old:
    case Exploration.State{map_id, point, meter, pending, identity}:
      Exploration.State{map_id, point,
        Bridge.meter_with_rng(meter, rng), pending, identity}

def selection_result(result: Encounters.EntryResult,
  old: Exploration.State, encounter_id: Nat,
  source_rng: Rng.RngState) -> PrepareResult:
  match result:
    case Encounters.EntryRejected{rng}: PrepareRejected{}
    case Encounters.EntrySelected{species_id, level, rng}:
      EncounterPrepared{Prepared{selected_world(old, rng), encounter_id,
        species_id, level, source_rng}}

def select_table(found: Maybe<&2, EncounterTable>,
  old: Exploration.State, encounter_id: Nat,
  +rng: Rng.RngState) -> PrepareResult:
  match found:
    case None{}: PrepareRejected{}
    case Some{EncounterTable{id, entries}}:
      selection_result(Encounters.choose(entries, rng), old,
        encounter_id, rng)

def prepare_region(valid: Bool, world: Exploration.State,
  table: Maybe<&2, EncounterTable>, encounter_id: Nat,
  rng: Rng.RngState) -> PrepareResult:
  match valid:
    case False{}: PrepareRejected{}
    case True{}: select_table(table, world, encounter_id, rng)

# Draw species and level exactly once. The returned world carries the
# post-selection RNG and remains pending until battle completion.
def prepare(+world: Exploration.State,
  tables: List<&2, EncounterTable>) -> PrepareResult:
  match world:
    case Exploration.State{map_id, point,
        Encounters.Meter{Some{region}, weighted, threshold, safe, +rng},
        Some{Exploration.PendingEncounter{pending_region, +encounter_id}},
        identity}:
      prepare_region(Nat.is_eq(region, pending_region), world,
        table_by_id(tables, encounter_id), encounter_id, rng)
    case _: PrepareRejected{}

def enemy_matches(enemy: Session.Enemy,
  species_id: Nat, level: Nat) -> Bool:
  match enemy:
    case Session.Enemy{actor,
        Progression.Individual{id, species, actual_level, xp, hp, max_hp,
          ivs, moves, history, observations, unlocks, harmony},
        base, reward}:
      Bool.and(Nat.is_eq(species, species_id),
        Nat.is_eq(U32.to_nat(actual_level), level))

def battle_enemy_matches(battle: Playable.PlayableSession,
  species_id: Nat, level: Nat) -> Bool:
  match battle:
    case Playable.PlayableSession{Session.State{m7, rewards,
        [enemy], owners}, learning, evolution, choices,
        evolution_choices, pending, ruleset, identity}:
      enemy_matches(enemy, species_id, level)
    case _: False{}

def fresh_battle(state: Battle.BattleState) -> Bool:
  match state:
    case Battle.BattleState{0, wait, actors, Nil{}, 0n,
        Battle.AwaitingCommands{}}: True{}
    case _: False{}

def fresh_runtime(state: Runtime.RuntimeState) -> Bool:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed,
        sources, Nil{}, trapped, defenders, None{}}:
      fresh_battle(battle)
    case _: False{}

def fresh_playable(session: Playable.PlayableSession) -> Bool:
  match session:
    case Playable.PlayableSession{Session.State{
        M7.State{runtime, economy, roster, captured, catalog},
        rewards, enemies, owners}, learning, evolution, Nil{}, Nil{},
        Playable.NoPending{}, 7n, identity}:
      fresh_runtime(runtime)
    case _: False{}

def rebase_runtime(state: Runtime.RuntimeState,
  rng: Rng.RngState) -> Runtime.RuntimeState:
  match state:
    case Runtime.RuntimeState{battle, old_rng, encounter, failed,
        sources, reservations, trapped, defenders, effects}:
      Runtime.RuntimeState{battle, rng, encounter, failed,
        sources, reservations, trapped, defenders, effects}

def rebase_m7(state: M7.State, rng: Rng.RngState) -> M7.State:
  match state:
    case M7.State{runtime, economy, roster, captured, catalog}:
      M7.State{rebase_runtime(runtime, rng), economy, roster,
        captured, catalog}

def rebase_session(state: Session.State,
  rng: Rng.RngState) -> Session.State:
  match state:
    case Session.State{m7, rewards, enemies, owners}:
      Session.State{rebase_m7(m7, rng), rewards, enemies, owners}

def rebase_playable(old: Playable.PlayableSession,
  rng: Rng.RngState) -> Playable.PlayableSession:
  match old:
    case Playable.PlayableSession{state, learning, evolution, choices,
        evolution_choices, pending, ruleset, identity}:
      Playable.PlayableSession{rebase_session(state, rng), learning,
        evolution, choices, evolution_choices, pending, ruleset, identity}

def selected_rng(world: Exploration.State) -> Rng.RngState:
  match world:
    case Exploration.State{map_id, point, meter, pending, identity}:
      Bridge.meter_rng(meter)

def started(result: Bridge.StartResult,
  species_id: Nat, level: Nat) -> HandoffResult:
  match result:
    case Bridge.Started{state}: HandoffStarted{state, species_id, level}
    case Bridge.StartRejected{}: HandoffRejected{}

def start_checked(valid: Bool, prepared: Prepared,
  battle: Playable.PlayableSession) -> HandoffResult:
  match valid prepared:
    case False{} _: HandoffRejected{}
    case True{} Prepared{+world, encounter_id, species_id, level,
        source_rng}:
      started(Bridge.start(world,
        rebase_playable(battle, selected_rng(world))), species_id, level)

# The host-supplied M7 session must contain the selected single wild enemy.
# Bridge.start checks the encounter ID, exact identity, and post-selection RNG.
def start(+prepared: Prepared,
  +battle: Playable.PlayableSession) -> HandoffResult:
  match prepared:
    case Prepared{world, encounter_id, species_id, level, source_rng}:
      start_checked(Bool.and(fresh_playable(battle),
        Bool.and(battle_enemy_matches(battle, species_id, level),
          Bridge.rng_equal(Bridge.playable_rng(battle), source_rng))),
        prepared, battle)
