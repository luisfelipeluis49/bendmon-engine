import Base
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry

def face_accepted(found: Geometry.FaceChoice) -> Bool:
  match found:
    case Geometry.FaceAccepted{face}: True{}
    case Geometry.FaceRejected{}: False{}

def on_surface(surface: Geometry.NavSurface,
  point: Geometry.Point) -> Bool:
  face_accepted(Geometry.face_for_point(surface, point))

def npcs_on_surface(npcs: List<&2, Catalog.Npc>,
  +surface: Geometry.NavSurface) -> Bool:
  match npcs:
    case Nil{}: True{}
    case Catalog.Npc{id, point, event_id} <> rest:
      Bool.and(on_surface(surface, point), npcs_on_surface(rest, surface))

def destination_on_map(found: Maybe<&2, Catalog.WorldMap>,
  point: Geometry.Point) -> Bool:
  match found:
    case None{}: False{}
    case Some{Catalog.WorldMap{id, navigation, regions, npcs,
        triggers, transitions}}:
      on_surface(navigation, point)

def transitions_on_targets(transitions: List<&2, Catalog.Transition>,
  +maps: List<&2, Catalog.WorldMap>) -> Bool:
  match transitions:
    case Nil{}: True{}
    case Catalog.Transition{id, vertices, target_map, destination} <> rest:
      Bool.and(destination_on_map(Catalog.map_by_id(maps, target_map),
        destination), transitions_on_targets(rest, maps))

def map_points_valid(maps: List<&2, Catalog.WorldMap>,
  +all_maps: List<&2, Catalog.WorldMap>) -> Bool:
  match maps:
    case Nil{}: True{}
    case Catalog.WorldMap{id, navigation, regions, npcs,
        triggers, transitions} <> rest:
      Bool.and(npcs_on_surface(npcs, navigation),
        Bool.and(transitions_on_targets(transitions, all_maps),
          map_points_valid(rest, all_maps)))

# An authored actor and transition destination must open on a baked face.
def valid(+maps: List<&2, Catalog.WorldMap>) -> Bool:
  map_points_valid(maps, maps)
