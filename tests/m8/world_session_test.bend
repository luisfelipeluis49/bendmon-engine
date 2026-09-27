import Base
import ../../engine/world/world_session.bend as WorldSession
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/events.bend as Events
import ../../engine/world/commands.bend as Commands
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng
import ./commands_test.bend as CommandFixture

def initial() -> WorldSession.WorldSession:
  WorldSession.WorldSession{EventBridge.State{
    Exploration.State{1n,
      Geometry.Point{Geometry.Coord{False{}, 100},
        Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 100}},
      Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 55n},
    Events.World{[Events.Value{41n, 9n}], [77n]}, None{}}, None{}}

def committed_preserves_world(result: WorldSession.SessionResult) -> Bool:
  match result:
    case WorldSession.Advanced{WorldSession.WorldSession{
        EventBridge.State{exploration, Events.World{[Events.Value{41n, 9n}],
          [77n]}, None{}}, None{}}}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [committed_preserves_world(WorldSession.command(CommandFixture.world(),
      initial(), Commands.Activate{5n}))]
