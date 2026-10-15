import Base
import ../../engine/world/dynamic_playable_encounter.bend as Encounter
import ../../engine/world/encounter_handoff.bend as Handoff
import ../../engine/world/world_session.bend as Session
import ../../engine/world/event_bridge.bend as Bridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/events.bend as Events
import ../../engine/world/geometry.bend as Geometry
import ../../engine/m7/dynamic_species.bend as Species
import ../../engine/m7/dynamic_moves.bend as Moves
import ../../engine/m7/playable.bend as Playable
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/m7/persistent_state.bend as Persistent
import ../../engine/progression/core.bend as Progression
import ../../engine/economy/roster.bend as Roster
import ../../engine/battle/rng.bend as Rng
import ../../engine/world/battle_bridge.bend as BattleBridge
import ../../engine/m7/session.bend as M7Session
import ../../engine/m7/reward_bridge.bend as RewardBridge
import ../../tests/m7/session_test.bend as PlayableFixture

def species_row(+id: Nat, hp: U32, speed: U32) -> Species.SpeciesProgressionRecord:
  Species.SpeciesProgressionRecord{id,
    Progression.StatBlock{hp, 50, 40, 35, 45, speed}, 500, 100, 0, [0],
    Rewards.SpeciesLearning{id, []}}

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
    Geometry.Coord{False{}, 0}}

def pending_session() -> Session.WorldSession:
  Session.WorldSession{Bridge.State{
    Exploration.State{1n, point(), Encounters.Meter{Some{1n}, 0n, 500000n,
      0n, Rng.RngState{1, 2, 3, 4}},
      Some{Exploration.PendingEncounter{1n, 77n}}, 123n},
    Events.World{[], []}, None{}}, None{}}

def encounter_tables() -> List<&2, Handoff.EncounterTable>:
  [Handoff.EncounterTable{77n,
    [Encounters.EncounterEntry{9n, 1n, 5n, 5n}]}]

def species_catalog(identity: U32) -> Species.Catalog:
  Species.Catalog{identity, 0,
    [species_row(4n, 50, 60), species_row(9n, 45, 55)]}

def move_catalog(identity: U32) -> Moves.Catalog:
  Moves.Catalog{identity, []}

def started(result: Encounter.EncounterResult) -> Bool:
  match result:
    case Encounter.Started{Session.Battling{persistent, battle}, 9n, 5n}:
      True{}
    case _: False{}

def rejected(result: Encounter.EncounterResult) -> Bool:
  match result:
    case Encounter.Rejected{}: True{}
    case _: False{}

def progressed_session(playable: Maybe<Playable.PlayableSession>) -> Session.WorldSession:
  Session.WorldSession{Bridge.State{
    Exploration.State{1n, point(), Encounters.Meter{None{}, 0n, 500000n,
      0n, Rng.RngState{1, 2, 3, 4}}, None{}, 123n}, Events.World{[], []},
    None{}}, Some{Persistent.PersistentState{PlayableFixture.economy(),
      Roster.Roster{PlayableFixture.capacity(),
        [Roster.IndividualId{77n}], []}, [PlayableFixture.owner_input()],
      Progression.RewardLedger{[7n]}, 7n, 123n}}}

def persistent_state() -> Persistent.PersistentState:
  Persistent.PersistentState{PlayableFixture.economy(),
    Roster.Roster{PlayableFixture.capacity(),
      [Roster.IndividualId{77n}], []}, [PlayableFixture.owner_input()],
    Progression.RewardLedger{[7n]}, 7n, 123n}

def pending_with_progression() -> Session.WorldSession:
  Session.WorldSession{Bridge.State{
    Exploration.State{1n, point(), Encounters.Meter{Some{1n}, 0n, 500000n,
      0n, Rng.RngState{1, 2, 3, 4}},
      Some{Exploration.PendingEncounter{1n, 77n}}, 123n},
    Events.World{[], []}, None{}}, Some{persistent_state()}}

def started_playable(result: Encounter.EncounterResult) -> Maybe<Playable.PlayableSession>:
  match result:
    case Encounter.Started{Session.Battling{persistent,
        BattleBridge.State{world, +playable, returned}}, 9n, 5n}:
      Some{playable}
    case _: None{}

def saved_first_owner(+owned: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match owned:
    case Rewards.OwnedRewardInput{individual, base, ivs, alive, active} <> rest:
      Nat.is_eq(Rewards.individual_id(individual), 77n)
    case Nil{}: False{}

def carried_ledger(context: Maybe<RewardBridge.Context>) -> Bool:
  match context:
    case Some{RewardBridge.Context{encounter, defeated, +owned, items,
        economy, Progression.RewardLedger{[7n]}}}:
      saved_first_owner(owned)
    case _: False{}

def session_context(state: M7Session.State) -> RewardBridge.Context:
  match state:
    case M7Session.State{m7, rewards, enemies, owners}: rewards

def playable_context(playable: Maybe<Playable.PlayableSession>) -> Bool:
  match playable:
    case None{}: False{}
    case Some{Playable.PlayableSession{state, learning, evolution,
        choices, evolution_choices, pending, ruleset, identity}}:
      carried_ledger(Some{session_context(state)})

def carries_progression(result: Encounter.EncounterResult) -> Bool:
  playable_context(started_playable(result))

def rejects_second_encounter() -> Bool:
  rejected(Encounter.start(progressed_session(Some{Playable.PlayableSession{
      PlayableFixture.session_state(), [], [], [], [], Playable.NoPending{},
      7n, 123n}}),
    encounter_tables(), species_catalog(123), move_catalog(123), 4n, 1, 60))

def starts_persistent_second_encounter() -> Bool:
  carries_progression(Encounter.start_persistent(pending_with_progression(),
    encounter_tables(), species_catalog(123), move_catalog(123), 60))

def main() -> Bool:
  Bool.and(started(Encounter.start(pending_session(), encounter_tables(),
      species_catalog(123), move_catalog(123), 4n, 1, 60)),
    Bool.and(rejected(Encounter.start(pending_session(), [],
        species_catalog(123), move_catalog(123), 4n, 1, 60)),
      Bool.and(rejected(Encounter.start(pending_session(), encounter_tables(),
        species_catalog(124), move_catalog(124), 4n, 1, 60)),
        Bool.and(rejects_second_encounter(),
          starts_persistent_second_encounter()))))

#| True
