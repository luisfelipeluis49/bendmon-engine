import Base
import ../../engine/world/save_boundary.bend as Save
import ../../engine/world/save_wire.bend as Wire
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/events.bend as Events
import ../../engine/battle/rng.bend as Rng

def snapshot() -> Save.SnapshotResult:
  Save.SnapshotReady{Save.Snapshot{123n, 2n,
    Geometry.Point{Geometry.Coord{False{}, 1024},
      Geometry.Coord{False{}, 0}, Geometry.Coord{True{}, 12}},
    None{}, 0n, 0n, 0n, Rng.RngState{1, 2, 3, 4},
    [Events.Value{7n, 8n}], [9n]}}

def main() -> Bool:
  Bool.and(String.eq(Wire.serialize(snapshot()),
    "1,123,2,0,1024,0,0,1,12,0,0,0,0,1,2,3,4,1,7,8,1,9"),
    String.eq(Wire.serialize(Save.SnapshotRejected{}), "0"))

#| True
