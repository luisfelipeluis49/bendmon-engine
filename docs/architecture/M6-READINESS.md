# M6 readiness package

Status: ready to start, but not started, on 2026-09-22.

## Prepared inputs

- All owner decisions needed by M6 are approved: D05 mixed cooldowns, D06
  Harmony, D09 observation/training/retention and D10 unordered distinct pairs.
- M4 supplies the only effect, accuracy, critical, status and RNG transaction.
  M5 supplies exact typed component allocation and aggregate normal damage.
- The controlling implementation contract and four bounded work slices are in
  `docs/work-orders/M6-MIX-DISCOVERY-HARMONY.md`.
- The law inventory is fixed at MIX-1–8, LEARN-1–3 and HARM-1–3. New formal
  claims must call production M6 functions; tests cover integration properties
  that are not yet practical universal proofs.
- The verification plan includes strict fixtures, a production Bend golden,
  replay cases, a Python exact oracle, native/JavaScript equality, the complete
  prior gate and hosted Ubuntu CI.

No runtime, test, proof, schema, executable ruleset constant or fixture file was
added or changed during preparation. The planning registry reserves `m6-1`, but
the runtime remains `m3-1`. M6 implementation begins only when an agent starts
M6-A or M6-B.

## Planned file manifest

New production modules:

- `engine/mixing/model.bend`
- `engine/mixing/recipe.bend`
- `engine/mixing/harmony.bend`
- `engine/mixing/observation.bend`
- `engine/mixing/training.bend`
- `engine/mixing/eligibility.bend`
- `engine/mixing/runtime.bend`

Expected additive integration edits:

- `engine/battle/sources.bend`
- `engine/battle/runtime.bend`
- the runtime replay fold/model files selected after M6-A freezes the exact
  types
- `LAWS.bend`, `PROOF.bend` and `scripts/verify.py`

Planned verification files:

- `tests/m6/recipe_test.bend`
- `tests/m6/learning_test.bend`
- `tests/m6/mixing_runtime_test.bend`
- `tests/m6/replay_test.bend`
- `tests/m6/fixtures/index.json` and focused JSON cases
- `tests/m6/fixture_loader.py`
- `tests/m6/test_mixing_fixtures.py`
- `tests/m6/test_cross_target_mixing.py`

Closeout files are created or updated only after the gate passes:

- `docs/mechanics/STATUS-M6.md`
- `docs/architecture/M6-STATUS.md`
- `PLAN.md` and `README.md`

## Parallel execution map

1. One Luna agent creates the shared M6 model and recipe catalog (M6-A).
2. After the model types land, a second Luna agent implements pure Harmony while
   a third implements observation/training. They may work in parallel because
   they do not modify shared battle files.
3. One Luna agent exclusively owns runtime/source/replay integration (M6-C).
4. A fixture agent builds the strict corpus and oracle alongside M6-C against
   the frozen public APIs, then finishes the production goldens after integration.
5. A separate Luna reviewer audits contracts, laws, runtime atomicity and
   cross-target evidence before closeout.

Only four agents may run concurrently. Shared `runtime.bend`, `sources.bend`,
`LAWS.bend`, `PROOF.bend` and `scripts/verify.py` each have one writer at a time.

## Fixture matrix prepared for implementation

The required golden scenarios are:

1. Valid registered mix: both sources reserve and charge, registered effects
   execute once, a witness observes and Harmony increments once.
2. Reversed command pair: canonical state and descriptor equal scenario 1.
3. Miss: valid witnesses observe; Harmony does not increment.
4. Invalid-target fizzle: both cooldowns and recovery apply; no observation,
   Harmony or RNG draw.
5. Actor cancellation: both reservations release; no cooldown, observation,
   Harmony or RNG change.
6. Training after a terminal loss: observation merges, one token is consumed,
   learned progress starts at zero.
7. Harmony boundaries: 4→5, 9→10, 19→20, 29→30, 39→40 and saturation at 40
   produce the exact six bonus packages.
8. Forgotten source: history remains, execution/training rejects until both
   sources are current again.

The broader matrix also covers self/duplicate/unknown pairs, non-single source
components, one unavailable source, odd/even mixed rounding, 3600→5400, deadline
overflow, ally/enemy/unconscious witnesses, same-action KO, repeated terminal
and completion events, blocked effects, full-HP healing, unrelated individuals,
mid-battle training and exact identity mismatch.

## Start checklist

Before the first implementation edit:

- Confirm `master` is clean and still contains the completed M5 commit.
- Run `./scripts/bend guide`; agents must use the repository wrapper because a
  bare `bend` may not be on `PATH`.
- Assign M6-A and M6-B work strictly by the work-order file boundaries.
- Preserve M4/M5 golden output and RNG consumption as baseline artifacts.
- Create no semantic exception to make a fixture or proof pass.

## Completion gate

M6 is complete only after production implementation, all production-linked
proofs, the full local gate, native/JavaScript equality, independent Luna
review, a clean pushed commit and hosted Ubuntu CI. Preparation satisfies none
of those completion claims; it removes the design and scheduling blockers so
implementation can begin directly.
