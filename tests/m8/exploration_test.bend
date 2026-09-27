import Base
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng

def nav() -> Geometry.NavSurface:
  Geometry.NavSurface{
    [Geometry.Vertex{Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
     Geometry.Vertex{Geometry.Coord{False{}, 200000},
      Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}},
     Geometry.Vertex{Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 200000}}],
    [Geometry.Triangle{0, 1, 2}], []}

def world() -> Catalog.Catalog:
  Catalog.Catalog{8n, 123n,
    [Catalog.WorldMap{1n, nav(),
      [Catalog.EncounterRegion{1n, 9n, [0]}], [], [], []}], []}

def start() -> Geometry.Point:
  Geometry.Point{Geometry.Coord{False{}, 1000},
    Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 1000}}

def direction() -> Geometry.Input:
  Geometry.Input{Geometry.Coord{False{}, 1024},
    Geometry.Coord{False{}, 0}, False{}, False{}}

def opened(result: Exploration.OpenResult) -> Bool:
  match result:
    case Exploration.Opened{Exploration.State{1n, point,
        Encounters.Meter{Some{1n}, 0n, threshold, 0n,
          Rng.RngState{7, 0, 1026, 12288}}, None{}, 123n}}:
      Nat.is_eq(threshold, 144384n)
    case _: False{}

def moved(result: Exploration.StepResult) -> Bool:
  match result:
    case Exploration.Moved{Exploration.State{1n, point,
        Encounters.Meter{Some{1n}, weighted, threshold, 0n, rng},
        None{}, 123n}}:
      Bool.and(Nat.is_gt(weighted, 0n),
        Nat.is_eq(threshold, 98304n))
    case _: False{}

def triggered(result: Exploration.StepResult) -> Bool:
  match result:
    case Exploration.EncounterReached{
        Exploration.State{1n, point, meter,
          Some{Exploration.PendingEncounter{1n, 9n}}, 123n}, 9n}:
      True{}
    case _: False{}

def rejected(result: Exploration.OpenResult) -> Bool:
  match result:
    case Exploration.OpenRejected{}: True{}
    case _: False{}

def near_threshold() -> Exploration.State:
  Exploration.State{1n, start(),
    Encounters.Meter{Some{1n}, 98300n, 98304n, 0n,
      Rng.RngState{1, 2, 3, 4}}, None{}, 123n}

def main() -> List<&2, Bool>:
  [opened(Exploration.open(world(), 1n, start(),
     Rng.RngState{1, 2, 3, 4}, 123n)),
   moved(Exploration.move(world(),
     Exploration.State{1n, start(),
       Encounters.Meter{Some{1n}, 0n, 98304n, 0n,
         Rng.RngState{1, 2, 3, 4}}, None{}, 123n}, direction())),
   triggered(Exploration.move(world(), near_threshold(), direction())),
   rejected(Exploration.open(world(), 1n, start(),
     Rng.RngState{1, 2, 3, 4}, 124n))]
