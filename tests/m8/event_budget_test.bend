import Base
import ../../engine/world/events.bend as Events

def empty() -> Events.World:
  Events.World{[], []}

def resume(result: Events.EventResult) -> Events.EventResult:
  match result:
    case Events.Yielded{machine, kind}:
      Events.resume(machine, Events.NoInput{})
    case Events.Progress{machine}:
      Events.step(machine, Events.NoInput{})
    case _: result

def abort_byte(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{Events.World{[], []}, Events.ByteLimit{}, usage}:
      True{}
    case _: False{}

def abort_entity(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{Events.World{[], []}, Events.EntityLimit{}, usage}:
      True{}
    case _: False{}

def abort_depth(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{Events.World{[], []}, Events.DepthLimit{}, usage}:
      True{}
    case _: False{}

def abort_queue(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{Events.World{[], []}, Events.QueueLimit{}, usage}:
      True{}
    case _: False{}

def byte_after_yield() -> Bool:
  abort_byte(resume(Events.start([
    Events.Node{0n, Events.Wait{1n}, [1n]},
    Events.Node{1n, Events.SetValue{1n, 2n}, [2n]},
    Events.Node{2n, Events.Stop{}, []}], 0n, empty(),
    Events.Limits{8n, 8n, 8n, 8n, 8n})))

def entity_after_write() -> Bool:
  abort_entity(resume(Events.start([
    Events.Node{0n, Events.SetValue{1n, 2n}, [1n]},
    Events.Node{1n, Events.AddEntity{3n, 1n}, [2n]},
    Events.Node{2n, Events.Stop{}, []}], 0n, empty(),
    Events.Limits{8n, 8n, 8n, 0n, 64n})))

def depth_after_write() -> Bool:
  abort_depth(resume(Events.start([
    Events.Node{0n, Events.SetValue{1n, 2n}, [1n]},
    Events.Node{1n, Events.Stop{}, []}], 0n, empty(),
    Events.Limits{8n, 8n, 0n, 8n, 64n})))

def zero_initial_queue() -> Bool:
  abort_queue(Events.start([Events.Node{0n, Events.Stop{}, []}],
    0n, empty(), Events.Limits{8n, 0n, 8n, 8n, 64n}))

def main() -> List<&2, Bool>:
  [byte_after_yield(), entity_after_write(), depth_after_write(),
    zero_initial_queue()]
