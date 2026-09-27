# M8 overworld work orders

Status: complete. M7 is the verified headless baseline. Approved D14 and
D16 control exploration and events. Content remains inert data; the Bend core
owns movement, encounter RNG and event semantics. M8 closes only when a loaded
world can move, interact, enter battle through the M7 playable session, resolve
the outcome, and return to the same authoritative world state under native and
JavaScript execution with bounded event and replay tests.

## M8-A — deterministic free-direction navigation

TASK: implement fixed-point world movement and collision.
OWNER MODEL: Luna.
DEPENDENCIES: D14, validated map geometry.
FILES ALLOWED TO CHANGE: `engine/world/geometry.bend`, M8 geometry fixtures.
FILES FORBIDDEN TO CHANGE: battle/progression, content loader, shared gates.
GOAL: checked coordinates, normalized digital/analog input, walk/run/sprint,
swept collision on baked navigation geometry, elevation links and stable ActorId
conflicts. Report actual ground distance independently of presentation frames.
NON-GOALS: renderer or animation.
ENGINE INVARIANTS AFFECTED: deterministic world position and collision.
LAWS AFFECTED: additive production-linked movement bounds and rejection laws.
INPUT CONTRACT: validated nav surface, ordered actors and one tick of input.
OUTPUT CONTRACT: accepted next positions/distance or unchanged rejection.
IMPLEMENTATION NOTES: choose fixed scale and speeds with reproducible feel
measurements; bound positions and arithmetic before updates.
EDGE CASES: diagonal normalization, high-speed thin obstacles, blocked starts,
map edge, ramp transition and simultaneous actor crossings.
TESTS REQUIRED: native/JS goldens and boundary/collision fixtures.
PROOF OBLIGATIONS: bounds and unchanged rejection witnesses.
ACCEPTANCE CRITERIA: deterministic sweeps and no wall tunneling.

## M8-B — bounded event machine

TASK: implement finite, declarative world event activations.
OWNER MODEL: Luna, parallel with M8-A.
DEPENDENCIES: D16 and closed opcode catalog.
FILES ALLOWED TO CHANGE: `engine/world/events.bend`, M8 event fixtures.
FILES FORBIDDEN TO CHANGE: battle/progression, content loader, shared gates.
GOAL: acyclic activation, cumulative fuel/queue/nesting/entity/byte budgets
across yields, deterministic diagnostics and atomic abort.
NON-GOALS: arbitrary pack code or persistent loops within one activation.
ENGINE INVARIANTS AFFECTED: budgeted event execution and atomicity.
LAWS AFFECTED: additive fuel/rollback witnesses.
INPUT CONTRACT: validated event graph and persistent world flags.
OUTPUT CONTRACT: committed effects or unchanged state plus diagnostic.
IMPLEMENTATION NOTES: loops require a later activation; budgets never reset on
yield or presentation frame.
EDGE CASES: cycles, nested chains, full queue, exhaustion after yield.
TESTS REQUIRED: native/JS goldens, budget matrix and atomic rollback.
PROOF OBLIGATIONS: cumulative budget and rejection witnesses.
ACCEPTANCE CRITERIA: no unbounded activation or partial effect on abort.

## M8-C — inert authored world content

TASK: extend Content-0 maps and loader for navigation and world entities.
OWNER MODEL: Luna, parallel with M8-A/B.
DEPENDENCIES: M2 content intake and D14/D16.
FILES ALLOWED TO CHANGE: map/world schemas, content models/loader and M8
content fixtures.
FILES FORBIDDEN TO CHANGE: Bend battle/progression and shared gates.
GOAL: bound and validate nav geometry, NPCs, triggers, encounter regions,
transitions and event graphs; include all semantic fields in project identity.
NON-GOALS: user-authored opcodes or scripts.
ENGINE INVARIANTS AFFECTED: untrusted-data boundary and identity.
LAWS AFFECTED: none unless a production-linked content rule is added.
INPUT CONTRACT: manifest-listed JSON with legacy maps still valid.
OUTPUT CONTRACT: immutable validated records or actionable diagnostics.
IMPLEMENTATION NOTES: preserve M2–M7 pack compatibility; sorted IDs and exact
canonical hash; enforce reference and graph checks before Bend runtime binding.
EDGE CASES: duplicate IDs, invalid coordinates, missing references, cycles,
oversize graphs and hash differences.
TESTS REQUIRED: positive/hostile loader fixtures and identity tests.
PROOF OBLIGATIONS: none for Python parser; Bend binder must validate IDs.
ACCEPTANCE CRITERIA: no authored executable code reaches runtime.

## M8-D — encounters and world/battle integration

TASK: bind validated content to world state and integrate M7 battle.
OWNER MODEL: Sol integration after parallel APIs stabilize.
DEPENDENCIES: M8-A/B/C, M7 playable session and shared RNG.
FILES ALLOWED TO CHANGE: new world runtime/encounter modules, M8 integration
fixtures, versioned identity and shared verification gate.
FILES FORBIDDEN TO CHANGE: M3 scheduler, M4 effects, M5 damage, M6 mix and M7
transaction semantics except a proven integration defect.
GOAL: deterministic encounter thresholds from weighted ground distance, explicit
NPC/trigger/transition commands, exploration-to-battle-to-world round trip and
stable-world save boundary. A world command is atomic on rejection.
NON-GOALS: graphical renderer (M9) or maker (M10).
ENGINE INVARIANTS AFFECTED: DET-1, event atomicity, encounter draw order and
exact world identity.
LAWS AFFECTED: additive encounter threshold and rollback witnesses.
INPUT CONTRACT: validated and hash-bound world catalog, saved M7 roster,
explicit RNG and commands.
OUTPUT CONTRACT: ordered world events or unchanged rejection, M7 battle handoff
and deterministic return; no duplicate rewards or encounter re-entry.
IMPLEMENTATION NOTES: draw one threshold on region entry and after encounter;
distance, not frames/tiles, advances the meter. Sprint multiplier is larger.
EDGE CASES: region edge, collision with zero travel, battle loss/draw/escape,
event yield, map transition and content mismatch.
TESTS REQUIRED: native/JS full headless journey, repeated command replay and
budget exhaustion.
PROOF OBLIGATIONS: production-linked laws; canonical `PROOF.bend` gate.
ACCEPTANCE CRITERIA: all M8 fixtures and full repository gate pass; independent
Luna review finds no unresolved correctness defect.

Reviewer and evidence links: record in `docs/architecture/M8-STATUS.md`.
Escalation: Luna → Sol for integration/algorithms; Sol → Astra for semantic law
changes. Existing laws must not be weakened.
