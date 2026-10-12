import Base
import ./geometry.bend as Geometry

type Edge is Data:
  Edge{index: Nat, a: Geometry.Vertex, b: Geometry.Vertex}

def contains(+index: U32, values: List<&2, U32>) -> Bool:
  match values:
    case Nil{}: False{}
    case head <> rest:
      Bool.or(U32.is_eq(index, head), contains(index, rest))

def valid_indices(indices: List<&2, U32>, +vertex_count: Nat,
  +seen: List<&2, U32>) -> Bool:
  match indices:
    case Nil{}: True{}
    case +index <> +rest:
      Bool.and(Nat.is_lt(U32.to_nat(index), vertex_count),
        Bool.and(Bool.not(contains(index, seen)),
          valid_indices(rest, vertex_count, index <> seen)))

def vertex_result(result: Geometry.VertexResult) -> Geometry.Vertex:
  match result:
    case Geometry.VertexValue{value}: value
    case Geometry.VertexMissing{}:
      Geometry.Vertex{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 0}}

def vertex(vertices: List<&2, Geometry.Vertex>, index: U32) -> Geometry.Vertex:
  vertex_result(Geometry.vertex_at(U32.to_nat(index), vertices))

def area_term(a: Geometry.Vertex, b: Geometry.Vertex) -> Geometry.WideSigned:
  match a b:
    case Geometry.Vertex{+ax, ay, +az} Geometry.Vertex{+bx, by, +bz}:
      Geometry.wide_sub(Geometry.wide_product(ax, bz),
        Geometry.wide_product(bx, az))

@unsafe def area_scan(+vertices: List<&2, Geometry.Vertex>, +first: U32,
  +previous: U32, indices: List<&2, U32>, +sum: Geometry.WideSigned) ->
  Geometry.WideSigned:
  match indices:
    case Nil{}:
      Geometry.wide_add(sum, area_term(vertex(vertices, previous),
        vertex(vertices, first)))
    case +index <> +rest:
      area_scan(vertices, first, index, rest,
        Geometry.wide_add(sum, area_term(vertex(vertices, previous),
          vertex(vertices, index))))

@unsafe def edges_after(+first: U32, +previous: U32, +position: Nat,
  +vertices: List<&2, Geometry.Vertex>, indices: List<&2, U32>,
  +acc: List<&2, Edge>) -> List<&2, Edge>:
  match indices:
    case Nil{}:
      Edge{position, vertex(vertices, previous), vertex(vertices, first)} <> acc
    case +next <> +rest:
      edges_after(first, next, Nat.add(1n, position), vertices, rest,
        Edge{position, vertex(vertices, previous), vertex(vertices, next)} <> acc)

def edges(indices: List<&2, U32>, vertices: List<&2, Geometry.Vertex>) ->
  List<&2, Edge>:
  match indices:
    case +first <> +rest:
      List.reverse(&2, Edge, edges_after(first, first, 0n, vertices, rest, Nil{}))
    case Nil{}: Nil{}

def wide_zero(value: Geometry.WideSigned) -> Bool:
  match value:
    case Geometry.WideSigned{negative, magnitude}: Nat.is_eq(magnitude, 0n)

def wide_negative(value: Geometry.WideSigned) -> Bool:
  match value:
    case Geometry.WideSigned{negative, magnitude}:
      Bool.and(negative, Bool.not(Nat.is_eq(magnitude, 0n)))

def opposite_nonzero(+left: Geometry.WideSigned,
  +right: Geometry.WideSigned) -> Bool:
  Bool.and(Bool.not(wide_zero(left)), Bool.and(Bool.not(wide_zero(right)),
    Bool.not(Geometry.bool_equal(wide_negative(left), wide_negative(right)))))

def coord_le_same_sign(negative: Bool, left: U32, right: U32) -> Bool:
  match negative:
    case True{}: U32.is_le(right, left)
    case False{}: U32.is_le(left, right)

def coord_le(signs_equal: Bool, left_negative: Bool, left: U32,
  right_negative: Bool, right: U32) -> Bool:
  match signs_equal:
    case True{}: coord_le_same_sign(left_negative, left, right)
    case False{}: left_negative

def coordinate_le(left: Geometry.Coord, right: Geometry.Coord) -> Bool:
  match left right:
    case Geometry.Coord{+ln, lm} Geometry.Coord{+rn, rm}:
      coord_le(Geometry.bool_equal(ln, rn), ln, lm, rn, rm)

def between(+value: Geometry.Coord, +left: Geometry.Coord,
  +right: Geometry.Coord) -> Bool:
  Bool.or(Bool.and(coordinate_le(left, value), coordinate_le(value, right)),
    Bool.and(coordinate_le(right, value), coordinate_le(value, left)))

def on_segment(a: Geometry.Vertex, point: Geometry.Vertex,
  b: Geometry.Vertex) -> Bool:
  match a point b:
    case Geometry.Vertex{ax, ay, az} Geometry.Vertex{px, py, pz}
         Geometry.Vertex{bx, by, bz}:
      Bool.and(between(px, ax, bx), between(pz, az, bz))

def orientation(a: Geometry.Vertex, b: Geometry.Vertex,
  point: Geometry.Vertex) -> Geometry.WideSigned:
  match point:
    case Geometry.Vertex{x, y, z}: Geometry.orient(a, b, x, z)

def intersection_crosses(all_opposite: Bool,
  +ab_c: Geometry.WideSigned, +ab_d: Geometry.WideSigned,
  +cd_a: Geometry.WideSigned, +cd_b: Geometry.WideSigned,
  +a: Geometry.Vertex, +b: Geometry.Vertex, +c: Geometry.Vertex,
  +d: Geometry.Vertex) -> Bool:
  Bool.or(all_opposite,
  Bool.or(Bool.and(wide_zero(ab_c), on_segment(a, c, b)),
  Bool.or(Bool.and(wide_zero(ab_d), on_segment(a, d, b)),
  Bool.or(Bool.and(wide_zero(cd_a), on_segment(c, a, d)),
    Bool.and(wide_zero(cd_b), on_segment(c, b, d))))))

def intersects(+a: Geometry.Vertex, +b: Geometry.Vertex,
  +c: Geometry.Vertex, +d: Geometry.Vertex) -> Bool:
  +ab_c = orientation(a, b, c)
  +ab_d = orientation(a, b, d)
  +cd_a = orientation(c, d, a)
  +cd_b = orientation(c, d, b)
  intersection_crosses(Bool.and(opposite_nonzero(ab_c, ab_d),
    opposite_nonzero(cd_a, cd_b)), ab_c, ab_d, cd_a, cd_b, a, b, c, d)

def adjacent_pair(+first: Nat, +second: Nat, count: Nat) -> Bool:
  Bool.or(Nat.is_eq(second, Nat.add(first, 1n)),
    Bool.and(Nat.is_eq(first, 0n), Nat.is_eq(second, Nat.sub(count, 1n))))

def check_later_pairs(+edge: Edge, +count: Nat,
  rest: List<&2, Edge>) -> Bool:
  match edge rest:
    case Edge{index, +a, +b} Nil{}: False{}
    case Edge{index, +a, +b} Edge{other_index, +c, +d} <> tail:
      Bool.or(Bool.and(Bool.not(adjacent_pair(index, other_index, count)),
          intersects(a, b, c, d)), check_later_pairs(edge, count, tail))

def check_edge_pairs(+count: Nat, rest: List<&2, Edge>) -> Bool:
  match rest:
    case Nil{}: False{}
    case +edge <> +tail:
      Bool.or(check_later_pairs(edge, count, tail),
        check_edge_pairs(count, tail))

@unsafe def valid_count(ok: Bool, +vertices: List<&2, Geometry.Vertex>,
  +indices: List<&2, U32>) -> Bool:
  match ok:
    case False{}: False{}
    case True{}:
      polygon_valid_geometry(Nat.is_le(List.length(&2, U32, indices), 256n),
        vertices, indices)

@unsafe def polygon_valid_geometry(ok: Bool, +vertices: List<&2, Geometry.Vertex>,
  +indices: List<&2, U32>) -> Bool:
  match ok:
    case False{}: False{}
    case True{}:
      match indices:
        case first <> second <> rest:
          polygon_valid_area(wide_zero(area_scan(vertices, first, second,
            rest, area_term(vertex(vertices, first),
              vertex(vertices, second)))),
            vertices, indices)
        case _: False{}

def polygon_valid_area(zero_area: Bool, +vertices: List<&2, Geometry.Vertex>,
  +indices: List<&2, U32>) -> Bool:
  match zero_area:
    case True{}: False{}
    case False{}:
      Bool.not(check_edge_pairs(List.length(&2, U32, indices),
        edges(indices, vertices)))

# Content-0 treats polygons as horizontal XZ outlines: winding is free, but
# zero shoelace area and every nonadjacent closed-edge intersection are invalid.
def valid(+vertices: List<&2, Geometry.Vertex>,
  +indices: List<&2, U32>) -> Bool:
  valid_count(Bool.and(Nat.is_le(3n, List.length(&2, U32, indices)),
    Bool.and(Nat.is_le(List.length(&2, U32, indices),
        List.length(&2, Geometry.Vertex, vertices)),
    Bool.and(Nat.is_le(List.length(&2, Geometry.Vertex, vertices), 256n),
      valid_indices(indices, List.length(&2, Geometry.Vertex, vertices), Nil{})))),
    vertices, indices)
