import Base
import ../../engine/world/commands.bend as Commands
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/events.bend as Events
import ../../engine/world/event_bridge.bend as Bridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/encounters.bend as Encounters
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

def world() -> Catalog.Catalog:
  Catalog.Catalog{8n, 55n,
    [Catalog.WorldMap{1n, surface(), [],
      [Catalog.Npc{4n, point(200, 200), Some{7n}}],
      [Catalog.Trigger{5n, [0, 1, 2], 7n}],
      [Catalog.Transition{6n, [0, 1, 2], 2n, point(300, 300)}]},
     Catalog.WorldMap{2n, surface(), [], [], [], []}],
    [Catalog.EventGraph{7n, 0n, [Events.Node{0n, Events.Stop{}, []}] }]}

def initial_at(x: U32, z: U32) -> Bridge.State:
  Bridge.State{Exploration.State{1n, point(x, z),
    Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 55n},
    Events.World{[], []}, None{}}

def initial() -> Bridge.State:
  initial_at(100, 100)

def face_forward() -> Commands.Command:
  Commands.Interact{4n, Geometry.Coord{False{}, 1},
    Geometry.Coord{False{}, 1}}

def face_backward() -> Commands.Command:
  Commands.Interact{4n, Geometry.Coord{True{}, 1},
    Geometry.Coord{True{}, 1}}

def rejected(result: Commands.CommandResult) -> Bool:
  match result:
    case Commands.Rejected{state}: True{}
    case _: False{}

def event_started(result: Commands.CommandResult) -> Bool:
  match result:
    case Commands.EventStarted{Bridge.EventCommitted{state, events}}: True{}
    case _: False{}

def traveled(result: Commands.CommandResult) -> Bool:
  match result:
    case Commands.Applied{Bridge.State{
      Exploration.State{2n, point, meter, None{}, 55n}, persistent, None{}}}:
      True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [event_started(Commands.run(face_forward(), world(), initial())),
   event_started(Commands.run(Commands.Activate{5n}, world(), initial())),
   traveled(Commands.run(Commands.Traverse{6n}, world(), initial()))]
