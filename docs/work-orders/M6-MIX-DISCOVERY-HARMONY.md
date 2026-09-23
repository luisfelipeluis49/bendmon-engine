# M6 mix, discovery and Harmony work orders

Status: implementation in progress on 2026-09-23. M6-A and M6-B pure cores and
the first M6-C production mixed battle/learning path pass locally. Runtime
replay differential coverage, full content schema/proofs, hosted verification
and formal milestone closeout remain pending. See
`docs/architecture/M6-PROGRESS.md` for exact checkpoint evidence and limits.

This is the controlling M6 work package. The approved semantics are D05, D06,
D09 and D10 in `docs/DECISIONS.md`, MIX-1–8 in
`docs/mechanics/MIXING.md`, and the constants in `docs/RULES.md`. The slices
below are deliberately bounded so Luna agents can implement pure modules and
fixtures in parallel. Shared battle integration remains a single-owner slice.

## Frozen implementation contract

- `BaseMoveId` uses the existing typed move identity. `RecipeId` is a separate
  typed identity. A recipe key is exactly two distinct source IDs normalized as
  `(min, max)`. A catalog contains at most one recipe for a key.
- Each source resolves to exactly one type component. A result is a registered
  M4 effect descriptor with one to four M5 type components. It has no
  `BaseMoveId`, cannot be placed in a current move slot and cannot be a recipe
  source. M6 never synthesizes result effects.
- The initial closed requirement vocabulary is `Always` plus the target and
  execution guards already validated by the registered M4 descriptor. Adding
  weather, flags, inventory predicates or arbitrary expressions is outside M6
  and requires a versioned schema extension.
- Current move knowledge is a distinct bounded list of `BaseMoveId` values on
  one persistent `MonsterId`. Both recipe sources must be present when training
  and when submitting a mix. Slot order and command source order do not affect
  recipe identity.
- Harmony accuracy and critical bonuses are actor-side values captured at
  command acceptance with the other offensive snapshot. They enter the
  existing M4 action-level accuracy and critical calculations once and add no
  RNG draws. The ordinary critical chance still clamps at 2500.
- One accepted mix owns a stable battle-local action sequence. That sequence is
  the idempotence key for witness staging and Harmony award. Replayed duplicate
  completion for the same sequence is a no-op.
- Witness selection occurs after the actor and locked target are valid at mixed
  execution start and before accuracy/effect resolution. It includes active,
  conscious combatants on either side that currently know both sources. A miss
  still stages observation. Cancellation and invalid-target fizzle never do.
- Staged observations merge into persistent individuals only at a committed
  terminal result, including Victory, Defeat, Draw, Timeout and Escaped. Merge
  is set insertion and therefore idempotent.
- Mixed duration is `ceil(3*c/2)`, implemented without overflow as
  `c + floor(c/2) + (c mod 2)`. Both durations and `now + duration` are checked
  before either source changes. Accepted sources are off cooldown, so each new
  deadline is exactly `now + duration`; the shared source helper may retain its
  monotone `max` defense. Duration may not exceed 5400 and the battle-clock
  deadline must remain valid.
- Harmony success means the registered program committed and its intended
  program effects changed gameplay state: positive actual damage or healing,
  status add/replace/refresh that changes status state, status removal/clear,
  or a nonzero stat-stage change. Aftermath alone does not qualify. Miss,
  zero-damage/all-blocked output, full-HP healing, cancellation, fizzle,
  rejection and engine fault do not qualify. Award is one progress point for
  the whole action, regardless of components, nodes or targets.
- Training is a pure post-battle transaction over one individual and a U32
  token balance. It requires a designated trainer, an observed unlearned
  recipe, both current sources and catalog compatibility. Success consumes one
  token and installs Harmony progress 0 atomically; failure changes nothing.
  Mid-battle training is rejected.
- Observation, learned state and Harmony survive forgetting and later relearning
  sources. Persistent identity, recipe identity and exact ruleset/content
  identity control retention; no migration may remap a recipe silently.
- `m6-1` is reserved for states/replays containing M6 semantics and becomes the
  runtime identity only when M6 lands. Existing M3 replay fixtures remain
  `m3-1`; cross-version loading is rejected rather than reinterpreted. The
  project schema stays `unassigned` until a playable content ruleset is
  published.

## M6-A — recipe model, catalog and validation

TASK: M6-A typed recipe catalog and canonical lookup.

OWNER MODEL: Luna implementation agent.

DEPENDENCIES: completed M4 effect descriptor and M5 component algebra; frozen
contract above.

FILES ALLOWED TO CHANGE: new `engine/mixing/model.bend` and
`engine/mixing/recipe.bend`; additive M6 fixture/model documentation assigned
to this slice.

FILES FORBIDDEN TO CHANGE: M4 effect semantics, M5 type chart/allocation,
battle scheduler/reducer, RNG, persistence codecs and creator executable-code
boundary.

GOAL: define distinct recipe/individual identities, canonical unordered source
pairs, registered result descriptors, bounded catalogs, deterministic lookup
and closed validation diagnostics.

NON-GOALS: runtime reservation/execution, observation, training, Harmony
progress, host JSON loading, renderer or maker UI.

ENGINE INVARIANTS AFFECTED: MIX-1, MIX-3, MIX-6, MIX-7 and MIX-8.

LAWS AFFECTED: production-linked canonical-pair symmetry and registered-result
lookup. Do not add a law until it calls the production functions.

INPUT CONTRACT: a finite catalog of recipes and referenced base-move metadata,
including component count and registered M4/M5 result descriptor.

OUTPUT CONTRACT: either a validated catalog with one canonical entry per
distinct pair or ordered typed diagnostics; lookup of `(A,B)` and `(B,A)` is
identical.

IMPLEMENTATION NOTES: keep authored result component order; use canonical order
only for pair identity. Reject self-pairs, duplicate keys, unknown sources,
non-single-component sources, invalid result descriptors and any result exposed
as a base source.

EDGE CASES: empty catalog; minimum/maximum IDs; reversed duplicates; self-pair;
one source with 0, 2, 3 or 4 components; result with 0 or 5 components; invalid
M4 descriptor; multiple diagnostics in stable input order.

TESTS REQUIRED: pure Bend tests plus fixture-oracle cases for every rejection,
positive 1–4-component results and reversed lookup equality.

PROOF OBLIGATIONS: `canonical_pair(a,b) == canonical_pair(b,a)` for distinct
IDs; successful lookup returns only the stored descriptor; accepted recipe
sources each have one component.

ACCEPTANCE CRITERIA: changed Bend entries check; production-linked proofs pass;
fixture diagnostics and canonical lookup are deterministic; no existing module
is modified.

## M6-B — Harmony and individual learning state

TASK: M6-B pure observation, training and Harmony transitions.

OWNER MODEL: Luna implementation agent, parallel with M6-A after shared types
are fixed.

DEPENDENCIES: M6 model types and approved D06/D09 semantics.

FILES ALLOWED TO CHANGE: new `engine/mixing/harmony.bend`,
`engine/mixing/observation.bend`, `engine/mixing/training.bend`, assigned pure
tests and additive production-linked laws.

FILES FORBIDDEN TO CHANGE: battle runtime/scheduler/reducer, M4/M5 mechanics,
RNG and host persistence.

GOAL: implement per-individual observed recipe sets, learned recipe/Harmony
maps, witness selection/merge, atomic training and exact tier/bonus derivation.

NON-GOALS: battle command submission, runtime effect execution, training NPC
world placement, inventory implementation or save encoding.

ENGINE INVARIANTS AFFECTED: LEARN-1–3 and HARM-1–3.

LAWS AFFECTED: observation does not learn; training guards are necessary;
Harmony is bounded, monotone and idempotent by action sequence.

INPUT CONTRACT: valid persistent individual states; valid catalog; active
combatant snapshots; staged action identities; explicit trainer/battle-mode and
U32 token inputs.

OUTPUT CONTRACT: canonical set/map state and typed events, or an unchanged
typed rejection. Tier packages are exactly
`0:(0,0)`, `5:(100,125)`, `10:(200,250)`, `20:(300,375)`,
`30:(400,500)`, `40:(500,625)`.

IMPLEMENTATION NOTES: use sorted unique lists until a proven canonical map/set
representation exists. Keep observation staging separate from terminal merge.
Store awarded action sequences for the battle transaction so duplicate
completion cannot increment twice; terminal persistence need retain only the
resulting progress.

EDGE CASES: no witnesses; ally/enemy witnesses; unconscious/benched combatant;
same-action KO; repeated witness/terminal event; missing token/source;
unrelated individual; already learned recipe; forgetting/relearning; progress
at 4/5, 9/10, 19/20, 29/30, 39/40 and repeated success at 40.

TESTS REQUIRED: table-driven tier boundaries; success classifier cases for all
M4 effect event families; witness and terminal-result matrix; training guard
matrix; retention and duplicate-action fixtures.

PROOF OBLIGATIONS: award output is at most 40 and never below input; the same
action key cannot award twice; observation transition cannot add learned state;
successful training implies observation, both current sources and token
consumption.

ACCEPTANCE CRITERIA: all pure tests and production-linked proofs pass; failures
are unchanged transactions; no new RNG or battle integration exists in this
slice.

## M6-C — battle/runtime integration

TASK: M6-C mixed command, two-source transaction and M4/M5 execution adapter.

OWNER MODEL: one Luna implementation agent; exclusive owner of shared battle
files during this slice.

DEPENDENCIES: completed M6-A and M6-B pure APIs.

FILES ALLOWED TO CHANGE: new `engine/mixing/eligibility.bend` and
`engine/mixing/runtime.bend`; smallest additive changes to
`engine/battle/runtime.bend`, `engine/battle/sources.bend`, replay fold/model
files, and assigned runtime tests.

FILES FORBIDDEN TO CHANGE: M4 effect/status meaning, M5 allocation/chart/math,
scheduler ordering, battle completion ordering, ordinary RNG transition and
critical cap.

GOAL: submit one learned registered mix, reserve both sources atomically,
execute its registered descriptor once, apply both checked mixed cooldowns,
stage observations, classify Harmony success and preserve replay identity.

NON-GOALS: new effects, multihit, per-component accuracy/critical draws,
retargeting, world trainer UI, renderer or save-anywhere support.

ENGINE INVARIANTS AFFECTED: MIX-2, MIX-4, MIX-5, D05 cancellation/fizzle,
DET-1, TIME-1 and CD-1.

LAWS AFFECTED: atomic two-source engagement/no partial charge and eligibility
necessity. Universal runtime preservation may remain test-backed if the current
proof representation cannot express the full state without a toy duplicate.

INPUT CONTRACT: validated catalog and individual state, a complete command
barrier, valid M4/M5 snapshots, two available source records, explicit RNG and
stable action sequence.

OUTPUT CONTRACT: accepted queued mix with both reservations; committed action
with both deadlines, one M4/M5 result, ordered semantic events and optional
observation/Harmony deltas; or unchanged rejection/fault. Cancellation releases
both for free. Invalid-target execution fizzles, charges both and applies normal
recovery without observation or RNG consumption.

IMPLEMENTATION NOTES: construct and validate an immutable `MixPlan` before
mutation. Extend the existing batch reservation API for two requests. Add a
batch charge function that computes both deadlines before changing either
source. Enter the M4 action boundary exactly once and pass the registered M5
component result through its existing aggregate damage seam.

EDGE CASES: one unavailable/reserved source; duplicate source request; odd/even
cooldowns; 3600→5400 maximum; deadline overflow; cancellation; fizzle; miss;
all-blocked effects; full-HP heal; same-action KO; battle completion; escape or
loss after success; critical bonus clamping.

TESTS REQUIRED: runtime and replay Bend goldens for success, reversed pair,
miss observation, cancellation, fizzle, both arithmetic boundaries, blocked
effect, full heal, Harmony threshold and terminal merge.

PROOF OBLIGATIONS: accepted eligibility implies both known/available/learned;
mixed duration formula and bound; batch charge cannot expose a one-source
commit; registered descriptor identity is preserved into execution.

ACCEPTANCE CRITERIA: M4/M5 baselines remain byte-identical where M6 is unused;
M6 runtime/replay outputs match native and JavaScript; no draw-count changes;
all rejection/cancellation/fizzle state and RNG rules match the frozen contract.

## M6-D — fixtures, proof gate, CI and review

TASK: M6-D independent verification and formal closeout.

OWNER MODEL: Luna fixture agent plus a separate Luna reviewer who did not own
M6-C.

DEPENDENCIES: M6-A–C complete.

FILES ALLOWED TO CHANGE: `tests/m6/**`, additive `LAWS.bend` and `PROOF.bend`
entries tied to production APIs, `scripts/verify.py`, M6 status documents,
`PLAN.md` and `README.md` after the milestone passes.

FILES FORBIDDEN TO CHANGE: production behavior merely to satisfy an oracle;
approved decisions/law semantics; prior fixture expectations without a proven
pre-existing defect.

GOAL: demonstrate every MIX-1–8, LEARN-1–3 and HARM-1–3 behavior, exact replay
and cross-target determinism, and absence of regression through the full gate.

NON-GOALS: implementing missing runtime behavior, weakening laws, publishing a
content ruleset, or claiming UI/persistence work from core fixtures.

ENGINE INVARIANTS AFFECTED: all M6 candidate laws and prior milestone gates.

LAWS AFFECTED: adopt only claims connected to production functions and paired
with legal positive witnesses.

INPUT CONTRACT: versioned fixtures with exact IDs, state, commands, RNG and
expected canonical events/state.

OUTPUT CONTRACT: deterministic diagnostics and canonical golden output;
byte-identical native/JavaScript execution; full local and hosted gate evidence.

IMPLEMENTATION NOTES: create `tests/m6/fixtures/index.json`, a strict loader,
Python exact oracle, Bend production golden and cross-target runner. Register
M6 after M5 in `scripts/verify.py`; use the established 180-second allowance
only where differential compilation needs it.

EDGE CASES: every case listed in M6-A–C plus malformed fixtures, duplicate
event delivery and ruleset/content identity mismatch.

TESTS REQUIRED: recipe, eligibility, runtime, observation/training/Harmony,
replay, fixture-oracle, native/JavaScript differential and complete repository
verification.

PROOF OBLIGATIONS: run the canonical `./scripts/bend PROOF.bend` gate and audit
each new law for real production linkage, satisfiable premises and positive
witnesses.

ACCEPTANCE CRITERIA: all prior and M6 checks pass locally; independent Luna
contract/code review has no unresolved finding; branch is pushed; hosted Ubuntu
CI passes the same gate; M6 status records exact check count, commit and run URL.

Reviewer and evidence links: to be filled only after implementation and hosted
verification.

Escalation: implementation defects are fixed within these contracts. Any change
to the approved decisions, law meaning, RNG schedule, M4/M5 ownership or
`m6-1` semantic identity requires explicit owner approval before code changes.
