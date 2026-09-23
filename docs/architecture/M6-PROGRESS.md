# M6 implementation progress

Status: in progress on 2026-09-23. This is an incremental M6 checkpoint,
not milestone completion.

The typed recipe catalog, canonical unordered pair lookup, strict source/result
validation, current-knowledge eligibility, post-battle training, observation
history, and bounded per-individual Harmony core are implemented. Mixed command
submission now passes through `mixing.runtime.submit_mix`, which validates the
catalog, learned recipe, known sources, target and current source availability
before lowering one command into the production battle runtime. That command
reserves both sources in one batch; execution rechecks the actor and locked
target, releases both sources on cancellation, and charges both checked
`ceil(3*c/2)` cooldowns on a valid attempt or invalid-target fizzle.

A registered M4 damage effect enters one M5 component aggregate and one M4
accuracy/critical transaction. The defender's HP and defense come from the
execution-time effect world. Immutable type and current-move snapshots come
from command acceptance. Live active/conscious witness status comes from the
pre-effect battle roster, then the learning ledger filters witnesses for both
source moves. A committed miss still stages observation. The runner folds
committed mixed events into each caller-owned individual ledger, awards at most
one Harmony point to the acting individual for a real intended program effect,
and merges observations only when a terminal result commits. Status success is
classified from the pre-action state and program event so aftermath duration
ticks and unchanged refreshes do not award Harmony. Accepted Harmony accuracy
and critical bonuses are derived from learned progress at the command barrier;
the ordinary critical cap remains 2500.

`python3 scripts/verify.py` passes 159 local checks, including the prior
milestones, the canonical proof gate, M6 recipe/source/learning/eligibility and
runtime/ledger/driver goldens, strict fixture-oracle checks, and a native/JS
pure-learning differential. The production checkpoint is commit `dfbbfd1` on
`master`; hosted Ubuntu CI passed in
[run 35817031631](https://github.com/luisfelipeluis49/bendmon-engine/actions/runs/35817031631).
The later hosted documentation commit exposed a Bend interpreter machine-stack
overflow in the unchanged roster golden. The gate now compiles that golden to
a single-threaded native executable with the same expected output; the revised
159-check suite passes locally and in hosted
[run 35818263633](https://github.com/luisfelipeluis49/bendmon-engine/actions/runs/35818263633).
A separate GPT-6 Luna runtime review found missing
Harmony snapshot injection and persistent learning wiring; both were added in
this checkpoint. It also flagged the low-level `RuntimeMixedMove` constructor:
Bend does not hide the constructor, so the host must treat `Runtime.runtime_submit`
as a trusted engine API and submit creator-derived mixes only through
`mixing.runtime.submit_mix`. The latter is the validated content boundary.

The next integration slice now folds each committed event across every
participant's battle-local ledger and merges all of them at terminal battle
results. A canonical host codec records every roster individual's observations
and per-recipe Harmony progress under exact save schema, ruleset and content
identity. It rejects missing or duplicate individuals, malformed progress,
and learned recipes without an observation. The codec is a boundary component;
no full save installation path exists yet, and catalog membership must be
checked when that path is built. Replay/save mismatch diagnostics name both
expected and actual identities. `m3-1` remains the active default; `m6-1` is
explicitly selectable for M6 records until milestone closeout. An additive
Content-0 move document validates authored timing, accuracy or always-hit,
and animation asset references. The original demo remains unassigned and
existing content can omit moves.

The integrated checkpoint passes 160 local checks with
`python3 scripts/verify.py`, including the new full queued mixed-action golden
and native/JavaScript differential. Hosted verification for this checkpoint is
pending.

The native/JavaScript differential now covers the production M6 driver plus
full queued mixed cancellation/fizzle transitions, and an independent Luna
integration review found and resolved a premature ruleset-default switch.
Additional checked production-call laws cover concrete Harmony thresholds,
replay idempotence, mixed source charging and witness filtering. M6 still needs
same-action KO and all-blocked edge oracles, broader quantified MIX/LEARN/HARM
laws, authored mix
result schema coverage beyond the added base move timing/accuracy/animation
fields, final runtime/replay integration review, and a hosted gate for the
latest checkpoint. The project schema stays `unassigned` until a playable
content ruleset is published.

The existing `m3-1` replay identity remains active for prior fixtures. The
reserved `m6-1` identity will become the default only when the full M6 runtime/replay
boundary is complete.
