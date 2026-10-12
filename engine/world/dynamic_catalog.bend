import Base
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry
import ./dynamic_position_checks.bend as Positions
import ./dynamic_region_checks.bend as RegionChecks
import ./dynamic_polygon_checks.bend as PolygonChecks
import ./dynamic_navigation.bend as Navigation
import ./dynamic_records.bend as Records

type DynamicCatalog is Data:
  DynamicCatalog{content_identity: U32, entry_map: Nat,
    catalog: Catalog.Catalog}

type DecodeResult is Data:
  DecodeRejected{reason: String}
  DecodeAccepted{value: DynamicCatalog}

def entry_result(found: Maybe<&2, Catalog.WorldMap>, +identity: U32, +entry: Nat,
  +maps: List<&2, Catalog.WorldMap>) -> DecodeResult:
  match found:
    case None{}: DecodeRejected{"entry-map"}
    case Some{found_map}:
      DecodeAccepted{DynamicCatalog{identity, entry,
        Catalog.Catalog{8n, U32.to_nat(identity), maps, Nil{}}}}

def map_count_valid(ok: Bool, +identity: U32, +entry: Nat,
  +maps: List<&2, Catalog.WorldMap>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"map-count"}
    case True{}:
      entry_result(Catalog.map_by_id(maps, entry), identity, entry, maps)

# Construct the production WorldMap record after all numeric references pass.
def navigation_map(id: Nat, vertices: List<&2, Geometry.Vertex>,
  faces: List<&2, Geometry.Triangle>, links: List<&2, Geometry.NavLink>) ->
  Catalog.WorldMap:
  Catalog.WorldMap{id,
    Geometry.NavSurface{vertices, faces, links}, Nil{}, Nil{}, Nil{}, Nil{}}

def catalog(+identity: U32, +entry: Nat,
  +maps: List<&2, Catalog.WorldMap>) -> DecodeResult:
  map_count_valid(Bool.and(Nat.is_lt(0n, List.length(&2,
    Catalog.WorldMap, maps)), Nat.is_le(List.length(&2, Catalog.WorldMap, maps),
    256n)), identity, entry, maps)

type WorldRead is Data:
  WorldBad{reason: String}
  WorldDone{maps: List<&2, Catalog.WorldMap>, rest: List<&2, U32>}

@unsafe def after_transitions(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, npcs: List<&2, Catalog.Npc>,
  triggers: List<&2, Catalog.Trigger>, result: Records.TransitionsRead) -> WorldRead:
  match result:
    case Records.TransitionsBad{reason}: WorldBad{reason}
    case Records.TransitionsDone{transitions, rest}:
      decode_maps(remaining, rest, Catalog.WorldMap{U32.to_nat(id),
        surface, regions, npcs, triggers, transitions} <> acc)

@unsafe def transition_count_stage(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, npcs: List<&2, Catalog.Npc>,
  triggers: List<&2, Catalog.Trigger>, +count: U32,
  tokens: List<&2, U32>) -> WorldRead:
  transition_count_valid(U32.is_le(count, 256), remaining, acc, id, surface,
    regions, npcs, triggers, count, tokens)

@unsafe def transition_count_valid(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, npcs: List<&2, Catalog.Npc>,
  triggers: List<&2, Catalog.Trigger>, +count: U32,
  tokens: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"transition-count"}
    case True{}:
      after_transitions(remaining, acc, id, surface, regions, npcs, triggers,
        Records.transitions_read(U32.to_nat(count),
          List.length(&2, Geometry.Vertex, surface_vertices(surface)),
          tokens, Nil{}))

def surface_vertices(+surface: Geometry.NavSurface) -> List<&2, Geometry.Vertex>:
  match surface:
    case Geometry.NavSurface{vertices, faces, links}: vertices

@unsafe def after_triggers(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, npcs: List<&2, Catalog.Npc>,
  result: Records.TriggersRead) -> WorldRead:
  match result:
    case Records.TriggersBad{reason}: WorldBad{reason}
    case Records.TriggersDone{triggers, rest}:
      match rest:
        case count <> tokens:
          transition_count_stage(remaining, acc, id, surface, regions, npcs,
            triggers, count, tokens)
        case _: WorldBad{"transition-count-missing"}

@unsafe def trigger_count_stage(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, npcs: List<&2, Catalog.Npc>,
  +count: U32, tokens: List<&2, U32>) -> WorldRead:
  trigger_count_valid(U32.is_le(count, 256), remaining, acc, id, surface,
    regions, npcs, count, tokens)

@unsafe def trigger_count_valid(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, npcs: List<&2, Catalog.Npc>,
  +count: U32, tokens: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"trigger-count"}
    case True{}:
      after_triggers(remaining, acc, id, surface, regions, npcs,
        Records.triggers_read(U32.to_nat(count),
          List.length(&2, Geometry.Vertex, surface_vertices(surface)),
          tokens, Nil{}))

@unsafe def after_npcs(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, result: Records.NpcsRead) -> WorldRead:
  match result:
    case Records.NpcsBad{reason}: WorldBad{reason}
    case Records.NpcsDone{npcs, rest}:
      match rest:
        case count <> tokens:
          trigger_count_stage(remaining, acc, id, surface, regions, npcs,
            count, tokens)
        case _: WorldBad{"trigger-count-missing"}

@unsafe def npc_count_stage(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, +count: U32,
  tokens: List<&2, U32>) -> WorldRead:
  npc_count_valid(U32.is_le(count, 256), remaining, acc, id, surface,
    regions, count, tokens)

@unsafe def npc_count_valid(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>, +count: U32,
  tokens: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"npc-count"}
    case True{}:
      after_npcs(remaining, acc, id, surface, regions,
        Records.npcs_read(U32.to_nat(count), tokens, Nil{}))

@unsafe def after_regions(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  result: Records.RegionsRead) -> WorldRead:
  match result:
    case Records.RegionsBad{reason}: WorldBad{reason}
    case Records.RegionsDone{regions, rest}:
      match rest:
        case count <> tokens:
          npc_count_stage(remaining, acc, id, surface, regions, count, tokens)
        case _: WorldBad{"npc-count-missing"}

@unsafe def region_count_stage(remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  +count: U32, tokens: List<&2, U32>) -> WorldRead:
  region_count_valid(U32.is_le(count, 256), remaining, acc, id, surface,
    count, tokens)

@unsafe def region_count_valid(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, +surface: Geometry.NavSurface,
  +count: U32, tokens: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"region-count"}
    case True{}:
      after_regions(remaining, acc, id, surface,
        Records.regions_read(U32.to_nat(count),
          List.length(&2, Geometry.Triangle, surface_faces(surface)),
          tokens, Nil{}))

def surface_faces(+surface: Geometry.NavSurface) -> List<&2, Geometry.Triangle>:
  match surface:
    case Geometry.NavSurface{vertices, faces, links}: faces

@unsafe def validated_surface(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32,
  +surface: Geometry.NavSurface, rest: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"surface-geometry"}
    case True{}:
      match rest:
        case region_count <> tokens:
          region_count_stage(remaining, acc, id, surface,
            region_count, tokens)
        case _: WorldBad{"region-count-missing"}


@unsafe def map_after_links(remaining: Nat, acc: List<&2, Catalog.WorldMap>, id: U32,
  +vertices: List<&2, Geometry.Vertex>, +faces: List<&2, Geometry.Triangle>,
  result: Navigation.LinksRead) -> WorldRead:
  match result:
    case Navigation.LinksBad{reason}: WorldBad{reason}
    case Navigation.LinksDone{links, rest}:
      +surface: Geometry.NavSurface = Geometry.NavSurface{vertices, faces, links}
      validated_surface(Navigation.surface_geometry_valid(surface), remaining, acc,
        id, surface, rest)

def link_count_after(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32,
  +vertices: List<&2, Geometry.Vertex>, +faces: List<&2, Geometry.Triangle>,
  link_count: U32, tail: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"link-count"}
    case True{}:
      map_after_links(remaining, acc, id, vertices, faces,
        Navigation.links_read(U32.to_nat(link_count),
          List.length(&2, Geometry.Triangle, faces), tail, Nil{}))

def map_after_faces(remaining: Nat, acc: List<&2, Catalog.WorldMap>, id: U32,
  vertices: List<&2, Geometry.Vertex>, result: Navigation.FacesRead) -> WorldRead:
  match result:
    case Navigation.FacesBad{reason}: WorldBad{reason}
    case Navigation.FacesDone{faces, rest}:
      match rest:
        case +link_count <> tail:
          link_count_after(U32.is_le(link_count, 4096), remaining, acc,
            id, vertices, faces, link_count, tail)
        case _: WorldBad{"link-count-missing"}

def face_count_after(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32,
  +vertices: List<&2, Geometry.Vertex>, face_count: U32,
  tail: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"face-count"}
    case True{}:
      map_after_faces(remaining, acc, id, vertices,
        Navigation.faces_read(U32.to_nat(face_count),
          List.length(&2, Geometry.Vertex, vertices), tail, Nil{}))

def map_after_vertices(remaining: Nat, acc: List<&2, Catalog.WorldMap>,
  id: U32, result: Records.VerticesRead) -> WorldRead:
  match result:
    case Records.VerticesBad{reason}: WorldBad{reason}
    case Records.VerticesDone{vertices, rest}:
      match rest:
        case +face_count <> tail:
          face_count_after(U32.is_le(face_count, 256), remaining, acc,
            id, vertices, face_count, tail)
        case _: WorldBad{"face-count-missing"}

def vertex_count_after(ok: Bool, remaining: Nat,
  acc: List<&2, Catalog.WorldMap>, id: U32, vertex_count: U32,
  rest: List<&2, U32>) -> WorldRead:
  match ok:
    case False{}: WorldBad{"vertex-count"}
    case True{}:
      map_after_vertices(remaining, acc, id,
        Records.vertices_read(U32.to_nat(vertex_count), rest, Nil{}))

@unsafe def decode_maps(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Catalog.WorldMap>) -> WorldRead:
  match count:
    case 0n: WorldDone{List.reverse(&2, Catalog.WorldMap, acc), tokens}
    case 1n+remaining:
      match tokens:
        case id <> vertex_count <> rest:
          vertex_count_after(Bool.and(U32.is_le(1, id),
            Bool.and(U32.is_le(vertex_count, 256),
              U32.is_le(1, vertex_count))), remaining, acc, id,
            vertex_count, rest)
        case _: WorldBad{"map-header"}

def nav_ref_count(navigation: Geometry.NavSurface) -> Nat:
  match navigation:
    case Geometry.NavSurface{+vertices, +faces, +links}:
      (3n * List.length(&2, Geometry.Triangle, faces) +
        2n * List.length(&2, Geometry.NavLink, links) : Nat)

def region_reference_count(regions: List<&2, Catalog.EncounterRegion>) -> Nat:
  match regions:
    case Nil{}: 0n
    case Catalog.EncounterRegion{+id, +encounter_id, +faces} <> rest:
      (List.length(&2, U32, faces) + region_reference_count(rest) : Nat)

def trigger_reference_count(triggers: List<&2, Catalog.Trigger>) -> Nat:
  match triggers:
    case Nil{}: 0n
    case Catalog.Trigger{+id, +vertices, +event_id} <> rest:
      (List.length(&2, U32, vertices) + trigger_reference_count(rest) : Nat)

def transition_reference_count(
  transitions: List<&2, Catalog.Transition>) -> Nat:
  match transitions:
    case Nil{}: 0n
    case Catalog.Transition{+id, +vertices, +target_map, +destination} <> rest:
      (List.length(&2, U32, vertices) + transition_reference_count(rest) : Nat)

def map_ref_count(maps: List<&2, Catalog.WorldMap>) -> Nat:
  match maps:
    case Nil{}: 0n
    case Catalog.WorldMap{+id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      (nav_ref_count(navigation) + region_reference_count(regions) +
        trigger_reference_count(triggers) +
        transition_reference_count(transitions) + map_ref_count(rest) : Nat)

def id_in_maps(+id: Nat, maps: List<&2, Catalog.WorldMap>) -> Bool:
  match maps:
    case Nil{}: False{}
    case Catalog.WorldMap{+row_id, _, _, _, _, _} <> +rest:
      Bool.or(Nat.is_eq(id, row_id), id_in_maps(id, rest))

def duplicate_map_ids(maps: List<&2, Catalog.WorldMap>) -> Bool:
  match maps:
    case Nil{}: False{}
    case Catalog.WorldMap{+row_id, _, _, _, _, _} <> +rest:
      Bool.or(id_in_maps(row_id, rest), duplicate_map_ids(rest))

def transition_targets_valid(transitions: List<&2, Catalog.Transition>,
  +all_maps: List<&2, Catalog.WorldMap>) -> Bool:
  match transitions:
    case Nil{}: True{}
    case Catalog.Transition{+id, +vertices, +target_map, +destination} <> rest:
      Bool.and(id_in_maps(target_map, all_maps),
        transition_targets_valid(rest, all_maps))

def all_transition_targets_valid(maps: List<&2, Catalog.WorldMap>,
  +all_maps: List<&2, Catalog.WorldMap>) -> Bool:
  match maps:
    case Nil{}: True{}
    case Catalog.WorldMap{+id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      Bool.and(transition_targets_valid(transitions, all_maps),
        all_transition_targets_valid(rest, all_maps))

def total_regions(maps: List<&2, Catalog.WorldMap>) -> Nat:
  match maps:
    case Nil{}: 0n
    case Catalog.WorldMap{+id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      (List.length(&2, Catalog.EncounterRegion, regions) +
        total_regions(rest) : Nat)

def total_npcs(maps: List<&2, Catalog.WorldMap>) -> Nat:
  match maps:
    case Nil{}: 0n
    case Catalog.WorldMap{+id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      (List.length(&2, Catalog.Npc, npcs) + total_npcs(rest) : Nat)

def total_triggers(maps: List<&2, Catalog.WorldMap>) -> Nat:
  match maps:
    case Nil{}: 0n
    case Catalog.WorldMap{+id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      (List.length(&2, Catalog.Trigger, triggers) + total_triggers(rest) : Nat)

def total_transitions(maps: List<&2, Catalog.WorldMap>) -> Nat:
  match maps:
    case Nil{}: 0n
    case Catalog.WorldMap{+id, +navigation, +regions, +npcs,
        +triggers, +transitions} <> rest:
      (List.length(&2, Catalog.Transition, transitions) +
        total_transitions(rest) : Nat)

def trigger_polygons_valid(+vertices: List<&2, Geometry.Vertex>,
  triggers: List<&2, Catalog.Trigger>) -> Bool:
  match triggers:
    case Nil{}: True{}
    case Catalog.Trigger{id, +indices, event_id} <> rest:
      Bool.and(PolygonChecks.valid(vertices, indices),
        trigger_polygons_valid(vertices, rest))

def transition_polygons_valid(+vertices: List<&2, Geometry.Vertex>,
  transitions: List<&2, Catalog.Transition>) -> Bool:
  match transitions:
    case Nil{}: True{}
    case Catalog.Transition{id, +indices, target_map, destination} <> rest:
      Bool.and(PolygonChecks.valid(vertices, indices),
        transition_polygons_valid(vertices, rest))

def surface_polygons_valid(navigation: Geometry.NavSurface,
  triggers: List<&2, Catalog.Trigger>,
  transitions: List<&2, Catalog.Transition>) -> Bool:
  match navigation:
    case Geometry.NavSurface{+vertices, faces, links}:
      Bool.and(trigger_polygons_valid(vertices, triggers),
        transition_polygons_valid(vertices, transitions))

def map_polygons_valid(maps: List<&2, Catalog.WorldMap>) -> Bool:
  match maps:
    case Nil{}: True{}
    case Catalog.WorldMap{id, +navigation, regions, npcs,
        +triggers, +transitions} <> rest:
      Bool.and(surface_polygons_valid(navigation, triggers, transitions),
        map_polygons_valid(rest))

def map_content_valid(+maps: List<&2, Catalog.WorldMap>) -> Bool:
  Bool.and(Nat.is_le(map_ref_count(maps), 4096n),
  Bool.and(Nat.is_le(total_regions(maps), 256n),
  Bool.and(Nat.is_le(total_npcs(maps), 256n),
  Bool.and(Nat.is_le(total_triggers(maps), 256n),
    Nat.is_le(total_transitions(maps), 256n)))))

def map_records_valid(+maps: List<&2, Catalog.WorldMap>) -> Bool:
  Bool.and(Bool.not(duplicate_map_ids(maps)),
  Bool.and(all_transition_targets_valid(maps, maps),
  Bool.and(Positions.valid(maps),
    RegionChecks.maps_disjoint(maps))))

def polygons_result(ok: Bool, identity: U32, entry: U32,
  +maps: List<&2, Catalog.WorldMap>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"world-records"}
    case True{}: map_count_valid(True{}, identity, U32.to_nat(entry), maps)

def records_result(ok: Bool, identity: U32, entry: U32,
  +maps: List<&2, Catalog.WorldMap>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"world-records"}
    case True{}:
      polygons_result(map_polygons_valid(maps), identity, entry, maps)

def bounds_result(ok: Bool, identity: U32, entry: U32,
  +maps: List<&2, Catalog.WorldMap>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"world-limits"}
    case True{}: records_result(map_records_valid(maps), identity, entry, maps)

def world_result(result: WorldRead, identity: U32, entry: U32) -> DecodeResult:
  match result:
    case WorldBad{reason}: DecodeRejected{reason}
    case WorldDone{+maps, Nil{}}:
      bounds_result(Bool.and(Nat.is_lt(0n,
        List.length(&2, Catalog.WorldMap, maps)),
        Bool.and(Nat.is_le(List.length(&2, Catalog.WorldMap, maps), 256n),
          map_content_valid(maps))), identity, entry, maps)
    case WorldDone{maps, rest}: DecodeRejected{"trailing"}

def decode_world_after(ok: Bool, identity: U32, entry: U32,
  map_count: U32, tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"header"}
    case True{}:
      world_result(decode_maps(U32.to_nat(map_count), tokens, Nil{}),
        identity, entry)

# Decode the v2 numeric token sequence emitted by m10_world_wire.py.
# Token slots are already numeric U32 values; the strict host wire encoder
# supplies the text tokenizer and this function validates every structural
# count and reference before constructing engine records.
def decode_tokens_inner(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 10 <> 2 <> +identity <> +entry <> +map_count <> rest:
      decode_world_after(Bool.and(U32.is_le(map_count, 256),
        Bool.and(U32.is_le(entry, 4294967295),
          U32.is_le(identity, 4294967295))), identity, entry, map_count, rest)
    case _: DecodeRejected{"version-or-header"}

def decode_token_limit(ok: Bool, tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"token-limit"}
    case True{}: decode_tokens_inner(tokens)

def decode_tokens(+tokens: List<&2, U32>) -> DecodeResult:
  decode_token_limit(Nat.is_le(List.length(&2, U32, tokens), 140000n), tokens)
