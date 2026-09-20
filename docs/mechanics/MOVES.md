# Proposed moves and effect algebra

Fixed: moves use engine-defined primitives; attacks have a nonempty generic list of damage/type components; each component resolves its own interactions. No move-name branches and no creator code.

## Closed algebra proposal

A move contains an ordered, bounded sequence of typed effect nodes. Authoring JSON maps to tagged nodes, never function names. Predicates are closed tags over explicit current action/state values; no expression strings. Every node has a stable serialized tag and version. Payload bounds, permitted targets, status/stack policies and total execution cost are checked before runtime.

| Family | Inputs / targets | Proposed order and stacking | Failure / validation |
|---|---|---|---|
| Damage | approved power/category; nonempty components; legal target selector | explicit component order; resolve before subsequent effects; HP clamps at zero | reject empty types, unknown refs, invalid arithmetic; immunity is a zero contribution |
| Heal / Drain / Recoil | bounded engine-approved magnitude or fraction; self/target | Heal clamps to max HP; Drain/Recoil consume recorded actual damage from a named earlier node | forward/cyclic damage refs rejected; zero damage gives zero derived amount |
| ApplyStatus / RemoveStatus | engine StatusId and legal duration/target | stack policy defined per status in ruleset | ineligible application emits explicit NoEffect; unknown status rejected |
| ModifyStat | finite stat selector and bounded stage delta | saturate at engine stage bounds | invalid stat rejected; no arbitrary numerical expressions |
| Conditional | typed predicate, bounded then/else sequences | branch reads state at this node; ordered depth-first resolution | bounded depth/cost; absent data uses defined false/error semantics per predicate |
| MultiHit | bounded count/profile, permitted damage subtree | successive hits resolve in declared order, stop on invalidated target under D03 | no recursive MultiHit; RNG draw schedule explicitly versioned |
| Protect / Trap / Charge / Recovery / Priority / CooldownModifier | approved behavior tags and bounded data | engine timing/status stage only; cannot reschedule arbitrary functions | source reservation and minimum timing invariants preserved; D04 approves combinations |
| Weather / Terrain / Hazards | closed field tags, side/location, duration | engine-defined replacement/stack ordering | unsupported combinations rejected |
| ForceSwitch / ChangeType / ChangeAbility / CopyMove / DelayedEffect | approved finite reference/selection tags | late milestone extensions only after dedicated ordering/expiry rules | rejected as unsupported until rules/proofs exist; never accepted inertly |

M3 gets only the minimal approved operation needed for a test battle. M4 grows the supported algebra to representative physical/special/status/healing/buff/debuff/conditional moves. Deferred tags are not advertised in the initial accepted schema. For every enabled tag, Sol must implement its typed input contract, exact ordering/stacking/failure table, serialization, validator, proof impact and tests before acceptance.

## Split-type proposal (D07)

Equal components only in initial authoring. For total integer power P and N components, recommend `q = floor(P/N)` and `r = P mod N`; allocate `q+1` to the first r components in canonical TypeId order, and q to the rest. Thus allocations sum to P, including P < N; no component is forced to minimum one. Recommend reject duplicate TypeIds initially. N is generic but bounded by an engine resource cap (not a hard-coded two).

Example allocation only: P=100,N=3 gives 34,33,33 in canonical order. This is not a finalized damage formula. Each component independently applies its type interaction, immunity, STAB eligibility, ability/weather/terrain and approved modifiers. Proposed rational modifiers use checked wide/intermediate arithmetic, with floor once at the end of each component and final damage equal to the sum. Applying an additive base-damage term per component would inflate damage; recommend allocate the base attack budget once before modifiers, with the exact base formula decided in D04. Zero-power/immune components remain zero. No hidden final minimum damage.

STAB proposal: apply only to components whose TypeId matches an actor type, once per component, with an owner-approved multiplier (D08). Accuracy/crit draws per action versus per component remain D04 decisions; recommend one shared hit and crit decision per action with component-local eligibility/modifiers. Arbitrary weights are not exposed. A future weighted schema needs ruleset/version review and a new allocation law.

No numeric damage, effectiveness chart, accuracy, critical, STAB or capture constants are finalized in this document.
