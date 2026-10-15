# M11 persistence and offline packaging work orders

Status: complete locally. M11 closes the approved D17/U12 save and replay contract
for the M10 creator runtime and ships a verified offline Linux x86-64 package.
The existing M8 snapshot codec remains an exact historical format. M11 does not
reinterpret historical rulesets, admit mid-battle saves, or accept package
content as executable code. `docs/architecture/DETERMINISM.md` and
`docs/DECISIONS.md` remain authoritative for semantics.

## M11-A — durable save envelope, slots and migration

TASK: add a bounded, canonical, integrity-checked stable-world save envelope,
explicit schema migration and crash-safe slot storage.
OWNER MODEL: Luna.
DEPENDENCIES: existing `platform/persistence/world_state.py` and exact content
identity; this work order.
FILES ALLOWED TO CHANGE: new `platform/persistence/m11_save.py`,
`platform/persistence/save_slots.py`, `tests/persistence/test_m11_save.py`,
`tests/persistence/test_save_slots.py`; narrowly necessary existing persistence
codec fixes only after coordinating with integration.
FILES FORBIDDEN TO CHANGE: battle/world transition semantics, maker service/UI,
packaging scripts, replay codec and existing proof laws.

GOAL: typed save records carry schema/build, project/catalog IDs, exact
ruleset/content digest, Wait choice, four RNG words and a canonical payload
digest; strict decode validates every field and full identity before
installation. Provide ten manual slots, one rotating autosave and one verified
previous-version recovery copy per slot. One explicit version-specific legacy
M8 world-schema migration preserves ruleset/content identity; unknown migrations
reject. An atomic same-directory write with file and directory fsync protects
the previous valid save and retains the original until migrated readback passes.
NON-GOALS: mid-battle save, cross-ruleset conversion, cloud sync or anti-cheat.
ENGINE INVARIANTS AFFECTED: exact identity and stable-world installation only.
LAWS AFFECTED: SAVE-ID production obligation; do not weaken or claim a host
SHA-256/filesystem proof.
INPUT CONTRACT: bounded canonical bytes and validated typed stable-world data.
OUTPUT CONTRACT: typed validated save or an offending-field diagnostic; durable
slot bytes after a successful write.
IMPLEMENTATION NOTES: canonical UTF-8 JSON uses `canonical_json`; do not accept
duplicate keys, booleans, floats, unknown fields, invalid path components,
noncanonical bytes or unbounded containers. Migration is an explicit named
transform followed by full revalidation. Keep I/O in `platform/` and allow
named fake I/O injection for interruption tests.
EDGE CASES: same-prefix/different-full digest, corrupt primary with valid or
invalid recovery, failed write at each durability step, missing slot, future
schema, wrong Wait/RNG, active battle/event/pending commit.
TESTS REQUIRED: byte-exact round trip, mismatch, migration, recovery and
interruption tests; no helper-mirroring assertions.
PROOF OBLIGATIONS: native/JS Bend save-boundary fixtures remain canonical; add
production-linked law only if a pure Bend rule changes.
ACCEPTANCE CRITERIA: every decoded record has passed identity, digest, boundary
and shape validation; failed/migrating writes preserve a loadable prior copy.

## M11-B — canonical command replay file

TASK: serialize and verify complete initial state and accepted commands.
OWNER MODEL: Luna.
DEPENDENCIES: `platform/persistence/battle_replay.py`,
`replay_checkpoints.py`, M10 command parser and packaged Bend runner.
FILES ALLOWED TO CHANGE: new `platform/persistence/m11_replay.py`,
`tests/replay/test_m11_replay.py` and narrowly necessary replay tests.
FILES FORBIDDEN TO CHANGE: battle/world transition semantics, save slots,
maker UI/service and packaging scripts.

GOAL: a strict bounded replay file records schema, exact ruleset/full content
digest, RNG revision/four words, immutable game Wait choice, full initial state,
and ordered accepted `(logicalTick, barrierId, commandOrdinal, actorId,
payload)` records. Optional checkpoints every 1024 commands and terminally
supplement, never replace, simulation. A replay runner must resubmit records to
the authoritative Bend runtime and reject any command it does not accept.
NON-GOALS: Python gameplay simulation or inferred timing from render frames.
ENGINE INVARIANTS AFFECTED: accepted-command order and exact replay identity.
LAWS AFFECTED: SAVE-ID and REPLAY-1 obligations, without weakening them.
INPUT CONTRACT: typed accepted commands and bounded canonical bytes.
OUTPUT CONTRACT: validated replay record and deterministic runner result.
IMPLEMENTATION NOTES: reject duplicates, gaps, decreasing tick/barrier order,
oversized files and wrong initial/content/RNG identity. Historical rulesets
remain exact or explicitly unsupported, never silently upgraded.
EDGE CASES: malformed command body, duplicate ordinal, checkpoint tampering,
same compact identity but different full digest, a formerly accepted command
that the current authoritative runner rejects.
TESTS REQUIRED: round trip, mismatch, order, bounds, checkpoint and
authoritative-rejection tests with a named fake runner.
PROOF OBLIGATIONS: Bend runtime/replay fixtures remain the simulation oracle.
ACCEPTANCE CRITERIA: loading never treats an asserted accepted log or digest
as authority without replaying through Bend.

## M11-C — verifiable offline Linux package

TASK: build and verify a bounded, deterministic offline maker distribution.
OWNER MODEL: Luna.
DEPENDENCIES: M10 precompiled Bend/Bun runtime and shipping content loader.
FILES ALLOWED TO CHANGE: new `scripts/package_m11.py`,
`scripts/verify_m11_package.py`, `tests/packaging/test_m11_package.py` and
package launcher assets owned by those scripts.
FILES FORBIDDEN TO CHANGE: gameplay rules, persistence codecs, maker service/UI.

GOAL: emit a Linux x86-64 package containing the prebuilt trusted runtime,
content kernel, Python host modules, browser/renderer assets, validated starter
content, versioned metadata and SHA-256 manifest. Package verification checks
all included files, exact paths/sizes/digests and the Content-0 project hash
before launch, without network, compiler or Bun on the target.
NON-GOALS: Windows/macOS support, unsigned anti-tamper claim or compiling
creator-authored material on the target.
ENGINE INVARIANTS AFFECTED: inert content and full digest binding.
LAWS AFFECTED: none; package hashing and filesystem are trusted host code.
INPUT CONTRACT: trusted build artifacts and a shipping-loader validated project.
OUTPUT CONTRACT: reproducible package directory and an explicit verifier result.
IMPLEMENTATION NOTES: reject symlinks, traversal, duplicate normalized paths,
undeclared files and mismatched bytes; do not rely on absolute checkout paths or
development caches at runtime. Include only approved support target metadata.
EDGE CASES: altered executable, missing asset, swapped same-prefix project,
copy into an empty directory without source checkout, offline invocation.
TESTS REQUIRED: clean-copy launch and playtest, manifest mismatch and path
attack regressions, and compiler/Bun/network-absent target test.
PROOF OBLIGATIONS: no new Bend law unless a pure rule changes.
ACCEPTANCE CRITERIA: a copied package verifies and runs the creator journey on
the supported target without any repository, compiler, Bun or network access.

## M11-D — creator integration and closure

TASK: wire stable-boundary save/load/replay controls into M10 service and browser,
then close M11 with integrated evidence.
OWNER MODEL: Sol integration with independent Luna review.
DEPENDENCIES: M11-A/B/C.
FILES ALLOWED TO CHANGE: `platform/maker/`, `scripts/run_m10_maker.py`,
`scripts/verify.py`, M11 integration tests and M11 architecture/status docs.
FILES FORBIDDEN TO CHANGE: existing gameplay semantics or historical format
meaning.

GOAL: an author/player can save and resume an exact frozen run at a stable world
boundary; manual and permitted autosaves use the specified slot policy; a saved
replay can be exported, loaded and deterministically verified. The browser
explains unavailable save states and exact identity mismatches. Integrate an
offline copied-package journey and complete the repository gate.
NON-GOALS: hidden mid-battle snapshots, permissive migration or public cloud.
ENGINE INVARIANTS AFFECTED: deterministic command order, exact frozen content
identity, event/battle transaction boundary.
LAWS AFFECTED: only additive production-linked SAVE-ID law if implemented in
pure Bend and approved at the exact stated scope.
INPUT CONTRACT: validated M11 save/replay records and existing M10 session.
OUTPUT CONTRACT: resumed session with same accepted commands and scene/state
digest, or clear rejection without changing the live session.
IMPLEMENTATION NOTES: derive save availability from authoritative runtime
status; never trust a browser flag. Verify copied-package behavior outside the
source checkout and include all tests in `python3 scripts/verify.py`.
EDGE CASES: battle, dialogue, pending event, content edit after freezing,
expired session, tampered slot, recovery path, restart between write steps.
TESTS REQUIRED: full save/load, autosave triggers and exclusions, replay,
identity mismatch, migration and clean-install package integration.
PROOF OBLIGATIONS: `./scripts/bend PROOF.bend` before Bend commit; preserve laws.
ACCEPTANCE CRITERIA: M11 PLAN exit evidence passes; independent Luna review has
no unresolved correctness defect; full repository gate passes.

Reviewer and evidence links: record in `docs/architecture/M11-STATUS.md`.
Escalation: Luna → Sol for integration/semantics; Sol → Astra for rule/law
changes. Existing laws must not be weakened.
