import Base
import ../../engine/world/dynamic_catalog.bend as Dynamic
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/catalog.bend as Catalog

def world_tokens() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 0, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 3, 0
   1, 3, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
]

def bad_npc_point() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 0, 1, 1
   5, 1, 2, 0, 3, 0, 4, 1, 1, 5, 3, 0
   1, 3, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
  ]

def accepted_shape(result: Dynamic.DecodeResult) -> Bool:
  match result:
    case Dynamic.DecodeAccepted{Dynamic.DynamicCatalog{123, 1n,
        Catalog.Catalog{8n, 123n,
          Catalog.WorldMap{1n, Geometry.NavSurface{vertices, faces, links},
            regions, npcs, triggers, transitions} <> Nil{}, Nil{}}}}:
      Bool.and(Nat.is_eq(List.length(&2, Geometry.Vertex, vertices), 4n),
      Bool.and(Nat.is_eq(List.length(&2, Geometry.Triangle, faces), 2n),
      Bool.and(Nat.is_eq(List.length(&2, Geometry.NavLink, links), 1n),
      Bool.and(Nat.is_eq(List.length(&2, Catalog.EncounterRegion, regions), 1n),
      Bool.and(Nat.is_eq(List.length(&2, Catalog.Npc, npcs), 1n),
      Bool.and(Nat.is_eq(List.length(&2, Catalog.Trigger, triggers), 1n),
        Nat.is_eq(List.length(&2, Catalog.Transition, transitions), 1n)))))))
    case _: False{}

def rejected(result: Dynamic.DecodeResult) -> Bool:
  match result:
    case Dynamic.DecodeRejected{reason}: True{}
    case _: False{}

def bad_transition_target() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 0, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 3, 0
   1, 3, 1, 1, 99, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
]
def bad_trigger_index() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 0, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 3, 0
   1, 4, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
]
def bad_region_face() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 2, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 3, 0
   1, 3, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
]
def bad_region_encounter() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 3, 0
   1, 3, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
]
def bad_trigger_duplicate() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 0, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 3, 0
   0, 3, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
]

def bad_trigger_zero_area() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 1, 1, 2, 1, 0, 1, 1
   5, 0, 0, 0, 0, 0, 0, 1, 1, 5, 4, 0
   3, 1, 2, 1, 1, 0, 1, 0, 0, 0, 1, 3
   0, 1, 3
  ]

def bad_overlapping_regions() -> List<&2, U32>:
  [
   10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0
   0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
   1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1
   3, 2, 1, 0, 1, 2, 1, 2, 1, 0, 2, 2
   1, 0, 1, 1, 5, 0, 0, 0, 0, 0, 0, 1
   1, 5, 3, 0, 1, 3, 1, 1, 1, 0, 1, 0
   0, 0, 1, 3, 0, 1, 3
  ]

def main() -> Bool:
  Bool.and(accepted_shape(Dynamic.decode_tokens(world_tokens())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_npc_point())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_transition_target())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_trigger_index())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_region_face())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_region_encounter())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_trigger_duplicate())),
    Bool.and(rejected(Dynamic.decode_tokens(bad_trigger_zero_area())),
      rejected(Dynamic.decode_tokens(bad_overlapping_regions()))))))))))

#| True
