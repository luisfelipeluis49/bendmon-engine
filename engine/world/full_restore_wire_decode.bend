import Base
import ./save_boundary.bend as Save
import ./save_wire_decode.bend as WorldWire
import ../m7/persistent_wire_decode.bend as ProgressionWire
import ../m7/persistent_state.bend as Persistent

# M11 restore v2 appends a presence flag and a length-delimited M7 v1 token
# row to the same world payload used by restore v1.
type DecodeResult is Data:
  DecodeRejected{}
  DecodeAccepted{snapshot: Save.Snapshot,
    progression: Maybe<&2, Persistent.PersistentState>}

type TokensRead is Data:
  TokensRead{values: List<&2, U32>, rest: List<&2, U32>}
  TokensMissing{}

def reverse(values: List<&2, U32>, result: List<&2, U32>) -> List<&2, U32>:
  match values:
    case Nil{}: result
    case head <> tail: reverse(tail, head <> result)

def take(count: Nat, values: List<&2, U32>,
  result: List<&2, U32>) -> TokensRead:
  match count:
    case 0n: TokensRead{reverse(result, []), values}
    case 1n+remaining:
      match values:
        case head <> tail: take(remaining, tail, head <> result)
        case Nil{}: TokensMissing{}

def append(left: List<&2, U32>, right: List<&2, U32>) -> List<&2, U32>:
  match left:
    case Nil{}: right
    case head <> tail: head <> append(tail, right)

def nat_tokens(values: List<&2, U32>) -> List<&2, Nat>:
  match values:
    case Nil{}: []
    case head <> tail: U32.to_nat(head) <> nat_tokens(tail)

def accepted(world: WorldWire.DecodeResult,
  progression: Maybe<&2, Persistent.PersistentState>) -> DecodeResult:
  match world:
    case WorldWire.DecodeAccepted{snapshot}:
      DecodeAccepted{snapshot, progression}
    case _: DecodeRejected{}

def absent_tail(world: WorldWire.DecodeResult, count: U32,
  rest: List<&2, U32>) -> DecodeResult:
  match count:
    case 0: match rest:
      case Nil{}: accepted(world, None{})
      case _: DecodeRejected{}
    case _: DecodeRejected{}

def absent(world: WorldWire.DecodeResult, flag: U32,
  count: U32, rest: List<&2, U32>) -> DecodeResult:
  match flag:
    case 0: absent_tail(world, count, rest)
    case _: DecodeRejected{}

def progression_identity_matches(valid: Bool, +world: WorldWire.DecodeResult,
  state: Persistent.PersistentState) -> DecodeResult:
  match valid:
    case True{}: accepted(world, Some{state})
    case False{}: DecodeRejected{}

def progression_state(+world: WorldWire.DecodeResult,
  +state: Persistent.PersistentState) -> DecodeResult:
  match world:
    case WorldWire.DecodeAccepted{snapshot}:
      match state:
        case Persistent.PersistentState{economy, roster, owned, ledger,
            ruleset, content_identity}:
          progression_identity_matches(
            Nat.is_eq(content_identity, Save.snapshot_identity(snapshot)),
            world, state)
    case _: DecodeRejected{}

def progression_decoded(world: WorldWire.DecodeResult,
  result: ProgressionWire.DecodeResult) -> DecodeResult:
  match result:
    case ProgressionWire.DecodeRejected{}: DecodeRejected{}
    case ProgressionWire.DecodeAccepted{state}: progression_state(world, state)

def present_tokens(world: WorldWire.DecodeResult,
  result: TokensRead) -> DecodeResult:
  match result:
    case TokensMissing{}: DecodeRejected{}
    case TokensRead{values, Nil{}}: progression_decoded(world,
      ProgressionWire.decode(nat_tokens(values)))
    case _: DecodeRejected{}

def present_bounded(valid: Bool, world: WorldWire.DecodeResult,
  count: U32, rest: List<&2, U32>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}: present_tokens(world, take(U32.to_nat(count), rest, []))

def present_count(world: WorldWire.DecodeResult, +count: U32,
  rest: List<&2, U32>) -> DecodeResult:
  present_bounded(U32.is_le(count, 4096), world, count, rest)

def present(world: WorldWire.DecodeResult, flag: U32,
  count: U32, rest: List<&2, U32>) -> DecodeResult:
  match flag:
    case 1: present_count(world, count, rest)
    case _: DecodeRejected{}

def progression_flag(world: WorldWire.DecodeResult, flag: U32,
  count: U32, rest: List<&2, U32>) -> DecodeResult:
  match flag:
    case 0: absent(world, flag, count, rest)
    case 1: present(world, flag, count, rest)
    case _: DecodeRejected{}

def progression_tail(world: WorldWire.DecodeResult,
  values: List<&2, U32>) -> DecodeResult:
  match values:
    case flag <> count <> rest:
      progression_flag(world, flag, count, rest)
    case _: DecodeRejected{}

def world_row(identity: U32, prefix: List<&2, U32>, value_count: U32,
  values: List<&2, U32>, entity_count: U32,
  entities: List<&2, U32>) -> List<&2, U32>:
  append([18, 1, identity], append(prefix, append([value_count],
    append(values, append([entity_count], entities)))))

def world_entity_tokens(prefix: List<&2, U32>, identity: U32,
  value_count: U32, values: List<&2, U32>, entity_count: U32,
  result: TokensRead) -> DecodeResult:
  match result:
    case TokensMissing{}: DecodeRejected{}
    case TokensRead{entities, suffix}:
      progression_tail(WorldWire.decode_tokens(world_row(identity, prefix,
        value_count, values, entity_count, entities)), suffix)

def world_entity_bounded(valid: Bool, prefix: List<&2, U32>,
  identity: U32, value_count: U32, values: List<&2, U32>,
  +entity_count: U32, entries: List<&2, U32>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}: world_entity_tokens(prefix, identity, value_count, values,
      entity_count, take(U32.to_nat(entity_count), entries, []))

def world_entity_count(prefix: List<&2, U32>, identity: U32,
  value_count: U32, values: List<&2, U32>, +entity_count: U32,
  entries: List<&2, U32>) -> DecodeResult:
  world_entity_bounded(U32.is_le(entity_count, 4096), prefix, identity,
    value_count, values, entity_count, entries)

def world_value_tokens(prefix: List<&2, U32>, identity: U32,
  value_count: U32, result: TokensRead) -> DecodeResult:
  match result:
    case TokensMissing{}: DecodeRejected{}
    case TokensRead{values, entity_count <> entries}:
      world_entity_count(prefix, identity, value_count, values,
        entity_count, entries)
    case _: DecodeRejected{}

def bounded_world_count(valid: Bool, prefix: List<&2, U32>,
  identity: U32, +value_count: U32, rest: List<&2, U32>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}: world_value_tokens(prefix, identity, value_count,
      take((2n * U32.to_nat(value_count) : Nat), rest, []))

def world_values(prefix: List<&2, U32>, identity: U32,
  +value_count: U32, rest: List<&2, U32>) -> DecodeResult:
  bounded_world_count(U32.is_le(value_count, 4096), prefix,
    identity, value_count, rest)

def decode_tokens(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 18 <> 2 <> identity <> map_id <> x_sign <> x_magnitude <>
         y_sign <> y_magnitude <> z_sign <> z_magnitude <> region <>
         weighted <> threshold <> safe <> a <> b <> c <> d <>
         value_count <> rest:
      world_values([map_id, x_sign, x_magnitude, y_sign, y_magnitude,
        z_sign, z_magnitude, region, weighted, threshold, safe, a, b, c, d],
        identity, value_count, rest)
    case _: DecodeRejected{}
