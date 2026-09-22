# M4 effect algebra status

Status: complete and verified locally and through hosted Ubuntu CI on 2026-09-22.

## Implemented

- A closed, version-bounded Bend effect algebra with physical/special damage, fixed healing, actual-damage drain/recoil, status application/removal/full cleanse, seven finite stat selectors, saturating deltas and current-state conditionals.
- Preflight validation for the 1–16 top-level bound, 64-node total cost, one damage node, power/heal/fraction/stage bounds, duplicate IDs and backward-only actual-damage references.
- A pure sequential interpreter with one action-level accuracy gate. Nondamaging moves consume ordinary accuracy without critical checks; damage must be first and a miss stops later effects. It delegates damage math/RNG to the M3 production resolver, reads execution-time defense/evasion, emits ordered semantic events and preserves the original world/RNG on rejection or engine fault.
- Actual HP loss records after saturation, so drain/recoil cannot use nominal overkill damage. Full-HP healing, zero derived amounts, zero damage, protection, immunity, absent cleanse and weaker conflicts are observable `NoEffect` results.
- The complete initial status registry: canonical durations/magnitudes, stronger refresh, burn/poison expected-residual comparison, sleep/stun replacement, independent blind, protection/immunity ordering, named/full cleanse, resolved-physical-damage burn and Accuracy blind modifiers, action blocking, residual aftermath and expiry. Incoming incompatible or out-of-catalog status state rejects.
- `RuntimeEffectMove` carries validated programs through the normal command, reservation, scheduler, reducer and replay path. Acceptance canonically captures Burn and Blind from engine-owned status state. Execution commits HP, statuses, RNG, cooldown/recovery, ordered semantic events and opportunity aftermath atomically. Typed rejection preserves creator-facing effect diagnostics. The scalar M3 adapter remains compatible and synchronizes HP into the effect world when both paths are used.
- Additive production-linked laws for effect determinism, stage saturation, the burn duration registry and exact burn multiplier.

## Verification

- `tests/battle/effects_test.bend` covers 28 production behaviors across every enabled family, move-level accuracy, miss short-circuiting, ordered state visibility, branch reference dominance, burn damage, overflow boundaries, status conflicts/lifecycle, runtime blocking, invalid incoming state, rejection and fault atomicity.
- `tests/battle/runtime_effect_test.bend` exercises the queued production path: model/effect-world HP synchronization, semantic events, unchanged nondamaging RNG, exact rejection diagnostics, sleep blocking and aftermath, acceptance-time Burn/Blind capture through real submission and scalar/effect compatibility. `tests/replay/runtime_effect_fold_test.bend` proves the exact effect diagnostic survives replay folding.
- `tests/battle/test_effects_cross_target.py` compiles the same production golden to native and JavaScript and requires byte-identical output.
- `python3 scripts/verify.py` passes 137 local checks, including the proof gate, native/JavaScript boundaries, runtime/replay goldens and content validation.
- An independent Luna review found four runtime integration defects and two follow-up coverage gaps. The final focused re-review found no remaining semantic defect; all six items are fixed and covered before the push.
- Hosted Ubuntu verification passed the same 137-check gate in [GitHub Actions run 35686502069](https://github.com/luisfelipeluis49/bendmon-engine/actions/runs/35686502069).

## Milestone boundary

M4 owns the action-effect transaction and status lifecycle. M5 adds generic nonempty type components, allocation, STAB and type interaction to damage resolution. Multihit and nested conditionals remain unavailable until their draw schedule and bounded recursion receive a later ruleset review.
