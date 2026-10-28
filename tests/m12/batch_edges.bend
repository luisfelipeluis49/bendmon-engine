import Base
import ../../engine/performance/parallel_workload.bend as Workload
import ../../engine/world/encounters.bend as Encounters
import ../../engine/battle/rng.bend as Rng
import ./parallel_workload.bend as Fixture

def accepted_size(result: Workload.BatchResult, expected: Nat) -> Bool:
  match result:
    case Workload.BatchAccepted{results}:
      Nat.is_eq(List.length(&2, Encounters.EntryResult, results), expected)
    case _: False{}

def rejected_count(result: Workload.BatchResult, expected: Nat) -> Bool:
  match result:
    case Workload.BatchRejected{count}: Nat.is_eq(count, expected)
    case _: False{}

def invalid_entry_is_rejected(result: Workload.BatchResult) -> Bool:
  match result:
    case Workload.BatchAccepted{
        Encounters.EntryRejected{Rng.RngState{1, 2, 3, 4}} <> Nil{}}: True{}
    case _: False{}

def oversized_entry_is_rejected(result: Workload.BatchResult) -> Bool:
  match result:
    case Workload.BatchAccepted{
        Encounters.EntryRejected{Rng.RngState{1, 2, 3, 4}} <> Nil{}}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  one_entry: Encounters.EncounterEntry = Encounters.EncounterEntry{7n, 1n, 2n, 2n}
  invalid_entry: Encounters.EncounterEntry = Encounters.EncounterEntry{7n, 0n, 2n, 2n}
  one_job: Workload.EncounterJob = Workload.EncounterJob{[one_entry], Rng.RngState{1, 2, 3, 4}}
  invalid_job: Workload.EncounterJob = Workload.EncounterJob{[invalid_entry], Rng.RngState{1, 2, 3, 4}}
  [accepted_size(Workload.run_batch([]), 0n),
   accepted_size(Workload.run_batch([one_job]), 1n),
   accepted_size(Workload.run_batch(Fixture.make_jobs(9n, 10, [])), 9n),
   accepted_size(Workload.run_batch(Fixture.make_jobs(256n, 10, [])), 256n),
   rejected_count(Workload.run_batch(Fixture.make_jobs(257n, 10, [])), 257n),
   rejected_count(Workload.run_batch(Fixture.make_jobs(1024n, 10, [])), 257n),
   accepted_size(Workload.run_batch(Fixture.make_jobs(7n, 10, [])), 7n),
   accepted_size(Workload.run_batch(Fixture.make_jobs(8n, 10, [])), 8n),
   invalid_entry_is_rejected(Workload.run_batch([invalid_job])),
   oversized_entry_is_rejected(Workload.run_batch([
     Workload.EncounterJob{Fixture.make_entries(257n, 1n, []),
       Rng.RngState{1, 2, 3, 4}}]))]
