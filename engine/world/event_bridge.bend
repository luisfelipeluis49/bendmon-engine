import Base
import ./catalog.bend as Catalog
import ./events.bend as Events
import ./exploration.bend as Exploration

# Uncommitted event work remains in Machine until Complete. The persistent
# world value is never changed by Progress or Yielded.
type State is Data:
  State{exploration: Exploration.State, persistent: Events.World,
    active: Maybe<&2, Events.Machine>}

type EventBridgeResult is Data:
  EventCommitted{state: State, events: List<&2, Events.OutputEvent>}
  EventProgress{state: State}
  EventYielded{state: State, kind: Events.Opcode}
  EventAborted{state: State, diagnostic: Events.Diagnostic}
  EventRejected{state: State}

def limits() -> Events.Limits:
  Events.Limits{256n, 256n, 256n, 256n, 1048576n}

def updated(old: State, persistent: Events.World,
  active: Maybe<&2, Events.Machine>) -> State:
  match old:
    case State{exploration, prior, prior_active}:
      State{exploration, persistent, active}

def from_event_result(result: Events.EventResult, +old: State) -> EventBridgeResult:
  match result:
    case Events.Complete{world, usage, events}:
      EventCommitted{updated(old, world, None{}), events}
    case Events.Progress{machine}:
      match old:
        case State{exploration, persistent, active}:
          EventProgress{State{exploration, persistent, Some{machine}}}
    case Events.Yielded{machine, kind}:
      match old:
        case State{exploration, persistent, active}:
          EventYielded{State{exploration, persistent, Some{machine}}, kind}
    case Events.Aborted{world, diagnostic, usage}:
      EventAborted{updated(old, world, None{}), diagnostic}

def start_graph(found: Maybe<&2, Catalog.EventGraph>,
  +old: State) -> EventBridgeResult:
  match found old:
    case None{} _: EventRejected{old}
    case Some{Catalog.EventGraph{id, entry, nodes}}
         State{exploration, persistent, active}:
      from_event_result(Events.start(nodes, entry, persistent, limits()), old)

def start_checked(valid: Bool, found: Maybe<&2, Catalog.EventGraph>,
  +old: State) -> EventBridgeResult:
  match valid:
    case False{}: EventRejected{old}
    case True{}: start_graph(found, old)

def start_ready(catalog: Catalog.Catalog, +old: State,
  event_id: Nat) -> EventBridgeResult:
  match catalog old:
    case Catalog.Catalog{ruleset, identity, maps, graphs}
         State{Exploration.State{map_id, point, meter, None{}, state_identity},
           persistent, None{}}:
      start_checked(Bool.and(Nat.is_eq(ruleset, 8n),
        Nat.is_eq(identity, state_identity)),
        Catalog.event_by_id(graphs, event_id), old)
    case _ _: EventRejected{old}

# Activate a validated inert graph at a stable world boundary.
def start(catalog: Catalog.Catalog, +old: State,
  event_id: Nat) -> EventBridgeResult:
  start_ready(catalog, old, event_id)

# Advance one node of an activation, retaining all cumulative budgets.
def step(+old: State, input: Events.Input) -> EventBridgeResult:
  match old:
    case State{exploration, persistent, None{}}: EventRejected{old}
    case State{exploration, persistent, Some{machine}}:
      from_event_result(Events.step(machine, input), old)
