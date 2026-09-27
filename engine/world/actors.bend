import Base
import ./geometry.bend as Geometry

# Actor collision radius is 512 Q10 subunits (half a world unit).
def collision_radius_sq() -> Nat:
  262144n

type Actor is Data:
  Actor{id: Geometry.ActorId, point: Geometry.Point,
    input: Geometry.Input}

type ActorMotion is Data:
  ActorMotion{id: Geometry.ActorId, start: Geometry.Point,
    finish: Geometry.Point, accepted: Bool}

type Batch is Data:
  Batch{valid: Bool, motions: List<&2, ActorMotion>}

type DeltaXZ is Data:
  DeltaXZ{x: Geometry.Coord, z: Geometry.Coord}

def ordered_pair(left: Geometry.ActorId,
  right: Geometry.ActorId) -> Bool:
  match left right:
    case Geometry.ActorId{a} Geometry.ActorId{b}: U32.is_lt(a, b)

def ordered_continue(previous: Maybe<&2, Geometry.ActorId>,
  current: Geometry.ActorId, rest_valid: Bool) -> Bool:
  match previous:
    case None{}: rest_valid
    case Some{prior_id}: Bool.and(ordered_pair(prior_id, current), rest_valid)

def ordered_after(actors: List<&2, Actor>,
  previous: Maybe<&2, Geometry.ActorId>) -> Bool:
  match actors:
    case Nil{}: True{}
    case Actor{+id, point, input} <> rest:
      ordered_continue(previous, id, ordered_after(rest, Some{id}))

def ordered_actors(actors: List<&2, Actor>) -> Bool:
  ordered_after(actors, None{})

def coord_sub_result(result: Geometry.CoordResult) -> Geometry.Coord:
  match result:
    case Geometry.CoordValue{value}: value
    case Geometry.CoordRejected{}: Geometry.Coord{False{}, 524288}

def coord_sub(+left: Geometry.Coord, right: Geometry.Coord) -> Geometry.Coord:
  match right:
    case Geometry.Coord{negative, magnitude}:
      coord_sub_result(Geometry.coord_add(left,
        Geometry.Coord{Bool.not(negative), magnitude}))

def radius_delta(delta: DeltaXZ) -> Bool:
  match delta:
    case DeltaXZ{Geometry.Coord{xn, xm}, Geometry.Coord{zn, zm}}:
      +x = U32.to_nat(xm)
      +z = U32.to_nat(zm)
      Nat.is_le((x * x + z * z : Nat), collision_radius_sq())

def within_radius(+left: Geometry.Point, +right: Geometry.Point) -> Bool:
  match left right:
    case Geometry.Point{lx, ly, lz} Geometry.Point{rx, ry, rz}:
      radius_delta(DeltaXZ{coord_sub(lx, rx), coord_sub(lz, rz)})

def vertex(point: Geometry.Point) -> Geometry.Vertex:
  match point:
    case Geometry.Point{x, y, z}: Geometry.Vertex{x, y, z}

def orientation(+a: Geometry.Point, +b: Geometry.Point,
  +p: Geometry.Point) -> Geometry.WideSigned:
  match p:
    case Geometry.Point{x, y, z}:
      Geometry.orient(vertex(a), vertex(b), x, z)

def opposite_or_zero(left: Geometry.WideSigned,
  right: Geometry.WideSigned) -> Bool:
  match left right:
    case Geometry.WideSigned{ln, lm} Geometry.WideSigned{rn, rm}:
      Bool.or(Nat.is_eq(lm, 0n), Bool.or(Nat.is_eq(rm, 0n),
        Bool.not(Cmp.is_eq(Bool.cmp(ln, rn)))))

def same_xz(left: Geometry.Point, right: Geometry.Point) -> Bool:
  match left right:
    case Geometry.Point{lx, ly, lz} Geometry.Point{rx, ry, rz}:
      Bool.and(Geometry.coord_equal(lx, rx), Geometry.coord_equal(lz, rz))

def coord_less_sign(same_sign: Bool, left_negative: Bool,
  left: U32, right: U32) -> Bool:
  match same_sign:
    case True{}:
      match left_negative:
        case True{}: U32.is_gt(left, right)
        case False{}: U32.is_lt(left, right)
    case False{}: left_negative

def coord_less(left: Geometry.Coord, right: Geometry.Coord) -> Bool:
  match left right:
    case Geometry.Coord{+ln, lm} Geometry.Coord{rn, rm}:
      coord_less_sign(Cmp.is_eq(Bool.cmp(ln, rn)), ln, lm, rm)

def coord_le(left: Geometry.Coord, right: Geometry.Coord) -> Bool:
  Bool.not(coord_less(right, left))

def between(+value: Geometry.Coord, +left: Geometry.Coord,
  +right: Geometry.Coord) -> Bool:
  Bool.or(Bool.and(coord_le(left, value), coord_le(value, right)),
    Bool.and(coord_le(right, value), coord_le(value, left)))

def intervals_overlap(+a: Geometry.Coord, +b: Geometry.Coord,
  +c: Geometry.Coord, +d: Geometry.Coord) -> Bool:
  Bool.or(Bool.or(between(a, c, d), between(b, c, d)),
    Bool.or(between(c, a, b), between(d, a, b)))

def point_x(point: Geometry.Point) -> Geometry.Coord:
  match point:
    case Geometry.Point{x, y, z}: x

def point_z(point: Geometry.Point) -> Geometry.Coord:
  match point:
    case Geometry.Point{x, y, z}: z

def bounds_overlap(+a0: Geometry.Point, +a1: Geometry.Point,
  +b0: Geometry.Point, +b1: Geometry.Point) -> Bool:
  Bool.and(intervals_overlap(point_x(a0), point_x(a1),
      point_x(b0), point_x(b1)),
    intervals_overlap(point_z(a0), point_z(a1),
      point_z(b0), point_z(b1)))

def four_zero(a: Geometry.WideSigned, b: Geometry.WideSigned,
  c: Geometry.WideSigned, d: Geometry.WideSigned) -> Bool:
  match a b c d:
    case Geometry.WideSigned{an, am} Geometry.WideSigned{bn, bm}
         Geometry.WideSigned{cn, cm} Geometry.WideSigned{dn, dm}:
      Bool.and(Nat.is_eq(am, 0n), Bool.and(Nat.is_eq(bm, 0n),
        Bool.and(Nat.is_eq(cm, 0n), Nat.is_eq(dm, 0n))))

def crossing_test(collinear: Bool, +a0: Geometry.Point,
  +a1: Geometry.Point, +b0: Geometry.Point, +b1: Geometry.Point) -> Bool:
  match collinear:
    case True{}: bounds_overlap(a0, a1, b0, b1)
    case False{}:
      Bool.and(opposite_or_zero(orientation(a0, a1, b0),
          orientation(a0, a1, b1)),
        opposite_or_zero(orientation(b0, b1, a0),
          orientation(b0, b1, a1)))

def crossing_nonstationary(moving: Bool, +a0: Geometry.Point,
  +a1: Geometry.Point, +b0: Geometry.Point, +b1: Geometry.Point) -> Bool:
  match moving:
    case False{}: False{}
    case True{}:
      crossing_test(four_zero(orientation(a0, a1, b0),
        orientation(a0, a1, b1), orientation(b0, b1, a0),
        orientation(b0, b1, a1)), a0, a1, b0, b1)

def paths_cross(+a0: Geometry.Point, +a1: Geometry.Point,
  +b0: Geometry.Point, +b1: Geometry.Point) -> Bool:
  crossing_nonstationary(Bool.and(Bool.not(same_xz(a0, a1)),
    Bool.not(same_xz(b0, b1))), a0, a1, b0, b1)

def as_wide(coord: Geometry.Coord) -> Geometry.WideSigned:
  match coord:
    case Geometry.Coord{negative, magnitude}:
      Geometry.WideSigned{negative, U32.to_nat(magnitude)}

def wide_difference_result(result: Geometry.WideSigned) -> Geometry.Coord:
  match result:
    case Geometry.WideSigned{negative, magnitude}:
      Geometry.Coord{negative, U32.from_nat(magnitude)}

def wide_difference(left: Geometry.Coord,
  right: Geometry.Coord) -> Geometry.Coord:
  wide_difference_result(Geometry.wide_sub(as_wide(left), as_wide(right)))

def wide_product_sum(left: Geometry.Coord, right: Geometry.Coord,
  other_left: Geometry.Coord, other_right: Geometry.Coord)
  -> Geometry.WideSigned:
  Geometry.wide_add(Geometry.wide_product(left, right),
    Geometry.wide_product(other_left, other_right))

def vector_length(dx: Geometry.Coord, dz: Geometry.Coord) -> Nat:
  match dx dz:
    case Geometry.Coord{_, +xm} Geometry.Coord{_, +zm}:
      (U32.to_nat(xm) * U32.to_nat(xm) +
        U32.to_nat(zm) * U32.to_nat(zm) : Nat)

def signed_le_zero(value: Geometry.WideSigned) -> Bool:
  match value:
    case Geometry.WideSigned{negative, +magnitude}:
      Bool.or(negative, Nat.is_eq(magnitude, 0n))

def signed_ge(value: Geometry.WideSigned, bound: Nat) -> Bool:
  match value:
    case Geometry.WideSigned{negative, magnitude}:
      Bool.and(Bool.not(negative), Nat.is_ge(magnitude, bound))

def cross_within_radius(cross: Geometry.WideSigned, length: Nat) -> Bool:
  match cross:
    case Geometry.WideSigned{negative, +magnitude}:
      Nat.is_le((magnitude * magnitude : Nat),
        (collision_radius_sq() * length : Nat))

def point_segment_interior(+dot: Geometry.WideSigned, +length: Nat,
  cross: Geometry.WideSigned) -> Bool:
  Bool.and(Bool.not(signed_le_zero(dot)),
    Bool.and(Bool.not(signed_ge(dot, length)),
      cross_within_radius(cross, length)))

def point_segment_end_projection(after_finish: Bool,
  +point: Geometry.Point, +finish: Geometry.Point,
  dx: Geometry.Coord, dz: Geometry.Coord,
  vx: Geometry.Coord, vz: Geometry.Coord,
  +dot: Geometry.WideSigned, +length: Nat) -> Bool:
  match after_finish:
    case True{}: within_radius(point, finish)
    case False{}:
      point_segment_interior(dot, length,
        Geometry.wide_sub(Geometry.wide_product(vx, dz),
          Geometry.wide_product(vz, dx)))

def point_segment_projection(after_start: Bool, +point: Geometry.Point,
  +start: Geometry.Point, +finish: Geometry.Point,
  dx: Geometry.Coord, dz: Geometry.Coord,
  vx: Geometry.Coord, vz: Geometry.Coord,
  +dot: Geometry.WideSigned, +length: Nat) -> Bool:
  match after_start:
    case True{}: within_radius(point, start)
    case False{}:
      point_segment_end_projection(signed_ge(dot, length), point,
        finish, dx, dz, vx, vz, dot, length)

def point_segment(+point: Geometry.Point, +start: Geometry.Point,
  +finish: Geometry.Point) -> Bool:
  match point start finish:
    case Geometry.Point{px, py, pz} Geometry.Point{sx, sy, sz}
         Geometry.Point{fx, fy, fz}:
      +dx = wide_difference(px, sx)
      +dz = wide_difference(pz, sz)
      +vx = wide_difference(fx, sx)
      +vz = wide_difference(fz, sz)
      +length = vector_length(vx, vz)
      +dot = wide_product_sum(dx, vx, dz, vz)
      point_segment_projection(signed_le_zero(dot), point, start, finish,
        dx, dz, vx, vz, dot, length)

def collision_points(+a0: Geometry.Point, +a1: Geometry.Point,
  +b0: Geometry.Point, +b1: Geometry.Point) -> Bool:
  Bool.or(paths_cross(a0, a1, b0, b1),
    Bool.or(Bool.or(point_segment(a0, b0, b1), point_segment(a1, b0, b1)),
      Bool.or(point_segment(b0, a0, a1), point_segment(b1, a0, a1))))

def conflicts(+candidate_start: Geometry.Point, +candidate_finish: Geometry.Point,
  prior: List<&2, ActorMotion>) -> Bool:
  match prior:
    case Nil{}: False{}
    case ActorMotion{id, start, finish, accepted} <> rest:
      Bool.or(collision_points(candidate_start, candidate_finish, start,
        finish), conflicts(candidate_start, candidate_finish, rest))

def future_overlap(+finish: Geometry.Point,
  future: List<&2, Actor>) -> Bool:
  match future:
    case Nil{}: False{}
    case Actor{id, point, input} <> rest:
      Bool.or(within_radius(finish, point), future_overlap(finish, rest))

def settle_motion(conflict: Bool, id: Geometry.ActorId,
  +start: Geometry.Point, +finish: Geometry.Point) -> ActorMotion:
  match conflict:
    case True{}: ActorMotion{id, start, start, False{}}
    case False{}: ActorMotion{id, start, finish, True{}}

def settle_proposal(id: Geometry.ActorId, +start: Geometry.Point,
  motion: Geometry.Motion, prior: List<&2, ActorMotion>,
  future: List<&2, Actor>) -> ActorMotion:
  match motion:
    case Geometry.Motion{finish, traveled, False{}, segments}:
      ActorMotion{id, start, start, False{}}
    case Geometry.Motion{+finish, traveled, True{}, segments}:
      settle_motion(Bool.or(conflicts(start, finish, prior),
        future_overlap(finish, future)),
        id, start, finish)

def resolve(+surface: Geometry.NavSurface, actors: List<&2, Actor>,
  +prior: List<&2, ActorMotion>, +output: List<&2, ActorMotion>)
  -> List<&2, ActorMotion>:
  match actors:
    case Nil{}: output
    case Actor{id, +point, input} <> +rest:
      +motion = settle_proposal(id, point,
        Geometry.move_tick(surface, point, input), prior, rest)
      resolve(surface, rest, motion <> prior, motion <> output)

def reverse_motions(motions: List<&2, ActorMotion>,
  reversed: List<&2, ActorMotion>) -> List<&2, ActorMotion>:
  match motions:
    case Nil{}: reversed
    case motion <> rest: reverse_motions(rest, motion <> reversed)

def reject_batch(ordered: Bool) -> Batch:
  match ordered:
    case True{}: Batch{True{}, []}
    case False{}: Batch{False{}, []}

# Inputs must have strictly increasing ActorId values. Earlier actors resolve
# first; every later move is checked against all earlier final positions/paths.
def move_batch_checked(valid: Bool, surface: Geometry.NavSurface,
  actors: List<&2, Actor>) -> Batch:
  match valid:
    case True{}: Batch{True{}, reverse_motions(resolve(surface, actors, [], []), [])}
    case False{}: Batch{False{}, []}

def move_batch(surface: Geometry.NavSurface,
  +actors: List<&2, Actor>) -> Batch:
  move_batch_checked(ordered_actors(actors), surface, actors)
