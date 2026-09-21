# M3 headless battle work orders

Authorization: all currently identified gameplay decisions were closed by the owner on 2026-09-21. `docs/DECISIONS.md`, `docs/RULES.md`, `docs/mechanics/BATTLE.md` and `LAWS.bend` are semantic authority. Changing a listed rule requires explicit owner approval; implementation defects change code and tests.

TASK: M3-A battle state, event queue and command barriers.
OWNER MODEL: GPT-5.6 Sol or primary architecture-capable agent.
DEPENDENCIES: M2 typed content foundation; D01–D05, D19 and U01–U03.
FILES ALLOWED TO CHANGE: engine/battle/**, platform/battle/**, tests/battle/**, additive PROOF.bend definitions after law adoption.
FILES FORBIDDEN TO CHANGE: approved decision/rule semantics, existing content contracts, existing laws except additive owner-approved laws.
GOAL: pure deterministic Ready/Windup/Execute/Recovery reducer with atomic grouped command barriers, total event ordering, Wait, cooldown reservations, cancellation/fizzle, completion, escape, reinforcement and switching.
NON-GOALS: renderer, editor, full M4 status catalog, M5 multi-type runtime, M6 mixing runtime.
ENGINE INVARIANTS AFFECTED: TIME-1, CD-1, DET-1, VAL-1, HP-1.
LAWS AFFECTED: future additive scheduler/cooldown preservation laws; do not add until their statements call production functions and receive architecture review.
INPUT CONTRACT: validated canonical battle state, explicit four-word RNG state and a complete command batch for every required ready controlled actor.
OUTPUT CONTRACT: next canonical state plus ordered semantic events, AwaitingCommands, terminal result or typed deterministic fault; rejected commands change nothing.
IMPLEMENTATION NOTES: integer ticks only; no render deltas; checked deadlines; canonical sorted structures; one reducer owns RNG; independently computable preview/validation may parallelize but commits remain sequential.
EDGE CASES: zero windup, all Wait, all cooldowns active, current-tick queueing, equal priority/speed, target switches, pre-execution KO, invalid-target fizzle, Draw, Timeout, escape failure/success, queued reinforcement, forced replacement, deadline overflow, RNG sampling exhaustion.
TESTS REQUIRED: approved M3 fixture corpus, native/JS differential vectors, input-order permutations, repeated replay hashes, rejection unchanged assertions and all boundary ticks.
PROOF OBLIGATIONS: clock monotonicity/no wrap; no unavailable move acceptance; atomic batch/source reservation; HP bounds; deterministic fold under identical complete inputs.
ACCEPTANCE CRITERIA: `./scripts/bend PROOF.bend`, all changed Bend entries check, repository verification passes, independent semantic review finds no decision drift.

TASK: M3-B deterministic fixture corpus and harness.
OWNER MODEL: GPT-5.6 Luna.
DEPENDENCIES: frozen M3-A contracts and approved decision register.
FILES ALLOWED TO CHANGE: tests/battle/fixtures/**, tests/battle/test_*fixture*.py, narrow fixture documentation.
FILES FORBIDDEN TO CHANGE: production engine, LAWS.bend, gameplay docs/rules.
GOAL: machine-readable fixtures covering required states, commands and expected semantic event traces before and during reducer implementation.
NON-GOALS: substitute Python battle implementation or new expected mechanics.
ENGINE INVARIANTS AFFECTED: none; fixtures reflect approved rules.
LAWS AFFECTED: none.
INPUT CONTRACT: stable fixture schema with explicit IDs, ticks, RNG words, state and expected result/events.
OUTPUT CONTRACT: deterministic ordered corpus and validation tests.
IMPLEMENTATION NOTES: preserve semantic sequence order; sort discovery/file enumeration; duplicate scenario IDs reject.
EDGE CASES: every scenario named in M3-A.
TESTS REQUIRED: fixture schema, uniqueness, stable ordering, coverage manifest.
PROOF OBLIGATIONS: none claimed.
ACCEPTANCE CRITERIA: targeted Python tests pass and M3-A can consume the fixtures without reinterpretation.

TASK: M3-C replay harness and canonical digests.
OWNER MODEL: GPT-5.6 Sol; Luna may implement the separately specified canonical JSON adapter and mechanical fixtures.
DEPENDENCIES: M3-A reducer; U12 canonical JSON/SHA-256 contract.
FILES ALLOWED TO CHANGE: engine/replay/**, platform/persistence/**, tests/replay/**, tests/persistence/**.
FILES FORBIDDEN TO CHANGE: save/replay identity semantics, RNG algorithm/draw policy, content hash semantics.
GOAL: fold accepted command logs, emit canonical checkpoints and prove/test repeated identical results.
NON-GOALS: mid-battle save UI, permissive identity ranges, migration invention.
ENGINE INVARIANTS AFFECTED: DET-1, SAVE-1, REPLAY-1.
LAWS AFFECTED: future additive replay-fold law tied to the production reducer.
INPUT CONTRACT: exact ruleset/content identities, initial state/RNG and ordered accepted commands.
OUTPUT CONTRACT: terminal/current state, semantic events and optional SHA-256 checkpoints every 1024 accepted commands plus terminal completion.
IMPLEMENTATION NOTES: adapter rejects noncanonical host values; imported accepted logs are revalidated.
EDGE CASES: empty log, rejected/stale command, checkpoint boundary, identity mismatch, terminal command followed by extra input.
TESTS REQUIRED: mutation sensitivity, cross-target goldens and replay of every M3 fixture.
PROOF OBLIGATIONS: fold determinism under identical complete inputs.
ACCEPTANCE CRITERIA: repeated and supported-backend runs have identical canonical state/event hashes.
