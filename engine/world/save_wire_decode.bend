import Base
import ./save_boundary.bend as Save
import ./geometry.bend as Geometry
import ./events.bend as Events
import ../battle/rng.bend as Rng

# M11 restore row v1 is `18 1 identity map xSign xMagnitude ySign yMagnitude
# zSign zMagnitude region weighted threshold safe rngA rngB rngC rngD
# valueCount (key value)* entityCount entity*`. Region zero means no region.
# The decoder requires exact exhaustion; Save.restore performs catalog and
# stable-boundary validation after this inert numeric record is decoded.

type DecodeResult is Data:
  DecodeRejected{}
  DecodeAccepted{snapshot: Save.Snapshot}

type ValuesRead is Data:
  ValuesRejected{}
  ValuesAccepted{values: List<&2, Events.Value>, rest: List<&2, U32>}

type EntitiesRead is Data:
  EntitiesRejected{}
  EntitiesAccepted{entities: List<&2, Nat>, rest: List<&2, U32>}

def read_values(count: Nat, tokens: List<&2, U32>,
  acc: List<&2, Events.Value>) -> ValuesRead:
  match count:
    case 0n: ValuesAccepted{List.reverse(&2, Events.Value, acc), tokens}
    case 1n+remaining:
      match tokens:
        case key <> value <> rest:
          read_values(remaining, rest,
            Events.Value{U32.to_nat(key), U32.to_nat(value)} <> acc)
        case _: ValuesRejected{}

def read_entities(count: Nat, tokens: List<&2, U32>,
  acc: List<&2, Nat>) -> EntitiesRead:
  match count:
    case 0n: EntitiesAccepted{List.reverse(&2, Nat, acc), tokens}
    case 1n+remaining:
      match tokens:
        case entity <> rest:
          read_entities(remaining, rest, U32.to_nat(entity) <> acc)
        case _: EntitiesRejected{}

def finish_entities(result: EntitiesRead, identity: U32, map_id: U32,
  point: Geometry.Point, +region: U32, weighted: U32, threshold: U32,
  safe: U32, random: Rng.RngState,
  values: List<&2, Events.Value>) -> DecodeResult:
  match result:
    case EntitiesRejected{}: DecodeRejected{}
    case EntitiesAccepted{entities, Nil{}}:
      DecodeAccepted{Save.Snapshot{U32.to_nat(identity), U32.to_nat(map_id),
        point, Bool.pick(Maybe<&2, Nat>, U32.is_eq(region, 0), None{},
          Some{U32.to_nat(region)}), U32.to_nat(weighted),
        U32.to_nat(threshold), U32.to_nat(safe), random, values, entities}}
    case _: DecodeRejected{}

def finish_entities_after_count(valid: Bool, count: U32,
  entries: List<&2, U32>, identity: U32, map_id: U32,
  point: Geometry.Point, +region: U32, weighted: U32, threshold: U32,
  safe: U32, random: Rng.RngState,
  values: List<&2, Events.Value>) -> DecodeResult:
  match valid:
    case False{}: DecodeRejected{}
    case True{}:
      finish_entities(read_entities(U32.to_nat(count), entries, Nil{}),
        identity, map_id, point, region, weighted, threshold, safe, random,
        values)

def finish_values(result: ValuesRead, identity: U32, map_id: U32,
  point: Geometry.Point, region: U32, weighted: U32, threshold: U32,
  safe: U32, random: Rng.RngState) -> DecodeResult:
  match result:
    case ValuesRejected{}: DecodeRejected{}
    case ValuesAccepted{values, rest}:
      match rest:
        case +count <> entries:
          finish_entities_after_count(U32.is_le(count, 4096), count, entries,
            identity, map_id, point, region, weighted, threshold, safe,
            random, values)
        case _: DecodeRejected{}

def decode_body(identity: U32, +map_id: U32, +x_negative: U32,
  +x_magnitude: U32, +y_negative: U32, +y_magnitude: U32,
  +z_negative: U32, +z_magnitude: U32, region: U32, weighted: U32,
  threshold: U32, safe: U32, a: U32, b: U32, c: U32, d: U32,
  +value_count: U32, rest: List<&2, U32>) -> DecodeResult:
  Bool.pick(DecodeResult,
    Bool.and(U32.is_le(x_negative, 1),
    Bool.and(U32.is_le(y_negative, 1),
    Bool.and(U32.is_le(z_negative, 1),
    Bool.and(Bool.not(Bool.and(U32.is_eq(x_negative, 1),
      U32.is_eq(x_magnitude, 0))),
    Bool.and(Bool.not(Bool.and(U32.is_eq(y_negative, 1),
      U32.is_eq(y_magnitude, 0))),
    Bool.and(Bool.not(Bool.and(U32.is_eq(z_negative, 1),
      U32.is_eq(z_magnitude, 0))),
    Bool.and(U32.is_le(value_count, 4096), U32.is_gt(map_id, 0)))))))),
    finish_values(read_values(U32.to_nat(value_count), rest, Nil{}),
      identity, map_id,
      Geometry.Point{Geometry.Coord{U32.is_eq(x_negative, 1), x_magnitude},
        Geometry.Coord{U32.is_eq(y_negative, 1), y_magnitude},
        Geometry.Coord{U32.is_eq(z_negative, 1), z_magnitude}}, region,
      weighted, threshold, safe, Rng.RngState{a, b, c, d}), DecodeRejected{})

def decode_tokens(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 18 <> 1 <> identity <> map_id <> x_negative <> x_magnitude <>
         y_negative <> y_magnitude <> z_negative <> z_magnitude <>
         region <> weighted <> threshold <> safe <> a <> b <> c <> d <>
         value_count <> rest:
      decode_body(identity, map_id, x_negative, x_magnitude, y_negative,
        y_magnitude, z_negative, z_magnitude, region, weighted, threshold,
        safe, a, b, c, d, value_count, rest)
    case _: DecodeRejected{}
