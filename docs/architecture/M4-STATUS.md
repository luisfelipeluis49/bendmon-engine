# M4 effect algebra status

Status: implementation complete; verification evidence is recorded below when the milestone gate finishes.

## Implemented

- A closed, version-bounded Bend effect algebra with physical/special damage, fixed healing, actual-damage drain/recoil, status application/removal/full cleanse, seven finite stat selectors, saturating deltas and current-state conditionals.
- Preflight validation for the 1–16 top-level bound, 64-node total cost, one damage node, power/heal/fraction/stage bounds, duplicate IDs and backward-only actual-damage references.
- A pure sequential interpreter that delegates damage accuracy/critical math and RNG to the M3 production resolver, reads execution-time defense/evasion, emits ordered semantic events and preserves the original world/RNG on rejection or engine fault.
- Actual HP loss records after saturation, so drain/recoil cannot use nominal overkill damage. Full-HP healing, zero derived amounts, zero damage, protection, immunity, absent cleanse and weaker conflicts are observable `NoEffect` results.
- The complete initial status registry: canonical durations/magnitudes, stronger refresh, burn/poison expected-residual comparison, sleep/stun replacement, independent blind, protection/immunity ordering, named/full cleanse, physical burn and Accuracy blind modifiers, action blocking, residual aftermath and expiry.
- Additive production-linked laws for effect determinism, stage saturation, the burn duration registry and exact burn multiplier.

## Verification

- `tests/battle/effects_test.bend` covers 16 production behaviors across every enabled family, ordered state visibility, status conflicts/lifecycle, invalid incoming status state, rejection and fault atomicity.
- `tests/battle/test_effects_cross_target.py` compiles the same production golden to native and JavaScript and requires byte-identical output.
- Final local repository and hosted CI counts are added after their successful runs.

## Milestone boundary

M4 owns the action-effect transaction and status lifecycle. M5 adds generic nonempty type components, allocation, STAB and type interaction to damage resolution. Multihit and nested conditionals remain unavailable until their draw schedule and bounded recursion receive a later ruleset review.
