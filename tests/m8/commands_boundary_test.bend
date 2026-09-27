import Base
import ./commands_test.bend as Fixture
import ../../engine/world/commands.bend as Commands

def main() -> List<&2, Bool>:
  [Fixture.event_started(Commands.run(Commands.Activate{5n},
     Fixture.world(), Fixture.initial_at(500, 500))),
   Fixture.rejected(Commands.run(Commands.Activate{5n},
     Fixture.world(), Fixture.initial_at(600, 600))),
   Fixture.traveled(Commands.run(Commands.Traverse{6n},
     Fixture.world(), Fixture.initial_at(500, 500))),
   Fixture.rejected(Commands.run(Commands.Traverse{6n},
     Fixture.world(), Fixture.initial_at(600, 600)))]
