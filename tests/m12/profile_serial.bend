import Base
import ./parallel_workload.bend as Fixture
import ./workload_digest.bend as Digest
import ../../engine/world/encounters.bend as Encounters

def main() -> U32:
  entries: List<&2, Encounters.EncounterEntry> =
    Fixture.make_entries(64n, 1n, [])
  +entries_copy = entries
  Digest.run_serial(256n,
    Fixture.make_weighted_jobs(256n, entries_copy, 11, []))
