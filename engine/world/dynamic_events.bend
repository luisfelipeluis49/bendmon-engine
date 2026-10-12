import Base
import ./events.bend as Events
import ./encounters.bend as Encounters
import ./encounter_handoff.bend as Handoff
import ./dynamic_events_validation.bend as Validation

# The unproved parser helpers below are a closed numeric decoder, not creator
# callbacks. `decode_tokens` caps the whole request at 140,000 U32 values;
# graph/table counts and every per-record node/entry count are capped at 256,
# and aggregate successor/entry references are capped at 4,096 before output.
# The only recursive paths are the shrinking counters in nodes_read/nodes_push,
# graphs_read/graph_accumulate, entries_read/entry_after, and
# tables_read/table_more; the finite duplicate scans run over those decoded
# lists. Staged helpers are marked unsafe because Bend's checker cannot carry
# these parsed Nat counts through their mutually staged cursor continuations.

type DynamicEvents is Data:
  DynamicEvents{content_identity: U32,
    graphs: List<&2, EventsGraph>, tables: List<&2, Handoff.EncounterTable>}

type EventsGraph is Data:
  EventsGraph{id: Nat, entry: Nat, nodes: List<&2, Events.Node>}

type DecodeResult is Data:
  DecodeRejected{reason: String}
  DecodeAccepted{value: DynamicEvents}

type NodeRead is Data:
  NodeBad{reason: String}
  NodeDone{value: Events.Node, rest: List<&2, U32>}

type NodesRead is Data:
  NodesBad{reason: String}
  NodesDone{values: List<&2, Events.Node>, rest: List<&2, U32>}

type GraphRead is Data:
  GraphBad{reason: String}
  GraphDone{value: EventsGraph, rest: List<&2, U32>, refs: Nat}

type GraphsRead is Data:
  GraphsBad{reason: String}
  GraphsDone{values: List<&2, EventsGraph>, rest: List<&2, U32>, refs: Nat}

type TableRead is Data:
  TableBad{reason: String}
  TableDone{value: Handoff.EncounterTable, rest: List<&2, U32>, refs: Nat}

type TablesRead is Data:
  TablesBad{reason: String}
  TablesDone{values: List<&2, Handoff.EncounterTable>,
    rest: List<&2, U32>, refs: Nat}

def opcode_value(code: U32, a: U32, b: U32) -> Maybe<&2, Events.Opcode>:
  match code:
    case 0: Some{Events.SetValue{U32.to_nat(a), U32.to_nat(b)}}
    case 1: Some{Events.AddEntity{U32.to_nat(a), U32.to_nat(b)}}
    case 2: Some{Events.EmitSignal{U32.to_nat(a), U32.to_nat(b)}}
    case 3: Some{Events.Wait{U32.to_nat(a)}}
    case 4: Some{Events.Choice{U32.to_nat(a)}}
    case 5: Some{Events.Stop{}}
    case _: None{}

def arg_limits(code: U32, a: U32, b: U32) -> Bool:
  match code:
    case 0: Bool.and(U32.is_le(a, 999999999), U32.is_le(b, 999999999))
    case 1: Bool.and(U32.is_le(a, 999999999), U32.is_le(b, 1048576))
    case 2: Bool.and(U32.is_le(a, 999999999), U32.is_le(b, 1048576))
    case 3: U32.is_le(a, 999999999)
    case 4: U32.is_le(a, 999999999)
    case 5: True{}
    case _: False{}

def node_value_result(result: Maybe<&2, Events.Opcode>, expected_id: U32,
  target: U32, tail: List<&2, U32>) -> NodeRead:
  match result:
    case None{}: NodeBad{"event-opcode"}
    case Some{op}:
      NodeDone{Events.Node{U32.to_nat(expected_id), op,
        [U32.to_nat(target)]}, tail}

@unsafe def nodes_read(index: Nat, count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Events.Node>) -> NodesRead:
  match index:
    case 0n: NodesDone{List.reverse(&2, Events.Node, acc), tokens}
    case 1n+left:
      match tokens:
        case id <> code <> tail:
          node_read_after(left, count, id, code, tail, acc)
        case _: NodesBad{"event-node-header"}

@unsafe def node_read_after(+left: Nat, +count: Nat, +id: U32, code: U32,
  tail: List<&2, U32>, acc: List<&2, Events.Node>) -> NodesRead:
  node_id_check(Nat.is_eq(U32.to_nat(id), Nat.sub(Nat.sub(count, 1n), left)),
    left, count, id, code, tail, acc)

@unsafe def node_id_check(ok: Bool, left: Nat, count: Nat, id: U32, code: U32,
  tail: List<&2, U32>, acc: List<&2, Events.Node>) -> NodesRead:
  match ok:
    case False{}: NodesBad{"event-node-id"}
    case True{}: node_after(left, count, id, code, tail, acc)

@unsafe def node_after(left: Nat, count: Nat, id: U32, code: U32,
  tail: List<&2, U32>, acc: List<&2, Events.Node>) -> NodesRead:
  match code:
    case 0: node_two_args(left, count, id, code, tail, acc)
    case 1: node_two_args(left, count, id, code, tail, acc)
    case 2: node_two_args(left, count, id, code, tail, acc)
    case 3: node_one_arg(left, count, id, code, tail, acc)
    case 4: node_choice(left, count, id, tail, acc)
    case 5:
      nodes_push(left, count,
        NodeDone{Events.Node{U32.to_nat(id), Events.Stop{}, []}, tail}, acc)
    case _: NodesBad{"event-opcode"}

def node_argument_check(ok: Bool, code: U32, a: U32, b: U32,
  expected_id: U32, target: U32, tail: List<&2, U32>) -> NodeRead:
  match ok:
    case False{}: NodeBad{"event-argument"}
    case True{}:
      node_value_result(opcode_value(code, a, b), expected_id, target, tail)

def node_arguments_valid(+code: U32, +a: U32, +b: U32,
  expected_id: U32, target: U32, tail: List<&2, U32>) -> NodeRead:
  node_argument_check(arg_limits(code, a, b), code, a, b,
    expected_id, target, tail)

def one_successor_check(ok: Bool, code: U32, a: U32, b: U32,
  expected_id: U32, target: U32, tail: List<&2, U32>) -> NodeRead:
  match ok:
    case False{}: NodeBad{"event-successor"}
    case True{}:
      node_arguments_valid(code, a, b, expected_id, target, tail)

def node_with_one_successor(code: U32, a: U32, b: U32,
  expected_id: U32, count: Nat, +target: U32,
  tail: List<&2, U32>) -> NodeRead:
  one_successor_check(Bool.and(U32.is_le(target, 255),
    Nat.is_lt(U32.to_nat(target), count)), code, a, b,
    expected_id, target, tail)

def choice_arguments_valid(ok: Bool, prompt: U32, expected_id: U32,
  first: U32, second: U32, tail: List<&2, U32>) -> NodeRead:
  match ok:
    case False{}: NodeBad{"event-argument"}
    case True{}:
      NodeDone{Events.Node{U32.to_nat(expected_id),
        Events.Choice{U32.to_nat(prompt)},
        [U32.to_nat(first), U32.to_nat(second)]}, tail}

def two_successors_check(ok: Bool, +prompt: U32, expected_id: U32,
  +first: U32, +second: U32, tail: List<&2, U32>) -> NodeRead:
  match ok:
    case False{}: NodeBad{"event-successor"}
    case True{}:
      choice_arguments_valid(U32.is_le(prompt, 999999999), prompt,
        expected_id, first, second, tail)

def node_with_two_successors(+prompt: U32, expected_id: U32,
  +count: Nat, +first: U32, +second: U32,
  tail: List<&2, U32>) -> NodeRead:
  two_successors_check(Bool.and(U32.is_le(first, 255),
    Bool.and(U32.is_le(second, 255), Bool.and(
      Nat.is_lt(U32.to_nat(first), count),
      Nat.is_lt(U32.to_nat(second), count)))), prompt, expected_id,
      first, second, tail)

@unsafe def node_two_args(left: Nat, +count: Nat, id: U32, code: U32,
  tail: List<&2, U32>, acc: List<&2, Events.Node>) -> NodesRead:
  match tail:
    case +a <> +b <> rest:
      match rest:
        case target <> after:
          nodes_push(left, count,
            node_with_one_successor(code, a, b, id, count, target, after), acc)
        case _: NodesBad{"event-successor-missing"}
    case _: NodesBad{"event-argument-missing"}

@unsafe def node_one_arg(left: Nat, +count: Nat, id: U32, code: U32,
  tail: List<&2, U32>, acc: List<&2, Events.Node>) -> NodesRead:
  match tail:
    case +a <> target <> rest:
      nodes_push(left, count,
        node_with_one_successor(code, a, 0, id, count, target, rest), acc)
    case _: NodesBad{"event-argument-or-successor-missing"}

@unsafe def node_choice(left: Nat, +count: Nat, id: U32,
  tail: List<&2, U32>, acc: List<&2, Events.Node>) -> NodesRead:
  match tail:
    case +prompt <> first <> second <> rest:
      nodes_push(left, count,
        node_with_two_successors(prompt, id, count, first, second, rest), acc)
    case _: NodesBad{"event-argument-or-successor-missing"}

@unsafe def nodes_push(left: Nat, count: Nat, result: NodeRead,
  acc: List<&2, Events.Node>) -> NodesRead:
  match left:
    case 0n: nodes_push_last(result, acc)
    case 1n+more: nodes_push_more(result, more, count, acc)

def nodes_push_last(result: NodeRead,
  acc: List<&2, Events.Node>) -> NodesRead:
  match result:
    case NodeBad{reason}: NodesBad{reason}
    case NodeDone{node, rest}:
      NodesDone{List.reverse(&2, Events.Node, node <> acc), rest}

@unsafe def nodes_push_more(result: NodeRead, more: Nat, count: Nat,
  acc: List<&2, Events.Node>) -> NodesRead:
  match result:
    case NodeBad{reason}: NodesBad{reason}
    case NodeDone{node, rest}:
      nodes_read((1n + more : Nat), count, rest, node <> acc)

@unsafe def graph_count_valid(ok: Bool, id: U32, entry: U32, +count: U32,
  tail: List<&2, U32>) -> GraphRead:
  match ok:
    case False{}: GraphBad{"event-graph-header"}
    case True{}:
      graph_nodes(id, entry, nodes_read(U32.to_nat(count),
        U32.to_nat(count), tail, Nil{}))

def graph_node_refs(nodes: List<&2, Events.Node>) -> Nat:
  match nodes:
    case Nil{}: 0n
    case Events.Node{id, op, next} <> rest:
      (List.length(&2, Nat, next) + graph_node_refs(rest) : Nat)

def graph_nodes(id: U32, entry: U32,
  result: NodesRead) -> GraphRead:
  match result:
    case NodesBad{reason}: GraphBad{reason}
    case NodesDone{+nodes, rest}:
      GraphDone{EventsGraph{U32.to_nat(id), U32.to_nat(entry), nodes},
        rest, graph_node_refs(nodes)}

def graph_header(+id: U32, +entry: U32, +count: U32,
  tail: List<&2, U32>) -> GraphRead:
  graph_count_valid(Bool.and(U32.is_le(1, id),
      Bool.and(U32.is_le(1, count), Bool.and(U32.is_le(count, 256),
        U32.is_lt(entry, count)))), id, entry, count, tail)

@unsafe def graphs_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, EventsGraph>, refs: Nat) -> GraphsRead:
  match count:
    case 0n: GraphsDone{List.reverse(&2, EventsGraph, acc), tokens, refs}
    case 1n+left:
      match tokens:
        case id <> entry <> node_count <> rest:
          graph_push(left, id, entry, node_count, rest, acc, refs)
        case _: GraphsBad{"event-graph-header"}

@unsafe def graph_push(left: Nat, id: U32, entry: U32, node_count: U32,
  rest: List<&2, U32>, acc: List<&2, EventsGraph>, refs: Nat) -> GraphsRead:
  graph_accumulate(left, acc, refs,
    graph_header(id, entry, node_count, rest))

@unsafe def graph_accumulate(left: Nat, acc: List<&2, EventsGraph>,
  +refs: Nat, result: GraphRead) -> GraphsRead:
  match result:
    case GraphBad{reason}: GraphsBad{reason}
    case GraphDone{EventsGraph{id, entry, nodes}, rest, +new_refs}:
      graph_ref_check(Nat.is_le((refs + new_refs : Nat), 4096n),
        left, acc, refs, new_refs, id, entry, nodes, rest)

@unsafe def graph_ref_check(ok: Bool, left: Nat,
  acc: List<&2, EventsGraph>, +refs: Nat, +new_refs: Nat, id: Nat,
  entry: Nat, nodes: List<&2, Events.Node>, rest: List<&2, U32>) -> GraphsRead:
  match ok:
    case False{}: GraphsBad{"event-reference-count"}
    case True{}:
      match left:
        case 0n:
          GraphsDone{List.reverse(&2, EventsGraph,
            EventsGraph{id, entry, nodes} <> acc), rest,
            (refs + new_refs : Nat)}
        case 1n+more:
          graphs_read((1n + more : Nat), rest,
            EventsGraph{id, entry, nodes} <> acc,
            (refs + new_refs : Nat))

type EntriesRead is Data:
  EntriesBad{reason: String}
  EntriesDone{values: List<&2, Encounters.EncounterEntry>,
    rest: List<&2, U32>}

def encounter_entry(ok: Bool, species: U32, weight: U32,
  minimum: U32, maximum: U32) -> Maybe<&2, Encounters.EncounterEntry>:
  match ok:
    case True{}:
      Some{Encounters.EncounterEntry{U32.to_nat(species),
        U32.to_nat(weight), U32.to_nat(minimum), U32.to_nat(maximum)}}
    case False{}: None{}

def valid_entry(+species: U32, +weight: U32, +minimum: U32,
  +maximum: U32) -> Maybe<&2, Encounters.EncounterEntry>:
  encounter_entry(Bool.and(U32.is_le(1, species),
    Bool.and(U32.is_le(species, 256), Bool.and(U32.is_le(1, weight),
      Bool.and(U32.is_le(weight, 10000), Bool.and(U32.is_le(1, minimum),
        Bool.and(U32.is_le(minimum, maximum), U32.is_le(maximum, 200))))))),
    species, weight, minimum, maximum)

@unsafe def entries_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Encounters.EncounterEntry>) -> EntriesRead:
  match count:
    case 0n: EntriesDone{List.reverse(&2, Encounters.EncounterEntry, acc), tokens}
    case 1n+left:
      match tokens:
        case species <> weight <> minimum <> maximum <> rest:
          entry_after(left, species, weight, minimum, maximum, rest, acc)
        case _: EntriesBad{"encounter-entry-missing"}

@unsafe def entry_after(left: Nat, +species: U32, +weight: U32,
  +minimum: U32, +maximum: U32, rest: List<&2, U32>,
  acc: List<&2, Encounters.EncounterEntry>) -> EntriesRead:
  entry_validation(valid_entry(species, weight, minimum, maximum),
    left, species, weight, minimum, maximum, rest, acc)

def entry_validation(result: Maybe<&2, Encounters.EncounterEntry>,
  left: Nat, species: U32, weight: U32, minimum: U32, maximum: U32,
  rest: List<&2, U32>, acc: List<&2, Encounters.EncounterEntry>) -> EntriesRead:
  match result:
    case None{}: EntriesBad{"encounter-entry"}
    case Some{entry}:
      match left:
        case 0n: EntriesDone{List.reverse(&2,
          Encounters.EncounterEntry, entry <> acc), rest}
        case 1n+more:
          entries_read(left, rest, entry <> acc)

@unsafe def tables_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Handoff.EncounterTable>, refs: Nat) -> TablesRead:
  match count:
    case 0n: TablesDone{List.reverse(&2, Handoff.EncounterTable, acc), tokens, refs}
    case 1n+left:
      match tokens:
        case id <> entry_count <> rest:
          table_after(left, id, entry_count, rest, acc, refs)
        case _: TablesBad{"encounter-header"}

@unsafe def table_after(left: Nat, +id: U32, +entry_count: U32,
  rest: List<&2, U32>, acc: List<&2, Handoff.EncounterTable>,
  refs: Nat) -> TablesRead:
  table_count_check(Bool.and(U32.is_le(1, id),
    Bool.and(U32.is_le(1, entry_count), U32.is_le(entry_count, 256))),
    left, id, entry_count, rest, acc, refs)

@unsafe def table_count_check(ok: Bool, left: Nat, +id: U32, +entry_count: U32,
  rest: List<&2, U32>, acc: List<&2, Handoff.EncounterTable>,
  refs: Nat) -> TablesRead:
  match ok:
    case False{}: TablesBad{"encounter-count"}
    case True{}:
      tables_entries(left, id, entry_count,
        entries_read(U32.to_nat(entry_count), rest, Nil{}), acc, refs)

@unsafe def tables_entries(left: Nat, id: U32, entry_count: U32,
  result: EntriesRead, acc: List<&2, Handoff.EncounterTable>,
  refs: Nat) -> TablesRead:
  match result:
    case EntriesBad{reason}: TablesBad{reason}
    case EntriesDone{entries, rest}:
      table_add(left, id, entry_count, entries, rest, acc, refs)

@unsafe def table_add(left: Nat, id: U32, +entry_count: U32,
  entries: List<&2, Encounters.EncounterEntry>, rest: List<&2, U32>,
  acc: List<&2, Handoff.EncounterTable>, +refs: Nat) -> TablesRead:
  table_ref_check(Nat.is_le((refs + U32.to_nat(entry_count) : Nat), 4096n),
    left, id, entry_count, entries, rest, acc, refs)

@unsafe def table_ref_check(ok: Bool, left: Nat, id: U32,
  entry_count: U32, entries: List<&2, Encounters.EncounterEntry>,
  rest: List<&2, U32>, acc: List<&2, Handoff.EncounterTable>,
  refs: Nat) -> TablesRead:
  match ok:
    case False{}: TablesBad{"encounter-reference-count"}
    case True{}:
      match left:
        case 0n: table_last(id, entry_count, entries, rest, acc, refs)
        case 1n+more:
          table_more(more, id, entry_count, entries, rest, acc, refs)

def table_last(id: U32, entry_count: U32,
  entries: List<&2, Encounters.EncounterEntry>, rest: List<&2, U32>,
  acc: List<&2, Handoff.EncounterTable>, refs: Nat) -> TablesRead:
  +table: Handoff.EncounterTable = Handoff.EncounterTable{
    U32.to_nat(id), entries}
  TablesDone{List.reverse(&2, Handoff.EncounterTable, table <> acc), rest,
    (refs + U32.to_nat(entry_count) : Nat)}

@unsafe def table_more(more: Nat, id: U32, entry_count: U32,
  entries: List<&2, Encounters.EncounterEntry>, rest: List<&2, U32>,
  acc: List<&2, Handoff.EncounterTable>, refs: Nat) -> TablesRead:
  +table: Handoff.EncounterTable = Handoff.EncounterTable{
    U32.to_nat(id), entries}
  tables_read((1n + more : Nat), rest, table <> acc,
    (refs + U32.to_nat(entry_count) : Nat))

@unsafe def duplicate_graph_id(graph: EventsGraph,
  graphs: List<&2, EventsGraph>) -> Bool:
  match graph:
    case EventsGraph{graph_id, graph_entry, graph_nodes}:
      duplicate_graph_scan(graph_id, graphs)

def duplicate_graph_scan(+id: Nat, graphs: List<&2, EventsGraph>) -> Bool:
  match graphs:
    case Nil{}: False{}
    case EventsGraph{row_id, entry, nodes} <> rest:
      Bool.or(Nat.is_eq(id, row_id), duplicate_graph_scan(id, rest))

def unique_graphs(graphs: List<&2, EventsGraph>) -> Bool:
  match graphs:
    case Nil{}: True{}
    case graph <> +rest:
      Bool.and(Bool.not(duplicate_graph_id(graph, rest)), unique_graphs(rest))

@unsafe def duplicate_table_id(table: Handoff.EncounterTable,
  tables: List<&2, Handoff.EncounterTable>) -> Bool:
  match table:
    case Handoff.EncounterTable{id, entries}:
      duplicate_table_scan(id, tables)

def duplicate_table_scan(+id: Nat,
  tables: List<&2, Handoff.EncounterTable>) -> Bool:
  match tables:
    case Nil{}: False{}
    case Handoff.EncounterTable{row_id, entries} <> rest:
      Bool.or(Nat.is_eq(id, row_id), duplicate_table_scan(id, rest))

def unique_tables(tables: List<&2, Handoff.EncounterTable>) -> Bool:
  match tables:
    case Nil{}: True{}
    case table <> +rest:
      Bool.and(Bool.not(duplicate_table_id(table, rest)), unique_tables(rest))

def graph_node_total(graphs: List<&2, EventsGraph>) -> Nat:
  match graphs:
    case Nil{}: 0n
    case EventsGraph{id, entry, nodes} <> rest:
      (List.length(&2, Events.Node, nodes) + graph_node_total(rest) : Nat)

def graphs_acyclic(graphs: List<&2, EventsGraph>) -> Bool:
  match graphs:
    case Nil{}: True{}
    case EventsGraph{id, entry, nodes} <> rest:
      Bool.and(Validation.acyclic(nodes), graphs_acyclic(rest))

def graph_semantics(+graphs: List<&2, EventsGraph>) -> Bool:
  Bool.and(Nat.is_le(graph_node_total(graphs), 256n),
    graphs_acyclic(graphs))

@unsafe def decode_after_graphs(identity: U32, result: GraphsRead) -> DecodeResult:
  match result:
    case GraphsBad{reason}: DecodeRejected{reason}
    case GraphsDone{graphs, rest, refs}:
      match rest:
        case +table_count <> tail:
          tables_after(identity, refs, graphs,
            U32.is_le(table_count, 256), table_count, tail)
        case _: DecodeRejected{"encounter-count-missing"}

@unsafe def tables_after(identity: U32, refs: Nat,
  graphs: List<&2, EventsGraph>, ok: Bool, count: U32,
  tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"encounter-count"}
    case True{}:
      decode_after_tables(identity, graphs,
        tables_read(U32.to_nat(count), tokens, Nil{}, refs))

@unsafe def decode_after_tables(identity: U32, +graphs: List<&2, EventsGraph>,
  result: TablesRead) -> DecodeResult:
  match result:
    case TablesBad{reason}: DecodeRejected{reason}
    case TablesDone{+tables, Nil{}, refs}:
      unique_content_result(Bool.and(graph_semantics(graphs),
        Bool.and(unique_graphs(graphs), unique_tables(tables))),
        identity, graphs, tables)
    case TablesDone{tables, rest, refs}: DecodeRejected{"trailing"}

def unique_content_result(ok: Bool, identity: U32,
  graphs: List<&2, EventsGraph>,
  tables: List<&2, Handoff.EncounterTable>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"duplicate-content-id"}
    case True{}: DecodeAccepted{DynamicEvents{identity, graphs, tables}}

def header_ok(magic: U32, version: U32, count: U32) -> Bool:
  Bool.and(U32.is_eq(magic, 12), Bool.and(U32.is_eq(version, 1),
    U32.is_le(count, 256)))

@unsafe def decode_tokens_inner(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case magic <> version <> identity <> +graph_count <> rest:
      decode_header(header_ok(magic, version, graph_count), identity,
        graph_count, rest)
    case _: DecodeRejected{"header"}

def decode_header(ok: Bool, identity: U32, graph_count: U32,
  rest: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"header"}
    case True{}:
      decode_after_graphs(identity,
        graphs_read(U32.to_nat(graph_count), rest, Nil{}, 0n))

@unsafe def decode_tokens(+tokens: List<&2, U32>) -> DecodeResult:
  decode_token_bound(Nat.is_le(List.length(&2, U32, tokens), 140000n), tokens)

def decode_token_bound(ok: Bool, tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"token-count"}
    case True{}: decode_tokens_inner(tokens)
