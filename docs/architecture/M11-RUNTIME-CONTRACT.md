# M11 persistence and package runtime contract

Status: complete locally. This document describes the implemented M11
format and package boundaries; verification evidence is in `M11-STATUS.md`. The controlling work orders
are in `docs/work-orders/M11-PERSISTENCE-PACKAGING.md`.

## Stable-world save envelope

`platform/persistence/m11_save.py` encodes canonical UTF-8 JSON save schema 4,
bounded to 2 MiB. The envelope identifies the engine build, project, catalog,
exact `m8-1` ruleset, full Content-0 SHA-256 digest, and fixed Wait choice
(30, 60 or 120 ticks). Its payload includes the stable M8 world snapshot,
typed settled-M7 progression after battle,
initial four-word RNG state and at most 4096 accepted commands. An optional
`restoreWorld` anchor records a stable M8 world supplied before those accepted
commands; `restoreProgression` records its distinct starting progression when
one exists. The final progression remains a separate payload field. A canonical
payload digest protects internal consistency; it does not replace the full
content identity check.

Decode requires the caller's exact ruleset, digest, project and catalog
identity. It checks canonical bytes, strict field shape, payload digest, RNG
agreement, every accepted command against the closed M10 wire, and the M8 stable-world boundary. Pending event, encounter or battle
state is not installable. The explicit `migrate_m8_v1_to_v2` path accepts only
the legacy M8 schema-1 world format and preserves its ruleset and content
digest; unknown save versions and cross-ruleset conversion reject. Migration
stores the legacy world as `restoreWorld`, allowing the migrated run to resume
from that exact state and replay later commands under its original M8 identity.
Schemas 2 and 3 remain exact historical formats. Loading an anchored schema-3
save with final progression rejects when its missing restore baseline makes
authoritative replay ambiguous.

`platform/persistence/save_slots.py` provides ten manual slots, one rotating
autosave and a recovery copy. Slot replacement stages and reads back the new
envelope before replacement, uses same-directory atomic operations and fsync,
and keeps the previous valid bytes for recovery. Migration remains explicit.
This host filesystem behavior is exercised with injected I/O; it is not a Bend
formal proof of filesystem durability.

## Replay file

`platform/persistence/m11_replay.py` encodes canonical replay schema 1, bounded
to 2 MiB and 4096 commands. The header stores the exact supported ruleset and
full content digest, RNG revision and state, Wait choice, engine build and
complete initial state. Commands carry logical tick, barrier, ordinal, actor
and a closed JSON payload. Ordering, duplicates, gaps, bounds and optional
checkpoint positions are checked. A replay's accepted-command claims are not
authority: `verify_replay` resubmits every command through an injected
authoritative runner and checks acceptance and available state digests.

The M10 session adapter, `platform/maker/m11_session_codec.py`, maps each
accepted maker command into the ordered replay form and can resubmit it through
the packaged Bend runtime. M10's current display response does not expose
checkpoint state digests, so this adapter rejects replay files that claim
checkpoints. Replay initial state may carry the same optional `restoreWorld`
anchor; verification supplies it to Bend before replaying the command log.
The Bend runtime exports each command's acceptance and completion ticks and
whether it generated a trusted enemy wait. World and dialogue input leaves the
logical clock paused; battle input uses the battle scheduler tick. The maker
assigns one barrier per accepted UI command at ordinal zero. When Bend inserts
an enemy wait, the adapter records it at ordinal one in the same barrier and
acceptance tick. Verification resubmits the UI commands and requires Bend to
regenerate exactly those enemy waits and ticks; it never executes a replayed AI
row twice. Battle actor IDs are copied from accepted payloads. The restore
anchor carries the stable world and typed settled progression when present.
Historical ruleset data can be decoded only when the caller
requests its exact supported version; it is never silently upgraded.

## M10 stable-save projection

The composed M10 Bend runtime emits closed numeric `SAVE` and `PROGRESSION`
projections only when the world snapshot is stable and dialogue is closed. The
host parses them into typed world and settled-M7 records; a save is rejected during an active
encounter, dialogue or battle. MakerService consumes this projection to save a
manual slot and automatically records the initial stable state and successful
world-transition results. For saves with a restore anchor, the host sends a
versioned M11 restore row after the command row; older runtimes reject that
extra row. Loading decodes the exact save identity, freezes the matching
project, restores the optional anchor, replays every accepted M10 command
through Bend, and installs the session only when the replayed world and
progression equal the saved state. This gives an explicitly migrated M8 v1 save a path to
continue play without treating its progressed snapshot as a fresh boot state.

The maker exposes manual slot save/load, replay export and replay verification
routes. The browser offers a slot selector, save/load buttons, replay download
and replay import/verification. Save/load is available only at a runtime
reported stable boundary; UI state does not authorize persistence.
`tests/m11/test_service.py` exercises service-level save/load, recovery,
replay verification and identity mismatch against the packaged Bend runtime.
The browser interaction journey passed on a loopback test server: save, load,
continued movement, replay download, import and verification.

## Offline package

`scripts/package_m11.py` consumes prebuilt trusted M10 runtime and Content-0
kernel executables, packaged Python host modules, browser/renderer files and
the validated M10 starter. It emits an `m11-package-1` manifest for Linux
x86-64 and Python 3.12+, recording each included regular file's normalized
relative path, size, mode and SHA-256 plus the starter's full Content-0 digest.
The builder does not compile Bend or fetch Bun. `start-maker` invokes
`scripts/verify_m11_package.py` before launching the copied host. Verification
rejects symlinks, unsafe or duplicate paths, missing or extra files, changed
bytes/modes, unsupported target metadata, and a starter whose shipping-loader
digest differs from the package metadata.

The manifest detects accidental or untrusted package changes only when the
manifest itself is obtained through a trusted distribution channel. No
signature or anti-tamper guarantee is claimed. The copied-package test runs the
verifier and M10 service API from a clean directory with Bend and Bun absent
from `PATH` and Python network connections denied, then validates the starter, saves and reloads a command, verifies
its replay, and migrates a progressed M8 v1 save before continuing, resaving
and verifying through the packaged runtime. Separately, a copied `start-maker`
launcher verified its package and served the full browser save/load/replay
journey over loopback with Bend and Bun absent from `PATH`. The sandbox rejects
OS network namespace creation, so offline evidence uses denied Python network
connections and the compiler-free copied-package journey instead.
