import Base
import ../../engine/presentation/wire.bend as Wire
import ../../engine/world/presentation_cues.bend as Presentation
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/commands.bend as Commands
import ../../engine/world/events.bend as Events
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/world_session.bend as Session
import ../../engine/battle/rng.bend as Rng

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 1024}}

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 876n,
    [Catalog.WorldMap{5n,
      Geometry.NavSurface{
        [Geometry.Vertex{Geometry.Coord{False{}, 0},
           Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
         Geometry.Vertex{Geometry.Coord{False{}, 65536},
           Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
         Geometry.Vertex{Geometry.Coord{False{}, 0},
           Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 65536}}],
        [Geometry.Triangle{0, 1, 2}], []}, [], [],
      [Catalog.Trigger{1n, [0, 1, 2], 1n}], []}],
    [Catalog.EventGraph{1n, 0n,
      [Events.Node{0n, Events.Wait{3n}, [1n]},
       Events.Node{1n, Events.Stop{}, []}]}]}

def initial() -> Session.WorldSession:
  Session.WorldSession{EventBridge.State{
    Exploration.State{5n, point(), Encounters.empty(Rng.RngState{1, 2, 3, 4}),
      None{}, 876n}, Events.World{[], []}, None{}}, None{}}

def resumed_step(next: Session.PresentedResult,
  first_cues: List<&2, Presentation.Cue>) -> String:
  match next:
    case Session.PresentedResult{result, cues}:
      Wire.serialize_cues(first_cues) ++ "\n" ++ Wire.serialize_cues(cues)

def resumed(started: Session.PresentedResult) -> String:
  match started:
    case Session.PresentedResult{Session.Advanced{state}, first_cues}:
      resumed_step(Session.event_step_presented(state, Events.NoInput{}, 21n),
        first_cues)
    case _: "not-advanced"

def main() -> String:
  resumed(Session.command_presented(catalog(), initial(),
    Commands.Activate{1n}, 20n))
