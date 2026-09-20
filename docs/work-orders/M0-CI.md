# M0-CI — reproducible verification boundary

TASK: document and automate the M0 local and Ubuntu CI verification boundary.
OWNER MODEL: Codex implementation agent; parent agent reviews the resulting
workspace state.
DEPENDENCIES: pinned Bend release in `toolchain.lock.json`; `scripts/setup_toolchain.py`;
`scripts/verify.py`.
FILES ALLOWED TO CHANGE: `.github/workflows/verify.yml`, `.gitignore`,
`docs/BUILD.md`, and this work order.
FILES FORBIDDEN TO CHANGE: Bend engine sources, `LAWS.bend`, `PROOF.bend`,
public schemas, and gameplay mechanics.
GOAL: provide a repeatable Python/clang/Node 20 verification command on
Ubuntu 24.04 CPU and preserve generated evidence as a CI artifact.
NON-GOALS: claiming a hosted CI run, GPU support, live window output, or live
audio playback.
ENGINE INVARIANTS AFFECTED: none; this order only describes and invokes the
existing verification boundary.
LAWS AFFECTED: none.
INPUT CONTRACT: a clean checkout, Python 3, clang, and Node.js 20; the pinned
workspace toolchain is installed by the bootstrap script.
OUTPUT CONTRACT: verifier exit status plus `build/evidence/verification.json`,
logs, and generated presentation artifacts when the relevant checks pass.
IMPLEMENTATION NOTES: CI runs on `ubuntu-24.04`, installs clang, selects Node
20 with `actions/setup-node@v4`, bootstraps the local Bend release, and uploads
`build/evidence/` with `if: always()`.
EDGE CASES: absent network during bootstrap, compiler installation failure,
missing Node runtime, or unavailable display/audio device; the verifier records
the evidence boundary and does not turn file generation into a live-device claim.
TESTS REQUIRED: inspect the workflow YAML and run the documented local
commands; the parent verification run supplies the authoritative check results.
PROOF OBLIGATIONS: none beyond the existing canonical `bend PROOF.bend` gate.
ACCEPTANCE CRITERIA: build instructions identify the exact native entry path,
the compiler-free runtime path, CPU-only scope, and evidence limitations; CI
contains the pinned platform and Node 20 setup and uploads evidence.
