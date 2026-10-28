# M12 hardening and optimization status

Status: **complete locally** (2026-10-15). The fresh 604-check repository gate,
canonical Bend proof, all 31 M12 tests, offline package verification and
independent Luna requirement/invariant review passed. Work orders are in
`../work-orders/M12-HARDENING-OPTIMIZATION.md`. M13 is the next milestone.

## Implemented boundaries and corpora

- Content validation now runs its trusted native kernel through a bounded
  nonblocking process adapter. Output flooding, deadlines, setup failures and
  descendants retaining pipes fail closed; tests check child termination.
- Loader and maker diagnostics bound untrusted error fields. Creator JSON has
  lexical nesting/structure budgets before allocation and rejects surrogates,
  duplicate keys and noninteger numbers. Replay decoding normalizes Python's
  oversized-integer failure into its declared codec error. Accepted gameplay
  content, rulesets and historical save/replay meanings are retained.
- Draft reads use the loader's no-follow 1 MiB file boundary. Enumeration stops
  at 8192 filesystem entries or 64 JSON documents; raw and canonical bundles
  each have a 64 MiB ceiling. Tests cover a sparse 128 MiB file, the accepted
  64-document boundary, atomic rejection of document 65 and excess scan entries.
- The generated corpus covers 512 lexical JSON cases (192 accepted with
  canonical round trips, 320 rejected), 512 malformed structured projects,
  128 malformed native wire vectors, 16 fixed adversarial projects, and 128
  mutations each for save and replay (64 rehashed semantic and 64 raw cases).
  Only declared content/codec/infrastructure errors are accepted rejection paths.
- The shipping native kernel accepts a generated project with 256 species,
  59 maps within the total 64-file budget, and 256 NPCs. Catalog, aggregate NPC
  and file-count cap-plus-one cases reject. A separate learning-heavy project
  reaches 4096 level-move references across 256 species and 32 moves.
- A separate 512×512 geometry project has 256 vertices and 254 nonoverlapping
  faces. It loads through the native kernel; excess vertices and width reject.
  The aggregate intake test accepts exactly 8 MiB, then rejects the next byte.
- The schema lock freezes 18 schema identities and cross-checks key limits
  against engine constants. Schemas and the lock now ship in offline packages.
  Compatibility policy is in `../schemas/COMPATIBILITY.md`.

## Load optimization evidence

Profiling found repeated construction of the same finalized move registry
inside recipe and level-up-reference loops. The loader now constructs the
validated ID indexes once and reuses them. Canonical content bytes and digest
remain identical across the baseline and optimized load.

`scripts/benchmark_m12_loading.py` records actual native-kernel-backed load times,
traced allocation peak, cProfile hotspots, source SHA-256 and the exact content
digest. `build/evidence/m12-load-before.json` and `m12-load-after.json` contain
31-run measurements for the 4096-reference project: median load fell from
62.47 ms to 55.97 ms (10.42%) with identical canonical content digest.
`m12-load-comparison.json` records the calculation and both source identities.
`build/m12-loader-before.py`
is the trusted pre-index-reuse source snapshot used by the developer benchmark.
The same snapshot is retained in `build/evidence/m12-loader-before.py`.
Reproduce with:

```sh
python3 scripts/benchmark_m12_loading.py --loader-source build/m12-loader-before.py --label before-index-reuse --repeats 31 --output build/evidence/m12-load-before.json
python3 scripts/benchmark_m12_loading.py --label after-index-reuse --repeats 31 --output build/evidence/m12-load-after.json
```

These are local measurements rather than portable latency guarantees. Timings
are evidence, not pass/fail thresholds; the result identity is a correctness gate.

## Deterministic parallel workload and profiles

`engine/performance/parallel_workload.bend` provides `run_batch` for up to 256
independent encounter jobs, each with its own explicit RNG. Each table is capped
at 256 entries before production encounter selection. Rejected batch counts
saturate at 257, so intake inspects at most 257 jobs. Fewer than eight jobs run
serially; larger accepted batches build a balanced tree of independent parallel
calls. Result order follows input order, not worker completion order.

Exact serial versus parallel result comparisons cover nine and 256 jobs on
native CPU workers 1/2/4, repeated worker runs, and JavaScript. They retain every
selected ID/level and all post-draw RNG words. Edge tests cover empty, singleton,
7/8 threshold, max, 257/1024 rejected jobs and invalid/oversized tables with
unchanged rejection RNG. Three additive production-linked laws prove empty
batch behavior, singleton evaluation and two-leaf branch order. They do not
claim formal proof of host timings or all scheduler implementations.

The pinned Bend 2.0.27 JS pure-value printer loops when imported constructor
names in its display metadata differ from runtime tags. The parity fixtures
project results to primitive words using `tests/m12/result_wire.bend`; all
semantic fields remain in the comparison. The workaround cites pinned upstream
commit `63bee70b55a71024d6bdcb49a745111bc54b114e`.

`scripts/profile_m12.py --output build/evidence/m12-profile.json` measures small,
large and geometry project loads plus small/bulk encounter batches. Repeated
wall timings are separate from cProfile/tracemalloc runs; reported traced memory
excludes native-child allocations. It rejects changed outputs between samples.
Bulk work is 256 jobs × 64 entries × 256 repeats. The five-run local report
`m12-profile-5runs.json` measured 94.07 ms serial and 116.83/106.80/88.29 ms for
the batch route on 1/2/4 workers. Four workers improved this measured workload;
one and two workers incurred overhead. Small measurements are dominated by
process startup and do not establish a universally optimal routing threshold.
The normal gate writes a fresh profile including actual GPU query/capability
evidence. GPU performance is unclaimed where device/toolchain support cannot
be established; CPU-only operation remains supported.

## Independent review and focused evidence

An independent Luna review found and verified fixes for selector-setup cleanup,
raw duplicate-key diagnostic output, and uncapped oversized-batch counting.
The reviewer confirmed the final primitive-wire comparison preserves semantic
coverage and verified the bounded maker reads, traversal and aggregates. The
independent seven-bullet requirement audit found no remaining capability gap.
Actual child-process tests verify
termination after timeout, output failure, inherited pipes and setup failure.
The existing 87-test content suite, 31-test focused package/save/replay/boundary
suite, new parallel checks and canonical Bend proof passed during iteration.
All 31 M12 tests and the focused 25 maker/request tests pass. The copied offline
package verifies all 83 files, including the schema lock and bounded adapters.

The first full M12 gate stopped at the existing M8 encounter JavaScript golden:
Node's default stack overflowed on generated recursive Nat operations. The same
generated program passes with an 8192 KiB stack and exactly matches native
output. The gate now explicitly sets that stack only for this fixture, without
changing its assertions or gameplay rules. The subsequent fresh full gate
passed all 604 checks, including this fixture.

## Completed exit evidence

- `python3 scripts/verify.py`: exit 0, all 604 checks passed in one fresh run;
  `build/evidence/verification.json` and `001.log` through `604.log` retain the
  results. Check 600 ran all 31 M12 tests with ResourceWarning promoted to error.
- `./scripts/bend PROOF.bend`: all terms check; the full gate also ran it.
- `m12-profile.json`: final source SHA-256 identities match current sources.
  Three-run median loads were 3.38 ms small, 34.51 ms large and 17.39 ms geometry.
  Bulk medians were 89.86 ms serial and 112.32/117.42/87.45 ms batch on 1/2/4
  workers, with identical result digests. Local CPU measurements show overhead
  and modest four-worker benefit; they establish no universal speed guarantee.
- GPU benchmarking was unavailable: no nvidia-smi, CUDA toolkit or NVIDIA
  control device was found. No GPU performance or supported-device claim is made.
- `m12-load-current.json`: current loader identity and the 4096-reference content
  digest match the measured before/after evidence; median 52.95 ms over 3 runs.
- Independent Luna audit mapped every original M12 requirement to implementation
  and direct evidence, with no outstanding capability gap or correctness finding.
- `git diff --check`, architecture document links and Python compilation pass.

The seven original requirements are closed: malformed-content fuzzing, actual
performance profiles, large accepted maps/catalogs and cap rejection,
deterministic parallel encounter batches, measured load optimization, bounded
actionable diagnostics and frozen schema identities. Host filesystem/process
safety and timings remain tested boundaries outside Bend's formal guarantee.
Completion covers local implementation and verification on the documented platform.
