# M4 effect and status contract

Status: implemented for ruleset 1 on 2026-09-22. This table closes the M4 implementation details required by D04 and U05; projects select these engine tags and cannot redefine their behavior.

## Interpreter boundary

An `EffectProgram` has 1–16 top-level nodes and a validated total cost of at most 64 nodes. The enabled leaves are physical or special `Damage`, fixed `Heal`, actual-damage `Drain` and `Recoil`, `ApplyStatus`, named `RemoveStatus`, `ClearStatuses`, and bounded `ModifyStat`. A `Conditional` reads current transaction state at its position and selects one ordered leaf sequence. Ruleset 1 permits at most one damage node, requires it to be the first top-level node, and forbids damage inside conditional branches. It does not admit nested conditionals. These restrictions make every named damage reference dominate its use, keep termination structural, and preserve the approved single accuracy/critical draw schedule; later recursion or multihit requires a ruleset change.

Damage power is 1–200. Fixed healing is 1–9999. Drain and recoil fractions use numerator and denominator 1–16, floor once, and name a unique earlier damage node. `PriorDamagePositive` conditionals use the same backward-only rule and must name an already-seen damage node. Stage deltas are 1–6 and saturate at −6…+6. Validation counts both conditional branches, rejects forward or duplicate damage references, and runs before RNG or state mutation. A rejected program and an RNG fault return the original world and RNG.

Every valid action performs one move-level accuracy gate. Ordinary nondamaging actions consume one accuracy sample and never roll critical; always-hit nondamaging actions consume neither. The first damage node owns the same gate and its critical draw. A miss stops the effect sequence. Effects otherwise resolve in author order. Damage records actual HP removed after saturation. Drain and recoil consume that value; zero actual damage produces an explicit `ZeroDerived` result. Healing uses overflow-safe room calculation and clamps at max HP. Protection and status immunity run before status conflict handling. Gameplay `NoEffect` outcomes do not roll back earlier valid nodes, while engine faults roll back the whole action transaction.

## Status table

Durations count the affected actor's completed action opportunities. The opportunity transition determines whether sleep or stun blocks the opportunity, applies residual aftermath, then decrements every active duration and removes entries that reach zero. A battle driver must not invoke aftermath after battle completion.

| Status | Initial / legal remaining duration | Canonical magnitude and stronger comparison | Active behavior | Default immunity | Incompatibility |
|---|---:|---|---|---|---|
| Burn | 3 / 1–3 | `max(1,floor(maxHP/16))`; larger residual is stronger; stored magnitude is bounded so duration × magnitude fits U32 | Fully resolved normal physical damage is multiplied by 3/4 with one floor before critical doubling; stored residual damage after each opportunity | none | Poison; new status replaces only when its duration × magnitude exceeds the remaining incumbent value, otherwise `NoEffect` |
| Poison | 4 / 1–4 | `max(1,floor(maxHP/8))`; larger residual is stronger; stored magnitude is bounded so duration × magnitude fits U32 | Stored residual damage after each opportunity | none | Burn; same expected-residual comparison |
| Sleep | 2 / 1–2 | 0; equal | Blocks each remaining opportunity | none | Stun; the newer application replaces |
| Stun | 1 / 1 | 0; equal | Blocks the next opportunity | none | Sleep; the newer application replaces |
| Blind | 3 / 1–3 | 2 Accuracy stages; larger stage penalty is stronger | Captured Accuracy is lowered by two stages with normal saturation | none | independent |

A target has at most one active instance of a named status. Reapplication restores the canonical duration and retains the larger stored magnitude. Named cleanse removes all instances of that name; full cleanse is a separate node. The engine accepts an explicit immunity list for future engine-owned sources, but ordinary actors start with an empty list. Protection or immunity emits an observable `NoEffect`, allowing the UI to explain why the application did nothing.

## Runtime use

`engine/battle/effects.bend::run` is the canonical pure effect transaction. `Effects.attempt` is wired into the normal runtime through `RuntimeEffectMove`: submission canonically captures Burn and Blind, reservation preserves that snapshot, execution blocks sleep/stun before accuracy, runs the program once, commits HP/status/RNG/events, and applies opportunity aftermath/expiry while battle continues. Burn floors resolved normal physical damage at 3/4 before critical doubling; Blind lowers captured Accuracy by two stages. Runtime and replay rejection retain effect diagnostics. M5 supplies typed damage components and their type modifiers without changing this transaction boundary.
