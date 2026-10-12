import Base
import ../../engine/world/playtest_boot.bend as Boot
import ../../engine/world/playtest_boot_wire.bend as Wire
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng

def point(x: U32, z: U32) -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, x}, Geometry.Coord{False{}, 0},
    Geometry.Coord{False{}, z}}

def catalog() -> Catalog.Catalog:
  Catalog.Catalog{8n, 123n,
    [Catalog.WorldMap{1n,
      Geometry.NavSurface{
        [Geometry.Vertex{Geometry.Coord{False{}, 0},
          Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
         Geometry.Vertex{Geometry.Coord{False{}, 4096},
          Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
         Geometry.Vertex{Geometry.Coord{False{}, 0},
          Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 4096}}],
        [Geometry.Triangle{0, 1, 2}], []}, [], [], [], []}], []}

def success(result: Boot.BootResult) -> Bool:
  match result:
    case Boot.Booted{session}: True{}
    case _: False{}

def failure(result: Boot.BootResult) -> Bool:
  match result:
    case Boot.BootRejected{reason}: True{}
    case _: False{}

def main() -> Bool:
  +rng: Rng.RngState = Rng.RngState{1, 2, 3, 4}
  +wire: List<&2, U32> = [11, 2, 123, 1, 0, 1024, 0, 0, 0, 1024,
    1, 2, 3, 4, 60, 1, 5]
  Bool.and(success(Wire.boot(Wire.decode_tokens(wire), catalog())),
    Bool.and(failure(Wire.boot(Wire.decode_tokens(
      [11, 2, 123, 1, 1, 0, 0, 0, 0, 1024, 1, 2, 3, 4, 60, 1, 5]), catalog())),
  Bool.and(success(Boot.boot(catalog(), 1n, point(1024, 1024), rng, 123n)),
    Bool.and(failure(Boot.boot(catalog(), 1n, point(4096, 4096), rng, 123n)),
    Bool.and(failure(Boot.boot(catalog(), 2n, point(1024, 1024), rng, 123n)),
    Bool.and(failure(Boot.boot(catalog(), 1n, point(1024, 1024), rng, 124n)),
      failure(Boot.boot(catalog(), 1n, point(1024, 1024),
        Rng.RngState{0, 0, 0, 0}, 123n))))))))

#| True
