import Base
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/event_bridge.bend as Bridge
import ../../engine/world/events.bend as Events
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 123n, [],
    [Catalog.EventGraph{1n, 0n,
      [Events.Node{0n, Events.SetValue{3n, 8n}, [1n]},
       Events.Node{1n, Events.Wait{2n}, [2n]},
       Events.Node{2n, Events.Stop{}, []}]}]}

def initial() -> Bridge.State:
  Bridge.State{
    Exploration.State{1n,
      Geometry.Point{Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
      Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 123n},
    Events.World{[], []}, None{}}

def first(result: Bridge.EventBridgeResult) -> Bool:
  match result:
    case Bridge.EventProgress{Bridge.State{exploration,
        Events.World{[], []}, Some{machine}}}: True{}
    case _: False{}

def progress_state(result: Bridge.EventBridgeResult) -> Maybe<&2, Bridge.State>:
  match result:
    case Bridge.EventProgress{state}: Some{state}
    case _: None{}

def waited(result: Bridge.EventBridgeResult) -> Bool:
  match result:
    case Bridge.EventYielded{Bridge.State{exploration,
        Events.World{[], []}, Some{machine}}, Events.Wait{2n}}:
      True{}
    case _: False{}

def resume_progress(found: Maybe<&2, Bridge.State>) -> Bridge.EventBridgeResult:
  match found:
    case None{}: Bridge.EventRejected{initial()}
    case Some{state}: Bridge.step(state, Events.NoInput{})

def completed(result: Bridge.EventBridgeResult) -> Bool:
  match result:
    case Bridge.EventCommitted{Bridge.State{exploration,
        Events.World{[Events.Value{3n, 8n}], []}, None{}}, events}:
      True{}
    case _: False{}

def resume_yield(result: Bridge.EventBridgeResult) -> Bridge.EventBridgeResult:
  match result:
    case Bridge.EventYielded{state, kind}:
      Bridge.step(state, Events.NoInput{})
    case _: Bridge.EventRejected{initial()}

def rejected(result: Bridge.EventBridgeResult) -> Bool:
  match result:
    case Bridge.EventRejected{state}: True{}
    case _: False{}

def wrong_identity() -> Bridge.State:
  Bridge.State{
    Exploration.State{1n,
      Geometry.Point{Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
      Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 124n},
    Events.World{[], []}, None{}}

def main() -> List<&2, Bool>:
  [first(Bridge.start(catalog(), initial(), 1n)),
   waited(resume_progress(progress_state(
     Bridge.start(catalog(), initial(), 1n)))),
   completed(resume_yield(resume_progress(progress_state(
     Bridge.start(catalog(), initial(), 1n))))),
   rejected(Bridge.start(catalog(), wrong_identity(), 1n))]
