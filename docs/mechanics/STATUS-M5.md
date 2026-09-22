# M5 mechanics status

The M5 resolver accepts power 1–200, one to four distinct authored `TypeId`s, a captured one-or-two-type actor snapshot, a current one-or-two-type defender snapshot and the relevant level/attack/defense profile. Canonical registry rank assigns remainder points; result events retain authored component order.

For each component it keeps the approved base damage ratio, every U04 defender interaction and exact `3/2` STAB as one rational value, then floors once. Component results are summed with a checked U32 boundary. A zero allocation remains zero, there is no hidden minimum, and the initial chart contains no immunity. The algebra retains an explicit immune result for later engine-owned chart versions and proves that such a component contributes zero independently.

The resolver is pure and consumes no RNG. The established M4 transaction owns one action-level accuracy draw and, for a successful nonimmune damaging attempt, one aggregate critical draw. Critical doubles the resolved aggregate once; it is never sampled per component.
