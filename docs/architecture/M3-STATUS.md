# M3 battle implementation status

Status: complete and locally verified on 2026-09-21. Remote CI remains an M0 infrastructure gate.

## Implemented

- Closed Bend battle types for stable actor IDs, sides, Ready/Windup/Recovery/Defeated phases, commands, event keys, queued events, terminal outcomes and typed diagnostics.
- Atomic grouped command submission against one unchanged barrier snapshot. Command input order is normalized by ActorId; incomplete, stale, invalid-target, cooldown, timing and deadline failures return the original state.
- Engine-owned Wait choices of 30, 60 or 120 ticks, with a checked 216000-tick clock cap.
- Fixed-width `U32` battle clocks and durations. Deadline validation checks the remaining range before addition, so scheduling cannot wrap.
- The approved event-key prefix: due tick, phase rank, priority rank, captured speed descending, ActorId, action sequence and event ordinal.
- A canonical runtime boundary using typed `MoveId` sources, per-move reservations and cooldowns, captured attacker values, execution-time defender values, conditional RNG draws, recoil, HP saturation, Recovery, invalid-target fizzle, pre-execution cancellation, Victory, Defeat and mutual-KO Draw boundaries. The scalar scheduler payload remains an internal compatibility adapter and is zeroed by the runtime.
- The approved xoshiro128** 1.1 transition over four `U32` words, unbiased bounded sampling, a 64-candidate budget and atomic `RngSamplingExhausted` failure retaining the original state.
- Pure combat math for the approved one-floor damage formula, accuracy and evasion stages, always-hit bypass, critical chance cap and critical doubling.
- A pure combat resolver that consumes draws in the approved branch order, preserves the original RNG on failure and distinguishes Miss, NoDamage and Hit outcomes for clear UI feedback.
- Terminal actions discard queued events and emit the preserved core outcome. Readiness never revives a zero-HP actor.
- Active rosters support up to 12 participants and four active actors per side, deterministic encounter-order reinforcement, voluntary switching, execution-time switch revalidation and trapped-actor rejection.
- Wild escape uses the approved speed and failed-attempt formula. Trainer, boss and locked encounters reject escape before scheduling; success discards pending events and failure consumes RNG, increments the attempt counter and enters Recovery.
- A bounded driver drains simultaneous due events, stops at complete command barriers, reports empty-queue stalls, and resolves the 216000-tick cap as Timeout.
- Strict machine-readable fixture loading, runtime accepted-command replay folding, exact ruleset/content/RNG identity validation, and canonical SHA-256 checkpoints every 1024 accepted commands and at requested final completion.
- `TIME-WAIT`, `RNG-REF`, `DMG-REF` and `ACC-REF` freeze the production timing, RNG and combat references. Additive production laws cover clock caps, escape chance, duplicate source rejection, driver determinism, HP saturation, reinforcement order and runtime determinism.

## Verified locally

- Scheduler and runtime goldens cover input-order normalization, exact priority ordering, atomic unchanged rejection, all Wait choices, per-move cooldown independence, current defender reads, switch and escape execution, forbidden encounters and atomic RNG faults.
- Reducer and driver goldens cover Victory, Defeat, mutual-KO Draw, invalid-target fizzle cost, cancellation, zero-HP readiness preservation, simultaneous readiness, stalls and Timeout.
- The strict fixture corpus covers 22 approved scenarios. Replay and persistence suites cover canonical hashing, checkpoint boundaries, terminal extra input and exact identity mismatch rejection.
- Native and generated JavaScript executions produce identical battle and replay golden outputs.
- `python3 scripts/verify.py`: 132 checks pass.
- `./scripts/bend PROOF.bend`: `All terms check.`

## Milestone boundary

M3 supplies the deterministic headless battle kernel and replay boundary required by M4. The closed effect/status interpreter, type modifiers and authored move integration belong to M4–M5; progression, renderer and maker integration remain in their planned milestones.
