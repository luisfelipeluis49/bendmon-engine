import Base
import ../world/encounters.bend as Encounters
import ../battle/rng.bend as Rng

# Bounded independent encounter draws. `run_batch` is the validated public path;
# it preserves input order and each job's explicit RNG state.
type EncounterJob is Data:
  EncounterJob{entries: List<&2, Encounters.EncounterEntry>, rng: Rng.RngState}

type JobTree is Data:
  JobEmpty{}
  JobLeaf{job: EncounterJob}
  JobBranch{left: JobTree, right: JobTree}

type BatchResult is Data:
  BatchAccepted{results: List<&2, Encounters.EntryResult>}
  BatchRejected{count: Nat}

def jobs_count_capped(fuel: Nat, jobs: List<&2, EncounterJob>) -> Nat:
  match fuel:
    case 0n: 257n
    case 1n+remaining:
      match jobs:
        case Nil{}: 0n
        case _ <> rest:
          Nat.min(257n, Nat.add(1n, jobs_count_capped(remaining, rest)))

# Rejected counts saturate at 257: inspection must not traverse an arbitrarily
# long caller-owned list merely to establish that the batch exceeds its cap.
def jobs_count(jobs: List<&2, EncounterJob>) -> Nat:
  jobs_count_capped(257n, jobs)

def entry_count_capped(fuel: Nat,
  entries: List<&2, Encounters.EncounterEntry>) -> Nat:
  match fuel:
    case 0n: 257n
    case 1n+rest:
      match entries:
        case Nil{}: 0n
        case _ <> tail: Nat.add(1n, entry_count_capped(rest, tail))

def evaluate_job_valid(valid: Bool, +job: EncounterJob) -> Encounters.EntryResult:
  match valid:
    case False{}:
      match job:
        case EncounterJob{entries, rng}: Encounters.EntryRejected{rng}
    case True{}:
      match job:
        case EncounterJob{entries, rng}: Encounters.choose(entries, rng)

def evaluate_job(+job: EncounterJob) -> Encounters.EntryResult:
  match job:
    case EncounterJob{+entries, rng}:
      evaluate_job_valid(Nat.is_le(entry_count_capped(257n, entries), 256n), job)

def job_leaves(jobs: List<&2, EncounterJob>) -> List<&2, JobTree>:
  match jobs:
    case Nil{}: []
    case job <> rest: JobLeaf{job} <> job_leaves(rest)

def pair_level(trees: List<&2, JobTree>) -> List<&2, JobTree>:
  match trees:
    case Nil{}: []
    case tree <> Nil{}: [tree]
    case left <> right <> rest:
      JobBranch{left, right} <> pair_level(rest)

def pair_levels(depth: Nat, trees: List<&2, JobTree>) -> List<&2, JobTree>:
  match depth:
    case 0n: trees
    case 1n+rest: pair_levels(rest, pair_level(trees))

def finish_tree(trees: List<&2, JobTree>) -> JobTree:
  match trees:
    case tree <> Nil{}: tree
    case Nil{}: JobEmpty{}
    case _: JobEmpty{}

def append_results(left: List<&2, Encounters.EntryResult>,
  right: List<&2, Encounters.EntryResult>) -> List<&2, Encounters.EntryResult>:
  match left:
    case Nil{}: right
    case first <> rest: first <> append_results(rest, right)

def serial(jobs: List<&2, EncounterJob>) -> List<&2, Encounters.EntryResult>:
  match jobs:
    case Nil{}: []
    case job <> rest:
      evaluate_job(job) <> serial(rest)

def run_tree(tree: JobTree) -> List<&2, Encounters.EntryResult>:
  match tree:
    case JobEmpty{}: []
    case JobLeaf{job}: [evaluate_job(job)]
    case JobBranch{left, right}:
      left_results right_results = run_tree(left) run_tree(right)
      append_results(left_results, right_results)

# The caller caps jobs at 256; eight pair-reduction rounds produce one balanced
# tree. The <8 route stays serial to avoid task overhead on short batches.
def parallel_tree_unchecked(jobs: List<&2, EncounterJob>) -> List<&2, Encounters.EntryResult>:
  run_tree(finish_tree(pair_levels(8n, job_leaves(jobs))))

def batch_route(small: Bool, +jobs: List<&2, EncounterJob>, +count: Nat) -> BatchResult:
  match small:
    case True{}: BatchAccepted{serial(jobs)}
    case False{}: BatchAccepted{parallel_tree_unchecked(jobs)}

def batch_checked(valid: Bool, +jobs: List<&2, EncounterJob>, +count: Nat) -> BatchResult:
  match valid:
    case False{}: BatchRejected{count}
    case True{}: batch_route(Nat.is_lt(count, 8n), jobs, count)

# Example: run_batch([EncounterJob{table, RngState{a, b, c, d}}]).
def run_batch(+jobs: List<&2, EncounterJob>) -> BatchResult:
  +count = jobs_count(jobs)
  batch_checked(Nat.is_le(count, 256n), jobs, count)
