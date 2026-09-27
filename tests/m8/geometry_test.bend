import Base
import ../../engine/world/geometry.bend as World

def walk_speed_exact() -> Bool:
  U32.is_eq(World.mode_speed(World.Walk{}), 2560)

def run_speed_exact() -> Bool:
  U32.is_eq(World.mode_speed(World.Run{}), 4608)

def sprint_speed_exact() -> Bool:
  U32.is_eq(World.mode_speed(World.Sprint{}), 7168)

def face_surface() -> World.NavSurface:
  World.NavSurface{
    [World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
      World.Coord{False{}, 0}},
     World.Vertex{World.Coord{False{}, 1000}, World.Coord{False{}, 0},
      World.Coord{False{}, 0}},
     World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
      World.Coord{False{}, 1000}}],
    [World.Triangle{0, 1, 2}], []}

def inside_face_result(result: World.FaceChoice) -> Bool:
  match result:
    case World.FaceAccepted{0}: True{}
    case _: False{}

def inside_face_lookup() -> Bool:
  inside_face_result(World.face_for_point(face_surface(),
    World.Point{World.Coord{False{}, 100}, World.Coord{False{}, 0},
      World.Coord{False{}, 100}}))

def outside_face_result(result: World.FaceChoice) -> Bool:
  match result:
    case World.FaceRejected{}: True{}
    case _: False{}

def outside_face_lookup() -> Bool:
  outside_face_result(World.face_for_point(face_surface(),
    World.Point{World.Coord{False{}, 1200}, World.Coord{False{}, 0},
      World.Coord{False{}, 1200}}))

def movement_result(result: World.Motion) -> Bool:
  match result:
    case World.Motion{World.Point{World.Coord{False{}, 142},
        World.Coord{False{}, 0}, World.Coord{False{}, 100}},
        42, True{}, segments}:
      Nat.is_eq(List.length(&2, World.FaceTravel, segments), 42n)
    case _: False{}

def movement_stays_on_face() -> Bool:
  movement_result(World.move_tick(face_surface(),
      World.Point{World.Coord{False{}, 100}, World.Coord{False{}, 0},
        World.Coord{False{}, 100}},
      World.Input{World.Coord{False{}, 64}, World.Coord{False{}, 0},
        True{}, False{}}))

def conflict_order_result(result: World.ConflictOrder) -> Bool:
  match result:
    case World.ConflictOrder{World.ActorId{2}, World.ActorId{7}}: True{}
    case _: False{}

def stable_conflict_order() -> Bool:
  conflict_order_result(World.conflict_order(World.ActorId{7},
    World.ActorId{2}))

def main() -> List<&2, Bool>:
  [walk_speed_exact(), run_speed_exact(), sprint_speed_exact(),
    World.surface_valid(face_surface()), inside_face_lookup(),
    outside_face_lookup(), movement_stays_on_face(), stable_conflict_order()]
