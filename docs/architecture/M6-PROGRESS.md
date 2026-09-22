# M6 implementation progress

Status: in progress on 2026-09-22. This is an incremental implementation
checkpoint, not milestone completion.

The first slice introduces a typed recipe catalog, canonical unordered pair
lookup, strict source/result validation, pure command eligibility, atomic
two-source cooldown charging, active conscious witness staging and terminal
observation merge, post-battle training, and bounded per-recipe Harmony rules.
Harmony awards update the persistent individual's learned recipe progress and
deduplicate a battle-local action sequence. The pure command plan reserves both
sources in one batch after validating the catalog, current move knowledge,
learned recipe state and target guard. Its accepted pair uses canonical source
order.

`python3 scripts/verify.py` passes 151 local checks, including the five new M6
goldens, all prior milestone fixtures, the canonical proof gate and existing
native/JavaScript differential checks. A separate GPT-6 Luna review found the
initial missing link between Harmony awards and persistent learned progress;
the link and focused idempotence fixture were added. Its final read-only review
found no further pure-slice defect. The new laws are production-linked reference
claims for mixed cooldowns, pair symmetry and Harmony boundaries. Universal
MIX/LEARN/HARM obligations remain for later M6 slices.

M6 still needs one mixed command on the production battle scheduler/runtime
path, execution of the registered descriptor through the M4 effect transaction
with M5 component damage, simultaneous source cooldown/recovery/fizzle/cancel
handling, persistent battle-to-world learning commit, replay equivalence,
native/JavaScript production differential fixtures, all relevant MIX/LEARN/HARM
production-linked laws, independent final review, and hosted CI. The recipe
catalog core currently carries registered effects/components and ordinary
source cooldowns; authored timing/accuracy/animation content schemas are a
later M6 slice. The project remains marked `unassigned` until that playable
content boundary exists.

The old `m3-1` replay identity remains active during this incremental work.
The reserved `m6-1` identity is activated only when the M6 runtime semantics
are integrated and its exact replay boundary is verified.
