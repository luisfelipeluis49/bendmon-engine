# M11 persistence and packaging status

Status: **complete locally** as of 2026-10-15. Save, replay, package and maker
workflows passed the 600-check repository gate, canonical Bend proof, independent
Luna correctness review and source/copied-package browser journeys. These are
local verification results; hosted CI evidence is tracked separately.

## Implemented components

- M11-A adds bounded canonical save schema 4, exact `m8-1`/full-digest/project/
  catalog validation, the explicit M8 schema-1 migration, and local ten-slot,
  autosave and recovery storage with staged readback and atomic replacement.
- M11-B adds bounded replay schema 1, command-order and checkpoint validation,
  authoritative replay verification, and the M10 session command adapter.
  M10's current runtime response has no state digest, so its adapter rejects
  replay files that carry checkpoints.
- The M10 Bend runtime now projects a typed stable-world save only at a safe
  world boundary. MakerService wires manual saves, automatic stable-boundary
  saves, exact replay-based loads and replay export/verification. The browser
  exposes manual slot selection, save/load, replay download and replay import.
- M11 saves and replays can carry an optional `restoreWorld` anchor. Explicit
  M8 schema-1 migration records the legacy world as this anchor so subsequent
  command replay can resume from the progressed state. The host emits the
  versioned Bend restore row before command execution. The service migration
  test now proves restore, continued command execution, resave/reload and replay
  verification against the compiled native Bend runtime. The restore-and-continue
  fixture also passes with matching native and JavaScript output.
- M11-C packages the prebuilt M10 runtime, Content-0 kernel, Python host,
  browser/renderer assets and validated starter for Linux x86-64. The verifier
  checks the exact file set, sizes, modes, SHA-256 values and the starter's full
  content digest before the launcher starts.
- A bounded settled-M7 projection now retains economy, roster, every owned
  individual with XP, moves, history, observations, unlocks and Harmony, plus
  the reward ledger and content identity. Its numeric Bend encoder has a fixed
  version/count contract with a length-prefixed owned record; both Bend native
  and JavaScript decoders round-trip the same vector and reject malformed
  headers. The host has a typed JSON and numeric-wire codec. The M10 runtime
  emits this projection after a returned encounter and rejects malformed or
  mismatched rows. A versioned restore row reinstalls world and progression.
- Save schema 4 carries final typed progression alongside the world snapshot
  and keeps the restore anchor's starting progression separately. Schema 2 and
  3 remain byte-compatible, and M8 migration remains an explicit schema-2
  transform. An anchored pre-v4 save whose final progression has no recoverable
  starting baseline rejects safely. Load compares replayed progression as well
  as the world snapshot. The continued party starts a later encounter from its
  retained HP and individual state.

## Local evidence

- `tests/persistence/test_m11_save.py` covers canonical round-trip, exact
  identity, integrity failures, bounds, stable-world restrictions and explicit
  migration. `tests/persistence/test_save_slots.py` covers slot, recovery and
  interruption behavior.
- `tests/replay/test_m11_replay.py` covers canonical round-trip, exact identity,
  ordering, bounds, checkpoints and authoritative-runner acceptance.
- `tests/m10/test_m11_session_codec.py` checks the maker command mapping and
  runtime replay adapter. `tests/m10/test_runtime_response.py` checks typed
  runtime save projection parsing and rejection at unsafe boundaries.
- `tests/m10/test_runtime_process.py` checks restore-row encoding, placement,
  receipt validation and rejection by an older runtime. These fake-runner
  tests supplement the runtime-backed migration continuation test below.
- The M10 service exposes manual save, load, replay export and replay verify
  routes. `tests/m11/test_service.py` checks the runtime-backed service flows.
- `tests/m11/save_wire_test.bend` checks the closed Bend save projection.
- `test_progressed_m8_snapshot_migrates_then_continues_and_resaves` in
  `tests/m11/test_service.py` exercises an actual progressed schema-1 world
  through migration and continued commands using the compiled Bend runtime.
- `tests/m11/restore_wire_test.bend` exercises restore followed by a command;
  its compiled native and JavaScript outputs match.
- A separate schema-4 round trip and maker service regression check preserve
  distinct starting and final progression, preventing a loaded save from
  replaying accepted commands against already-final rewards.
- `tests/packaging/test_m11_package.py` checks package tampering, unexpected
  files, unsafe paths, and a clean-directory copied service validation,
  save/load, replay verification and progressed M8 v1 migration/continuation
  with Bend and Bun absent from `PATH` and Python network connection attempts
  denied. It invokes the service API directly; it does not exercise HTTP serving.
- The browser journey on a loopback test server created a project, started a
  playtest, moved, saved to manual slot 1, moved again, loaded the saved run,
  moved from the restored position, downloaded the replay, imported it, and
  verified it against the frozen project. The loopback server required an
  approved sandbox escalation. The copied-package test exercises the service
  without a listener. A separate copied-package `start-maker` launch verified
  its manifest and served the browser over loopback with Bend and Bun absent
  from `PATH`; the same browser save/load/continue/export/import/verify journey
  passed there. OS-level network namespace creation is denied by the sandbox;
  the copied service test denies Python network connections instead.
- The focused Python suites, Bend save-wire fixture, and canonical Bend proof
  passed during implementation. The historical M8 loaded journey exceeds the
  pinned 2.0.27 native compiler's arity limit on the unchanged M10 baseline;
  the gate records its JavaScript result and retains native/JS parity on smaller
  M8 boundaries. An M11 session-copy regression initially caused the separate
  M8 replay rejection native fixture to hit the same limit. Removing the
  redundant copy restored native compilation; all M8 native fixture builds
  subsequently passed.
- An independent Luna correctness review found a restore-anchor bug: a loaded
  save could use final progression as replay's starting progression. Schema 4
  and a focused service regression now keep these states separate; the reviewer
  checked the fix and the 17 focused save/service tests passed. A separate
  Luna review corrected battle actor IDs in replay records and added a test.
  Final independent review found that the save codec accepted malformed
  command JSON before service replay. A shared closed M10 command decoder now
  validates each record at save encode/decode, with malformed-log regressions;
  the 37 focused codec, slot, maker and service tests passed.
- A final independent Luna review found no concrete defect in TRACE 2 timing,
  trusted enemy-wait records, the 4096-record cap or stable save/restore.
  A gate failure then exposed a fixture expectation error: the first advance
  while the player is already ready does not insert an enemy wait. Luna
  isolated that assertion and corrected the fixture; it now checks both absent
  and present AI wait paths without changing gameplay code.
- All **600 gate checks passed**. The initial `python3 scripts/verify.py` run
  supplied checks 1–548. After the fixture-only correction, the exact remaining
  gate body rebuilt check 549 and ran through check 600, preserving the earlier
  passing evidence. Production sources were unchanged between these segments.
  `build/evidence/verification.json` records every result and this execution
  provenance. The canonical `./scripts/bend PROOF.bend` was rerun successfully;
  `git diff --check` and Python compilation checks passed.
- `build/m11-package-release` contains the assembled Linux x86-64 package.
  Its verifier accepted all 62 files, sizes, modes, SHA-256 hashes and the
  starter content identity. Launch it with `build/m11-package-release/start-maker`.

## Scope and platform limits

The maker now carries the settled M7 party and economy through save, restore,
replay and a second encounter. The Bend runtime emits acceptance and completion
ticks plus trusted enemy-wait decisions. Replay records use one barrier per UI
command, with the UI at ordinal zero and an inserted enemy wait at ordinal one.
Verification requires the authoritative Bend runtime to regenerate the same
waits and acceptance ticks. Battle actor IDs come from accepted payloads.
Optional replay checkpoints are rejected by this adapter
because the M10 runtime does not emit per-command canonical state digests.
Autosaves cover the available stable map-entry boundaries: initial playtest,
traversal and fast travel. Healing/rest, capture and story-checkpoint commands
are not exposed by the M10 maker command surface; their autosave hooks belong
with those future command integrations.

The package manifest is an integrity check, not a signature. The package
requires Linux x86-64 and system Python 3.12 or newer.
