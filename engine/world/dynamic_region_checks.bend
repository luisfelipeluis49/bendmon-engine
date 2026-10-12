import Base
import ./catalog.bend as Catalog

def face_in_regions(+face: U32,
  regions: List<&2, Catalog.EncounterRegion>) -> Bool:
  match regions:
    case Nil{}: False{}
    case Catalog.EncounterRegion{id, encounter_id, faces} <> rest:
      Bool.or(Catalog.face_in_region(face, faces),
        face_in_regions(face, rest))

def any_face_reused(faces: List<&2, U32>,
  +regions: List<&2, Catalog.EncounterRegion>) -> Bool:
  match faces:
    case Nil{}: False{}
    case face <> rest:
      Bool.or(face_in_regions(face, regions),
        any_face_reused(rest, regions))

def disjoint(regions: List<&2, Catalog.EncounterRegion>) -> Bool:
  match regions:
    case Nil{}: True{}
    case Catalog.EncounterRegion{id, encounter_id, faces} <> +rest:
      Bool.and(Bool.not(any_face_reused(faces, rest)), disjoint(rest))

def maps_disjoint(maps: List<&2, Catalog.WorldMap>) -> Bool:
  match maps:
    case Nil{}: True{}
    case Catalog.WorldMap{id, navigation, regions, npcs,
        triggers, transitions} <> rest:
      Bool.and(disjoint(regions), maps_disjoint(rest))
