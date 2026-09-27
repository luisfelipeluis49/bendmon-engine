import Base
import ../../engine/presentation/projection.bend as Projection
import ../../engine/presentation/wire.bend as Wire
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/events.bend as Events
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/world_session.bend as WorldSession
import ../../engine/battle/rng.bend as Rng

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{True{}, 24},
    Geometry.Coord{False{}, 8}, Geometry.Coord{False{}, 96}}

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 876n,
    [Catalog.WorldMap{5n, Geometry.NavSurface{[], [], []}, [],
      [Catalog.Npc{11n, point(), Some{3n}}], [], []}], []}

def session() -> WorldSession.WorldSession:
  WorldSession.WorldSession{EventBridge.State{
    Exploration.State{5n, point(), Encounters.empty(Rng.RngState{1, 2, 3, 4}),
      None{}, 876n}, Events.World{[], []}, None{}}, None{}}

def main() -> String:
  Wire.serialize(Projection.project(catalog(), session(), Projection.East{}))
