import Base
import ../../engine/world/events.bend as Events

def choice_graph() -> List<&2, Events.Node>:
  [Events.Node{0n, Events.Choice{7n}, [1n, 2n]},
   Events.Node{1n, Events.Stop{}, []},
   Events.Node{2n, Events.Stop{}, []}]

def respond(result: Events.EventResult) -> Events.EventResult:
  match result:
    case Events.Yielded{machine, kind}:
      Events.resume(machine, Events.Choose{True{}})
    case _: result

def fuel_abort(result: Events.EventResult) -> Bool:
  match result:
    case Events.Aborted{Events.World{[], []}, Events.FuelLimit{}, usage}:
      True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [fuel_abort(respond(Events.start(choice_graph(), 0n,
    Events.World{[], []}, Events.Limits{1n, 8n, 8n, 8n, 64n})))]
