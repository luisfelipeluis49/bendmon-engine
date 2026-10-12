import Base
# Bounded readers for dynamic world record references and polygons.
import ./geometry.bend as Geometry
import ./catalog.bend as Catalog

type PointRead is Data:
  PointBad{reason: String}
  PointDone{value: Geometry.Point, rest: List<&2, U32>}

type VerticesRead is Data:
  VerticesBad{reason: String}
  VerticesDone{values: List<&2, Geometry.Vertex>, rest: List<&2, U32>}

def coord_value(sign: U32, magnitude: U32) -> Geometry.Coord:
  Geometry.Coord{U32.is_eq(sign, 1), magnitude}

def point_validate(ok: Bool, sx: U32, mx: U32, sy: U32, my: U32,
  sz: U32, mz: U32, rest: List<&2, U32>) -> PointRead:
  match ok:
    case False{}: PointBad{"coordinate"}
    case True{}:
      PointDone{Geometry.Point{coord_value(sx, mx), coord_value(sy, my),
        coord_value(sz, mz)}, rest}

def point_read(tokens: List<&2, U32>) -> PointRead:
  match tokens:
    case +sx <> +mx <> +sy <> +my <> +sz <> +mz <> rest:
      +point: Geometry.Point = Geometry.Point{coord_value(sx, mx),
        coord_value(sy, my), coord_value(sz, mz)}
      point_validate(Bool.and(U32.is_le(sx, 1),
        Bool.and(U32.is_le(sy, 1), Bool.and(U32.is_le(sz, 1),
          Geometry.valid_point(point)))), sx, mx, sy, my, sz, mz, rest)
    case _: PointBad{"vertex-missing"}

@unsafe def vertex_after(left: Nat, acc: List<&2, Geometry.Vertex>,
  result: PointRead) -> VerticesRead:
  match result:
    case PointBad{reason}: VerticesBad{reason}
    case PointDone{Geometry.Point{x, y, z}, rest}:
      vertices_read(left, rest, Geometry.Vertex{x, y, z} <> acc)

@unsafe def vertices_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Geometry.Vertex>) -> VerticesRead:
  match count:
    case 0n: VerticesDone{List.reverse(&2, Geometry.Vertex, acc), tokens}
    case 1n+left:
      vertex_after(left, acc, point_read(tokens))

type IndexRead is Data:
  IndexBad{reason: String}
  IndexDone{values: List<&2, U32>, rest: List<&2, U32>}

type RegionsRead is Data:
  RegionsBad{reason: String}
  RegionsDone{values: List<&2, Catalog.EncounterRegion>, rest: List<&2, U32>}

type NpcsRead is Data:
  NpcsBad{reason: String}
  NpcsDone{values: List<&2, Catalog.Npc>, rest: List<&2, U32>}

type TriggersRead is Data:
  TriggersBad{reason: String}
  TriggersDone{values: List<&2, Catalog.Trigger>, rest: List<&2, U32>}

type TransitionsRead is Data:
  TransitionsBad{reason: String}
  TransitionsDone{values: List<&2, Catalog.Transition>, rest: List<&2, U32>}

def index_present(+key: U32, values: List<&2, U32>) -> Bool:
  match values:
    case Nil{}: False{}
    case head <> rest:
      Bool.or(U32.is_eq(key, head), index_present(key, rest))

def all_unique(values: List<&2, U32>) -> Bool:
  match values:
    case Nil{}: True{}
    case +head <> +rest:
      Bool.and(Bool.not(index_present(head, rest)), all_unique(rest))

def index_finish(ok: Bool, values: List<&2, U32>,
  rest: List<&2, U32>) -> IndexRead:
  match ok:
    case False{}: IndexBad{"duplicate-index"}
    case True{}: IndexDone{List.reverse(&2, U32, values), rest}

@unsafe def read_indices(count: Nat, +bound: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, U32>) -> IndexRead:
  match count:
    case 0n: index_finish(all_unique(acc), acc, tokens)
    case 1n+remaining:
      match tokens:
        case +index <> rest:
          index_value_valid(Nat.is_lt(U32.to_nat(index), bound),
            remaining, bound, rest, index, acc)
        case _: IndexBad{"index-missing"}

def index_value_valid(ok: Bool, remaining: Nat, +bound: Nat,
  +tokens: List<&2, U32>, index: U32, +acc: List<&2, U32>) -> IndexRead:
  match ok:
    case False{}: IndexBad{"index-range"}
    case True{}: read_indices(remaining, bound, tokens, index <> acc)

@unsafe def region_indices_after(ok: Bool, remaining: Nat, +face_count: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Catalog.EncounterRegion>,
  id: U32, encounter_id: U32, count: U32, result: IndexRead) -> RegionsRead:
  match ok result:
    case True{} IndexBad{reason}: RegionsBad{reason}
    case True{} IndexDone{faces, rest}:
      regions_read(remaining, face_count, rest,
        Catalog.EncounterRegion{U32.to_nat(id), U32.to_nat(encounter_id),
          faces} <> acc)
    case False{} _: RegionsBad{"region-count"}

@unsafe def region_record_valid(ok: Bool, remaining: Nat,
  +face_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.EncounterRegion>, id: U32, encounter_id: U32,
  +count: U32) -> RegionsRead:
  match ok:
    case False{}: RegionsBad{"region-count"}
    case True{}:
      region_indices_after(True{}, remaining, face_count, tokens, acc,
        id, encounter_id, count,
        read_indices(U32.to_nat(count), face_count, tokens, Nil{}))

def region_header_valid(+id: U32, +encounter_id: U32, +face_count_raw: U32,
  face_count: Nat) -> Bool:
  Bool.and(U32.is_le(1, id), Bool.and(U32.is_le(id, 256),
    Bool.and(U32.is_le(1, encounter_id),
      Bool.and(U32.is_le(1, face_count_raw),
        Bool.and(U32.is_le(face_count_raw, 256),
          U32.is_le(face_count_raw, U32.from_nat(face_count)))))))

@unsafe def regions_read(count: Nat, +face_count: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Catalog.EncounterRegion>) -> RegionsRead:
  match count:
    case 0n: RegionsDone{List.reverse(&2, Catalog.EncounterRegion, acc), tokens}
    case 1n+remaining:
      match tokens:
        case id <> encounter_id <> face_count_raw <> rest:
          region_record_valid(region_header_valid(id, encounter_id,
            face_count_raw, face_count),
            remaining, face_count, rest, acc, id, encounter_id, face_count_raw)
        case _: RegionsBad{"region-header"}

def npc_option_result(is_zero: Bool, event_id: U32) -> Maybe<&2, Nat>:
  match is_zero:
    case True{}: None{}
    case False{}: Some{U32.to_nat(event_id)}

def npc_option(+event_id: U32) -> Maybe<&2, Nat>:
  npc_option_result(U32.is_zero(event_id), event_id)

@unsafe def npc_point_after(remaining: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Npc>, id: U32, event_id: U32,
  result: PointRead) -> NpcsRead:
  match result:
    case PointBad{reason}: NpcsBad{reason}
    case PointDone{point, +rest}:
      npcs_read(remaining, rest,
        Catalog.Npc{U32.to_nat(id), point, npc_option(event_id)} <> acc)

@unsafe def npcs_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Npc>) -> NpcsRead:
  match count:
    case 0n: NpcsDone{List.reverse(&2, Catalog.Npc, acc), tokens}
    case 1n+remaining:
      match tokens:
        case id <> event_id <> rest:
          npc_record_valid(Bool.and(U32.is_le(1, id), U32.is_le(id, 256)), remaining, rest, acc,
            id, event_id)
        case _: NpcsBad{"npc-header"}

@unsafe def npc_record_valid(ok: Bool, remaining: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Npc>, id: U32, event_id: U32) -> NpcsRead:
  match ok:
    case False{}: NpcsBad{"npc-id"}
    case True{}: npc_point_after(remaining, tokens, acc, id, event_id,
      point_read(tokens))

@unsafe def trigger_indices_after(ok: Bool, remaining: Nat,
  +vertex_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Trigger>, id: U32, event_id: U32, count: U32,
  result: IndexRead) -> TriggersRead:
  match ok result:
    case True{} IndexBad{reason}: TriggersBad{reason}
    case True{} IndexDone{vertices, rest}:
      triggers_read(remaining, vertex_count, rest,
        Catalog.Trigger{U32.to_nat(id), vertices, U32.to_nat(event_id)} <> acc)
    case False{} _: TriggersBad{"trigger-polygon-count"}

@unsafe def trigger_record_valid(ok: Bool, remaining: Nat,
  +vertex_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Trigger>, id: U32, event_id: U32,
  +count: U32) -> TriggersRead:
  match ok:
    case False{}: TriggersBad{"trigger-header"}
    case True{}:
      trigger_indices_after(True{}, remaining, vertex_count, tokens, acc,
        id, event_id, count,
        read_indices(U32.to_nat(count), vertex_count, tokens, Nil{}))

def trigger_header_valid(+id: U32, +event_id: U32,
  +polygon_count: U32) -> Bool:
  Bool.and(U32.is_le(1, id), Bool.and(U32.is_le(id, 256),
    Bool.and(U32.is_le(1, event_id), Bool.and(U32.is_le(3, polygon_count),
      U32.is_le(polygon_count, 256)))) )

@unsafe def triggers_read(count: Nat, +vertex_count: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Catalog.Trigger>) -> TriggersRead:
  match count:
    case 0n: TriggersDone{List.reverse(&2, Catalog.Trigger, acc), tokens}
    case 1n+remaining:
      match tokens:
        case id <> event_id <> polygon_count <> rest:
          trigger_record_valid(trigger_header_valid(id, event_id,
            polygon_count), remaining, vertex_count,
              rest, acc, id, event_id, polygon_count)
        case _: TriggersBad{"trigger-header"}

@unsafe def transition_indices_after(ok: Bool, remaining: Nat,
  +vertex_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Transition>, id: U32, target_map: U32,
  destination: Geometry.Point, count: U32, result: IndexRead) -> TransitionsRead:
  match ok result:
    case True{} IndexBad{reason}: TransitionsBad{reason}
    case True{} IndexDone{vertices, rest}:
      transitions_read(remaining, vertex_count, rest,
        Catalog.Transition{U32.to_nat(id), vertices, U32.to_nat(target_map),
          destination} <> acc)
    case False{} _: TransitionsBad{"transition-polygon-count"}

@unsafe def transition_point_after(remaining: Nat,
  +vertex_count: Nat, +acc: List<&2, Catalog.Transition>, id: U32,
  target_map: U32, +polygon_count: U32, result: PointRead) -> TransitionsRead:
  match result:
    case PointBad{reason}: TransitionsBad{reason}
    case PointDone{point, +rest}:
      transition_indices_after(Bool.and(U32.is_le(3, polygon_count),
        U32.is_le(polygon_count, 256)), remaining, vertex_count, rest, acc,
        id, target_map, point, polygon_count,
        read_indices(U32.to_nat(polygon_count), vertex_count, rest, Nil{}))

@unsafe def transition_after_point(remaining: Nat,
  +vertex_count: Nat, +acc: List<&2, Catalog.Transition>, id: U32,
  target_map: U32, result: PointRead) -> TransitionsRead:
  match result:
    case PointBad{reason}: TransitionsBad{reason}
    case PointDone{point, rest}:
      match rest:
        case polygon_count <> tail:
          transition_point_after(remaining, vertex_count, acc, id,
            target_map, polygon_count, PointDone{point, tail})
        case _: TransitionsBad{"transition-polygon-count"}

@unsafe def transitions_read(count: Nat, +vertex_count: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Catalog.Transition>) -> TransitionsRead:
  match count:
    case 0n: TransitionsDone{List.reverse(&2, Catalog.Transition, acc), tokens}
    case 1n+remaining:
      match tokens:
        case id <> target_map <> rest:
          transition_header_valid(Bool.and(U32.is_le(1, id),
            U32.is_le(1, target_map)), remaining, vertex_count, rest, acc,
            id, target_map)
        case _: TransitionsBad{"transition-header"}

@unsafe def transition_header_valid(ok: Bool, remaining: Nat,
  +vertex_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.Transition>, id: U32, target_map: U32) -> TransitionsRead:
  match ok:
    case False{}: TransitionsBad{"transition-header"}
    case True{}:
      transition_count_after(remaining, vertex_count, tokens, acc,
        id, target_map)

@unsafe def transition_count_after(remaining: Nat, +vertex_count: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Catalog.Transition>,
  id: U32, target_map: U32) -> TransitionsRead:
  transition_after_point(remaining, vertex_count, acc, id, target_map,
    point_read(tokens))
