import Base
import ../../engine/world/dynamic_polygon_checks.bend as Polygon
import ../../engine/world/geometry.bend as Geometry

def vertex(x: U32, z: U32, y: U32) -> Geometry.Vertex:
  Geometry.Vertex{Geometry.Coord{False{}, x}, Geometry.Coord{False{}, y},
    Geometry.Coord{False{}, z}}

def square_vertices() -> List<&2, Geometry.Vertex>:
  [vertex(0, 0, 0), vertex(4, 0, 8), vertex(4, 4, 2), vertex(0, 4, 3)]

def crossing_vertices() -> List<&2, Geometry.Vertex>:
  [vertex(0, 0, 0), vertex(4, 4, 1), vertex(0, 4, 2), vertex(3, 0, 3)]

def main() -> Bool:
  Bool.and(Polygon.valid(square_vertices(), [0, 1, 2, 3]),
  Bool.and(Polygon.valid(square_vertices(), [3, 2, 1, 0]),
  Bool.and(Bool.not(Polygon.valid(square_vertices(), [0, 2, 1, 3])),
  Bool.and(Bool.not(Polygon.valid(crossing_vertices(), [0, 1, 2, 3])),
  Bool.and(Bool.not(Polygon.valid(square_vertices(), [0, 1, 1])),
    Bool.not(Polygon.valid(square_vertices(), [0, 1, 4])))))))

#| True
