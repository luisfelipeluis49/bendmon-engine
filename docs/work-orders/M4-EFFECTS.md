# M4 closed effect algebra work order

TASK: M4-A closed effect interpreter and status lifecycle.
OWNER MODEL: primary architecture-capable agent.
DEPENDENCIES: completed M3 deterministic battle/RNG runtime; approved D04 and U05 stacking, failure, draw and status semantics.
FILES ALLOWED TO CHANGE: engine/battle/effects.bend, tests/battle/effects_test.bend, M4 mechanics/status documentation, additive production-linked laws and verification registration.
FILES FORBIDDEN TO CHANGE: approved formulas, M3 scheduler ordering, RNG transition/draw policy, creator executable-code prohibition.

GOAL: implement a bounded typed interpreter for representative physical, special, heal, actual-damage drain/recoil, status, cleanse, buff/debuff and conditional moves, including the initial status lifecycle.

NON-GOALS: multihit, multi-type component allocation/modifiers, authored move JSON schema, arbitrary predicates, nested conditionals, renderer/UI implementation.

ENGINE INVARIANTS AFFECTED: DET-1, VAL-1, HP-1, the D04 effect/status transaction.

LAWS AFFECTED: additive effect determinism, stage saturation, status catalog and burn modifier laws.

INPUT CONTRACT: a prevalidated closed `EffectProgram`, two valid effect actors, an accepted offensive snapshot and explicit xoshiro state.

OUTPUT CONTRACT: one committed world/RNG with ordered semantic events and actual-damage records, unchanged rejection, or unchanged atomic RNG fault.

IMPLEMENTATION NOTES: 16 top-level nodes, 64-node total validation cost, one damage node, conditional leaf branches, sequential commit, no host callbacks. Independent native/JavaScript builds must match.

EDGE CASES: zero rounded damage, HP saturation, heal at full HP, zero derived amount, forward reference, invalid fraction, duplicate damage ID, protected/immune status, weaker burn/poison conflict, refresh with stronger magnitude, stage saturation, sleep/stun replacement, blind modifier, lethal residual, invalid RNG.

TESTS REQUIRED: production golden covering every enabled family, ordering and conditional current-state read; unchanged rejection/fault; lifecycle boundaries; native/JavaScript differential execution.

PROOF OBLIGATIONS: pure interpreter determinism; +6 saturation; fixed catalog duration; exact burn multiplier. HP and order remain exercised by concrete transaction goldens pending stronger universal preservation lemmas.

ACCEPTANCE CRITERIA: changed Bend entries check, `bend PROOF.bend` passes, repository verification passes, native/JavaScript effect goldens agree, and a separate review finds no decision drift.

Reviewer and evidence links: `docs/architecture/M4-STATUS.md`.
Escalation: semantic changes require owner approval; implementation defects are corrected without changing the approved rules.
