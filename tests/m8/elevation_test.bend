import Base
import ../../engine/world/geometry.bend as World

def point(x: U32, y: U32, z: U32) -> World.Point:
  World.Point{World.Coord{False{}, x}, World.Coord{False{}, y},
    World.Coord{False{}, z}}

def slope() -> World.NavSurface:
  World.NavSurface{
    [World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
      World.Coord{False{}, 0}},
     World.Vertex{World.Coord{False{}, 1000}, World.Coord{False{}, 100},
      World.Coord{False{}, 0}},
     World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
      World.Coord{False{}, 1000}}],
    [World.Triangle{0, 1, 2}], []}

def reverse_slope() -> World.NavSurface:
  World.NavSurface{
    [World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
      World.Coord{False{}, 0}},
     World.Vertex{World.Coord{False{}, 1000}, World.Coord{False{}, 100},
      World.Coord{False{}, 0}},
     World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
      World.Coord{False{}, 1000}}],
    [World.Triangle{0, 2, 1}], []}

def extrapolation_surface(reverse: Bool) -> World.NavSurface:
  match reverse:
    case False{}:
      World.NavSurface{
        [World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 100},
          World.Coord{False{}, 0}},
         World.Vertex{World.Coord{False{}, 1000}, World.Coord{False{}, 0},
          World.Coord{False{}, 0}},
         World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
          World.Coord{False{}, 1000}}],
        [World.Triangle{0, 1, 2}], []}
    case True{}:
      World.NavSurface{
        [World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 100},
          World.Coord{False{}, 0}},
         World.Vertex{World.Coord{False{}, 1000}, World.Coord{False{}, 0},
          World.Coord{False{}, 0}},
         World.Vertex{World.Coord{False{}, 0}, World.Coord{False{}, 0},
          World.Coord{False{}, 1000}}],
        [World.Triangle{0, 2, 1}], []}

def projected(result: World.Point) -> Bool:
  match result:
    case World.Point{World.Coord{False{}, 500},
        World.Coord{False{}, 50}, World.Coord{False{}, 100}}: True{}
    case _: False{}

def projected_negative_extrapolation(result: World.Point) -> Bool:
  match result:
    case World.Point{World.Coord{False{}, 1200},
        World.Coord{True{}, 30}, World.Coord{False{}, 100}}: True{}
    case _: False{}

def moved_up(result: World.Motion) -> Bool:
  match result:
    case World.Motion{World.Point{World.Coord{False{}, 142},
        World.Coord{False{}, 14}, World.Coord{False{}, 100}},
        42, True{}, segments}: True{}
    case _: False{}

def rejected_off_surface(result: World.Motion) -> Bool:
  match result:
    case World.Motion{World.Point{World.Coord{False{}, 100},
        World.Coord{False{}, 0}, World.Coord{False{}, 100}},
        0, False{}, segments}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [projected(World.projected_point(slope(), 0, point(500, 0, 100))),
   projected(World.projected_point(reverse_slope(), 0,
     point(500, 0, 100))),
   projected_negative_extrapolation(World.projected_point(
     extrapolation_surface(False{}), 0, point(1200, 0, 100))),
   projected_negative_extrapolation(World.projected_point(
     extrapolation_surface(True{}), 0, point(1200, 0, 100))),
   World.coord_equal(World.coord_sub(World.Coord{False{}, 524288},
     World.Coord{True{}, 524288}), World.Coord{False{}, 1048576}),
   moved_up(World.move_tick(slope(), point(100, 10, 100),
     World.Input{World.Coord{False{}, 64}, World.Coord{False{}, 0},
       True{}, False{}})),
   rejected_off_surface(World.move_tick(slope(), point(100, 0, 100),
     World.Input{World.Coord{False{}, 64}, World.Coord{False{}, 0},
       True{}, False{}}))]
