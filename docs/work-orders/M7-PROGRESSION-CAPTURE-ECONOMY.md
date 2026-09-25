# M7 progression, capture and economy work orders

Status: implemented locally; hosted verification is linked in
`docs/architecture/M7-PROGRESS.md`. This package is the M7 contract under
approved D11–D13 and U06–U08 in `docs/DECISIONS.md`, with constants in
`docs/RULES.md`. M6 remains the verified baseline. New semantics use an exact
`m7-1` ruleset identity when M7 lands; existing `m6-1` replays retain theirs.

The work orders below have separate file ownership so Luna agents can build
pure cores in parallel. Shared battle integration has one owner after those
APIs are stable. No project content may provide executable code or change the
engine's formulas, type registry, RNG, hard ceilings, or transaction ordering.

## M7-A — progression, evolution and learning

TASK: implement level 1–200 progression and individual growth.
OWNER MODEL: Luna implementation agent.
DEPENDENCIES: M3 individual identity and M6 learning state; D11/U06.
FILES ALLOWED TO CHANGE: new `engine/progression/**`, new `tests/m7/progression*`.
FILES FORBIDDEN TO CHANGE: shared battle runtime, economy/capture cores,
creator code boundary and prior replay semantics.

GOAL: ship the exact 200-entry cumulative XP table, bounded stat formulas,
level-up HP delta, ordered evolution predicates, move-learning choice barrier,
and atomic battle reward preparation.
NON-GOALS: world UI, content editor, save installation and automatic evolution
unless an authored rule explicitly marks it automatic.
ENGINE INVARIANTS AFFECTED: PROG-1, identity retention and reward atomicity.
LAWS AFFECTED: threshold monotonicity, level cap, HP-delta preservation, and
rejected transaction identity.
INPUT CONTRACT: validated species growth data, level/XP/individual values,
ordered evolution rules (at most four AND predicates), current moves and
learning history, and eligible defeated-opponent reward records.
OUTPUT CONTRACT: checked unchanged rejection or one complete next individual
state; XP caps at level 200; evolution preserves identity, XP, observations,
unlocks and Harmony; full move slots pause at an explicit choice barrier and
declining is recorded. Victory/Capture rewards are prepared once; Loss, Draw,
Timeout and Escape yield none.
IMPLEMENTATION NOTES: the shipped threshold table is canonical. Generate and
check all 200 entries against `25*(L-1)^3+75*(L-1)` without runtime floating
point. Base stats are 1–500, individual values 0–31, effective stats 1–9999.
XP award to each eligible living or previously active participant is
`floor(baseXpYield * defeatedLevel / eligibleParticipantCount)`; currency is
summed once per encounter.
EDGE CASES: levels 1/200, exact thresholds, capped XP, overflow, HP increase,
full move slots and decline, duplicate reward delivery, invalid evolution
predicates and first valid EvolutionRuleId ordering.
TESTS REQUIRED: generated 200-entry threshold/stat checks, boundary fixtures,
transaction rejection, evolution and learning preservation, native/JS equality.
PROOF OBLIGATIONS: production-linked table bounds, cap and rejection witnesses.
ACCEPTANCE CRITERIA: all pure fixtures pass; no identity or reward duplication;
independent review finds no unresolved defect.

## M7-B — capacity tiers, inventory and shops

TASK: implement bounded capacity and economy transactions.
OWNER MODEL: Luna implementation agent, parallel with M7-A.
DEPENDENCIES: D13/U08 and engine resource limits.
FILES ALLOWED TO CHANGE: new `engine/economy/**`, new `tests/m7/economy*`.
FILES FORBIDDEN TO CHANGE: shared battle runtime, progression/capture cores and
unrelated content schemas.

GOAL: validate at most 16 monotone creator-authored capacity tiers and perform
atomic item, party/storage, currency, buy, sell and reward transactions.
NON-GOALS: shop UI, unbounded storage or caller-authored sell prices.
ENGINE INVARIANTS AFFECTED: INV-1 and CAP-1 destination capacity.
LAWS AFFECTED: bounded capacities, conservation and unchanged rejection.
INPUT CONTRACT: validated tier table and selected tier, owned roster/storage,
bounded item stacks/entries and currency, catalog item price and transaction.
OUTPUT CONTRACT: complete validated next state or exact unchanged rejection.
Defaults are party 6, moves 4, storage 1000, stack 999, entries 512 and
currency 9,999,999. Hard ceilings are 12, 8, 10000, 9999, 4096 and
999,999,999 respectively. Buy price is 0–1,000,000; zero is unavailable;
sell value is `floor(buyPrice/2)` unless unsellable. A tier downgrade below
current occupancy rejects. Captured individuals route party first, then storage.
IMPLEMENTATION NOTES: validate full projected results before mutation. Capacity
overrides participate in content identity. Bound arithmetic before add/multiply
and keep deterministic item/individual ordering.
EDGE CASES: exact/full capacities, distinct-entry limit, stack split/overflow,
currency overflow, zero-price item, unsellable item, tier downgrade, duplicate
individual, insufficient balance and item quantity.
TESTS REQUIRED: transaction matrix, hostile boundary fixtures, native/JS
goldens and unchanged-input rejection checks.
PROOF OBLIGATIONS: production-linked atomic rejection and capacity witnesses.
ACCEPTANCE CRITERIA: no partial grant/discard or arbitrage-producing sell
override; independent review finds no unresolved defect.

## M7-C — capture calculation and eligibility

TASK: implement the pure capture action plan and chance calculation.
OWNER MODEL: Luna implementation agent, parallel with M7-A/B.
DEPENDENCIES: M3 RNG/action boundary, M7-B destination API, D12/U07.
FILES ALLOWED TO CHANGE: new `engine/capture/**`, new `tests/m7/capture*`.
FILES FORBIDDEN TO CHANGE: shared battle runtime until M7-D, progression and
economy transaction implementations.

GOAL: reject restricted or impossible captures before item consumption and
compute an exact bounded chance for legal wild targets.
NON-GOALS: arbitrary capture scripts or a new RNG algorithm.
ENGINE INVARIANTS AFFECTED: CAP-1, DET-1 and atomic ownership.
LAWS AFFECTED: chance clamp, pre-accept rejection and one-destination result.
INPUT CONTRACT: species capture rate 500–9000, exact item multiplier 1/2–4,
status, target current/max HP, target ownership/restrictions, item availability,
legal party/storage destination and explicit RNG state.
OUTPUT CONTRACT: checked rejection before acceptance, or a capture plan with
`clamp(floor(captureRate * itemMultiplier * statusMultiplier *
(3*maxHP-2*currentHP)/(3*maxHP)),100,9500)`. Sleep/stun multiplier is 2;
burn/poison/blind is 3/2; otherwise 1. Chance uses the shared 0–10000 scale
and unbiased `[0,10000)` draw. Success owns exactly one new individual and
selects party before storage; failure consumes one item/action/recovery.
IMPLEMENTATION NOTES: use checked exact integer arithmetic with one final
floor. Trainer-owned, boss and explicitly uncapturable targets reject.
EDGE CASES: full/1 HP, min/max rate and multiplier, status combinations,
zero/full destination, invalid item, draw exactly at the threshold, overflow.
TESTS REQUIRED: formula/reference table, rejection and RNG draw-count goldens,
native/JS equality.
PROOF OBLIGATIONS: production-linked bound and threshold witnesses.
ACCEPTANCE CRITERIA: no pre-accept item loss or duplicate capture; independent
review finds no unresolved defect.

## M7-D — battle, rewards and content integration

TASK: integrate M7-A/B/C into the production battle and content boundaries.
OWNER MODEL: one Luna integration agent with exclusive shared-file ownership.
DEPENDENCIES: reviewed M7-A/B/C APIs.
FILES ALLOWED TO CHANGE: smallest necessary additive battle/replay/content
modules, M7 integration tests and corresponding versioned host schemas.
FILES FORBIDDEN TO CHANGE: M3 scheduler ordering, M4 effect semantics, M5
damage math, M6 mixed command behavior and the RNG algorithm.

GOAL: submit capture as one battle action, consume one eligible item only at
attempted execution, commit exactly one owned individual on success, remove
the target and run normal reinforcement/completion ordering. Commit XP,
currency, item rewards and level-up/learning changes atomically after eligible
Victory/Capture outcomes. Resolve inventory/shop/party transfers through the
same bounded transaction APIs. Load creator-authored species yields, capture
rates, evolution/learning entries, item data, shops and capacity tiers as inert
validated content.
NON-GOALS: map/shop visual UI, save-anywhere and user-authored executable code.
ENGINE INVARIANTS AFFECTED: DET-1, CAP-1, INV-1, PROG-1 and replay identity.
LAWS AFFECTED: accepted-action effect, exact draw count, terminal reward gate
and atomic transaction preservation.
INPUT CONTRACT: validated M7 catalogs, exact `m7-1` identity, battle state,
explicit RNG and complete command barrier.
OUTPUT CONTRACT: deterministic canonical events/state or unchanged rejection;
no reward on Loss/Draw/Timeout/Escape and no duplicate action/item/capture.
IMPLEMENTATION NOTES: calculate complete post-state before committing; keep
M3–M6 baselines byte-identical when M7 is unused. Content remains inert data.
EDGE CASES: failed capture, target invalidation, full party/storage, same-action
completion, reinforcement after capture, replayed completion and reward
overflow.
TESTS REQUIRED: battle/replay native/JS goldens, content hostile-input suite,
transaction failure matrix, exact identity mismatch and M0–M6 regressions.
PROOF OBLIGATIONS: production-linked capture/reward transaction laws.
ACCEPTANCE CRITERIA: full production path passes local and hosted CI with no
unresolved independent review finding.

Integration handoff notes: `engine/capture/core.bend` returns a checked plan;
`engine/battle/runtime.bend` currently has an additive attempted-capture
transaction, while queued `RuntimeCapture` and persistent owner state are in
progress. `engine/economy/core.bend` handles bounded count/currency/item
transactions; an identity ledger is required for party/storage uniqueness.
`engine/progression/core.bend` prepares encounter rewards and applies one
individual's XP with HP delta; M7-D must combine all participants, currency and
every encounter item reward as one commit. If any step rejects, the original
ledger, owned individuals, inventory and battle state must remain unchanged.
No prepared reward may be replayed after encounter completion.

## M7-E — fixtures, proof gate and formal closeout

TASK: verify every M7 contract and publish milestone evidence.
OWNER MODEL: Luna fixture agent and separate Luna reviewer.
DEPENDENCIES: M7-A–D complete.
FILES ALLOWED TO CHANGE: `tests/m7/**`, additive `LAWS.bend`/`PROOF.bend`,
`scripts/verify.py`, M7 status docs, `PLAN.md` and `README.md`.
FILES FORBIDDEN TO CHANGE: approved decision semantics or prior expected
outputs without a demonstrated pre-existing defect.

GOAL: prove M7 behavior at its actual production boundaries and preserve all
earlier milestone gates.
NON-GOALS: calling pure cores or host metadata alone a playable M7 feature.
ENGINE INVARIANTS AFFECTED: all M7 and previous milestone laws.
LAWS AFFECTED: add only production-linked claims with legal witnesses and
clearly stated quantified scope.
INPUT CONTRACT: exact fixtures for levels, species, items, tiers, party/storage,
battle commands, RNG and expected canonical events/state.
OUTPUT CONTRACT: deterministic diagnostics, native/JS equality and actionable
rejections; exact `m7-1` save/replay identity without reinterpreting M6 records.
IMPLEMENTATION NOTES: register M7 after M6 in the canonical gate. Run
`./scripts/bend PROOF.bend` before commits. Record the exact final check count,
commit and hosted run URL in the M7 status file.
EDGE CASES: every M7-A–D boundary, malformed content, duplicate event
delivery, capacity downgrade and cross-version replay mismatch.
TESTS REQUIRED: pure, generated, hostile-input, integration, replay and full
repository verification, plus independent Luna contract/code review.
PROOF OBLIGATIONS: audit each new law for production linkage, satisfiable
premises and positive witnesses.
ACCEPTANCE CRITERIA: all M0–M7 checks pass locally and in hosted Ubuntu CI;
independent review has no unresolved finding; `master` is pushed and clean.

Reviewer and evidence links: pending M7 implementation.
Escalation: implementation defects stay within this contract. Any change to
approved decisions, law meaning, RNG schedule or prior replay identity needs
explicit owner approval before implementation.
