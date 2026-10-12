import Base
import ../../engine/world/playtest_world_command.bend as Commands
import ../../engine/world/playtest_boot.bend as Boot
import ../../engine/world/dynamic_content.bend as Joined
import ../../engine/world/dynamic_catalog.bend as World
import ../../engine/world/dynamic_events.bend as EventsWire
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/world_session.bend as Session
import ../../engine/battle/rng.bend as Rng
import ./dynamic_catalog_test.bend as WorldFixture

def event_tokens() -> List<&2, U32>:
  [12, 1, 123, 1, 5, 0, 1, 0, 5, 1, 2, 1, 1, 1, 1, 1]

def starting_point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
    Geometry.Coord{False{}, 0}}

def activated(result: Session.PresentedResult) -> Bool:
  match result:
    case Session.PresentedResult{Session.Advanced{state}, cues}: True{}
    case _: False{}

def rejected(result: Session.PresentedResult) -> Bool:
  match result:
    case Session.PresentedResult{Session.Rejected{state}, cues}: True{}
    case _: False{}

def opened(result: Boot.BootResult,
  catalog: Joined.BoundContent) -> Bool:
  match result catalog:
    case Boot.Booted{+session}
         Joined.BoundContent{identity, entry_map, +world, tables}:
      Bool.and(activated(Commands.run(world, session,
        Commands.PlayActivate{1n}, 7n)),
        rejected(Commands.run(world, session,
          Commands.PlayContinueEvent{}, 8n)))
    case _ _: False{}

def ready(result: Joined.JoinResult) -> Bool:
  match result:
    case Joined.JoinRejected{reason}: False{}
    case Joined.JoinAccepted{+content}:
      match content:
        case Joined.BoundContent{identity, entry_map, +catalog, tables}:
          opened(Boot.boot(catalog, entry_map, starting_point(),
            Rng.RngState{1, 2, 3, 4}, 123n), content)

def main() -> Bool:
  ready(Joined.join(World.decode_tokens(WorldFixture.world_tokens()),
    EventsWire.decode_tokens(event_tokens())))

#| True
