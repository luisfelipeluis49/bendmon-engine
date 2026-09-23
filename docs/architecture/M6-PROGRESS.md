# M6 mix, discovery and Harmony status

Status: M6 core complete on 2026-09-23. The local
`python3 scripts/verify.py` gate passes 165 checks, including the canonical
`PROOF.bend` gate and native/JavaScript M6 goldens. The same gate passed hosted
Ubuntu CI for closeout commit `2a54010` in
[run 35878115619](https://github.com/luisfelipeluis49/bendmon-engine/actions/runs/35878115619).

The M6 engine has typed recipe and result identities, one canonical unordered
pair per recipe, one type component per source, 1–4 result components, and a
validated catalog of registered closed M4 effect programs. Eligibility requires
an observed, trained recipe, both current source moves, an available actor and
locked target, and two available sources. Submission reserves both sources in
one batch. Cancellation releases both without charge; invalid-target fizzle
charges both without observation or RNG use. A valid attempt charges checked
`ceil(3*c/2)` cooldowns and executes one registered M4/M5 result through one
accuracy and critical transaction.

At valid execution start, active conscious combatants knowing both sources
witness the mix, including on a miss or same-action KO. Battle-local ledgers
fold every committed event for every participant; observations merge into each
individual only at a committed terminal result. Post-battle training spends one
token atomically and installs progress zero. Harmony awards at most one point
per successful intended program effect and action identity, saturates at 40,
and supplies tiered accuracy and critical bonuses captured at the command
barrier. Misses, blocked or zero-damage attempts, full-HP healing, cancellation,
fizzle and aftermath-only effects do not award progress. The ordinary critical
cap remains 2500.

M6 regression goldens cover validation, source transactions, learning,
training, threshold bonuses, roster-wide terminal merge, cancellation, fizzle,
same-action KO, queued status blocking, all-zero typed damage, full-HP healing,
and mixed command replay. The replay golden enters through production
`mixing.runtime.submit_mix`, asserts exact battle/effect events and RNG state,
and folds terminal learning. These runtime paths match in native and JavaScript.
Independent GPT-6 Luna reviews found no unresolved production defect in the
new replay and no-effect paths. Production-linked laws cover pair symmetry,
two-source charge/rejection witnesses, witness filtering, Harmony replay and
commit gates, saturation, and in-battle/atomic training rejection. The laws
state their quantified or concrete scope explicitly; they do not claim a full
universal proof of the entire battle runtime.

New replay/save identity defaults to `m6-1`. Historical M3 fixtures explicitly
retain `m3-1`, and cross-version ruleset/content mismatches are rejected with
expected and actual identities. The canonical host learning codec validates
every roster individual, recipe catalog membership, observation provenance,
and bounded Harmony progress under exact save identity.

Content-0 can validate inert move, mix recipe and result metadata, but there is
no host-to-Bend adapter that turns an authored mix result into a registered M4
effect program. The M6 work order explicitly excludes host JSON loading from
M6-A; production callers must supply a trusted validated Bend catalog and use
`mixing.runtime.submit_mix`. This adapter, playable content ruleset, visual
maker and full save installation are later integration work (M10/M11), not
claims made by this M6 core milestone. The original demo remains `unassigned`.
