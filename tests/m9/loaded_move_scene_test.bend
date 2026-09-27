import Base
import ../../build/m8_catalog.bend as Loaded
import ../../engine/world/world_session.bend as WorldSession
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/events.bend as Events
import ../../engine/world/commands.bend as Commands
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/encounters.bend as Encounters
import ../../engine/battle/rng.bend as Rng
import ../../engine/presentation/projection.bend as Projection
import ../../engine/presentation/wire.bend as Wire

def point() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 1024}}

def near_threshold(state: WorldSession.WorldSession) ->
  WorldSession.WorldSession:
  match state:
    case WorldSession.WorldSession{EventBridge.State{
        Exploration.State{map_id, point,
          Encounters.Meter{region, weighted, +threshold, safe, rng},
          pending, +identity}, +persistent, None{}}, None{}}:
      WorldSession.WorldSession{EventBridge.State{
        Exploration.State{map_id, point,
          Encounters.Meter{region, Nat.sub(threshold, 1n), threshold,
            safe, rng}, pending, identity}, persistent, None{}}, None{}}
    case other: other

def opened(result: Exploration.OpenResult) -> Maybe<WorldSession.WorldSession>:
  match result:
    case Exploration.Opened{state}:
      Some{near_threshold(WorldSession.WorldSession{EventBridge.State{state,
        Events.World{[], []}, None{}}, None{}})}
    case _: None{}

def initial() -> Maybe<WorldSession.WorldSession>:
  opened(Exploration.open(Loaded.catalog(), Loaded.entry_map(), point(),
    Rng.RngState{1, 2, 3, 4}, Loaded.identity()))

def east() -> Geometry.Input:
  Geometry.Input{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, False{}, False{}}

def after_move(result: WorldSession.SessionResult) -> String:
  match result:
    case WorldSession.EncounterPending{state, 1n}:
      Wire.serialize(Projection.project(Loaded.catalog(), state,
        Projection.East{}))
    case _: "FAIL"

def after_second_step(result: WorldSession.PresentedResult) -> String:
  match result:
    case WorldSession.PresentedResult{WorldSession.Advanced{+state}, cues}:
      Wire.serialize(Projection.project(Loaded.catalog(), state,
        Projection.East{})) ++ ";" ++
        after_move(WorldSession.move(Loaded.catalog(), state, east()))
    case _: "FAIL"

def after_first_step(result: WorldSession.PresentedResult) -> String:
  match result:
    case WorldSession.PresentedResult{WorldSession.Advanced{state}, cues}:
      after_second_step(WorldSession.event_step_presented(state,
        Events.NoInput{}, 42n))
    case _: "FAIL"

def after_command(result: WorldSession.PresentedResult) -> String:
  match result:
    case WorldSession.PresentedResult{WorldSession.Advanced{state}, cues}:
      after_first_step(WorldSession.event_step_presented(state,
        Events.NoInput{}, 41n))
    case _: "FAIL"

def start(found: Maybe<WorldSession.WorldSession>) -> String:
  match found:
    case Some{state}:
      after_command(WorldSession.command_presented(Loaded.catalog(), state,
        Commands.Activate{1n}, 40n))
    case _: "FAIL"

def main() -> String:
  start(initial())
