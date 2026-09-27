import Base

type Opcode is Data:
  SetValue{key: Nat, value: Nat}
  AddEntity{entity: Nat, bytes: Nat}
  EmitSignal{kind: Nat, bytes: Nat}
  Wait{ticks: Nat}
  Choice{prompt: Nat}
  Stop{}

type Node is Data:
  Node{id: Nat, op: Opcode, next: List<&2, Nat>}

type Value is Data:
  Value{key: Nat, value: Nat}

type World is Data:
  World{values: List<&2, Value>, entities: List<&2, Nat>}

type Limits is Data:
  Limits{fuel: Nat, queue: Nat, depth: Nat, entities: Nat, bytes: Nat}

type Usage is Data:
  Usage{fuel: Nat, queued: Nat, depth: Nat, entities: Nat, bytes: Nat}

type Diagnostic is Data:
  MissingNode{node: Nat}
  Cycle{node: Nat}
  FuelLimit{}
  QueueLimit{}
  DepthLimit{}
  EntityLimit{}
  ByteLimit{}
  InvalidChoice{node: Nat}

type Work is Data:
  Work{node: Nat, depth: Nat}

type OutputEvent is Data:
  Signal{kind: Nat}
  Waited{ticks: Nat}
  Asked{prompt: Nat}

type Input is Data:
  NoInput{}
  Choose{yes: Bool}

type Machine is Data:
  Machine{graph: List<&2, Node>, original: World, working: World,
    todo: List<&2, Work>, usage: Usage, events: List<&2, OutputEvent>,
    limits: Limits}

type EventResult is Data:
  Complete{world: World, usage: Usage, events: List<&2, OutputEvent>}
  Progress{machine: Machine}
  Yielded{machine: Machine, kind: Opcode}
  Aborted{world: World, diagnostic: Diagnostic, usage: Usage}

def machine_usage(machine: Machine) -> Usage:
  match machine:
    case Machine{+graph, original, working, todo, usage, events, limits}: usage

def machine_original(machine: Machine) -> World:
  match machine:
    case Machine{+graph, original, working, todo, usage, events, limits}: original

def machine_fuel_limit(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo, usage, events,
        Limits{fuel, queue, depth, entities, bytes}}: fuel

def replace_usage(machine: Machine, usage: Usage) -> Machine:
  match machine:
    case Machine{graph, original, working, todo, old_usage, events, limits}:
      Machine{graph, original, working, todo, usage, events, limits}

def set_value(key: Nat, value: Nat, values: List<&2, Value>) ->
  List<&2, Value>:
  # Values are an append-only journal. A later activation sees later writes
  # after earlier ones; no authored callback or equality scan is needed.
  Value{key, value} <> values

def successors(next: List<&2, Nat>, +depth: Nat,
  remaining: List<&2, Work>) -> List<&2, Work>:
  match next:
    case Nil{}: remaining
    case node <> rest:
      Work{node, depth} <> successors(rest, depth, remaining)

def node_at(id: Nat, nodes: List<&2, Node>) -> Maybe<&2, Node>:
  match id nodes:
    case _ Nil{}: None{}
    case 0n Node{node_id, op, next} <> rest:
      Some{Node{node_id, op, next}}
    case 1n+p node <> rest:
      node_at(p, rest)

def queue_growth(machine: Machine, candidate: Machine) -> Nat:
  match machine candidate:
    case Machine{graph, original, working, old_todo, usage, events, limits}
         Machine{next_graph, next_original, next_working, new_todo,
           next_usage, next_events, next_limits}:
      Nat.sub(List.length(&2, Work, new_todo),
        List.length(&2, Work, old_todo))

def queue_cap(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo, usage, events,
        Limits{fuel, queue, depth, entities, bytes}}: queue

def queued_count(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo,
        Usage{fuel, queued, depth, entities, bytes}, events, limits}: queued

def update_queued(machine: Machine, added: Nat) -> Machine:
  match machine:
    case Machine{graph, original, working, todo,
        Usage{fuel, queued, depth, entities, bytes}, events, limits}:
      Machine{graph, original, working, todo,
        Usage{fuel, (queued + added : Nat), depth, entities, bytes},
        events, limits}

def machine_depth_cap(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo, usage, events,
        Limits{fuel, queue, depth, entities, bytes}}: depth

def machine_entity_cap(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo, usage, events,
        Limits{fuel, queue, depth, entities, bytes}}: entities

def machine_byte_cap(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo, usage, events,
        Limits{fuel, queue, depth, entities, bytes}}: bytes

def usage_queue_after(usage: Usage, added: Nat) -> Nat:
  match usage:
    case Usage{fuel, queued, depth, entities, bytes}:
      (queued + added : Nat)


def machine_queue_cap(machine: Machine) -> Nat:
  match machine:
    case Machine{graph, original, working, todo, usage, events,
        Limits{fuel, queue, depth, entities, bytes}}: queue


def update_queue_usage(machine: Machine, added: Nat) -> Machine:
  match machine:
    case Machine{graph, original, working, todo,
        Usage{fuel, queued, depth, entities, bytes}, events, limits}:
      Machine{graph, original, working, todo,
        Usage{fuel, (queued + added : Nat), depth, entities, bytes},
        events, limits}


def finish_queued_machine(machine: Machine) -> EventResult:
  match machine:
    case Machine{graph, original, working, todo, usage, events, limits}:
      match todo:
        case Nil{}: Complete{working, usage,
          List.reverse(&2, OutputEvent, events)}
        case _ <> _: Progress{machine}


def finish_queue_check(ok: Bool, +machine: Machine, added: Nat) -> EventResult:
  match ok:
    case False{}:
      Aborted{machine_original(machine), QueueLimit{}, machine_usage(machine)}
    case True{}: finish_queued_machine(update_queue_usage(machine, added))

def yield_queue_check(ok: Bool, +machine: Machine, added: Nat,
  kind: Opcode) -> EventResult:
  match ok:
    case False{}:
      Aborted{machine_original(machine), QueueLimit{}, machine_usage(machine)}
    case True{}:
      Yielded{update_queue_usage(machine, added), kind}


def finish_step(+machine: Machine, +added: Nat) -> EventResult:
  match machine:
    case Machine{+graph, original, working, todo, usage, events, limits}:
      finish_queue_check(Nat.is_le(usage_queue_after(usage, added),
        machine_queue_cap(machine)), machine, added)


def set_value_world(depth: Nat, graph: List<&2, Node>, original: World,
  working: World, todo: List<&2, Work>, usage: Usage,
  events: List<&2, OutputEvent>, limits: Limits, id: Nat,
  +next: List<&2, Nat>, key: Nat, value: Nat) -> EventResult:
  match working:
    case World{values, entities}:
      finish_step(Machine{graph, original,
        World{set_value(key, value, values), entities},
        successors(next, (depth + 1n : Nat), todo), usage, events, limits},
        List.length(&2, Nat, next))

def usage_add_bytes(usage: Usage, extra: Nat) -> Usage:
  match usage:
    case Usage{fuel, queued, depth, entities, bytes}:
      Usage{fuel, queued, depth, entities, (bytes + extra : Nat)}




def set_value_accept(ok: Bool, depth: Nat, graph: List<&2, Node>,
  original: World, working: World, todo: List<&2, Work>, usage: Usage,
  events: List<&2, OutputEvent>, limits: Limits, id: Nat,
  +next: List<&2, Nat>, key: Nat, value: Nat) -> EventResult:
  match ok:
    case False{}:
      Aborted{original, ByteLimit{}, usage}
    case True{}:
      set_value_world(depth, graph, original, working, todo,
        usage_add_bytes(usage, 16n), events, limits, id, next, key, value)

def usage_bytes_after(usage: Usage, extra: Nat) -> Nat:
  match usage:
    case Usage{fuel, queued, depth, entities, bytes}:
      (bytes + extra : Nat)

def set_value_budget(ok: Bool, depth: Nat, machine: Machine, id: Nat,
  next: List<&2, Nat>, key: Nat, value: Nat) -> EventResult:
  match machine:
    case Machine{graph, original, working, todo, usage, events, limits}:
      set_value_accept(ok, depth, graph, original, working, todo, usage,
        events, limits, id, next, key, value)

def set_value_node(work: Work, +machine: Machine, id: Nat,
  next: List<&2, Nat>, key: Nat, value: Nat) -> EventResult:
  match work machine:
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}:
      set_value_budget(Nat.is_le(usage_bytes_after(usage, 16n),
        machine_byte_cap(machine)), depth, machine, id, next, key, value)

def add_entity_world_value(working: World, graph: List<&2, Node>,
  original: World, todo: List<&2, Work>, fuel: Nat, queued: Nat,
  depth_used: Nat, count: Nat, used_bytes: Nat,
  events: List<&2, OutputEvent>, limits: Limits, +next: List<&2, Nat>,
  depth: Nat, entity: Nat, bytes: Nat) -> EventResult:
  match working:
    case World{values, entities}:
      finish_step(Machine{graph, original, World{values, entity <> entities},
        successors(next, (depth + 1n : Nat), todo),
        Usage{fuel, queued, depth_used, (count + 1n : Nat),
          (used_bytes + bytes : Nat)}, events, limits},
        List.length(&2, Nat, next))


def add_entity_world(work: Work, machine: Machine, id: Nat,
  next: List<&2, Nat>, entity: Nat, +bytes: Nat) -> EventResult:
  match work machine:
    case Work{node, depth}
         Machine{graph, original, working, todo,
           Usage{fuel, queued, depth_used, count, used_bytes}, events, limits}:
      add_entity_world_value(working, graph, original, todo, fuel, queued,
        depth_used, count, used_bytes, events, limits, next, depth, entity,
        bytes)


def add_entity_limits(entities_ok: Bool, bytes_ok: Bool, work: Work,
  +machine: Machine, id: Nat, next: List<&2, Nat>, entity: Nat,
  bytes: Nat) -> EventResult:
  match entities_ok bytes_ok:
    case False{} _: Aborted{machine_original(machine), EntityLimit{}, machine_usage(machine)}
    case True{} False{}: Aborted{machine_original(machine), ByteLimit{}, machine_usage(machine)}
    case True{} True{}: add_entity_world(work, machine, id, next, entity, bytes)



def add_entity(work: Work, +machine: Machine, id: Nat,
  next: List<&2, Nat>, entity: Nat, +bytes: Nat) -> EventResult:
  match machine:
    case Machine{+graph, original, working, todo, usage, events, limits}:
      match usage:
        case Usage{fuel, queued, depth_used, count, used_bytes}:
          add_entity_limits(Nat.is_le((count + 1n : Nat), machine_entity_cap(machine)),
            Nat.is_le((used_bytes + bytes : Nat), machine_byte_cap(machine)), work,
            machine, id, next, entity, bytes)

def choose_one(node: Nat, work: Work, machine: Machine, id: Nat) -> EventResult:
  match work machine:
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}:
      finish_step(Machine{graph, original, working,
        Work{node, (depth + 1n : Nat)} <> todo, usage, events, limits}, 1n)


def choose_branch(yes: Bool, work: Work, +machine: Machine, id: Nat,
  next: List<&2, Nat>) -> EventResult:
  match yes next:
    case True{} first <> second <> rest:
      choose_one(first, work, machine, id)
    case False{} first <> second <> rest:
      choose_one(second, work, machine, id)
    case _ _: Aborted{machine_original(machine), InvalidChoice{id},
      machine_usage(machine)}


def ask_bytes_ok(ok: Bool, work: Work, +machine: Machine,
  +prompt: Nat) -> EventResult:
  match ok:
    case False{}:
      Aborted{machine_original(machine), ByteLimit{}, machine_usage(machine)}
    case True{}:
      match machine:
        case Machine{graph, original, working, todo, usage, events, limits}:
          # A choice response is a later charged work step. Repeated polls
          # cannot evade the activation's cumulative fuel or byte ceilings.
          Yielded{Machine{graph, original, working, work <> todo,
            usage_add_bytes(usage, 8n), Asked{prompt} <> events, limits},
            Choice{prompt}}

def ask_event(work: Work, +machine: Machine, prompt: Nat) -> EventResult:
  match work machine:
    case Work{node, depth}
         Machine{+graph, +original, +working, +todo, usage, +events, +limits}:
      ask_bytes_ok(Nat.is_le(usage_bytes_after(usage, 8n),
        machine_byte_cap(machine)), work, machine, prompt)

def choose_or_yield(work: Work, input: Input, machine: Machine, id: Nat,
  next: List<&2, Nat>, +prompt: Nat) -> EventResult:
  match input:
    case NoInput{}: ask_event(work, machine, prompt)
    case Choose{yes}:
      choose_branch(yes, work, machine, id, next)

def wait_queued(machine: Machine, ticks: Nat) -> EventResult:
  match machine:
    case Machine{graph, original, working, todo, usage, events, limits}:
      Yielded{Machine{graph, original, working, todo, usage, events,
        limits}, Wait{ticks}}


def wait_queue_check(ok: Bool, +machine: Machine, added: Nat,
  ticks: Nat) -> EventResult:
  match ok:
    case False{}:
      Aborted{machine_original(machine), QueueLimit{}, machine_usage(machine)}
    case True{}:
      wait_queued(update_queue_usage(machine, added), ticks)

def wait_bytes_ok(ok: Bool, work: Work, +machine: Machine, id: Nat,
  +next: List<&2, Nat>, +ticks: Nat) -> EventResult:
  match ok:
    case False{}:
      Aborted{machine_original(machine), ByteLimit{}, machine_usage(machine)}
    case True{}:
      match work machine:
        case Work{node, depth}
             Machine{graph, original, working, todo, usage, events, limits}:
          wait_queue_check(Nat.is_le(usage_queue_after(usage,
              List.length(&2, Nat, next)), machine_queue_cap(machine)),
            Machine{graph, original, working,
              successors(next, (depth + 1n : Nat), todo),
              usage_add_bytes(usage, 8n), Waited{ticks} <> events, limits},
            List.length(&2, Nat, next), ticks)

def wait_event(work: Work, +machine: Machine, id: Nat,
  next: List<&2, Nat>, ticks: Nat) -> EventResult:
  match work machine:
    case Work{node, depth}
         Machine{+graph, +original, +working, +todo, usage, +events, +limits}:
      wait_bytes_ok(Nat.is_le(usage_bytes_after(usage, 8n),
        machine_byte_cap(machine)), work, machine, id, next, ticks)

def emit_signal_ok(ok: Bool, work: Work, +machine: Machine, id: Nat,
  +next: List<&2, Nat>, kind: Nat, +bytes: Nat) -> EventResult:
  match ok:
    case False{}: Aborted{machine_original(machine), ByteLimit{}, machine_usage(machine)}
    case True{}:
      match work machine:
        case Work{node, depth}
             Machine{graph, original, working, todo,
               Usage{+fuel, +queued, +depth_used, +entities, +used_bytes}, events, limits}:
          finish_step(Machine{graph, original, working,
            successors(next, (depth + 1n : Nat), todo),
            Usage{fuel, queued, depth_used, entities, (used_bytes + bytes : Nat)},
            Signal{kind} <> events, limits}, List.length(&2, Nat, next))


def emit_signal(work: Work, machine: Machine, id: Nat,
  +next: List<&2, Nat>, kind: Nat, +bytes: Nat) -> EventResult:
  match machine:
    case Machine{+graph, +original, +working, +todo, usage, +events, +limits}:
      match usage:
        case Usage{+fuel, +queued, +depth_used, +entities, +used_bytes}:
          emit_signal_ok(Nat.is_le((used_bytes + bytes : Nat),
            machine_byte_cap(machine)), work, machine, id, next, kind, bytes)


def node_result(work: Work, input: Input, machine: Machine,
  node: Node) -> EventResult:
  match work machine node:
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}
         Node{id, SetValue{key, value}, next}:
      set_value_node(work, machine, id, next, key, value)
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}
         Node{id, AddEntity{entity, bytes}, next}:
      add_entity(work, machine, id, next, entity, bytes)
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}
         Node{id, EmitSignal{kind, bytes}, next}:
      emit_signal(work, machine, id, next, kind, bytes)
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}
         Node{id, Wait{+ticks}, next}:
      wait_event(work, machine, id, next, ticks)
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}
         Node{id, Choice{+prompt}, next}:
      choose_or_yield(work, input, machine, id, next, prompt)
    case Work{node_id, depth}
         Machine{graph, original, working, todo, usage, events, limits}
         Node{id, Stop{}, next}:
      finish_step(Machine{graph, original, working, todo, usage, events, limits}, 0n)

def work_node(work: Work) -> Nat:
  match work:
    case Work{node, depth}: node

def process_node(work: Work, input: Input, +machine: Machine,
  found: Maybe<&2, Node>) -> EventResult:
  match found:
    case None{}: Aborted{machine_original(machine),
      MissingNode{work_node(work)}, machine_usage(machine)}
    case Some{node}: node_result(work, input, machine, node)

def valid_depth(ok: Bool, work: Work, input: Input,
  +machine: Machine, found: Maybe<&2, Node>) -> EventResult:
  match ok:
    case False{}: Aborted{machine_original(machine),
      DepthLimit{}, machine_usage(machine)}
    case True{}: process_node(work, input, machine, found)

def work_depth(work: Work) -> Nat:
  match work:
    case Work{node, depth}: depth

def cycle_depth(ok: Bool, +work: Work, input: Input,
  +machine: Machine, found: Maybe<&2, Node>) -> EventResult:
  match ok:
    case True{}: Aborted{machine_original(machine),
      Cycle{work_node(work)}, machine_usage(machine)}
    case False{}:
      valid_depth(Nat.is_le(work_depth(work), machine_depth_cap(machine)),
        work, input, machine, found)

def process_step(+work: Work, input: Input, +original_machine: Machine,
  machine: Machine) -> EventResult:
  match machine:
    case Machine{+graph, original, working, todo, usage, events, limits}:
      +found = node_at(work_node(work), graph)
      cycle_depth(Nat.is_ge(work_depth(work), List.length(&2, Node, graph)),
        work, input, machine, found)

def step_fuel(ok: Bool, work: Work, input: Input, +original_machine: Machine,
  machine: Machine) -> EventResult:
  match ok:
    case False{}: Aborted{machine_original(original_machine), FuelLimit{},
      machine_usage(original_machine)}
    case True{}:
      process_step(work, input, original_machine, machine)

def step_nonempty(+work: Work, input: Input, machine: Machine) -> EventResult:
  match machine:
    case Machine{+graph, +original, +working, +todo,
        Usage{+fuel, +queued, +depth_used, +entities, +bytes}, +events, +limits}:
      step_fuel(Nat.is_le((fuel + 1n : Nat), machine_fuel_limit(machine)),
        work, input, machine,
        Machine{graph, original, working, todo,
          Usage{(fuel + 1n : Nat), queued,
            Nat.max(depth_used, work_depth(work)), entities, bytes}, events,
          limits})

def step(machine: Machine, input: Input) -> EventResult:
  match machine:
    case Machine{+graph, original, working, todo, usage, events, limits}:
      match todo:
        case Nil{}: Complete{working, usage,
          List.reverse(&2, OutputEvent, events)}
        case work <> remaining:
          step_nonempty(work, input,
            Machine{graph, original, working, remaining, usage, events, limits})

def start_queue(allowed: Bool, graph: List<&2, Node>, entry: Nat,
  +world: World, limits: Limits) -> EventResult:
  match allowed:
    case False{}:
      Aborted{world, QueueLimit{}, Usage{0n, 1n, 0n, 0n, 0n}}
    case True{}:
      step(Machine{graph, world, world, [Work{entry, 0n}],
        Usage{0n, 1n, 0n, 0n, 0n}, Nil{}, limits}, NoInput{})

def start(graph: List<&2, Node>, entry: Nat, world: World,
  +limits: Limits) -> EventResult:
  match limits:
    case Limits{fuel, queue, depth, entities, bytes}:
      start_queue(Nat.is_ge(queue, 1n), graph, entry, world, limits)

def resume(machine: Machine, input: Input) -> EventResult:
  step(machine, input)
