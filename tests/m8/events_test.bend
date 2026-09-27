import Base
import ../../engine/world/events.bend as Events

def limits(fuel: Nat, queue: Nat) -> Events.Limits:
  Events.Limits{fuel, queue, 8n, 8n, 64n}

def empty_world() -> Events.World:
  Events.World{Nil{}, Nil{}}

def waited_result() -> Events.EventResult:
  Events.start([
    Events.Node{0n, Events.Wait{4n}, [1n]},
    Events.Node{1n, Events.SetValue{7n, 9n}, [2n]},
    Events.Node{2n, Events.Stop{}, Nil{}}], 0n, empty_world(), limits(8n, 8n))

def resume_wait(result: Events.EventResult) -> Events.EventResult:
  match result:
    case Events.Yielded{machine, kind}:
      Events.resume(machine, Events.NoInput{})
    case _:
      result

def advance_one(result: Events.EventResult) -> Events.EventResult:
  match result:
    case Events.Progress{machine}:
      Events.step(machine, Events.NoInput{})
    case Events.Yielded{machine, kind}:
      Events.resume(machine, Events.NoInput{})
    case _:
      result

def wait_commits(result: Events.EventResult) -> Bool:
  match result:
    case Events.Complete{world, usage, events}:
      match world events:
        case Events.World{[Events.Value{7n, 9n}], Nil{}}
             [Events.Waited{4n}]: True{}
        case _ _: False{}
    case _:
      False{}

def choice_result() -> Events.EventResult:
  Events.start([
    Events.Node{0n, Events.Choice{3n}, [1n, 2n]},
    Events.Node{1n, Events.SetValue{1n, 11n}, [3n]},
    Events.Node{2n, Events.SetValue{1n, 22n}, [3n]},
    Events.Node{3n, Events.Stop{}, Nil{}}], 0n, empty_world(), limits(8n, 8n))

def choose_yes(result: Events.EventResult) -> Events.EventResult:
  match result:
    case Events.Yielded{machine, kind}:
      Events.resume(machine, Events.Choose{True{}})
    case _:
      result

def choice_commits(result: Events.EventResult) -> Bool:
  match result:
    case Events.Complete{world, usage, events}:
      match world:
        case Events.World{[Events.Value{1n, 11n}], Nil{}}: True{}
        case _: False{}
    case _: False{}

def atomic_abort_result() -> Events.EventResult:
  Events.start([
    Events.Node{0n, Events.SetValue{1n, 2n}, [1n]},
    Events.Node{1n, Events.SetValue{2n, 3n}, [2n]},
    Events.Node{2n, Events.Stop{}, Nil{}}], 0n, empty_world(), limits(1n, 8n))

def atomic_abort_check(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{world, diagnostic, usage}:
      match world diagnostic:
        case Events.World{Nil{}, Nil{}} Events.FuelLimit{}: True{}
        case _ _: False{}
    case _: False{}

def atomic_abort() -> Bool:
  atomic_abort_check(advance_one(atomic_abort_result()))

def cycle_abort_result() -> Events.EventResult:
  Events.start([
    Events.Node{0n, Events.SetValue{5n, 1n}, [1n]},
    Events.Node{1n, Events.SetValue{5n, 2n}, [0n]}], 0n, empty_world(),
      limits(8n, 8n))

def cycle_abort_check(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{world, diagnostic, usage}:
      match world diagnostic:
        case Events.World{Nil{}, Nil{}} Events.Cycle{0n}: True{}
        case _ _: False{}
    case _: False{}

def cycle_abort() -> Bool:
  cycle_abort_check(advance_one(advance_one(cycle_abort_result())))

def queue_abort_result() -> Events.EventResult:
  Events.start([
    Events.Node{0n, Events.SetValue{4n, 1n}, [1n, 2n]},
    Events.Node{1n, Events.Stop{}, Nil{}},
    Events.Node{2n, Events.Stop{}, Nil{}}], 0n, empty_world(),
      limits(8n, 2n))

def queue_abort_check(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{world, diagnostic, usage}:
      match world diagnostic:
        case Events.World{Nil{}, Nil{}} Events.QueueLimit{}: True{}
        case _ _: False{}
    case _: False{}

def queue_abort() -> Bool:
  queue_abort_check(queue_abort_result())

def finish(ok: Bool) -> U32:
  match ok:
    case True{}: 1
    case False{}: 0

def bool_num(value: Bool) -> U32:
  match value:
    case True{}: 1
    case False{}: 0

def main() -> List<Bool>:
  [wait_commits(advance_one(advance_one(resume_wait(waited_result())))),
   choice_commits(advance_one(advance_one(choose_yes(choice_result())))),
   atomic_abort(), cycle_abort(), queue_abort()]
