import Base
import ../../engine/world/playtest_replay.bend as Replay
import ../../engine/world/playtest_world_command.bend as Commands
import ../../engine/world/playtest_boot.bend as Boot
import ../../engine/world/dynamic_content.bend as Content
import ../../engine/world/dynamic_catalog.bend as World
import ../../engine/world/dynamic_events.bend as Events
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/world_session.bend as Session
import ../../engine/battle/rng.bend as Rng
import ./dynamic_catalog_test.bend as WorldFixture
import ./dynamic_content_test.bend as ContentFixture

def starting_point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
    Geometry.Coord{False{}, 0}}

def one_accepted(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.Replayed{session, 1n, cues}: True{}
    case _: False{}

def one_dialogue_accepted(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayedDialogue{session, 1n, cues, 0n, 0n, True{}}:
      True{}
    case _: False{}

def later_rejected(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayRejected{session, 1n}: True{}
    case _: False{}

def first_rejected(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayRejected{session, 0n}: True{}
    case _: False{}

def check_boot(result: Boot.BootResult,
  catalog: Content.BoundContent) -> Bool:
  match result catalog:
    case Boot.Booted{+session}
         Content.BoundContent{identity, entry_map, +world, tables}:
      Bool.and(one_accepted(Replay.run(
        [Commands.PlayActivate{1n}], world, session)),
      Bool.and(one_dialogue_accepted(Replay.run_dialogue_from(
        [], world, session, [], [], 1n)),
      Bool.and(later_rejected(Replay.run(
        [Commands.PlayActivate{1n}, Commands.PlayContinueEvent{}],
        world, session)),
        first_rejected(Replay.run(
          [Commands.PlayContinueEvent{}], world, session)))))
    case _ _: False{}

def check_content(result: Content.JoinResult) -> Bool:
  match result:
    case Content.JoinRejected{reason}: False{}
    case Content.JoinAccepted{+content}:
      match content:
        case Content.BoundContent{identity, entry_map, +catalog, tables}:
          check_boot(Boot.boot(catalog, entry_map, starting_point(),
            Rng.RngState{1, 2, 3, 4}, 123n), content)

def main() -> Bool:
  check_content(Content.join(
    World.decode_tokens(WorldFixture.world_tokens()),
    Events.decode_tokens(ContentFixture.event_tokens())))

#| True
