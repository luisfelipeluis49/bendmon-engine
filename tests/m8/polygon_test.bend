import Base
import ../../engine/world/geometry.bend as World

def point(x: U32, z: U32) -> World.Point:
  World.Point{World.Coord{False{}, x}, World.Coord{False{}, 0},
    World.Coord{False{}, z}}

def vertex(x: U32, z: U32) -> World.Vertex:
  World.Vertex{World.Coord{False{}, x}, World.Coord{False{}, 0},
    World.Coord{False{}, z}}

def square() -> World.NavSurface:
  World.NavSurface{[vertex(0, 0), vertex(100, 0),
    vertex(100, 100), vertex(0, 100)],
    [World.Triangle{0, 1, 2}, World.Triangle{0, 2, 3}], []}

def concave() -> World.NavSurface:
  World.NavSurface{[vertex(0, 0), vertex(100, 0),
    vertex(100, 100), vertex(50, 50), vertex(0, 100)],
    [World.Triangle{0, 1, 3}, World.Triangle{1, 2, 3},
      World.Triangle{0, 3, 4}], []}

def main() -> List<&2, Bool>:
  [World.polygon_contains(square(), [0, 1, 2, 3], point(50, 50)),
   Bool.not(World.polygon_contains(square(), [0, 1, 2, 3],
     point(150, 50))),
   World.polygon_contains(square(), [0, 1, 2, 3], point(0, 50)),
   Bool.not(World.polygon_contains(concave(), [0, 1, 2, 3, 4],
     point(50, 75)))]
