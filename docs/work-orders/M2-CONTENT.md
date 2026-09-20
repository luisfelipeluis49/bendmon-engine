# M2 content-kernel work orders

Authorization: owner requested the next implementation part. Architecture authority: Astra; exact shared contract is docs/schemas/CONTENT-0.md. This implements the balance-independent M1/M2 contract; it does not mark all M1 decisions approved or all M0 platform gates complete.

TASK: M2-A pure Bend validator and bounded wire CLI.
OWNER MODEL: GPT-5.6 Sol.
DEPENDENCIES: pinned M0 toolchain and CONTENT-0 contract.
FILES ALLOWED TO CHANGE: engine/content/**, platform/content/kernel.bend, PROOF.bend additions only, tests/content/*.bend.
FILES FORBIDDEN TO CHANGE: LAWS.bend, existing BOOT-1 proof semantics, shell loader/schema contract, gameplay formulas.
GOAL: typed references, pure semantic validation and a native executable boundary.
NON-GOALS: JSON/asset decoding in core, battle/world execution.
ENGINE INVARIANTS AFFECTED: typed refs, levels 1–200, deterministic validation.
LAWS AFFECTED: additive REF-EMPTY supplied by Astra; preserve BOOT-1.
INPUT CONTRACT: exact bounded wire protocol in CONTENT-0; raw core values revalidated.
OUTPUT CONTRACT: OK or stable ERR records; bad wire fails explicitly.
IMPLEMENTATION NOTES: run bend version/guide and read full relevant installed docs before syntax; parallelize independent validation and merge in fixed order.
EDGE CASES: empty catalogs, wrong refs, U32 overflow, counts/tokens/file caps, trailing data, dimension/level bounds.
TESTS REQUIRED: entry checks, native/JS pure fixtures if practical, malformed wire, generated semantic cases, canonical proof gate.
PROOF OBLIGATIONS: REF-EMPTY ties to production helper; no unsafe/foreign proof escape.
ACCEPTANCE CRITERIA: sample passes through actual Bend; invalid refs/levels/dimensions reject; separate Sol review and Astra integration.

TASK: M2-B strict filesystem/JSON shell.
OWNER MODEL: GPT-5.6 Sol.
DEPENDENCIES: frozen CONTENT-0 contract; M2-A executable for integration (can implement independently).
FILES ALLOWED TO CHANGE: platform/content/*.py, scripts/validate_project.py, tests/content/test_loader.py.
FILES FORBIDDEN TO CHANGE: Bend files, laws, schemas/contract, gameplay rules.
GOAL: bounded secure intake and stable diagnostics/content identity.
NON-GOALS: arbitrary scripts, general media codecs, executable caches or remote content.
ENGINE INVARIANTS AFFECTED: no creator code, valid references and exact identities.
LAWS AFFECTED: none; Python is outside formal boundary.
INPUT CONTRACT: only CONTENT-0 fields/paths/media permitted.
OUTPUT CONTRACT: immutable loaded result after native Bend success; JSON CLI errors with stable paths/pointers.
IMPLEMENTATION NOTES: standard library only; no host-side substitute for Bend semantic validation; no dynamic imports/eval from data.
EDGE CASES: duplicate keys/IDs, bad UTF/surrogates, float/bool numbers, path escapes/symlinks/hardlinks, resource limits, missing/hash-mismatched assets, unknown tags, host/kernel failure.
TESTS REQUIRED: valid fixture, parameterized malformed/adversarial cases, canonicalization permutations, deterministic diagnostics, kernel-called assertion, CLI integration.
PROOF OBLIGATIONS: none claimed; runtime boundaries tested.
ACCEPTANCE CRITERIA: malformed content cannot return LoadedProject; sample loads; independent Sol review.

TASK: M2-C original fixture and schema documentation.
OWNER MODEL: GPT-5.6 Luna.
DEPENDENCIES: CONTENT-0 frozen contract.
FILES ALLOWED TO CHANGE: examples/original-demo/**, schemas/content-0/**, docs/schemas/EXAMPLE.md.
FILES FORBIDDEN TO CHANGE: all engine/shell/law/contract files.
GOAL: one original declarative sample with 2 species, 1 map, 1 encounter roster, 1 original PPM sprite; strict JSON Schema documents for authoring hints.
NON-GOALS: gameplay rules/assets from copyrighted franchises, executable content.
ENGINE INVARIANTS AFFECTED: no new mechanics.
LAWS AFFECTED: none.
INPUT CONTRACT: CONTENT-0 only.
OUTPUT CONTRACT: sample files and manifest sizes/digests consistent; schemas reject unknown fields and document semantic validation requirement.
IMPLEMENTATION NOTES: generate tiny original 8x8 P6 pixels mechanically; schemas draft2020-12 with no remote runtime fetch requirement.
EDGE CASES: hash bytes, wrong IDs, schema/implementation drift.
TESTS REQUIRED: JSON syntax/hash/schema review; runtime validation after integration.
PROOF OBLIGATIONS: none.
ACCEPTANCE CRITERIA: Sol reviews fixture/schema, actual loader succeeds.
