# M10 maker work orders

Status: complete locally. M10 builds a no-code creator workflow over Content-0 and
the M8/M9 runtime. Draft content may be incomplete. Only a frozen project that
passes the shipping loader may enter playtest or export. The editor never
changes Bend rules, collision, encounter draws or renderer authority.

## M10-A — draft state and edit history

TASK: implement bounded browser draft state, selection and undo/redo.
OWNER MODEL: Luna.
DEPENDENCIES: Content-0 records and M10-B transport contract.
FILES ALLOWED TO CHANGE: `platform/maker/browser/state.mjs`, `tests/m10/browser/state.test.mjs`.
FILES FORBIDDEN TO CHANGE: engine, loader, runtime and other maker files.
GOAL: immutable edit snapshots with explicit dirty state, bounded history,
field/path updates and map placement drag operations.
NON-GOALS: widgets, filesystem, validation or gameplay.
ENGINE INVARIANTS AFFECTED: none; drafts have no runtime authority.
LAWS AFFECTED: none.
INPUT CONTRACT: JSON project document map keyed by relative Content-0 path.
OUTPUT CONTRACT: serializable snapshots and deterministic edit operations.
IMPLEMENTATION NOTES: reject prototype keys, invalid paths and oversized
history; keep all edits reversible including drag/drop.
EDGE CASES: redo invalidation, repeated edit, invalid path, history cap.
TESTS REQUIRED: Node tests for public editing behavior and limits.
PROOF OBLIGATIONS: none.
ACCEPTANCE CRITERIA: undo/redo restores full draft documents exactly.

## M10-B — project service and validation

TASK: expose bounded local project creation/open/edit/validate/export endpoints.
OWNER MODEL: Luna.
DEPENDENCIES: shipping `load_project` Content-0 boundary.
FILES ALLOWED TO CHANGE: `platform/maker/service.py`, `scripts/run_m10_maker.py`,
`tests/m10/test_service.py`.
FILES FORBIDDEN TO CHANGE: engine, content loader, M9 renderer, other maker files.
GOAL: browser can create/open a project, save draft documents atomically,
receive field-linked shipping diagnostics and export a validated frozen copy.
NON-GOALS: public network server, general archive/import format or M11 package.
ENGINE INVARIANTS AFFECTED: inert content and exact identity.
LAWS AFFECTED: none.
INPUT CONTRACT: local browser JSON requests and bounded paths/documents.
OUTPUT CONTRACT: canonical JSON responses, diagnostics with file/pointer,
validated digest; no partial replacement after a failed save/export.
IMPLEMENTATION NOTES: bind to loopback, keep projects under a configured root,
use the existing loader rather than duplicating validation; do not let a draft
claim it is validated. M10-D integrates the runtime route.
EDGE CASES: traversal, duplicate keys, oversized requests, invalid projects,
failed atomic write, changing content between validation and export.
TESTS REQUIRED: service tests for both success and hostile inputs.
PROOF OBLIGATIONS: none; identify Python/filesystem trusted boundary.
ACCEPTANCE CRITERIA: invalid drafts remain editable but cannot export as valid.

## M10-C — maker browser UI

TASK: implement creator-facing browser editor with map palette, drag/drop,
inspectors, catalog and story tools, validation feedback and playtest control.
OWNER MODEL: Sol integration, with Luna bounded panels if parallel space exists.
DEPENDENCIES: M10-A/B contracts and M10-D playtest route.
FILES ALLOWED TO CHANGE: `platform/maker/browser/index.html`, `main.mjs`,
`forms.mjs`, `map.mjs`, `styles.css`, UI tests and maker documentation.
FILES FORBIDDEN TO CHANGE: gameplay engine and shipping loader.
GOAL: a creator can edit the complete small-section content without opening
source files: map geometry/placements, species/moves/items, trainers,
encounters, NPCs, dialogue/events, assets and project metadata.
NON-GOALS: unrestricted 3D modeling or authored scripts.
ENGINE INVARIANTS AFFECTED: draft-only edits; runtime input remains validated.
LAWS AFFECTED: none.
INPUT CONTRACT: M10-A draft snapshots and M10-B service JSON.
OUTPUT CONTRACT: visible controls, field-linked errors and accessible status.
IMPLEMENTATION NOTES: use schema-oriented constrained controls where possible;
advanced JSON field editing can supplement, but not replace, visual workflows.
EDGE CASES: empty project, missing reference, drag cancellation, unsaved edits.
TESTS REQUIRED: browser behavior tests and a creator journey.
PROOF OBLIGATIONS: none.
ACCEPTANCE CRITERIA: creator builds and plays a small section without code.

## M10-D — frozen playtest and closure

TASK: connect a validated draft snapshot to a real M8/M9 playable run, then
close M10 with exact evidence.
OWNER MODEL: Luna runtime adapter; Sol integration and separate Luna review.
DEPENDENCIES: M10-B service, precompiled M8 runtime and M9 host contracts.
FILES ALLOWED TO CHANGE: new `platform/maker/playtest.py`,
`platform/maker/runtime_transport.bend`,
`platform/content/m10_world_wire.py`, `engine/world/dynamic_catalog.bend`,
`engine/world/playtest_boot.bend`, Content-0 project entry-point records/schema,
`tests/m10/` fixtures, `scripts/verify.py`,
`docs/architecture/M10-RUNTIME-CONTRACT.md`, `M10-STATUS.md`.
FILES FORBIDDEN TO CHANGE: battle/world semantics or existing proof laws.
GOAL: choose four canonical RNG words and game Wait pacing, freeze exact validated content identity, run the loaded
M8 world and M7 battle through accepted commands, display M9 projection and
ordered cues; edits create a later snapshot only.
NON-GOALS: save migration or M11 clean-install packaging.
ENGINE INVARIANTS AFFECTED: deterministic transitions and exact content hash.
LAWS AFFECTED: only additive production-linked laws if the core changes.
INPUT CONTRACT: validated Content-0 frozen project and canonical commands.
OUTPUT CONTRACT: playtest scene/cues/status with stable snapshot identity.
IMPLEMENTATION NOTES: do not simulate gameplay in Python/JS; use compiled Bend
runtime. Build/compiler use belongs to development, never creator workflow.
EDGE CASES: invalid draft, rejected command, active dialogue, battle return,
editing while playtest runs, mismatched content identity.
TESTS REQUIRED: loaded journey, native/JS equality where applicable, frozen
snapshot, invalid-blocking, creator acceptance and full repository gate.
PROOF OBLIGATIONS: `./scripts/bend PROOF.bend` before Bend commit.
ACCEPTANCE CRITERIA: no-code creator journey passes, full gate passes and an
independent Luna review finds no unresolved correctness defect.

Reviewer and evidence links: record in `docs/architecture/M10-STATUS.md`.
Escalation: Luna to Sol for integration/semantics, Sol to Astra for rule/law
changes. Existing laws must not be weakened.
