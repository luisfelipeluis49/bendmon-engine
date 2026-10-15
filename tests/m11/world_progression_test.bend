import Base
import ../../engine/world/world_session.bend as Session
import ../../engine/world/event_bridge.bend as Bridge
import ../../engine/world/full_save_boundary.bend as FullSave
import ../../engine/world/save_boundary.bend as Save
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/events.bend as Events
import ../../engine/world/commands.bend as Commands
import ../../engine/world/catalog.bend as Catalog
import ../../engine/battle/rng.bend as Rng
import ../../engine/m7/persistent_state.bend as Persistent
import ./persistent_wire_encode_test.bend as ProgressionFixture
import ../m8/commands_test.bend as WorldFixture

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 123n,
    [Catalog.WorldMap{1n, WorldFixture.surface(), [], [], [], []}], []}

def progressed_world() -> Session.WorldSession:
  Session.WorldSession{Bridge.State{Exploration.State{1n,
    WorldFixture.point(100, 100), Encounters.empty(Rng.RngState{1, 2, 3, 4}),
    None{}, 123n}, Events.World{[], []}, None{}},
    Some{ProgressionFixture.progressed()}}

def has_progression(session: Session.WorldSession) -> Bool:
  match session:
    case Session.WorldSession{world, Some{Persistent.PersistentState{
        economy, roster, owned, ledger, 7n, 123n}}}: True{}
    case _: False{}

def legacy_rejected(result: Save.SnapshotResult) -> Bool:
  match result:
    case Save.SnapshotRejected{}: True{}
    case _: False{}

def full_restored(result: FullSave.FullRestoreResult) -> Bool:
  match result:
    case FullSave.FullRestored{session}: has_progression(session)
    case _: False{}

def full_snapshot(result: FullSave.FullSnapshotResult) -> Bool:
  match result:
    case FullSave.FullSnapshotReady{snapshot}:
      full_restored(FullSave.restore(catalog(), snapshot))
    case _: False{}

def rejected_command(result: Session.SessionResult) -> Bool:
  match result:
    case Session.Rejected{session}: has_progression(session)
    case _: False{}

def main() -> List<Bool>:
  [legacy_rejected(Save.project(progressed_world())),
    full_snapshot(FullSave.project(progressed_world())),
    rejected_command(Session.command(catalog(), progressed_world(),
      Commands.Activate{999n}))]
