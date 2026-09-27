import Base

# D14/U09 authority: coordinates are signed Q10 (1024 subunits per world
# unit). `ticks` are simulation ticks at 60 Hz, never presentation frames.
type Coord is Data:
  Coord{negative: Bool, magnitude: U32}

type Point is Data:
  Point{x: Coord, y: Coord, z: Coord}

type Vertex is Data:
  Vertex{x: Coord, y: Coord, z: Coord}

type Triangle is Data:
  Triangle{a: U32, b: U32, c: U32}

type NavLink is Data:
  NavLink{from_face: U32, to_face: U32}

type NavSurface is Data:
  NavSurface{vertices: List<&2, Vertex>, faces: List<&2, Triangle>,
    links: List<&2, NavLink>}

type ActorId is Data:
  ActorId{value: U32}

type ConflictOrder is Data:
  ConflictOrder{first: ActorId, second: ActorId}

type MoveMode is Data:
  Walk{}
  Run{}
  Sprint{}

type Input is Data:
  Input{x: Coord, z: Coord, analog: Bool, sprint: Bool}

type Motion is Data:
  Motion{point: Point, traveled: U32, accepted: Bool,
    segments: List<&2, FaceTravel>}

type FaceTravel is Data:
  FaceTravel{face: U32, distance: U32, point: Point}

type CoordResult is Data:
  CoordValue{value: Coord}
  CoordRejected{}

type PointResult is Data:
  PointValue{value: Point}
  PointRejected{}

type VertexResult is Data:
  VertexValue{value: Vertex}
  VertexMissing{}

type FaceResult is Data:
  FaceValue{value: Triangle, index: U32}
  FaceMissing{}

type FaceChoice is Data:
  FaceAccepted{value: U32}
  FaceRejected{}

type WideSigned is Data:
  WideSigned{negative: Bool, magnitude: Nat}

type PolygonScan is Data:
  PolygonScan{inside: Bool, boundary: Bool, valid: Bool}

def bool_equal(left: Bool, right: Bool) -> Bool:
  Cmp.is_eq(Bool.cmp(left, right))

def valid_coord(coord: Coord) -> Bool:
  match coord:
    case Coord{negative, +magnitude}:
      Bool.and(U32.is_le(magnitude, 524288),
        Bool.not(Bool.and(negative, U32.is_zero(magnitude))))

def valid_point(point: Point) -> Bool:
  match point:
    case Point{x, y, z}:
      Bool.and(valid_coord(x), Bool.and(valid_coord(y), valid_coord(z)))

def coord_equal(left: Coord, right: Coord) -> Bool:
  match left right:
    case Coord{left_sign, left_magnitude} Coord{right_sign, right_magnitude}:
      Bool.and(bool_equal(left_sign, right_sign),
        U32.is_eq(left_magnitude, right_magnitude))

def coord_add_same_total(negative: Bool, total: Nat) -> CoordResult:
  match total:
    case 0n: CoordValue{Coord{False{}, 0}}
    case 1n+rest: CoordValue{Coord{negative, U32.from_nat(total)}}

def coord_add_same_checked(valid: Bool, negative: Bool,
  total: Nat) -> CoordResult:
  match valid:
    case True{}:
      coord_add_same_total(negative, total)
    case False{}: CoordRejected{}

def coord_add_same(negative: Bool, left: U32, right: U32) -> CoordResult:
  +total = (U32.to_nat(left) + U32.to_nat(right) : Nat)
  coord_add_same_checked(Nat.is_le(total, 1048576n), negative, total)

def signed_magnitude(negative: Bool, +magnitude: U32) -> Coord:
  Coord{Bool.and(negative, Bool.not(U32.is_zero(magnitude))), magnitude}

def coord_add_opposite_ordered(ordered: Bool, negative: Bool,
  left: U32, right: U32) -> CoordResult:
  match ordered:
    case True{}:
      CoordValue{signed_magnitude(negative, U32.sub(left, right))}
    case False{}:
      CoordValue{signed_magnitude(Bool.not(negative), U32.sub(right, left))}

def coord_add_opposite(negative: Bool, +left: U32, +right: U32) -> CoordResult:
  coord_add_opposite_ordered(U32.is_ge(left, right), negative, left, right)

def coord_add_sign(equal_sign: Bool, negative: Bool, left: U32,
  right: U32) -> CoordResult:
  match equal_sign:
    case True{}: coord_add_same(negative, left, right)
    case False{}: coord_add_opposite(negative, left, right)

def coord_add(left: Coord, right: Coord) -> CoordResult:
  match left right:
    case Coord{+left_sign, left_mag} Coord{+right_sign, right_mag}:
      coord_add_sign(bool_equal(left_sign, right_sign), left_sign,
        left_mag, right_mag)

def sqrt_iter(fuel: Nat, +n: Nat, +guess: Nat) -> Nat:
  match fuel:
    case 0n: guess
    case 1n+rest:
      +next = Nat.div((guess + Nat.div(n, guess) : Nat), 2n)
      sqrt_iter(rest, n, next)

def sqrt_start(is_zero: Bool, +n: Nat) -> Nat:
  match is_zero:
    case True{}: 0n
    case False{}: sqrt_iter(64n, n, n)

def sqrt_nat(+n: Nat) -> Nat:
  sqrt_start(Nat.is_eq(n, 0n), n)


def mode_speed(mode: MoveMode) -> U32:
  match mode:
    case Walk{}: 2560
    case Run{}: 4608
    case Sprint{}: 7168

def mode_weight(mode: MoveMode) -> U32:
  match mode:
    case Walk{}: 768
    case Run{}: 1024
    case Sprint{}: 1536

def choose_speed(sprint: Bool, slow: Bool) -> MoveMode:
  match sprint:
    case True{}: Sprint{}
    case False{}:
      match slow:
        case True{}: Walk{}
        case False{}: Run{}

def input_mode(input: Input) -> MoveMode:
  match input:
    case Input{x, z, analog, sprint}:
      match x z:
        case Coord{xn, xm} Coord{zn, zm}:
          +axis = U32.max(xm, zm)
          choose_speed(sprint, Bool.and(analog, U32.is_le(axis, 512)))

def digital_axis(has_second_axis: Bool, axis: Coord) -> Coord:
  match has_second_axis axis:
    case False{} value: value
    case True{} Coord{negative, magnitude}:
      Coord{negative, U32.div(U32.mul(magnitude, 724), 1024)}

def analog_axis_result(is_zero: Bool, axis: Coord,
  magnitude: U32, norm: U32) -> Coord:
  match is_zero:
    case True{}: Coord{False{}, 0}
    case False{}:
      match axis:
        case Coord{negative, axis_magnitude}:
          Coord{negative, U32.from_nat(Nat.div(
            (U32.to_nat(axis_magnitude) * 1024n : Nat),
            U32.to_nat(norm)))}

def analog_axis(+axis: Coord, +other: Coord) -> Coord:
  match axis other:
    case Coord{negative, +magnitude} Coord{other_negative, other_magnitude}:
      +x = U32.to_nat(magnitude)
      +z = U32.to_nat(other_magnitude)
      +norm = U32.from_nat(sqrt_nat(((x * x : Nat) + (z * z : Nat) : Nat)))
      analog_axis_result(U32.is_zero(norm), axis, magnitude, norm)

def axis_delta_scaled(mode: MoveMode, ticks: U32,
  scaled_axis: Coord) -> Coord:
  match scaled_axis:
    case Coord{negative, magnitude}:
      +product = (U32.to_nat(mode_speed(mode)) * U32.to_nat(magnitude) : Nat)
      +raw = Nat.div((product * U32.to_nat(ticks) : Nat), 61440n)
      Coord{negative, U32.from_nat(raw)}

def axis_direction(digital: Bool, axis: Coord, other: Coord) -> Coord:
  match digital other:
    case True{} Coord{negative, magnitude}:
      digital_axis(Bool.not(U32.is_zero(magnitude)), axis)
    case False{} _: analog_axis(axis, other)

def axis_delta(mode: MoveMode, axis: Coord, other: Coord,
  digital: Bool, ticks: U32) -> Coord:
  axis_delta_scaled(mode, ticks, axis_direction(digital, axis, other))

def add_point_xy(start: Point, dx: Coord, dz: Coord,
  result_x: CoordResult, result_z: CoordResult) -> PointResult:
  match start result_x result_z:
    case Point{sx, sy, sz} CoordValue{x} CoordValue{z}:
      PointValue{Point{x, sy, z}}
    case _ _ _:
      PointRejected{}

def propose(start: Point, input: Input, +mode: MoveMode,
  +ticks: U32) -> PointResult:
  match start input:
    case Point{+x, y, +z} Input{+ix, +iz, analog, sprint}:
      +digital = Bool.not(analog)
      +dx = axis_delta(mode, ix, iz, digital, ticks)
      +dz = axis_delta(mode, iz, ix, digital, ticks)
      add_point_xy(Point{x, y, z}, dx, dz, coord_add(x, dx), coord_add(z, dz))

def vertex_at(index: Nat, vertices: List<&2, Vertex>) -> VertexResult:
  match index:
    case 0n:
      match vertices:
        case Nil{}: VertexMissing{}
        case vertex <> rest: VertexValue{vertex}
    case 1n+rest_index:
      match vertices:
        case Nil{}: VertexMissing{}
        case vertex <> rest: vertex_at(rest_index, rest)

def get_vertex(surface: NavSurface, index: U32) -> VertexResult:
  match surface:
    case NavSurface{+vertices, +faces, +links}:
      vertex_at(U32.to_nat(index), vertices)

def triangle_at(index: Nat, faces: List<&2, Triangle>) -> FaceResult:
  match index:
    case 0n:
      match faces:
        case Nil{}: FaceMissing{}
        case face <> rest: FaceValue{face, 0}
    case 1n+rest_index:
      match faces:
        case Nil{}: FaceMissing{}
        case face <> rest: triangle_at(rest_index, rest)

def get_face(surface: NavSurface, index: U32) -> FaceResult:
  match surface:
    case NavSurface{vertices, faces, links}:
      triangle_at(U32.to_nat(index), faces)

def wide_product(left: Coord, right: Coord) -> WideSigned:
  match left right:
    case Coord{left_sign, left_mag} Coord{right_sign, right_mag}:
      WideSigned{Bool.not(bool_equal(left_sign, right_sign)),
        (U32.to_nat(left_mag) * U32.to_nat(right_mag) : Nat)}

def wide_sub_same_ordered(ordered: Bool, negative: Bool,
  left: Nat, right: Nat) -> WideSigned:
  match ordered:
    case True{}: WideSigned{negative, Nat.sub(left, right)}
    case False{}: WideSigned{Bool.not(negative), Nat.sub(right, left)}

def wide_sub_same(negative: Bool, +left: Nat, +right: Nat) -> WideSigned:
  wide_sub_same_ordered(Nat.is_ge(left, right), negative, left, right)

def wide_sub_sign(same_sign: Bool, left: WideSigned,
  right: WideSigned) -> WideSigned:
  match same_sign left right:
    case True{} WideSigned{negative, left_mag} WideSigned{rn, right_mag}:
      wide_sub_same(negative, left_mag, right_mag)
    case False{} WideSigned{negative, magnitude}
         WideSigned{ignored, right_magnitude}:
      WideSigned{negative, (magnitude + right_magnitude : Nat)}

def wide_sub(left: WideSigned, right: WideSigned) -> WideSigned:
  match left right:
    case WideSigned{+ln, lm} WideSigned{+rn, rm}:
      wide_sub_sign(bool_equal(ln, rn), WideSigned{ln, lm},
        WideSigned{rn, rm})

def wide_negate(value: WideSigned) -> WideSigned:
  match value:
    case WideSigned{negative, magnitude}:
      WideSigned{Bool.not(negative), magnitude}

def wide_add(left: WideSigned, right: WideSigned) -> WideSigned:
  wide_sub(left, wide_negate(right))

def coord_sub_result(result: CoordResult) -> Coord:
  match result:
    case CoordValue{value}: value
    case CoordRejected{}: Coord{False{}, 524288}

def coord_sub(left: Coord, right: Coord) -> Coord:
  match right:
    case Coord{negative, magnitude}:
      coord_sub_result(coord_add(left, Coord{Bool.not(negative), magnitude}))

def orient(a: Vertex, b: Vertex, x: Coord, z: Coord) -> WideSigned:
  match a b:
    case Vertex{+ax, ay, +az} Vertex{+bx, by, +bz}:
      +dx1 = coord_sub(bx, ax)
      +dz1 = coord_sub(bz, az)
      +dx2 = coord_sub(x, ax)
      +dz2 = coord_sub(z, az)
      wide_sub(wide_product(dx1, dz2), wide_product(dz1, dx2))

def same_sign_zeros(left_zero: Bool, right_zero: Bool,
  left: WideSigned, right: WideSigned) -> Bool:
  match left_zero right_zero left right:
    case True{} _ _ _: True{}
    case _ True{} _ _: True{}
    case False{} False{} WideSigned{left_sign, lm} WideSigned{right_sign, rm}:
      bool_equal(left_sign, right_sign)

def same_nonnegative_sign(left: WideSigned, right: WideSigned) -> Bool:
  match left right:
    case WideSigned{ln, +lm} WideSigned{rn, +rm}:
      same_sign_zeros(Nat.is_eq(lm, 0n), Nat.is_eq(rm, 0n), left, right)

def same_side(point: Point, +a: Vertex, +b: Vertex, +c: Vertex) -> Bool:
  match point c:
    case Point{px, py, pz} Vertex{cx, cy, cz}:
      same_nonnegative_sign(orient(a, b, px, pz), orient(a, b, cx, cz))

def vertex_valid(vertex: Vertex) -> Bool:
  match vertex:
    case Vertex{x, y, z}:
      Bool.and(valid_coord(x), Bool.and(valid_coord(y), valid_coord(z)))

def vertices_valid(vertices: List<&2, Vertex>) -> Bool:
  match vertices:
    case Nil{}: True{}
    case vertex <> rest:
      Bool.and(vertex_valid(vertex), vertices_valid(rest))

def nondegenerate_area(area: WideSigned) -> Bool:
  match area:
    case WideSigned{negative, magnitude}: Bool.not(Nat.is_eq(magnitude, 0n))

def nondegenerate(a: Vertex, b: Vertex, c: Vertex) -> Bool:
  match c:
    case Vertex{cx, cy, cz}:
      nondegenerate_area(orient(a, b, cx, cz))

def face_vertices_valid(a: VertexResult, b: VertexResult,
  c: VertexResult) -> Bool:
  match a b c:
    case VertexValue{+av} VertexValue{+bv} VertexValue{cv}:
      nondegenerate(av, bv, cv)
    case _ _ _: False{}

def face_valid(+vertices: List<&2, Vertex>, face: Triangle) -> Bool:
  match face:
    case Triangle{+a, +b, c}:
      face_vertices_valid(vertex_at(U32.to_nat(a), vertices),
        vertex_at(U32.to_nat(b), vertices),
        vertex_at(U32.to_nat(c), vertices))

def faces_valid(+vertices: List<&2, Vertex>,
  faces: List<&2, Triangle>) -> Bool:
  match faces:
    case Nil{}: True{}
    case face <> rest:
      Bool.and(face_valid(vertices, face), faces_valid(vertices, rest))

def face_pair_exist(from_face: FaceResult, to_face: FaceResult) -> Bool:
  match from_face to_face:
    case FaceValue{a, ai} FaceValue{b, bi}: True{}
    case _ _: False{}

def link_faces_valid(+surface: NavSurface, link: NavLink) -> Bool:
  match link:
    case NavLink{from, to}:
      face_pair_exist(get_face(surface, from), get_face(surface, to))

def links_valid(+surface: NavSurface, links: List<&2, NavLink>) -> Bool:
  match links:
    case Nil{}: True{}
    case link <> rest:
      Bool.and(link_faces_valid(surface, link), links_valid(surface, rest))

def surface_valid(surface: NavSurface) -> Bool:
  match surface:
    case NavSurface{+vertices, +faces, +links}:
      Bool.and(vertices_valid(vertices),
        Bool.and(faces_valid(vertices, faces), links_valid(surface, links)))

def point_in_vertices(+point: Point, a_result: VertexResult,
  b_result: VertexResult, c_result: VertexResult) -> Bool:
  match a_result b_result c_result:
    case VertexValue{+a} VertexValue{+b} VertexValue{+c}:
      Bool.and(same_side(point, a, b, c),
        Bool.and(same_side(point, b, c, a), same_side(point, c, a, b)))
    case _ _ _:
      False{}

def point_in_face(point: Point, face: Triangle,
  +vertices: List<&2, Vertex>) -> Bool:
  match face:
    case Triangle{+a, +b, c}:
      point_in_vertices(point, vertex_at(U32.to_nat(a), vertices),
        vertex_at(U32.to_nat(b), vertices), vertex_at(U32.to_nat(c), vertices))

def face_search(+surface: NavSurface, +point: Point,
  faces: List<&2, Triangle>,
  +cursor: U32) -> FaceChoice:
  match surface faces:
    case NavSurface{+vertices, sf, sl} Nil{}: FaceRejected{}
    case NavSurface{+vertices, sf, sl} face <> rest:
      Bool.pick(FaceChoice, point_in_face(point, face, vertices),
        FaceAccepted{cursor}, face_search(surface, point, rest, U32.inc(cursor)))

def face_for_point(+surface: NavSurface, +point: Point) -> FaceChoice:
  match surface:
    case NavSurface{vertices, faces, links}:
      face_search(surface, point, faces, 0)

def height_term(height: Coord, area: WideSigned) -> WideSigned:
  match height area:
    case Coord{negative, magnitude} WideSigned{area_sign, weight}:
      WideSigned{Bool.not(bool_equal(negative, area_sign)),
        (U32.to_nat(magnitude) * weight : Nat)}

def vertex_height(vertex: Vertex) -> Coord:
  match vertex:
    case Vertex{x, y, z}: y

def height_divide(total: WideSigned, area: WideSigned) -> Coord:
  match total:
    case WideSigned{negative, magnitude}:
      match area:
        case WideSigned{area_sign, area_magnitude}:
          signed_magnitude(Bool.not(bool_equal(negative, area_sign)),
            U32.from_nat(Nat.div(magnitude, area_magnitude)))

def height_at_vertices(+a: Vertex, +b: Vertex, +c: Vertex,
  point: Point) -> Coord:
  match a b c point:
    case Vertex{+ax, ay, +az} Vertex{+bx, by, +bz}
         Vertex{+cx, cy, +cz} Point{+px, py, +pz}:
      +wa = orient(b, c, px, pz)
      +wb = orient(c, a, px, pz)
      +wc = orient(a, b, px, pz)
      +total = wide_add(wide_add(height_term(ay, wa),
        height_term(by, wb)), height_term(cy, wc))
      height_divide(total, orient(a, b, cx, cz))

def height_from_vertices(a: VertexResult, b: VertexResult,
  c: VertexResult, point: Point) -> CoordResult:
  match a b c:
    case VertexValue{av} VertexValue{bv} VertexValue{cv}:
      CoordValue{height_at_vertices(av, bv, cv, point)}
    case _ _ _: CoordRejected{}

def height_from_face(face: FaceResult,
  +vertices: List<&2, Vertex>, point: Point) -> CoordResult:
  match face:
    case FaceMissing{}: CoordRejected{}
    case FaceValue{Triangle{a, b, c}, index}:
      height_from_vertices(vertex_at(U32.to_nat(a), vertices),
        vertex_at(U32.to_nat(b), vertices),
        vertex_at(U32.to_nat(c), vertices), point)

def face_height(surface: NavSurface, face: U32,
  point: Point) -> CoordResult:
  match surface:
    case NavSurface{vertices, faces, links}:
      height_from_face(triangle_at(U32.to_nat(face), faces),
        vertices, point)

def point_with_height(result: CoordResult, point: Point) -> Point:
  match result point:
    case CoordValue{height} Point{x, y, z}: Point{x, height, z}
    case CoordRejected{} unchanged: unchanged

def projected_point(surface: NavSurface, face: U32,
  +point: Point) -> Point:
  point_with_height(face_height(surface, face, point), point)

def coord_gt(left: Coord, right: Coord) -> Bool:
  match left right:
    case Coord{False{}, lm} Coord{True{}, rm}: True{}
    case Coord{True{}, lm} Coord{False{}, rm}: False{}
    case Coord{False{}, lm} Coord{False{}, rm}: U32.is_gt(lm, rm)
    case Coord{True{}, lm} Coord{True{}, rm}: U32.is_lt(lm, rm)

def coord_between(+value: Coord, +low: Coord, +high: Coord) -> Bool:
  Bool.not(Bool.or(Bool.and(coord_gt(low, value), coord_gt(high, value)),
    Bool.and(coord_gt(value, low), coord_gt(value, high))))

def edge_boundary(orientation: WideSigned, px: Coord, pz: Coord,
  ax: Coord, az: Coord, bx: Coord, bz: Coord) -> Bool:
  match orientation:
    case WideSigned{negative, magnitude}:
      Bool.and(Nat.is_eq(magnitude, 0n),
        Bool.and(coord_between(px, ax, bx), coord_between(pz, az, bz)))

def edge_crosses(orientation: WideSigned,
  +above_a: Bool, above_b: Bool) -> Bool:
  match orientation:
    case WideSigned{negative, magnitude}:
      Bool.and(Bool.not(bool_equal(above_a, above_b)),
        Bool.and(Nat.is_gt(magnitude, 0n),
          bool_equal(negative, above_a)))

def polygon_edge(+a: Vertex, +b: Vertex, point: Point,
  scan: PolygonScan) -> PolygonScan:
  match a b point scan:
    case Vertex{+ax, ay, +az} Vertex{+bx, by, +bz}
         Point{+px, py, +pz} PolygonScan{inside, boundary, valid}:
      +orientation = orient(a, b, px, pz)
      +above_a = coord_gt(az, pz)
      +above_b = coord_gt(bz, pz)
      PolygonScan{Bool.not(bool_equal(inside,
        edge_crosses(orientation, above_a, above_b))),
        Bool.or(boundary, edge_boundary(orientation, px, pz,
          ax, az, bx, bz)), valid}

def polygon_edge_results(a: VertexResult, b: VertexResult,
  point: Point, scan: PolygonScan) -> PolygonScan:
  match a b:
    case VertexValue{av} VertexValue{bv}:
      polygon_edge(av, bv, point, scan)
    case _ _:
      PolygonScan{False{}, False{}, False{}}

def polygon_scan_rest(+vertices: List<&2, Vertex>,
  remaining: List<&2, U32>, first: U32, previous: U32, +point: Point,
  scan: PolygonScan) -> PolygonScan:
  match remaining:
    case Nil{}:
      polygon_edge_results(vertex_at(U32.to_nat(previous), vertices),
        vertex_at(U32.to_nat(first), vertices), point, scan)
    case +next <> rest:
      polygon_scan_rest(vertices, rest, first, next, point,
        polygon_edge_results(vertex_at(U32.to_nat(previous), vertices),
          vertex_at(U32.to_nat(next), vertices), point, scan))

def polygon_scan(+vertices: List<&2, Vertex>,
  indices: List<&2, U32>, point: Point) -> PolygonScan:
  match indices:
    case Nil{}: PolygonScan{False{}, False{}, False{}}
    case +first <> rest:
      polygon_scan_rest(vertices, rest, first, first, point,
        PolygonScan{False{}, False{}, True{}})

def polygon_contains_result(scan: PolygonScan) -> Bool:
  match scan:
    case PolygonScan{inside, boundary, valid}:
      Bool.and(valid, Bool.or(inside, boundary))

def polygon_contains(surface: NavSurface, indices: List<&2, U32>,
  point: Point) -> Bool:
  match surface:
    case NavSurface{vertices, faces, links}:
      polygon_contains_result(polygon_scan(vertices, indices, point))

def linked(+from_face: U32, +to_face: U32,
  links: List<&2, NavLink>) -> Bool:
  match links:
    case Nil{}: False{}
    case NavLink{from, to} <> rest:
      Bool.or(Bool.and(U32.is_eq(from_face, from), U32.is_eq(to_face, to)),
        linked(from_face, to_face, rest))

def linked_either_way(linked_forward: Bool, +surface: NavSurface,
  from_face: U32, to_face: U32) -> Bool:
  match linked_forward:
    case True{}: True{}
    case False{}:
      match surface:
        case NavSurface{vertices, faces, links}:
          linked(to_face, from_face, links)

def faces_connected(same_face: Bool, forward: Bool, +surface: NavSurface,
  from_face: U32, to_face: U32) -> Bool:
  match same_face:
    case True{}: True{}
    case False{}:
      linked_either_way(forward, surface, from_face, to_face)

def trace_faces_linked(forward: Bool, +surface: NavSurface,
  +from_id: U32, +to_id: U32) -> Bool:
  faces_connected(U32.is_eq(from_id, to_id), forward, surface,
    from_id, to_id)

def trace_faces_connected(from_face: FaceChoice, to_face: FaceChoice,
  +surface: NavSurface) -> Bool:
  match from_face to_face surface:
    case FaceAccepted{+from_id} FaceAccepted{+to_id}
         NavSurface{vertices, faces, links}:
      trace_faces_linked(linked(from_id, to_id, links), surface,
        from_id, to_id)
    case _ _ _:
      False{}

def coord_shift_result(result: CoordResult, original: Coord) -> Coord:
  match result:
    case CoordValue{value}: value
    case CoordRejected{}: original

def interpolate_delta(delta: Coord, original: Coord,
  step: U32, steps: U32) -> Coord:
  match delta original:
    case Coord{negative, magnitude} Coord{+on, +om}:
      +part = U32.from_nat(Nat.div(
        (U32.to_nat(magnitude) * U32.to_nat(step) : Nat),
        U32.to_nat(steps)))
      coord_shift_result(coord_add(Coord{on, om},
        Coord{negative, part}), Coord{on, om})

def interpolate_coord(original: Coord, destination: Coord,
  step: U32, steps: U32) -> Coord:
  match original destination:
    case Coord{+on, +om} Coord{dn, dm}:
      interpolate_delta(coord_sub(Coord{dn, dm}, Coord{on, om}),
        Coord{on, om}, step, steps)

def interpolate_point(start: Point, finish: Point,
  +step: U32, +steps: U32) -> Point:
  match start finish:
    case Point{sx, sy, sz} Point{fx, fy, fz}:
      Point{interpolate_coord(sx, fx, step, steps), sy,
        interpolate_coord(sz, fz, step, steps)}

def step_distance(+full_distance: U32, +step: U32, +steps: U32) -> U32:
  +base = U32.div(full_distance, steps)
  +remainder = U32.mod(full_distance, steps)
  U32.add(base, Bool.to_u32(U32.is_le(step, remainder)))

def reverse_face_travels(xs: List<&2, FaceTravel>,
  acc: List<&2, FaceTravel>) -> List<&2, FaceTravel>:
  match xs:
    case Nil{}: acc
    case value <> rest:
      reverse_face_travels(rest, value <> acc)

def sweep_trace_next(remaining: Nat, face: FaceChoice, +surface: NavSurface,
  +start: Point, +finish: Point, +current: U32,
  +steps: U32, +full_distance: U32, +segments: List<&2, FaceTravel>) ->
  Maybe<&2, List<&2, FaceTravel>>:
  match remaining face:
    case 0n _: Some{reverse_face_travels(segments, [])}
    case 1n+ +rest FaceAccepted{+face_id}:
      +travel: FaceTravel = FaceTravel{face_id,
        step_distance(full_distance, current, steps),
        projected_point(surface, face_id,
          interpolate_point(start, finish, current, steps))}
      +next_step = U32.inc(current)
      +next_face = face_for_point(surface, interpolate_point(start, finish,
        next_step, steps))
      Bool.pick(Maybe<&2, List<&2, FaceTravel>>,
        Nat.is_eq(rest, 0n),
        Some{reverse_face_travels(travel <> segments, [])},
        Bool.pick(Maybe<&2, List<&2, FaceTravel>>,
          trace_faces_connected(face, next_face, surface),
          sweep_trace_next(rest, next_face, surface, start,
            finish, next_step, steps, full_distance, travel <> segments),
          None{}))
    case 1n+rest FaceRejected{}: None{}

def sweep_trace_start(zero_steps: Bool, +surface: NavSurface, +start: Point,
  +finish: Point, +steps: U32, +full_distance: U32) ->
  Maybe<&2, List<&2, FaceTravel>>:
  match zero_steps:
    case True{}: Some{[]}
    case False{}:
      +next_step: U32 = 1
      +next_face = face_for_point(surface, interpolate_point(start, finish,
        next_step, steps))
      Bool.pick(Maybe<&2, List<&2, FaceTravel>>,
        trace_faces_connected(face_for_point(surface, start), next_face,
          surface),
        sweep_trace_next(U32.to_nat(steps), next_face, surface, start,
          finish, next_step, steps, full_distance, []), None{})

def sweep_trace(surface: NavSurface, start: Point, finish: Point,
  +steps: U32, +full_distance: U32) -> Maybe<&2, List<&2, FaceTravel>>:
  sweep_trace_start(U32.is_zero(steps), surface, start, finish, steps,
    full_distance)

def face_transition_valid(same_face: Bool, same_height: Bool,
  +surface: NavSurface, +from_face: U32, +to_face: U32) -> Bool:
  match same_face:
    case True{}: same_height
    case False{}:
      match surface:
        case NavSurface{vertices, faces, links}:
          linked_either_way(linked(from_face, to_face, links),
            surface, from_face, to_face)

def elevation_valid(surface: NavSurface, start: Point, finish: Point,
  +from_face: U32, +to_face: U32) -> Bool:
  match start finish:
    case Point{sx, Coord{syn, symag}, sz}
         Point{fx, Coord{fyn, fymag}, fz}:
      face_transition_valid(U32.is_eq(from_face, to_face),
        Bool.and(bool_equal(syn, fyn), U32.is_eq(symag, fymag)),
        surface, from_face, to_face)

def abs_delta_ordered(condition: Bool, left: U32, right: U32) -> U32:
  match condition:
    case True{}: U32.sub(left, right)
    case False{}: U32.sub(right, left)

def abs_delta(+left: U32, +right: U32) -> U32:
  abs_delta_ordered(U32.is_ge(left, right), left, right)

def euclidean_delta(dx: Coord, dz: Coord) -> U32:
  match dx dz:
    case Coord{xn, xmag} Coord{zn, zmag}:
      +x = U32.to_nat(xmag)
      +z = U32.to_nat(zmag)
      U32.from_nat(sqrt_nat(((x * x : Nat) + (z * z : Nat) : Nat)))

def traveled(start: Point, finish: Point) -> U32:
  # Floor of the Euclidean Q10 length is the deterministic ground-distance
  # metric used for encounter accumulation.
  match start finish:
    case Point{sx, sy, sz} Point{fx, fy, fz}:
      euclidean_delta(coord_sub(fx, sx), coord_sub(fz, sz))

def movement_steps_deltas(dx: Coord, dz: Coord) -> U32:
  match dx dz:
    case Coord{xn, xmag} Coord{zn, zmag}: U32.max(xmag, zmag)

def movement_steps(start: Point, finish: Point) -> U32:
  match start finish:
    case Point{sx, sy, sz} Point{fx, fy, fz}:
      movement_steps_deltas(coord_sub(fx, sx), coord_sub(fz, sz))

def reject(start: Point) -> Motion:
  Motion{start, 0, False{}, []}

def trace_motion(trace: Maybe<&2, List<&2, FaceTravel>>,
  start: Point, finish: Point, distance: U32) -> Motion:
  match trace:
    case None{}: reject(start)
    case Some{segments}: Motion{finish, distance, True{}, segments}

def resolve_steps(bounded: Bool, +surface: NavSurface, +start: Point,
  +finish: Point, steps: U32, +distance: U32) -> Motion:
  match bounded:
    case True{}:
      trace_motion(sweep_trace(surface, start, finish, steps, distance),
        start, finish, distance)
    case False{}: reject(start)

def resolve_elevation(valid: Bool, +surface: NavSurface, +start: Point,
  +finish: Point, +distance: U32) -> Motion:
  match valid:
    case True{}:
      +steps = movement_steps(start, finish)
      resolve_steps(U32.is_le(steps, 120), surface, start, finish, steps,
        distance)
    case False{}: reject(start)

def same_point_height(left: Point, right: Point) -> Bool:
  match left right:
    case Point{lx, ly, lz} Point{rx, ry, rz}:
      coord_equal(ly, ry)

def resolve_face_pair(+surface: NavSurface, +start: Point, +finish: Point,
  +from_face: U32, +to_face: U32) -> Motion:
  +distance = traveled(start, finish)
  +on_surface = projected_point(surface, from_face, start)
  +destination = projected_point(surface, to_face, finish)
  resolve_elevation(same_point_height(start, on_surface),
    surface, start, destination, distance)

def resolve_candidate(+surface: NavSurface, +start: Point, +finish: Point,
  old_face: FaceChoice, new_face: FaceChoice) -> Motion:
  match old_face new_face:
    case FaceAccepted{from_face} FaceAccepted{to_face}:
      resolve_face_pair(surface, start, finish, from_face, to_face)
    case _ _:
      reject(start)

def resolve_proposal(+surface: NavSurface, +start: Point,
  proposed: PointResult) -> Motion:
  match proposed:
    case PointRejected{}: reject(start)
    case PointValue{+finish}:
      resolve_candidate(surface, start, finish,
        face_for_point(surface, start), face_for_point(surface, finish))

# One call is a fixed simulation tick. Integrators may batch ticks, but must
# submit them in canonical actor order and may not substitute render delta time.
def move_tick(+surface: NavSurface, +start: Point, +input: Input) -> Motion:
  +mode = input_mode(input)
  resolve_proposal(surface, start, propose(start, input, mode, 1))

def actor_before(left: ActorId, right: ActorId) -> Bool:
  match left right:
    case ActorId{left_id} ActorId{right_id}:
      U32.is_lt(left_id, right_id)

def conflict_order_by_id(left_before: Bool, left: ActorId,
  right: ActorId) -> ConflictOrder:
  match left_before:
    case True{}: ConflictOrder{left, right}
    case False{}: ConflictOrder{right, left}

def conflict_order(+left: ActorId, +right: ActorId) -> ConflictOrder:
  conflict_order_by_id(actor_before(left, right), left, right)

def interaction_in_range(ground_distance: U32) -> Bool:
  U32.is_le(ground_distance, 1536)

def cone_positive(dot: WideSigned, direction_sq: Nat,
  target_sq: Nat) -> Bool:
  match dot:
    case WideSigned{True{}, magnitude}: False{}
    case WideSigned{False{}, +magnitude}:
      Bool.and(Nat.is_gt(magnitude, 0n),
        Nat.is_ge((2n * magnitude * magnitude : Nat),
          (direction_sq * target_sq : Nat)))

def cone_components(+dx: Coord, +dz: Coord,
  +fx: Coord, +fz: Coord) -> Bool:
  match dx dz fx fz:
    case Coord{+dnx, +mx} Coord{+dnz, +mz}
         Coord{+fnx, +mf_x} Coord{+fnz, +mf_z}:
      +dot = wide_add(wide_product(dx, fx), wide_product(dz, fz))
      +direction_sq = ((U32.to_nat(mf_x) * U32.to_nat(mf_x) : Nat)
        + (U32.to_nat(mf_z) * U32.to_nat(mf_z) : Nat) : Nat)
      +target_sq = ((U32.to_nat(mx) * U32.to_nat(mx) : Nat)
        + (U32.to_nat(mz) * U32.to_nat(mz) : Nat) : Nat)
      cone_positive(dot, direction_sq, target_sq)

# A 90-degree facing cone is part of the logical interaction command. The
# input direction is replayed, so camera or sprite interpolation cannot alter
# which NPC receives the interaction.
def interaction_in_cone(origin: Point, target: Point,
  facing_x: Coord, facing_z: Coord) -> Bool:
  match origin target:
    case Point{ox, oy, oz} Point{tx, ty, tz}:
      cone_components(coord_sub(tx, ox), coord_sub(tz, oz),
        facing_x, facing_z)

def weighted_encounter_distance(distance: U32, mode: MoveMode) -> U32:
  U32.div(U32.mul(distance, mode_weight(mode)), 1024)
