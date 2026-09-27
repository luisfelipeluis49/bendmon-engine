import Base
import ../../engine/world/actors.bend as Actors
import ../../engine/world/geometry.bend as Geometry

def point(x: U32, z: U32) -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, x}, Geometry.Coord{False{}, 0},
    Geometry.Coord{False{}, z}}

def face_surface() -> Geometry.NavSurface:
  Geometry.NavSurface{
    [Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 0}},
     Geometry.Vertex{Geometry.Coord{False{}, 4096}, Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 0}},
     Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 4096}}], [Geometry.Triangle{0, 1, 2}], []}

def east() -> Geometry.Input:
  Geometry.Input{Geometry.Coord{False{}, 64}, Geometry.Coord{False{}, 0},
    True{}, False{}}

def actors_close() -> List<&2, Actors.Actor>:
  [Actors.Actor{Geometry.ActorId{1}, point(100, 100), east()},
   Actors.Actor{Geometry.ActorId{2}, point(630, 100), east()}]

def point_x(point: Geometry.Point) -> Geometry.Coord:
  match point:
    case Geometry.Point{x, y, z}: x

def ordered_conflict_result(batch: Actors.Batch) -> Bool:
  match batch:
    case Actors.Batch{True{}, [Actors.ActorMotion{Geometry.ActorId{1}, a, b,
         False{}}, Actors.ActorMotion{Geometry.ActorId{2}, c, d, True{}}]}:
      Bool.not(Actors.within_radius(b, d))
    case _: False{}

def ordered_conflict() -> Bool:
  ordered_conflict_result(Actors.move_batch(face_surface(), actors_close()))

def unsorted_result(batch: Actors.Batch) -> Bool:
  match batch:
    case Actors.Batch{False{}, []}: True{}
    case _: False{}

def unsorted_rejected() -> Bool:
  unsorted_result(Actors.move_batch(face_surface(),
    [Actors.Actor{Geometry.ActorId{2}, point(200, 100), east()},
     Actors.Actor{Geometry.ActorId{1}, point(100, 100), east()}]))

def separated_result(batch: Actors.Batch) -> Bool:
  match batch:
    case Actors.Batch{True{}, [Actors.ActorMotion{_, _, _, True{}},
      Actors.ActorMotion{_, _, _, True{}}]}: True{}
    case _: False{}

def separated_moves() -> Bool:
  separated_result(Actors.move_batch(face_surface(),
    [Actors.Actor{Geometry.ActorId{1}, point(100, 100), east()},
     Actors.Actor{Geometry.ActorId{2}, point(100, 1000), east()}]))

def final_positions_safe_result(batch: Actors.Batch) -> Bool:
  match batch:
    case Actors.Batch{True{}, [Actors.ActorMotion{Geometry.ActorId{1},
        first_start, first_finish, False{}},
      Actors.ActorMotion{Geometry.ActorId{2}, second_start, second_finish,
        True{}}]}:
      Bool.not(Actors.within_radius(first_finish, second_finish))
    case _: False{}

def later_start_blocker_prevents_overlap() -> Bool:
  final_positions_safe_result(Actors.move_batch(face_surface(),
    [Actors.Actor{Geometry.ActorId{1}, point(100, 100), east()},
     Actors.Actor{Geometry.ActorId{2}, point(630, 100), east()}]))

def collinear_disjoint_result(batch: Actors.Batch) -> Bool:
  match batch:
    case Actors.Batch{True{}, [Actors.ActorMotion{_, _, _, True{}},
      Actors.ActorMotion{_, _, _, True{}}]}: True{}
    case _: False{}

def collinear_disjoint_moves_are_allowed() -> Bool:
  collinear_disjoint_result(Actors.move_batch(face_surface(),
    [Actors.Actor{Geometry.ActorId{1}, point(100, 100), east()},
     Actors.Actor{Geometry.ActorId{2}, point(1000, 100), east()}]))

def near_parallel_paths_collide() -> Bool:
  Actors.collision_points(point(1000, 1000), point(3000, 1000),
    point(1800, 1400), point(2800, 1400))

def main() -> List<&2, Bool>:
  [ordered_conflict(), unsorted_rejected(), separated_moves(),
    later_start_blocker_prevents_overlap(),
    collinear_disjoint_moves_are_allowed(), near_parallel_paths_collide()]
