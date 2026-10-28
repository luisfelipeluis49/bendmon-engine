import Base
import ../../engine/performance/parallel_workload.bend as Workload
import ../../engine/world/encounters.bend as Encounters
import ../../engine/battle/rng.bend as Rng

def hash_word(digest: U32, word: U32) -> U32:
  U32.xor(U32.mul(digest, 16777619), word)

def digest_result(result: Encounters.EntryResult, digest: U32) -> U32:
  match result:
    case Encounters.EntrySelected{id, level, Rng.RngState{a, b, c, d}}:
      h1 = hash_word(digest, U32.from_nat(id))
      h2 = hash_word(h1, U32.from_nat(level))
      h3 = hash_word(h2, a)
      h4 = hash_word(h3, b)
      h5 = hash_word(h4, c)
      hash_word(h5, d)
    case Encounters.EntryRejected{Rng.RngState{a, b, c, d}}:
      h1 = hash_word(digest, 4294967295)
      h2 = hash_word(h1, a)
      h3 = hash_word(h2, b)
      h4 = hash_word(h3, c)
      hash_word(h4, d)

def digest_results(results: List<&2, Encounters.EntryResult>,
  +digest: U32) -> U32:
  match results:
    case Nil{}: digest
    case result <> rest:
      digest_results(rest, digest_result(result, digest))

def digest_batch(result: Workload.BatchResult, digest: U32) -> U32:
  match result:
    case Workload.BatchAccepted{results}: digest_results(results, digest)
    case Workload.BatchRejected{count}: hash_word(digest, U32.from_nat(count))

def serial_repeats(repeats: Nat, +jobs: List<&2, Workload.EncounterJob>,
  +digest: U32) -> U32:
  match repeats:
    case 0n: digest
    case 1n+rest:
      serial_repeats(rest, jobs,
        digest_results(Workload.serial(jobs), digest))

def parallel_repeats(repeats: Nat, +jobs: List<&2, Workload.EncounterJob>,
  +digest: U32) -> U32:
  match repeats:
    case 0n: digest
    case 1n+rest:
      parallel_repeats(rest, jobs,
        digest_batch(Workload.run_batch(jobs), digest))

def run_serial(repeats: Nat, jobs: List<&2, Workload.EncounterJob>) -> U32:
  serial_repeats(repeats, jobs, 2166136261)

def run_parallel(repeats: Nat, jobs: List<&2, Workload.EncounterJob>) -> U32:
  parallel_repeats(repeats, jobs, 2166136261)
