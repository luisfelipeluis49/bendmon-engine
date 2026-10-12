# M10 maker status

Status: **complete locally**. M0–M9 remain complete. The maker can create,
validate and play a frozen Content-0 exploration section in a packaged Bend
runtime. Authored encounters enter a playable M7 battle scene; wait, escape
and learned authored moves can resolve through M7 and return to exploration.
The 578-check repository gate, canonical proof and independent Luna review pass.

## Implemented

- The local loopback service manages bounded editable drafts, atomic saves,
  asset import, field-linked shipping validation and exact-hash exports. A
  playtest freezes the validated project and four RNG words with a selected
  30, 60 or 120 tick Wait pace. A creator never invokes the compiler.
- The browser provides undo/redo, schema-oriented document forms, map and NPC
  placement, navigation vertex/face authoring, a starting point tool, content
  diagnostics, and an M9 canvas showing live scene and cues. It recognizes
  imported validated records even when their filenames are arbitrary.
- The default `examples/m10-starter` template includes original species,
  encounter content, a navigable map and an authored starting point. New
  projects can pass validation and launch without source edits.
- Versioned bounded M10 world, event, species, move, dialogue, boot and
  command wires are decoded into typed Bend records and joined by compact
  content identity.
  The precompiled `platform/maker/dynamic_runtime.bend` accepts one exact
  seven-row request, replays up to 4096 accepted commands and emits M9 scene
  and cue CSV. The service keeps an in-memory session with optimistic command
  sequence checks; rejected candidates do not change its accepted log.
- M7 species progression, capture/reward, learning and closed move metadata
  are bound to dynamic encounter species. A typed M10-to-M7 learning adapter
  and progression-valid starter/wild individual constructor exist.
  World collision, trigger/event choices, transitions and encounter detection
  run through the existing deterministic M8 transitions. Far NPC interaction
  rejects before facing-cone arithmetic, preventing a native Nat overflow.
- Authored NPC dialogue now uses a bounded Bend cursor. Interacting with a
  dialogue-only NPC validates map, range and facing, and each accepted advance
  displays the next frozen speaker/text line. The default starter includes a
  nearby two-line guide, and the creator-to-service journey exercises start,
  advance and close.
- A pure encounter bridge constructs a validated M7 playable session from the
  selected wild species and authored starter. Its native interpreted and
  JavaScript fixtures reach `Battling`; the maker runtime now invokes it and
  projects the M9 battle scene. The pinned Bend compiler's native C backend
  cannot compile the wide composed boundary, so the product executable is
  packaged from Bend's JavaScript output with checksum-pinned Bun. The
  creator runs only that prebuilt executable.
- One ordered world/battle command wire now replays through encounter entry,
  actor-0 wait, escape or authored move, M7 advancement, battle completion and
  subsequent world movement. A ready enemy receives a trusted wait so M7's two-sided
  command barrier remains authoritative. The starter's fixed-seed integration
  test covers a failed escape, a second successful escape and resumed movement.
- Closed authored effect programs bind through Content-0, M10 move wire v3 and
  the Bend decoder to M4/M5 battle execution. Legacy `power` moves synthesize
  one typed damage node; explicit effects and legacy power cannot coexist.
  Priority is bounded to -8..+8. A packaged-runtime fixture verifies an
  authored special damage node and recoil change both battle HP values.
- The creator browser exposes effect and conditional rows as editable fields.
  A legacy power move is migrated to a single explicit damage effect when the
  creator adds effects. Browser control tests exercise adding and changing
  effects and conditional branches.

## Compiler scope

The composed boundary cannot compile to native C with pinned Bend 2.0.27
because it hits the upstream `an arity over 255` code-generation limit for a
join of wide results
([Bend changelog](https://github.com/bendlang/bend/blob/main/CHANGELOG.md)).
A side-by-side 2.0.36 attempt is not drop-in compatible: it rejects existing
duplicate constructor names across modules. The packaged runtime remains on
the pinned compiler and uses its JavaScript backend. The full composed replay
also exceeds the pinned interpreter's 480-second fixture window; its
JavaScript fixture and packaged-runner journey pass. Focused native and
JavaScript fixtures cover the typed M7 move, encounter handoff, authored move
decoder and other pure boundaries.

## Verification

The full repository gate passes 578 checks. The full M10 Python suite passes
92 tests. Focused Node browser controls, native/JavaScript Bend effect decoder,
packaged-runtime effect acceptance,
canonical `PROOF.bend` and `git diff --check` pass. A live local browser run
created a project from the starter, changed its map, dialogue and move,
authored special damage plus source recoil through effect controls, validated
the draft, launched a frozen playtest, reached a wild encounter through map
movement, resolved the move (wild HP 23→4; player HP 19→10 from recoil),
and completed the battle back on the edited map after 213 commands.
That journey exposed an enemy-ready/player-recovering command-barrier stall;
the advance path now queues a trusted enemy wait and a packaged-runtime
regression proves the battle completes. The independent Luna review identified
the original browser acceptance gap, which this journey closed. The live browser
journey is documented acceptance evidence; browser controls and service journeys
are automated separately, while a single full-browser workflow test remains a
future regression-coverage improvement.

Trainer records remain authorable and validated in M10. Trainer fights and
training behavior are part of M13's original demonstration scope in `PLAN.md`.
