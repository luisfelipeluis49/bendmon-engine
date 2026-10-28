import Base
import ../../engine/performance/parallel_workload.bend as Workload
import ../../engine/world/encounters.bend as Encounters
import ../../engine/battle/rng.bend as Rng
import ./result_wire.bend as Wire

def make_jobs(count: Nat, +seed: U32,
  acc: List<&2, Workload.EncounterJob>) -> List<&2, Workload.EncounterJob>:
  match count:
    case 0n: acc
    case 1n+rest:
      entry: Encounters.EncounterEntry = Encounters.EncounterEntry{7n, 3n, 5n, 8n}
      job: Workload.EncounterJob = Workload.EncounterJob{[entry],
        Rng.RngState{seed, 1, 2, 3}}
      make_jobs(rest, (seed + 1 : U32), job <> acc)

def make_entries(count: Nat, +id: Nat,
  acc: List<&2, Encounters.EncounterEntry>) ->
  List<&2, Encounters.EncounterEntry>:
  match count:
    case 0n: acc
    case 1n+rest:
      entry: Encounters.EncounterEntry = Encounters.EncounterEntry{id, 1n, 5n, 8n}
      make_entries(rest, Nat.add(id, 1n), entry <> acc)

def make_weighted_jobs(count: Nat,
  +entries: List<&2, Encounters.EncounterEntry>, +seed: U32,
  acc: List<&2, Workload.EncounterJob>) -> List<&2, Workload.EncounterJob>:
  match count:
    case 0n: acc
    case 1n+rest:
      job: Workload.EncounterJob = Workload.EncounterJob{entries,
        Rng.RngState{seed, 1, 2, 3}}
      make_weighted_jobs(rest, entries, (seed + 1 : U32), job <> acc)

def main() -> List<&2, U32>:
  Wire.encode_batch(Workload.run_batch(make_jobs(9n, 11, [])))
