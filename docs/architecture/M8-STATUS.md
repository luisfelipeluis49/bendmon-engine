# M8 overworld status

Status: complete. This file records the M8 exit evidence from
`docs/work-orders/M8-OVERWORLD.md`.

## Implemented boundary

- The pure Bend world core owns fixed-point navigation, ordered actor conflict
  resolution, weighted-distance encounters, finite event activations, explicit
  world commands, M7 battle handoff, stable-world projection/restore, and
  accepted-command replay. Rendering and editor UI remain later milestones.
- Content-0 maps and event graphs pass bounded Python schema, reference, and
  semantic validation before deterministic numeric binding. The sample project
  in `examples/m8-world/` is loaded through that boundary for the M8 journey.
- Stable world saves use canonical JSON and the full SHA-256 content digest at
  the host boundary. `scripts/bind_m8_save.py` checks that digest before
  constructing the bounded Bend snapshot. Bend's numeric content identity is
  a runtime consistency token, not a replacement for the full digest check.
- The loaded journey moves/interacts, selects an encounter, enters the M7
  playable battle, resolves it, and resumes its authoritative world. Save
  restore and replay have separate native/JavaScript fixtures.

## Review and verification

Independent Luna reviews found navigation edge cases: reversed-winding faces
could invert interpolated elevation, and swept actor paths could miss nearby
segments or their starting endpoints. These have production fixes and
native/JavaScript regression cases in `elevation_test.bend` and
`actors_test.bend`; a follow-up review confirmed the start-endpoint case is
resolved. A same-prefix/different-full-digest save is rejected by the M8 host
bridge test.

`./scripts/bend PROOF.bend` reported `All terms check.` on the final Bend
changes. `python3 scripts/verify.py` passed all 451 checks, recorded in
`build/evidence/verification.json`. The gate generated exact-hash world/save
bindings, compiled every M8 Bend fixture for native and JavaScript, compared
their outputs, and passed the Python content and persistence suites. In
particular, the loaded journey, command replay, and generated save restoration
passed on both targets. `git diff --check` passed. Graphical rendering and the
maker UI belong to later milestones and are outside the M8 work order.
