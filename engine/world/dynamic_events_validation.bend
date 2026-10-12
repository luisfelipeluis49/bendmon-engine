import Base
import ./events.bend as Events

def contains(+id: Nat, values: List<&2, Nat>) -> Bool:
  match values:
    case Nil{}: False{}
    case +value <> rest:
      Bool.or(Nat.is_eq(id, value), contains(id, rest))

def has_live_successor(successors: List<&2, Nat>,
  +remaining: List<&2, Nat>) -> Bool:
  match successors:
    case Nil{}: False{}
    case successor <> rest:
      Bool.or(contains(successor, remaining),
        has_live_successor(rest, remaining))

@unsafe def sink_choice(ok: Bool, id: Nat, rest: List<&2, Events.Node>,
  remaining: List<&2, Nat>) -> Maybe<&2, Nat>:
  match ok:
    case True{}: Some{id}
    case False{}: sink(rest, remaining)

@unsafe def sink(nodes: List<&2, Events.Node>,
  +remaining: List<&2, Nat>) -> Maybe<&2, Nat>:
  match nodes:
    case Nil{}: None{}
    case Events.Node{+id, op, next} <> rest:
      sink_choice(Bool.and(contains(id, remaining),
        Bool.not(has_live_successor(next, remaining))), id, rest, remaining)

@unsafe def remove_choice(equal: Bool, id: Nat, value: Nat,
  rest: List<&2, Nat>) -> List<&2, Nat>:
  match equal:
    case True{}: remove_id(id, rest)
    case False{}: value <> remove_id(id, rest)

@unsafe def remove_id(+id: Nat, remaining: List<&2, Nat>) -> List<&2, Nat>:
  match remaining:
    case Nil{}: Nil{}
    case +value <> rest:
      remove_choice(Nat.is_eq(id, value), id, value, rest)

def node_ids(nodes: List<&2, Events.Node>) -> List<&2, Nat>:
  match nodes:
    case Nil{}: Nil{}
    case Events.Node{id, op, next} <> rest: id <> node_ids(rest)

@unsafe def peel_next(result: Maybe<&2, Nat>, fuel: Nat,
  nodes: List<&2, Events.Node>, remaining: List<&2, Nat>) -> Bool:
  match result:
    case None{}: False{}
    case Some{id}: peel(fuel, nodes, remove_id(id, remaining))

@unsafe def peel(fuel: Nat, +nodes: List<&2, Events.Node>,
  remaining: List<&2, Nat>) -> Bool:
  match fuel remaining:
    case _ Nil{}: True{}
    case 0n _ <> _: False{}
    case 1n+left +head <> +tail:
      peel_next(sink(nodes, head <> tail), left, nodes, head <> tail)

# Repeatedly remove graph sinks. A bounded graph is acyclic iff every node can
# be removed; a cycle leaves at least one node with a live successor.
def acyclic(+nodes: List<&2, Events.Node>) -> Bool:
  peel(List.length(&2, Events.Node, nodes), nodes, node_ids(nodes))
