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
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/progression/core.bend as Progression
import ../../engine/battle/rng.bend as Rng

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

def main() -> Bool:
  Bool.and(started(Encounter.start(pending_session(), encounter_tables(),
      species_catalog(123), move_catalog(123), 4n, 1, 60)),
    Bool.and(rejected(Encounter.start(pending_session(), [],
        species_catalog(123), move_catalog(123), 4n, 1, 60)),
      rejected(Encounter.start(pending_session(), encounter_tables(),
        species_catalog(124), move_catalog(124), 4n, 1, 60))))

#| True
