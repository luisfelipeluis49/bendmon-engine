# Original proposed first implementation work order

Historical planning order: technical installation and initial bootstrap implementation were subsequently authorized by the owner. See M0-IMPLEMENTATION.md and M0-CI.md for executed scopes.

TASK: M0-A — establish Bend 2 feasibility without game mechanics.
OWNER MODEL: GPT-5.6 Sol; GPT-6 Astra specifies/reviews; Luna may receive a separate bounded CI/docs order after commands are known.
DEPENDENCIES: D18 owner identification/selection of compiler revision; writable real checkout; this architecture package reviewed. Toolchain installation plan must be reviewable; do not guess an older Bend release.
FILES ALLOWED TO CHANGE: after implementation authorization, README.md, docs/architecture/FEASIBILITY.md, tests/feasibility/**, platform/feasibility/**, scripts/verify.*, pinned toolchain metadata, .github/workflows/verify.*. LAWS.bend only for an explicitly human-approved bootstrap law; PROOF.bend implements that approved law.
FILES FORBIDDEN TO CHANGE: AGENTS.md, unrelated user files, existing law semantics, game-rule source, public content schemas, docs/DECISIONS.md approval status without owner input, supplied read-only .git/.agents/.codex metadata.

GOAL: demonstrate documented compilation/proof and a headless/presentation boundary on one CPU baseline; publish actual target evidence.

NON-GOALS: combat, content kernel, final renderer/editor, game-rule constants, declaring all platforms supported.

ENGINE INVARIANTS AFFECTED: purity boundary and proof gate only; no gameplay law adopted implicitly.

LAWS AFFECTED: one human-approved trivial non-gameplay bootstrap law; no claim to satisfy LAW_CATALOG yet.

INPUT CONTRACT: exact trusted Bend 2 revision; installed documentation available; fixtures contain no untrusted executable content.

OUTPUT CONTRACT: version/revision record, reproducible build/check instructions, positive and intentionally failing proof fixtures, headless executable, tested host value conversion, minimal sprite/depth/audio spike, target matrix with failures recorded.

IMPLEMENTATION NOTES: run bend --version then bend guide; read complete relevant installed guides and Base definitions before writing Bend. Inspect any existing source. Use compiler-authoritative syntax only. Evaluate narrow native/JS or IPC adapters without locking final presentation stack. Keep all host code developer-owned. Use CPU baseline before GPU. Do not represent merely normalizing a pure main as testing a compiled binary.

EDGE CASES: wrong Bend generation, incomplete install, open/false law accepted, unsafe proof dependency, integer overflow, array index wrapping, foreign invalid values, absent GPU/audio/display, unsupported browser target, interrupted IO, package requiring compiler at launch.

TESTS REQUIRED: exact documented check/build commands; canonical bend PROOF.bend locally and CI; negative fixture must fail; repeated headless fixture output; host boundary round trip; installed-binary run without compiler; visual/audio evidence or explicit failed gate.

PROOF OBLIGATIONS: bootstrap theorem attached to production-import structure; no unsafe axiom or skipped law; no broad correctness claim.

ACCEPTANCE CRITERIA: all required gates pass on declared baseline; graphics/audio/FFI strategy has measured feasibility; separate Sol reviewer inspects implementation and Astra reviews architectural evidence. Failure means M0 remains incomplete and requires revised work order, not a weaker proof or speculative support claim.
