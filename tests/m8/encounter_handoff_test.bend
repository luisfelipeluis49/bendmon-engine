import Base
import ../../engine/world/encounter_handoff.bend as Handoff
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng
import ../../engine/m7/playable.bend as Playable
import ../m7/session_learning_test.bend as LearningFixture

def world(pending: Maybe<&2, Exploration.PendingEncounter>) ->
  Exploration.State:
  Exploration.State{0n,
    Geometry.Point{Geometry.Coord{False{}, 100},
      Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 100}},
    Encounters.Meter{Some{0n}, 100n, 100n, 0n,
      Rng.RngState{1, 2, 3, 4}}, pending, 123n}

def battle() -> Maybe<Playable.PlayableSession>:
  Playable.open(LearningFixture.full_state(),
    Playable.ContentCatalog{LearningFixture.catalog(), [], 7n, 123n},
    7n, 123n)

def table(species: Nat) -> List<&2, Handoff.EncounterTable>:
  [Handoff.EncounterTable{7n,
    [Encounters.EncounterEntry{species, 1n, 1n, 1n}]}]

def started(result: Handoff.HandoffResult) -> Bool:
  match result:
    case Handoff.HandoffStarted{state, 9n, 1n}: True{}
    case _: False{}

def rejected(result: Handoff.HandoffResult) -> Bool:
  match result:
    case Handoff.HandoffRejected{}: True{}
    case _: False{}

def with_battle(prepared: Handoff.PrepareResult,
  battle: Maybe<Playable.PlayableSession>) -> Bool:
  match prepared battle:
    case Handoff.EncounterPrepared{value} Some{session}:
      started(Handoff.start(value, session))
    case _ _: False{}

def wrong_species(prepared: Handoff.PrepareResult,
  battle: Maybe<Playable.PlayableSession>) -> Bool:
  match prepared battle:
    case Handoff.EncounterPrepared{value} Some{session}:
      rejected(Handoff.start(value, session))
    case _ _: False{}

def prepare_rejected(result: Handoff.PrepareResult) -> Bool:
  match result:
    case Handoff.PrepareRejected{}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [with_battle(Handoff.prepare(world(Some{
     Exploration.PendingEncounter{0n, 7n}}), table(9n)), battle()),
   wrong_species(Handoff.prepare(world(Some{
     Exploration.PendingEncounter{0n, 7n}}), table(8n)), battle()),
   prepare_rejected(Handoff.prepare(world(None{}), table(9n))),
   prepare_rejected(Handoff.prepare(world(Some{
     Exploration.PendingEncounter{0n, 7n}}),
     [Handoff.EncounterTable{8n,
       [Encounters.EncounterEntry{9n, 1n, 1n, 1n}]}]))]
