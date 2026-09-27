import Base
import ./commands_test.bend as Fixture
import ../../engine/world/commands.bend as Commands
import ../../engine/world/events.bend as Events
import ../../engine/world/event_bridge.bend as Bridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng

def with_flags(values: List<&2, Events.Value>, x: U32, z: U32) ->
  Bridge.State:
  Bridge.State{Exploration.State{1n, Fixture.point(x, z),
    Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 55n},
    Events.World{values, []}, None{}}

def main() -> List<&2, Bool>:
  [Fixture.rejected(Commands.run(Commands.FastTravel{6n}, Fixture.world(),
     with_flags([Events.Value{6n, 1n}], 900, 900))),
   Fixture.traveled(Commands.run(Commands.FastTravel{6n}, Fixture.world(),
     with_flags([Events.Value{6n, 1n}], 100, 100))),
   Fixture.rejected(Commands.run(Commands.FastTravel{6n}, Fixture.world(),
     with_flags([], 100, 100))),
   Fixture.rejected(Commands.run(Commands.FastTravel{99n}, Fixture.world(),
     with_flags([Events.Value{6n, 1n}], 100, 100)))]
