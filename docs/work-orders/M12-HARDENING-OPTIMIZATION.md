# M12 hardening and optimization work orders

Status: complete locally (2026-10-15). All four work orders passed their
acceptance criteria, independent Luna audit and the fresh 604-check repository
gate; final evidence is in `../architecture/M12-STATUS.md`.
Scope follows PLAN M12 and the original project request:
malformed-content fuzzing, large maps/catalogs, resource caps, profiling,
deterministic Bend parallel work, measured load optimization, diagnostics and
schema stability. Existing versioned gameplay semantics and content ceilings
remain authoritative. A large accepted project exercises those ceilings;
oversized content must reject before native simulation.

## M12-A — bounded intake and actionable diagnostics

TASK: harden shipping content intake and its trusted native subprocess.
OWNER MODEL: Luna implementation; root integration and independent Luna review.
DEPENDENCIES: M11 content loader and native Content-0 kernel.
FILES ALLOWED TO CHANGE: `platform/content/loader.py`, a focused content-owned
process adapter, and `tests/m12/test_intake_limits.py`.
FILES FORBIDDEN TO CHANGE: gameplay transitions, ruleset versions, proof laws,
published schema meanings and maker replay semantics.

GOAL: resource ceilings apply before unbounded allocation or output capture;
malformed input produces bounded, stable diagnostics identifying location and
expected shape. Native timeout, output overflow and broken protocol fail closed.
NON-GOALS: changing accepted content, arbitrary plugins, network loading.
ENGINE INVARIANTS AFFECTED: inert content, exact digest, bounded host boundary.
LAWS AFFECTED: none; filesystem/process safety remains outside proof scope.
INPUT CONTRACT: bounded project files and one trusted executable path.
OUTPUT CONTRACT: unchanged typed LoadedProject or bounded ContentError /
InfrastructureError; no partial installation.
IMPLEMENTATION NOTES: use named process fakes and actual hostile child-process
tests. Preserve injected runner compatibility used by existing tests. Optimize
only after recording a relevant baseline; coordinate loader ownership with root.
EDGE CASES: duplicate huge keys, malformed numbers/Unicode, depth, byte/file
ceilings, output flooding, timeout, partial output and nonzero exit.
TESTS REQUIRED: actual cap rejection, diagnostic bounds, subprocess overflow /
timeout / protocol behavior and existing content regression suites.
PROOF OBLIGATIONS: preserve canonical proof; no new host-safety proof claim.
ACCEPTANCE CRITERIA: focused and full gates pass; malformed inputs cannot escape
as unexpected exceptions; resource behavior has measured test evidence.
Reviewer and evidence links: `docs/architecture/M12-STATUS.md`.
Escalation: Luna → root for algorithms or compatibility questions.

## M12-B — repeatable hostile corpus, large projects and schema stability

TASK: build deterministic generated corpora and compatibility regression gates.
OWNER MODEL: Luna implementation; independent Luna review.
DEPENDENCIES: shipping Content-0 loader, M11 save/replay codecs and schemas.
FILES ALLOWED TO CHANGE: `scripts/m12_corpus.py`, `tests/m12/__init__.py`,
`tests/m12/test_generated_content.py`, `tests/m12/test_codec_fuzz.py`,
`tests/m12/test_schema_stability.py`, `schemas/compatibility-lock.json`.
FILES FORBIDDEN TO CHANGE: loader/runtime production modules and existing schemas.

GOAL: seeded raw/structured malformed inputs have reproducible rejection or
canonical acceptance, large valid catalogs/maps load through the real native
kernel, and published schema identities cannot drift unnoticed.
NON-GOALS: expanding hard ceilings or treating the schema as semantic authority.
ENGINE INVARIANTS AFFECTED: strict parsing, bounds, identity and closed payloads.
LAWS AFFECTED: none; differential and adversarial tests supplement proof laws.
INPUT CONTRACT: fixed seeds and generated inert projects within current caps.
OUTPUT CONTRACT: bounded self-validating fixtures and a versioned schema lock.
IMPLEMENTATION NOTES: export `write_project(root: Path, scale: str) -> Path`
from `scripts/m12_corpus.py`, with small and large scales for the profiler.
Use the shipping loader and actual kernel on valid large projects; mutate
documents, paths, references, graphs and JSON bytes. Fuzz save/replay decoding
from valid canonical seeds as well as arbitrary bytes. Record case counts.
EDGE CASES: cap versus cap+1, duplicate IDs/keys, dangling references, reordered
records, noncanonical bytes, executable fields, depth and numeric extremes.
TESTS REQUIRED: deterministic generated corpus, large-world/catalog acceptance,
early rejection beyond caps, stable full digest and schema-lock self-validation.
PROOF OBLIGATIONS: preserve all historical format behavior and existing laws.
ACCEPTANCE CRITERIA: generated cases run in the full gate; no unexpected crash,
accepted invalid input or version/digest drift remains unresolved.
Reviewer and evidence links: `docs/architecture/M12-STATUS.md`.
Escalation: Luna → root for schema-contract defects; never silently change them.

## M12-C — profiles and deterministic parallel production work

TASK: benchmark representative load paths and pure Bend batch workloads.
OWNER MODEL: Luna implementation; root measures and integrates optimization.
DEPENDENCIES: pinned Bend guide, production encounter/RNG rules and M12-B corpus.
FILES ALLOWED TO CHANGE: `engine/performance/`, `platform/performance/`,
`scripts/profile_m12.py`, `tests/m12/test_parallel_workload.py`, and focused
Bend fixtures under `tests/m12/`.
FILES FORBIDDEN TO CHANGE: production encounter/RNG semantics, global RNG order,
loader and schemas, existing proof laws and verification orchestration.

GOAL: profiles expose time and allocation hotspots, and balanced independent
simulation/encounter batches use Bend parallel calls with exact deterministic
results across one/multiple CPU workers and JavaScript. Measure serial versus
parallel overhead and retain a serial path for small workloads.
NON-GOALS: parallelizing conflicting battle transitions or requiring a GPU.
ENGINE INVARIANTS AFFECTED: explicit per-job RNG/state and canonical job order.
LAWS AFFECTED: existing RNG/encounter laws remain unchanged; add a law only if it
protects production behavior at its actual formal boundary.
INPUT CONTRACT: bounded independent jobs with explicit seeds; validated projects.
OUTPUT CONTRACT: typed per-job results and reproducible machine-readable timing,
memory, result digests, worker counts and hardware/toolchain metadata.
IMPLEMENTATION NOTES: read the pinned shader/parallel guide. Invoke production
encounter or simulation rules rather than a synthetic arithmetic-only workload.
Expose a reusable batch API outside tests. Profile source and generated large
projects with cProfile/tracemalloc. Check GPU support and benchmark only when
actually available; record a reason when unsupported, never fabricate a speedup.
EDGE CASES: zero/one/max jobs, uneven partitions, invalid jobs and seed isolation.
TESTS REQUIRED: serial/parallel exact ordered output equality, repeated runs,
native CPU workers 1/2/4 and JavaScript parity; bounded input rejection.
PROOF OBLIGATIONS: canonical proof and any new pure-module checks pass.
ACCEPTANCE CRITERIA: actual measured profiles and CPU comparisons exist; suitable
work is parallel; unsupported GPU capability is explicit; no gameplay drift.
Reviewer and evidence links: `docs/architecture/M12-STATUS.md`.
Escalation: Luna → root for representation/performance/compiler issues.

## M12-D — integration and milestone closure

TASK: integrate resource/fuzz/performance gates and make one measured load-path
improvement; publish reproducible evidence and audit all M12 requirements.
OWNER MODEL: root integration; independent Luna invariant review.
DEPENDENCIES: M12-A/B/C.
FILES ALLOWED TO CHANGE: `scripts/verify.py`, `scripts/validate_project.py`,
`scripts/benchmark_m12_loading.py`,
`scripts/package_m11.py` if an adapter must ship, architecture/status documents,
PLAN and narrow integration tests. Loader edits coordinated with M12-A.
FILES FORBIDDEN TO CHANGE: established gameplay semantics and proof-law meanings.
GOAL: all M12 capabilities ship coherently and are independently verified.
NON-GOALS: M13 demo content or claims about untested release platforms.
ENGINE INVARIANTS AFFECTED: all boundaries above; deterministic identity retained.
LAWS AFFECTED: preserve existing production-linked laws without weakening.
INPUT CONTRACT: completed components and current repository sources.
OUTPUT CONTRACT: full gate, canonical proof, measured before/after load evidence,
bounded structured load diagnostics, documented schema policy and status report.
IMPLEMENTATION NOTES: evidence records exact environment and local scope;
performance timings are measurements, not brittle pass/fail speed thresholds.
EDGE CASES: clean package import, stale binaries, malformed profiler options.
TESTS REQUIRED: component suites, package regression, full repository gate,
canonical Bend proof and independent final Luna review.
PROOF OBLIGATIONS: `./scripts/bend PROOF.bend`; no unsupported formal claims.
ACCEPTANCE CRITERIA: every original M12 item has direct evidence and no unresolved
correctness defect; only then mark M12 complete in PLAN and status.
Reviewer and evidence links: `docs/architecture/M12-STATUS.md`.
Escalation: Luna → root; explicit owner approval for any law semantic change.
