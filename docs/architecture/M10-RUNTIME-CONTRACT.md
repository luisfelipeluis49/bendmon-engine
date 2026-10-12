# M10 precompiled playtest contract

The maker validates a Content-0 project with the shipping loader, exports an
exact frozen copy, and checks its full SHA-256 digest before every run. The
creator never compiles authored material. `scripts/build_m10_runtime.py`
builds a trusted standalone executable during development from pinned Bend
JavaScript and checksum-pinned Bun. The pinned Bend native compiler cannot
compile the composed M7/M8 wide join; the independent pure fixtures still run
on native and JavaScript lanes. The service takes an
explicit executable path and runs it against a temporary bounded request.

## Request and response

`M10PLAY2` is a newline-delimited request with an exact header and seven
canonical unsigned numeric rows, in this order:

1. `M10WORLD` v2 (`10, 2`): maps, navigation, NPCs, regions, triggers and
   transitions.
2. `M10EVENTS` v1 (`12, 1`): event graphs and encounter tables.
3. `M10M7SPECIES` v2 (`13, 2`): species stats, combat types, capture/reward
   values and level learning records.
4. `M10M7MOVES` v3 (`15, 3`): bounded move timing, hit mode, components,
   priority and a closed effect program. Legacy power moves become one damage
   effect at the Bend boundary.
5. `M10DIALOGUE` v1 (`16, 1`): bounded authored text code points and numeric
   NPC associations.
6. `M10BOOT` v2 (`11, 2`): entry map and point, four RNG words, selected
   30/60/120-tick Wait pacing, and optional explicit starter species/level.
7. `M10COMMANDS` v1 (`14, 1`): up to 4096 ordered world and battle commands,
   each with an exact zero-based sequence number and a closed operation tag.
   Dialogue advance is tag 8; player-actor-0 battle wait, escape and battle
   advance are tags 9–11; an authored move command is tag 12.

The host caps the request at 2 MiB, checks canonical U32 tokens and verifies
every row's compact identity against the frozen digest's first eight hex
digits. Bend independently decodes each row into typed records, checks counts,
bounds and references, joins matching identities, and boots only an authored
point on baked navigation. `M10M7SPECIES` is a progression subset, not a full
battle catalog.

The runtime responds with `M10PLAY2 ACCEPTED`, `ENCOUNTER`, `BATTLE` or `REJECTED`, an
identity and accepted command count, a closed numeric dialogue cursor, and
(on accepted/encounter) a bounded M9 scene and cue CSV. The host resolves an
active cursor against the frozen validated dialogue records, then displays
speaker and text without making gameplay decisions. The response parser checks the exact grammar,
identity and count; process stdout/stderr and duration are bounded. No runtime
diagnostic or malformed output is treated as accepted play.

## Session behavior

The service holds a frozen snapshot and an in-memory accepted command log.
Each UI action supplies the expected log length and one closed JSON command.
The service encodes the candidate log and runs the precompiled process. Bend
replays from the original boot through the existing M8 world transitions;
the candidate is appended only after an accepted response. A rejected command
leaves the log and prior presentation intact. Only the last command's cues are
returned, so replay does not display old effects again. Sessions are capped at
32, expire after one hour of inactivity and stop at 4096 accepted commands.

World movement, interaction, event pause/choice, transitions and encounter
detection use deterministic Bend transitions. A dialogue-only NPC starts a
bounded Bend cursor after the same range and facing checks as event NPCs;
subsequent advance commands move one line at a time, and other commands reject
while dialogue is open. A reached encounter with an authored starter opens a
validated M7 battle and returns its M9 battle scene; one without a starter is
reported as a handoff. Battle wait and escape submit the player action with a
trusted enemy wait only when that enemy is ready; M7 enforces the two-sided
command barrier. Battle advance resolves the queued transition. A learned
authored move uses the same M7 reservation, cooldown, accuracy and effect
execution path as other battle moves. The authored effect program decodes into
the closed M4 effect algebra; its first damage node uses M5 typed damage. A
terminal battle resumes the same exploration session, and later world commands
continue through the same ordered log.
Trainer records remain authored metadata; trainer fights are part of M13.

The older `M10RT1` transport probe demonstrated bounded file IO only and is
not the playtest contract. The host keeps filesystem, clock, graphics and
process effects outside the deterministic Bend core.
