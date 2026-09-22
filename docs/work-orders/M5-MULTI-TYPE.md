# M5 multi-type attack work order

TASK: M5-A generic multi-type component allocation and damage modifiers.
OWNER MODEL: Luna implementation agent.
DEPENDENCIES: completed M4 effect/runtime boundary; approved D04, D07 and D08.
FILES ALLOWED TO CHANGE: engine/battle/multi_type.bend, additive M5 laws and mechanics documentation, and M5 fixtures when assigned.
FILES FORBIDDEN TO CHANGE: approved M4 effect/status semantics, scheduler ordering, RNG draw policy, and creator-code prohibition.

GOAL: provide a bounded closed algebra for one to four distinct TypeIds,
canonical quotient/remainder power allocation, independent type interaction and
STAB modifiers, immunity as a zero contribution, and checked deterministic
component aggregation.

NON-GOALS: type-chart authoring, weighted components, multihit, nested effects,
new RNG draws, or renderer/UI work.

ENGINE INVARIANTS AFFECTED: DMG-1, DMG-2, D07/D08 component semantics, and the
M4 single accuracy/critical transaction boundary.

INPUT CONTRACT: a total move power in 1–200, one to four distinct engine-owned
TypeIds in authored order, and accepted actor/defender type snapshots containing
one or two distinct registry types. The U04 chart is engine-owned.

OUTPUT CONTRACT: allocations remain in authored order while canonical TypeId
rank controls remainder ownership. Their sum equals total power; each component
resolves the engine chart, local STAB and one final floor independently. Final
damage is a checked sum or typed rejection, with no state/RNG mutation.

EDGE CASES: empty and five-component inputs, duplicate/unknown TypeIds, power
smaller than component count, future immunity, duplicate actor types, STAB at
one matching actor type, exact-rational zero damage and aggregate overflow.

PROOF OBLIGATIONS: allocation quotient/remainder conservation, canonical
remainder placement, distinct-type validation, independent immunity zeroing,
single-match STAB, and deterministic checked aggregation.

ACCEPTANCE CRITERIA: changed Bend entries check with the pinned compiler,
`bend PROOF.bend` passes after laws are registered, and native/JavaScript M5
fixtures agree. M5 must not alter M4 accuracy, critical, status, or runtime
draw scheduling.
