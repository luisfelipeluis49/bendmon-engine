# M3 battle implementation status

Status: the first deterministic M3 vertical slice is implemented and locally verified. M3 is not complete.

## Implemented

- Closed Bend battle types for stable actor IDs, sides, Ready/Windup/Recovery/Defeated phases, commands, event keys, queued events, terminal outcomes and typed diagnostics.
- Atomic grouped command submission against one unchanged barrier snapshot. Command input order is normalized by ActorId; incomplete, stale, invalid-target, cooldown, timing and deadline failures return the original state.
- Engine-owned Wait choices of 30, 60 or 120 ticks, with a checked 216000-tick clock cap.
- Fixed-width `U32` battle clocks and durations. Deadline validation checks the remaining range before addition, so scheduling cannot wrap.
- The approved event-key prefix: due tick, phase rank, priority rank, captured speed descending, ActorId, action sequence and event ordinal.
- A minimal deterministic damage operation sufficient to exercise execution, recoil, HP saturation, Recovery, cooldown start, invalid-target fizzle, pre-execution cancellation, Victory, Defeat and mutual-KO Draw boundaries.
- The approved xoshiro128** 1.1 transition over four `U32` words, unbiased bounded sampling, a 64-candidate budget and atomic `RngSamplingExhausted` failure retaining the original state.
- Pure combat math for the approved one-floor damage formula, accuracy and evasion stages, always-hit bypass, critical chance cap and critical doubling.
- A pure combat resolver that consumes draws in the approved branch order, preserves the original RNG on failure and distinguishes Miss, NoDamage and Hit outcomes for clear UI feedback.
- Terminal actions discard queued events and emit the preserved core outcome. Readiness never revives a zero-HP actor.
- Strict machine-readable fixture loading and generic canonical replay checkpoints every 1024 accepted commands and at requested final completion.
- `TIME-WAIT` is checked over the production scheduler, `RNG-REF` freezes the production xoshiro reference transition, and `DMG-REF`/`ACC-REF` freeze reference combat calculations. Broader scheduler, cooldown and completion laws remain pending production-complete statements.

## Verified locally

- Scheduler goldens cover input-order normalization, exact priority ordering, unchanged incomplete-batch rejection and maximum-clock Wait rejection.
- Reducer goldens cover Victory, mutual-KO Draw, invalid-target fizzle cost and zero-HP readiness preservation.
- The strict fixture corpus covers 11 approved scenarios, and replay/persistence regression suites cover canonical hashing and checkpoint boundaries.
- `python3 scripts/verify.py`: 118 checks pass.
- `./scripts/bend PROOF.bend`: `All terms check.`

## Remaining M3 scope

- Replace the reducer's minimal damage payload with typed MoveId snapshots and the implemented combat resolver, reading target defense and evasion from battle state.
- Model active slots, finite reinforcement rosters, voluntary switching, forced replacement barriers, escape and participant viability.
- Execute complete barriers until the next normal command boundary, including simultaneous readiness, empty-queue stall diagnostics and Timeout advancement.
- Connect accepted command logs to the generic checkpoint adapter and prove repeated native/JavaScript replay hashes.
- Adopt the remaining scheduler/cooldown/completion laws only after their statements reference the completed production reducer.
