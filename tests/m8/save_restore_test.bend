import Base
import ./save_boundary_test.bend as Fixture
import ../../engine/world/save_boundary.bend as Save
import ../../engine/world/events.bend as Events
import ../../engine/battle/rng.bend as Rng

def normal() -> Save.Snapshot:
  Save.Snapshot{123n, 1n, Fixture.point(), Some{1n}, 24n, 98304n, 0n,
    Rng.RngState{1, 2, 3, 4}, [], []}

def wrong_identity() -> Save.Snapshot:
  Save.Snapshot{999n, 1n, Fixture.point(), Some{1n}, 24n, 98304n, 0n,
    Rng.RngState{1, 2, 3, 4}, [], []}

def main() -> List<&2, Bool>:
  [Fixture.restore_ok(Save.restore(Fixture.catalog(), normal())),
   Fixture.restore_rejected(Save.restore(Fixture.catalog(),
     wrong_identity()))]
