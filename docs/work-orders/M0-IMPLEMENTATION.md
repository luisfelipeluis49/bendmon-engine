# M0 implementation orders

Authorization: owner requested implementation after the planning package. Technical toolchain selection and initial non-gameplay bootstrap laws are within that request. Existing gameplay decisions remain open until answered; this work adds no balance formulas. These orders supersede M0-A's requirement for the owner to manually select a compiler revision.

## M0-A Toolchain

TASK: establish reproducible workspace-local Bend 2.
OWNER MODEL: GPT-5.6 Sol.
DEPENDENCIES: upstream source inspection; workspace permissions.
FILES ALLOWED TO CHANGE: .toolchain/**, scripts/bend, toolchain.lock.json, docs/architecture/toolchain-evidence.md.
FILES FORBIDDEN TO CHANGE: LAWS.bend, PROOF.bend, game schemas and mechanics, global toolchain directories.
GOAL: pin official Bend 2 commit and run its CLI locally without a global install.
NON-GOALS: gameplay, code generation from community content.
ENGINE INVARIANTS AFFECTED: reproducibility; no game mechanics.
LAWS AFFECTED: none.
INPUT CONTRACT: trusted upstream source pinned by commit, inspected installer/dependencies.
OUTPUT CONTRACT: usable scripts/bend, lock metadata, command/guide evidence.
IMPLEMENTATION NOTES: no pipe-to-shell installers; use installed runtime or pinned local dependency.
EDGE CASES: wrong Bend generation, unsupported host runtime, restricted network.
TESTS REQUIRED: version, guide, help; source revision matches lock.
PROOF OBLIGATIONS: none for installer.
ACCEPTANCE CRITERIA: local CLI usable, no global changes; report limitations honestly.

## M0-B Pure headless boundary

TASK: implement a minimal command-to-state headless feasibility executable.
OWNER MODEL: GPT-5.6 Sol; Astra defines the law and interface.
DEPENDENCIES: M0-A; complete installed guide and relevant Base docs read before Bend code.
FILES ALLOWED TO CHANGE: engine/core/bootstrap.bend, platform/feasibility/headless.bend, PROOF.bend, tests/feasibility/*.bend.
FILES FORBIDDEN TO CHANGE: LAWS.bend (Astra owns initial statements), content schemas, game mechanics/constants.
GOAL: demonstrate pure deterministic state transition and compiled shell, with universal bootstrap proof.
NON-GOALS: scheduler, game clock pacing, damage, RPG gameplay; the accumulator is a toolchain probe only.
ENGINE INVARIANTS AFFECTED: pure state and explicit inputs.
LAWS AFFECTED: BOOT-1, zero-delta transition preserves accumulator state; pure function in production bootstrap module, not a duplicate theorem-only implementation.
INPUT CONTRACT: conceptual state is a natural-number accumulator; Add command contains a natural delta. CLI accepts bounded unsigned decimal inputs as developer test commands, rejects malformed input with nonzero exit, and never executes input.
OUTPUT CONTRACT: canonical single-line decimal total; no inputs yields 0; tests can compare native/JS/direct behavior. Expected ordinary invocation documented after actual runtime argument handling is inspected.
IMPLEMENTATION NOTES: transition(state, delta) computes natural addition; fold input in a terminating traversal. Independent fixture workloads should use Bend parallel calls where practical. Keep CLI conversion/IO outside pure module. No user-project parsing in this probe.
EDGE CASES: empty input, zero, multiple deltas, malformed integer, negative, oversized value, sum larger than U32 (either exact Nat output or explicit checked error, never wrap).
TESTS REQUIRED: changed entry points check, native executable round-trip, repeated inputs, negative inputs, supported JS comparison, deliberately false/open law fixtures rejected.
PROOF OBLIGATIONS: BOOT-1 proof for all Nat states and actual transition. No unsafe axioms/recursion.
ACCEPTANCE CRITERIA: canonical bend PROOF.bend passes, meaningful CLI tests pass, independent Sol review, Astra final review.

## M0-C Presentation boundary

TASK: demonstrate an original sprite/depth projection and generated audio through a developer-owned host shell.
OWNER MODEL: GPT-5.6 Sol.
DEPENDENCIES: M0-A; installed IO/host guidance read.
FILES ALLOWED TO CHANGE: platform/feasibility/presentation/**, tests/feasibility/presentation/**.
FILES FORBIDDEN TO CHANGE: all gameplay modules/laws/decisions.
GOAL: verify snapshot-to-presentation integration and document native dependencies or a measured fallback.
NON-GOALS: final renderer/editor or gameplay callbacks driven by animation.
ENGINE INVARIANTS AFFECTED: presentation cannot mutate simulation or supply executable content.
LAWS AFFECTED: none; host behavior is tested, not proved.
INPUT CONTRACT: bounded developer-owned typed snapshot; incoming host values checked before core entry.
OUTPUT CONTRACT: repeatable original sprite/depth frame and short tone with actual integration evidence; unavailable live window/audio recorded separately.
IMPLEMENTATION NOTES: choose host based on measured toolchain support; trusted C/JS adapter allowed. No downloaded assets, no pack callbacks, no arbitrary paths/symbols.
EDGE CASES: missing audio headers, no display, invalid foreign shapes, snapshot mutation.
TESTS REQUIRED: projection state preservation, input rejection, visual/artifact inspection, audio/ABI evidence or explicit blocked gate.
PROOF OBLIGATIONS: none outside core.
ACCEPTANCE CRITERIA: demonstrated boundary; limitations listed rather than waived.

## M0-D Integration and verification

TASK: integrate the implemented M0 slices and report their actual boundaries.
OWNER MODEL: Astra integration/specification; Sol independent review; Luna CI/docs with Sol review.
DEPENDENCIES: M0-A/B/C implementations; owner implementation authorization.
FILES ALLOWED TO CHANGE: initial LAWS.bend bootstrap claim, scripts/verify.py, README.md, PLAN.md, docs/LAW_CATALOG.md, docs/architecture/**, docs/work-orders/**, owner-approved decision status in docs/DECISIONS.md.
FILES FORBIDDEN TO CHANGE: existing law semantics, unapproved gameplay formulas, AGENTS.md, protected metadata.
GOAL: one reproducible local verification command, initial mathematical law adoption, accurate status/docs and review evidence.
NON-GOALS: claiming all M0 exit criteria or later engine milestones are complete.
ENGINE INVARIANTS AFFECTED: proof boundary, no hidden state in bootstrap transition, toolchain reproducibility.
LAWS AFFECTED: initial BOOT-1 only; no previous law modified.
INPUT CONTRACT: locked compiler plus Sol implementation files and inert developer fixtures.
OUTPUT CONTRACT: build artifacts/evidence, canonical proof gate and negative fixtures, native/JS generated cases, explicit presentation and distribution limits.
IMPLEMENTATION NOTES: invoke subprocesses with argument arrays, never execute fixture input as commands; use bounded generated cases and explicit failure codes.
EDGE CASES: false/open law mistakenly succeeds, thread-count differences, host rejection, CLI bounds, unsupported platform.
TESTS REQUIRED: full verify.py run, document-link checks, Python compilation, independent Sol review of code and Luna documentation.
PROOF OBLIGATIONS: BOOT-1 only; native and foreign tests do not widen formal scope.
ACCEPTANCE CRITERIA: verification passes after review fixes; status distinguishes local evidence from unrun remote CI/live-device checks.
