# Determinism, save and replay contracts

## Guarantee and preconditions

For the same ruleset semantics version, canonical validated content identity, valid initial state, RNG algorithm/state and ordered accepted commands, the pure core must produce the same logical state and ordered semantic events. Equality includes queue, cooldowns, learned/observed recipes and RNG state, not rendered frames. Identical command text without version/content/initial-state identity is insufficient.

Use integer/explicit rational arithmetic, documented overflow and rounding, canonical traversal, stable entity/event IDs and a single authority for action commits. No floating-point gameplay, host random, wall clock, locale-dependent ordering or thread-order-dependent merges. Rejected commands leave state and RNG unchanged. Runtime resource faults are explicit failures; they do not silently skip effects.

## RNG proposal

Select a documented integer PRNG only after cross-target arithmetic probes. Recommend a well-specified 32-bit-word generator with named algorithm revision, full nonzero state validation and published test vectors; consider xoshiro128** versus a counter-based generator or PCG with verified wide arithmetic. No algorithm is finalized by this document. Require seed expansion, invalid-state behavior and unbiased bounded sampling in the final contract.

Every random operation consumes explicit state in canonical effect/actor order. Define hit/crit/multi-hit/capture draw counts including miss/immunity branches before implementation. Avoid modulo bias; a rejection sampler must address termination in Bend: use a bounded attempt budget with deterministic error and no partial action commit, or a proved terminating equivalent. Partition RNG for independent simulation batches only with a specified stream derivation; never share mutable RNG across parallel tasks. Replays store full initial RNG state as well as human seed metadata if seed expansion is not otherwise reproduced exactly.

## Save proposal

Envelope: saveSchemaVersion, engineBuild, rulesetVersion, contentDigest, project/catalog IDs, RNG algorithm revision, payload integrity digest, canonical runtime payload. Payload separates world/NPC/event state, flags/quests, inventory, party/storage, individual monsters/XP/moves/observations/unlocks/Harmony and RNG streams. Mid-battle saves, if allowed, also store scheduler queues, reservations, command barrier and pending world commit. No pointer layout or dense-index identities.

Read pipeline: bounded parse → version/identity compatibility → structural validation → permitted explicit migration → full state validity validation → install state. Reject impossible cooldowns, queue ownership, duplicate monster IDs, out-of-range levels and learned recipes with impossible provenance according to approved persistence rules. Checksums detect corruption, not malicious authorship. Do not claim anti-cheat guarantees.

Write using a platform atomic replacement strategy with durability policy and interruption tests. Never overwrite the only valid save while migration is incomplete. Recommend no cross-ruleset migration at first; schema-only migrations are version-specific, explicit and preserve semantic identity. Keep old replay interpretation exact or reject with instructions.

## Replay proposal

Envelope: replay schema, exact ruleset and content identities, RNG revision/state, initial canonical battle state and ordered accepted commands. Record `(logicalTick, barrierId, commandOrdinal, actorId, payload)` so replays do not infer input timing from render frames. For AI, record commands too; deterministic AI regeneration is an additional test, not a required future compatibility promise. The replay runner must revalidate command legality; an accepted-log assertion from a file is untrusted.

Optional checkpoints contain canonical state/event digests; do not replace simulation. Duplicate/out-of-order commands or identity mismatches fail explicitly. Pin content hashing to an approved canonical encoding: sorted object keys, preserved semantic sequence order, exact integer encoding, UTF-8 policy and normalized path rules. Digest algorithm recommendation is SHA-256; its host implementation is trusted/tested, not proved by the gameplay laws.

Golden tests compare canonical bytes or semantic equality, not object addresses. Cross-target differential tests compare interpreter/native/JS only when those targets pass M0. Per-frame playback may interpolate differently; it must never change logical event order.
