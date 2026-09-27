import Base
import ../../engine/world/replay.bend as Replay
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/commands.bend as Commands
import ../../engine/world/world_session.bend as Session
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/events.bend as Events
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/save_boundary.bend as Save
import ../../engine/battle/rng.bend as Rng

def point(x: U32, z: U32) -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, x}, Geometry.Coord{False{}, 0},
    Geometry.Coord{False{}, z}}

def surface() -> Geometry.NavSurface:
  Geometry.NavSurface{
    [Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 0}},
     Geometry.Vertex{Geometry.Coord{False{}, 1000}, Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 0}},
     Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 1000}}],
    [Geometry.Triangle{0, 1, 2}], []}

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 55n,
    [Catalog.WorldMap{1n, surface(), [], [],
      [Catalog.Trigger{5n, [0, 1, 2], 7n}],
      [Catalog.Transition{6n, [0, 1, 2], 2n, point(300, 300)}]},
     Catalog.WorldMap{2n, surface(), [], [], [], []}],
    [Catalog.EventGraph{7n, 0n,
      [Events.Node{0n, Events.SetValue{41n, 9n}, [1n]},
       Events.Node{1n, Events.Stop{}, []}]}]}

def initial() -> Session.WorldSession:
  Session.WorldSession{EventBridge.State{
    Exploration.State{1n, point(100, 100),
      Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 55n},
    Events.World{[], [77n]}, None{}}, None{}}

def script() -> List<&2, Replay.Input>:
  [Replay.ReplayCommand{Commands.Activate{5n}},
   Replay.ReplayEvent{Events.NoInput{}},
   Replay.ReplayCommand{Commands.Traverse{6n}},
   Replay.ReplayMove{Geometry.Input{Geometry.Coord{False{}, 20},
     Geometry.Coord{False{}, 0}, False{}, False{}}}]

def invalid_script() -> List<&2, Replay.Input>:
  [Replay.ReplayCommand{Commands.Activate{5n}},
   Replay.ReplayEvent{Events.NoInput{}},
   Replay.ReplayCommand{Commands.Traverse{6n}},
   Replay.ReplayMove{Geometry.Input{Geometry.Coord{False{}, 20},
     Geometry.Coord{False{}, 0}, False{}, False{}}},
   Replay.ReplayCommand{Commands.Activate{999n}}]

def expected_snapshot(result: Save.SnapshotResult) -> Bool:
  match result:
    case Save.SnapshotReady{Save.Snapshot{55n, 2n, point,
        None{}, 0n, 0n, 0n, rng,
        [Events.Value{41n, 9n}], [77n]}}: True{}
    case _: False{}

def stable_journal(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayComplete{session, 4n}:
      expected_snapshot(Save.project(session))
    case _: False{}

def rejected_at(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayRejected{session, 4n}:
      expected_snapshot(Save.project(session))
    case _: False{}

def is_complete(result: Replay.ReplayResult, expected_steps: Nat) -> Bool:
  match result:
    case Replay.ReplayComplete{session, steps}:
      Nat.is_eq(steps, expected_steps)
    case _: False{}

def main() -> List<&2, Bool>:
  [stable_journal(Replay.replay(script(), catalog(), initial()))]
