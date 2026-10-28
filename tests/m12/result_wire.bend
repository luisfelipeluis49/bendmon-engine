import Base
import ../../engine/performance/parallel_workload.bend as Workload
import ../../engine/world/encounters.bend as Encounters
import ../../engine/battle/rng.bend as Rng

# Bend 2.0.27 (bendlang/bend@63bee70b55a71024d6bdcb49a745111bc54b114e)
# has a JS pure-value printer loop on imported constructor names.
# Compare every field through primitive words instead of that display path;
# this retains ordered IDs, levels and all four post-draw RNG words.
def encode_result(result: Encounters.EntryResult) -> List<&2, U32>:
  match result:
    case Encounters.EntrySelected{id, level, Rng.RngState{a, b, c, d}}:
      [1, U32.from_nat(id), U32.from_nat(level), a, b, c, d]
    case Encounters.EntryRejected{Rng.RngState{a, b, c, d}}:
      [0, a, b, c, d]

def encode_results(results: List<&2, Encounters.EntryResult>) -> List<&2, U32>:
  match results:
    case Nil{}: []
    case result <> rest:
      List.append(&2, U32, encode_result(result), encode_results(rest))

def encode_batch(result: Workload.BatchResult) -> List<&2, U32>:
  match result:
    case Workload.BatchAccepted{results}: 1 <> encode_results(results)
    case Workload.BatchRejected{count}: [0, U32.from_nat(count)]
