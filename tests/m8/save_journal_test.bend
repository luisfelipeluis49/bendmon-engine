import Base
import ./save_boundary_test.bend as Fixture
import ../../engine/world/save_boundary.bend as Save
import ../../engine/world/events.bend as Events
import ../../engine/battle/rng.bend as Rng

def main() -> List<&2, Bool>:
  [Fixture.journal_preserved(Save.restore(Fixture.catalog(),
    Save.Snapshot{123n, 1n, Fixture.point(), Some{1n}, 24n,
      98304n, 0n, Rng.RngState{1, 2, 3, 4},
      [Events.Value{7n, 1n}, Events.Value{7n, 0n}], [8n, 8n]}))]
