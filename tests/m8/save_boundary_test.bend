import Base
import ../../engine/world/save_boundary.bend as Save
import ../../engine/world/world_session.bend as Session
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/events.bend as Events
import ../../engine/battle/rng.bend as Rng

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 1000}, Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 1000}}

def stable() -> Session.WorldSession:
  Session.WorldSession{EventBridge.State{Exploration.State{1n, point(), Encounters.Meter{Some{1n}, 24n, 98304n, 0n, Rng.RngState{1, 2, 3, 4}}, None{}, 123n}, Events.World{[], []}, None{}}, None{}}


def nav() -> Geometry.NavSurface:
  Geometry.NavSurface{[Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}}, Geometry.Vertex{Geometry.Coord{False{}, 200000}, Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}}, Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 200000}}], [Geometry.Triangle{0, 1, 2}], []}

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 123n, [Catalog.WorldMap{1n, nav(), [Catalog.EncounterRegion{1n, 9n, [0]}], [], [], []}], []}

def snapshot_ok(result: Save.SnapshotResult) -> Bool:
  match result:
    case Save.SnapshotReady{snapshot}: True{}
    case _: False{}

def restore_ok(result: Save.RestoreResult) -> Bool:
  match result:
    case Save.Restored{session}: snapshot_ok(Save.project(session))
    case _: False{}

def snapshot_rejected(result: Save.SnapshotResult) -> Bool:
  match result:
    case Save.SnapshotRejected{}: True{}
    case _: False{}

def restore_rejected(result: Save.RestoreResult) -> Bool:
  match result:
    case Save.RestoreRejected{}: True{}
    case _: False{}

def journal_snapshot(result: Save.SnapshotResult) -> Bool:
  match result:
    case Save.SnapshotReady{Save.Snapshot{identity, map_id, point,
        region, weighted, threshold, safe, rng,
        [Events.Value{7n, 1n}, Events.Value{7n, 0n}], [8n, 8n]}}:
      True{}
    case _: False{}

def journal_preserved(result: Save.RestoreResult) -> Bool:
  match result:
    case Save.Restored{session}:
      journal_snapshot(Save.project(session))
    case _: False{}

def pending_rejected() -> Bool:
  snapshot_rejected(Save.project(Session.WorldSession{EventBridge.State{
    Exploration.State{1n, point(),
      Encounters.Meter{Some{1n}, 24n, 98304n, 0n,
        Rng.RngState{1, 2, 3, 4}},
      Some{Exploration.PendingEncounter{1n, 9n}}, 123n},
    Events.World{[], []}, None{}}, None{}}))

def main() -> List<&2, Bool>:
  [snapshot_ok(Save.project(stable())),
   pending_rejected()]
