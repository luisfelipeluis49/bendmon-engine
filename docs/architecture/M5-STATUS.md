# M5 multi-type attack status

Status: complete and verified locally and through hosted Ubuntu CI on 2026-09-22.

## Implemented

- A closed ten-entry engine type registry (`Neutral`, `Ember`, `Tide`, `Verdant`, `Stone`, `Gale`, `Spark`, `Frost`, `Radiant`, `Umbral`) and the approved U04 ordered strong/resisted chart. Project content cannot supply ratios or replace the chart.
- One to four distinct authored type components with power 1–200. Quotient/remainder allocation uses canonical numeric `TypeId` rank, while resolved component diagnostics retain authored order. Budgets smaller than the component count preserve legal zero allocations.
- Exact natural-number intermediates for the complete base formula, multiplicative dual-defender interaction and exact `3/2` component-local STAB. Each component floors once at the end of its chain; aggregation checks the U32 boundary.
- Accepted actor and defender type snapshots contain one or two distinct registered types. STAB applies once when any accepted actor type matches, without duplicate stacking.
- Typed allocation and resolution rejections, component-local power/damage/immunity/STAB diagnostics, and a pure API that neither owns nor consumes RNG. M4 continues to own the single action accuracy/critical schedule and transaction boundary.
- Production-linked DMG-1 allocation and DMG-2 immunity laws in the canonical proof gate.

## Verification

- `tests/m5/multi_type_test.bend` exercises the production resolver for multiplicative dual-defense interactions, authored output order, canonical remainder ownership, `P < N`, exact one-floor zero damage, single-match STAB and invalid snapshots.
- The fixture corpus covers one, two, three and four components, engine-chart boundaries and invalid shapes. Its Python oracle uses the same exact base formula and performs no intermediate flooring.
- `tests/m5/test_cross_target_multitype.py` builds the production golden to native and JavaScript and requires byte-identical output.
- `LAWS.bend` and `PROOF.bend` call production allocation and component-resolution functions; `scripts/verify.py` includes the M5 golden and complete M5 fixture/cross-target suite.
- `python3 scripts/verify.py` passes 140 checks locally, including every prior milestone gate.
- Two independent Luna reviews covered the approved contract, implementation and documentation. Final code review found one invalid public zero-denominator path; production interaction validation and a native/JavaScript golden now cover the fix. Documentation review found stale top-level status claims; the README now reflects the completed battle/effect milestones and current M5 state.
- Hosted Ubuntu verification passed the same 140-check gate in [GitHub Actions run 35708193300](https://github.com/luisfelipeluis49/bendmon-engine/actions/runs/35708193300). The first hosted attempt exposed only the M5 interpreter golden's runner-time allowance; the final gate uses the same bounded 180-second allowance already established for slow differential compilation.

## Milestone boundary

M5 owns deterministic typed allocation and normal-damage aggregation. It does not add RNG draws, critical policy, multihit, creator-defined charts or arbitrary modifiers. M4 remains the owner of action accuracy, aggregate critical handling and atomic effect execution. M6 consumes this component algebra for explicit mixed recipes and supplies the authored move/recipe integration path.
