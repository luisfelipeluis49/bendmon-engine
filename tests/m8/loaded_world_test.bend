import Base
import ../../build/m8_catalog.bend as Loaded
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/commands.bend as Commands
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/events.bend as Events
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 1024}}

def east() -> Geometry.Input:
  Geometry.Input{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, False{}, False{}}

def opened() -> Exploration.OpenResult:
  Exploration.open(Loaded.catalog(), Loaded.entry_map(), point(),
    Rng.RngState{1, 2, 3, 4}, Loaded.identity())

def triggered(result: Exploration.StepResult) -> Bool:
  match result:
    case Exploration.EncounterReached{Exploration.State{map_id, point,
        meter, Some{Exploration.PendingEncounter{1n, 1n}}, identity}, 1n}:
      True{}
    case _: False{}

def moved(result: Exploration.OpenResult) -> Bool:
  match result:
    case Exploration.Opened{Exploration.State{map_id, point,
        Encounters.Meter{region, weighted, +threshold, safe, rng},
        pending, identity}}:
      triggered(Exploration.move(Loaded.catalog(),
        Exploration.State{map_id, point,
          Encounters.Meter{region, Nat.sub(threshold, 1n), threshold,
            safe, rng}, pending, identity}, east()))
    case _: False{}

def event_applied(result: EventBridge.EventBridgeResult) -> Bool:
  match result:
    case EventBridge.EventCommitted{
        EventBridge.State{exploration,
          Events.World{Events.Value{7n, 1n} <> values, entities}, None{}},
        events}: True{}
    case _: False{}

def event_signal(result: EventBridge.EventBridgeResult) -> Bool:
  match result:
    case EventBridge.EventProgress{state}:
      event_applied(EventBridge.step(state, Events.NoInput{}))
    case _: False{}

def event_first(result: Commands.CommandResult) -> Bool:
  match result:
    case Commands.EventStarted{EventBridge.EventProgress{state}}:
      event_signal(EventBridge.step(state, Events.NoInput{}))
    case _: False{}

def command_result(result: Exploration.OpenResult) -> Bool:
  match result:
    case Exploration.Opened{state}:
      event_first(Commands.run(Commands.Activate{1n}, Loaded.catalog(),
        EventBridge.State{state, Events.World{[], []}, None{}}))
    case _: False{}

def main() -> List<&2, Bool>:
  [moved(opened()), command_result(opened())]
