# M6 implementation progress

Status: in progress on 2026-09-23. This is the second incremental M6 checkpoint,
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

`python3 scripts/verify.py` passes 158 local checks, including the prior
milestones, the canonical proof gate, M6 recipe/source/learning/eligibility and
runtime/ledger/driver goldens, strict fixture-oracle checks, and a native/JS
pure-learning differential. A separate GPT-6 Luna runtime review found missing
Harmony snapshot injection and persistent learning wiring; both were added in
this checkpoint. It also flagged the low-level `RuntimeMixedMove` constructor:
Bend does not hide the constructor, so the host must treat `Runtime.runtime_submit`
as a trusted engine API and submit creator-derived mixes only through
`mixing.runtime.submit_mix`. The latter is the validated content boundary.

M6 still needs runtime/replay native/JS differential fixtures, a complete
versioned `m6-1` replay/save identity and exact ruleset/content mismatch
handling, all MIX/LEARN/HARM production-linked laws and edge-case oracles,
independent review of the final integrated change, and hosted CI for this
checkpoint. The recipe catalog currently carries registered effects/components
and ordinary source cooldowns; authored timing, accuracy and animation content
schemas are pending. Battle-local individual ledgers are returned by the
mixing driver; a later persistence boundary must serialize every participant's
terminal learning state under exact content identity. The project schema stays
`unassigned` until a playable content ruleset is published.

The existing `m3-1` replay identity remains active for prior fixtures. The
reserved `m6-1` identity will activate only when the full M6 runtime/replay
boundary is complete.
