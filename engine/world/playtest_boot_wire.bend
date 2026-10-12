import Base
import ../battle/rng.bend as Rng
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry
import ./playtest_boot.bend as Boot

type BootRequest is Data:
  BootRequest{identity: U32, entry_map: U32, point: Geometry.Point,
    rng: Rng.RngState, wait_ticks: U32,
    starter_species: U32, starter_level: U32}

type DecodeResult is Data:
  BootAccepted{request: BootRequest}
  BootRejected{reason: String}

def coord(sign: U32, magnitude: U32) -> Geometry.Coord:
  Geometry.Coord{U32.is_eq(sign, 1), magnitude}

def sign_valid(+sign: U32, +magnitude: U32) -> Bool:
  Bool.and(U32.is_le(sign, 1),
    Bool.not(Bool.and(U32.is_eq(sign, 1), U32.is_zero(magnitude))))

def wait_valid(+ticks: U32) -> Bool:
  Bool.or(U32.is_eq(ticks, 30),
    Bool.or(U32.is_eq(ticks, 60), U32.is_eq(ticks, 120)))

def starter_valid(+species: U32, +level: U32) -> Bool:
  Bool.or(Bool.and(U32.is_zero(species), U32.is_zero(level)),
    Bool.and(Bool.not(U32.is_zero(species)), Bool.and(U32.is_le(1, level),
      U32.is_le(level, 100))))

def checked(valid: Bool, identity: U32, entry_map: U32,
  point: Geometry.Point, rng: Rng.RngState, wait_ticks: U32,
  starter_species: U32, starter_level: U32) -> DecodeResult:
  match valid:
    case False{}: BootRejected{"identity, map, coordinate, RNG, or Wait pacing is invalid"}
    case True{}:
      BootAccepted{BootRequest{identity, entry_map, point, rng, wait_ticks,
        starter_species, starter_level}}

def values(identity: U32, +entry_map: U32,
  +sx: U32, +mx: U32, +sy: U32, +my: U32, +sz: U32, +mz: U32,
  a: U32, b: U32, c: U32, d: U32, +wait_ticks: U32,
  +starter_species: U32, +starter_level: U32) -> DecodeResult:
  +point: Geometry.Point = Geometry.Point{coord(sx, mx), coord(sy, my), coord(sz, mz)}
  +rng: Rng.RngState = Rng.RngState{a, b, c, d}
  checked(Bool.and(Bool.not(U32.is_zero(entry_map)),
    Bool.and(sign_valid(sx, mx), Bool.and(sign_valid(sy, my),
    Bool.and(sign_valid(sz, mz), Bool.and(Geometry.valid_point(point),
    Bool.and(Rng.valid_state(rng), Bool.and(wait_valid(wait_ticks),
      starter_valid(starter_species, starter_level)))))))),
    identity, entry_map, point, rng, wait_ticks,
    starter_species, starter_level)

# Exactly seventeen U32 tokens; no trailing fields may smuggle another request.
def decode_tokens(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 11 <> 2 <> identity <> entry_map <>
         sx <> mx <> sy <> my <> sz <> mz <>
         a <> b <> c <> d <> wait_ticks <> starter_species <>
         starter_level <> Nil{}:
      values(identity, entry_map, sx, mx, sy, my, sz, mz,
        a, b, c, d, wait_ticks, starter_species, starter_level)
    case _: BootRejected{"boot wire must be M10BOOT v2 with seventeen U32 tokens"}

# The catalog identity and playable surface are checked again inside Boot.boot.
def boot(result: DecodeResult, catalog: Catalog.Catalog) -> Boot.BootResult:
  match result:
    case BootRejected{reason}: Boot.BootRejected{reason}
    case BootAccepted{BootRequest{identity, entry_map, point, rng,
        wait_ticks, starter_species, starter_level}}:
      Boot.boot(catalog, U32.to_nat(entry_map), point, rng,
        U32.to_nat(identity))
