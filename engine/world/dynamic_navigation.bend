import Base
# Bounded navigation primitives for the dynamic world wire parser.
import ./geometry.bend as Geometry

type FacesRead is Data:
  FacesBad{reason: String}
  FacesDone{values: List<&2, Geometry.Triangle>, rest: List<&2, U32>}

def face_option(ok: Bool, a: U32, b: U32, c: U32) ->
  Maybe<&2, Geometry.Triangle>:
  match ok:
    case True{}: Some{Geometry.Triangle{a, b, c}}
    case False{}: None{}

def valid_face(+a: U32, +b: U32, +c: U32,
  +vertex_count: Nat) -> Maybe<&2, Geometry.Triangle>:
  face_option(Bool.and(Nat.is_lt(U32.to_nat(a), vertex_count),
    Bool.and(Nat.is_lt(U32.to_nat(b), vertex_count),
      Nat.is_lt(U32.to_nat(c), vertex_count))), a, b, c)

@unsafe def faces_read(count: Nat, +vertex_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Geometry.Triangle>) -> FacesRead:
  match count:
    case 0n: FacesDone{List.reverse(&2, Geometry.Triangle, acc), tokens}
    case 1n+left:
      match tokens:
        case a <> b <> c <> rest:
          face_after(left, vertex_count, acc,
            valid_face(a, b, c, vertex_count), rest)
        case _: FacesBad{"face-missing"}

def face_after(left: Nat, +vertex_count: Nat,
  acc: List<&2, Geometry.Triangle>, result: Maybe<&2, Geometry.Triangle>,
  rest: List<&2, U32>) -> FacesRead:
  match result:
    case None{}: FacesBad{"face-index"}
    case Some{triangle}: faces_read(left, vertex_count, rest, triangle <> acc)

type LinksRead is Data:
  LinksBad{reason: String}
  LinksDone{values: List<&2, Geometry.NavLink>, rest: List<&2, U32>}

def link_option(ok: Bool, from_face: U32, to_face: U32) ->
  Maybe<&2, Geometry.NavLink>:
  match ok:
    case True{}: Some{Geometry.NavLink{from_face, to_face}}
    case False{}: None{}

def valid_link(+from_face: U32, +to_face: U32,
  +face_count: Nat) -> Maybe<&2, Geometry.NavLink>:
  link_option(Bool.and(Nat.is_lt(U32.to_nat(from_face), face_count),
    Nat.is_lt(U32.to_nat(to_face), face_count)), from_face, to_face)

@unsafe def links_read(count: Nat, +face_count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Geometry.NavLink>) -> LinksRead:
  match count:
    case 0n: LinksDone{List.reverse(&2, Geometry.NavLink, acc), tokens}
    case 1n+left:
      match tokens:
        case from_face <> to_face <> rest:
          link_after(left, face_count, acc,
            valid_link(from_face, to_face, face_count), rest)
        case _: LinksBad{"link-missing"}

def link_after(left: Nat, +face_count: Nat,
  acc: List<&2, Geometry.NavLink>, result: Maybe<&2, Geometry.NavLink>,
  rest: List<&2, U32>) -> LinksRead:
  match result:
    case None{}: LinksBad{"link-index"}
    case Some{link}: links_read(left, face_count, rest, link <> acc)

def same_face(left: Geometry.Triangle, right: Geometry.Triangle) -> Bool:
  match left right:
    case Geometry.Triangle{+a, +b, +c} Geometry.Triangle{+x, +y, +z}:
      Bool.or(Bool.and(U32.is_eq(a, x), Bool.and(U32.is_eq(b, y),
        U32.is_eq(c, z))), Bool.or(
        Bool.and(U32.is_eq(a, x), Bool.and(U32.is_eq(b, z), U32.is_eq(c, y))),
        Bool.or(Bool.and(U32.is_eq(a, y), Bool.and(U32.is_eq(b, x),
          U32.is_eq(c, z))), Bool.or(
          Bool.and(U32.is_eq(a, y), Bool.and(U32.is_eq(b, z), U32.is_eq(c, x))),
          Bool.or(Bool.and(U32.is_eq(a, z), Bool.and(U32.is_eq(b, x),
            U32.is_eq(c, y))), Bool.and(U32.is_eq(a, z),
            Bool.and(U32.is_eq(b, y), U32.is_eq(c, x))))))))

def face_in_list(+face: Geometry.Triangle,
  faces: List<&2, Geometry.Triangle>) -> Bool:
  match faces:
    case Nil{}: False{}
    case current <> rest:
      Bool.or(same_face(face, current), face_in_list(face, rest))

def duplicate_faces(faces: List<&2, Geometry.Triangle>) -> Bool:
  match faces:
    case Nil{}: False{}
    case +face <> +rest:
      Bool.or(face_in_list(face, rest), duplicate_faces(rest))

def same_link(left: Geometry.NavLink, right: Geometry.NavLink) -> Bool:
  match left right:
    case Geometry.NavLink{from_face, to_face}
         Geometry.NavLink{other_from, other_to}:
      Bool.and(U32.is_eq(from_face, other_from), U32.is_eq(to_face, other_to))

def link_in_list(+link: Geometry.NavLink,
  links: List<&2, Geometry.NavLink>) -> Bool:
  match links:
    case Nil{}: False{}
    case current <> rest:
      Bool.or(same_link(link, current), link_in_list(link, rest))

def duplicate_links(links: List<&2, Geometry.NavLink>) -> Bool:
  match links:
    case Nil{}: False{}
    case +link <> +rest:
      Bool.or(link_in_list(link, rest), duplicate_links(rest))

def bool_nat(value: Bool) -> Nat:
  match value:
    case True{}: 1n
    case False{}: 0n

def edge_shared(ok: Bool) -> Bool:
  ok

def common_vertices(+a: U32, +b: U32, +c: U32,
  face: Geometry.Triangle) -> Nat:
  match face:
    case Geometry.Triangle{+x, +y, +z}:
      (bool_nat(Bool.or(U32.is_eq(a, x), Bool.or(U32.is_eq(a, y),
        U32.is_eq(a, z)))) +
       bool_nat(Bool.or(U32.is_eq(b, x), Bool.or(U32.is_eq(b, y),
        U32.is_eq(b, z)))) +
       bool_nat(Bool.or(U32.is_eq(c, x), Bool.or(U32.is_eq(c, y),
        U32.is_eq(c, z)))) : Nat)

def link_faces_check(distinct: Bool, from_result: Geometry.FaceResult,
  to_result: Geometry.FaceResult) -> Bool:
  match distinct from_result to_result:
    case True{} Geometry.FaceValue{Geometry.Triangle{a, b, c}, from_index}
         Geometry.FaceValue{face, to_index}:
      Nat.is_ge(common_vertices(a, b, c, face), 2n)
    case _ _ _: False{}

def link_valid(+surface: Geometry.NavSurface, link: Geometry.NavLink) -> Bool:
  match link:
    case Geometry.NavLink{+from_face, +to_face}:
      link_faces_check(Bool.not(U32.is_eq(from_face, to_face)),
        Geometry.get_face(surface, from_face),
        Geometry.get_face(surface, to_face))

def links_geometry_valid(+surface: Geometry.NavSurface,
  links: List<&2, Geometry.NavLink>) -> Bool:
  match links:
    case Nil{}: True{}
    case +link <> +rest:
      Bool.and(link_valid(surface, link),
        links_geometry_valid(surface, rest))

def surface_geometry_valid(+surface: Geometry.NavSurface) -> Bool:
  match surface:
    case Geometry.NavSurface{+vertices, +faces, +links}:
      Bool.and(Nat.is_ge(List.length(&2, Geometry.Vertex, vertices), 3n),
        Bool.and(Nat.is_ge(List.length(&2, Geometry.Triangle, faces), 1n),
        Bool.and(Geometry.surface_valid(surface),
        Bool.and(Bool.not(duplicate_faces(faces)),
          Bool.and(Bool.not(duplicate_links(links)),
            links_geometry_valid(surface, links))))))
