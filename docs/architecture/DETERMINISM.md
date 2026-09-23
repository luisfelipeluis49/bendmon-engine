# Determinism, save and replay contracts

The approved initial gameplay RNG algorithm is versioned xoshiro128** over four explicit U32 state words. The battle core receives those four words directly and rejects the all-zero state. Native and JavaScript implementations must match fixed known-answer vectors exactly, including U32 wraparound, shifts and rotations. The battle reducer exclusively owns the state and commits semantic samples in canonical event order; pure parallel work cannot copy or mutate it. Sampling a bounded integer uses rejection sampling, never biased modulo reduction, with at most 64 candidates. Exhaustion returns atomic engine fault `RngSamplingExhausted`, not a gameplay outcome. Saves and replays identify the algorithm version and preserve all four exact state words; optional human seed metadata is noncanonical.

## Guarantee and preconditions

For the same ruleset semantics version, canonical validated content identity, valid initial state, RNG algorithm/state and ordered accepted commands, the pure core must produce the same logical state and ordered semantic events. Equality includes queue, cooldowns, learned/observed recipes and RNG state, not rendered frames. Identical command text without version/content/initial-state identity is insufficient.

Use integer/explicit rational arithmetic, documented overflow and rounding, canonical traversal, stable entity/event IDs and a single authority for action commits. No floating-point gameplay, host random, wall clock, locale-dependent ordering or thread-order-dependent merges. Rejected commands leave state and RNG unchanged. Runtime resource faults are explicit failures; they do not silently skip effects.

## RNG contract and remaining decisions

Use the approved versioned xoshiro128** transition with full nonzero state validation, explicit four-U32 battle input and fixed test vectors. Bounded sampling uses unbiased rejection sampling with the 64-candidate atomic-failure contract above.

Every random operation consumes explicit state in canonical effect/actor order. For M3, cancellation and invalid-target fizzle consume no samples; `alwaysHit` consumes no accuracy sample; an ordinary valid-target attempt consumes accuracy; a miss stops; nondamage and deterministic block/immunity consume no critical sample; a successful nonimmune damaging hit consumes critical even if final damage is zero. Rejected batches do not advance state. Each rejection sampler stops after at most 64 candidates with no partial action commit. No stream partition is approved; never share mutable RNG across parallel tasks. Replays store full initial and checkpoint RNG state.

## Approved initial save contract

Envelope: saveSchemaVersion, engineBuild, rulesetVersion, contentDigest, project/catalog IDs, RNG algorithm revision, payload integrity digest, canonical runtime payload. Payload separates world/NPC/event state, flags/quests, inventory, party/storage, individual monsters/XP/moves/observations/unlocks/Harmony and RNG streams. Mid-battle saves, if allowed, also store scheduler queues, reservations, command barrier and pending world commit. No pointer layout or dense-index identities.

Read pipeline: bounded parse → exact ruleset version and project content digest match → structural validation → permitted explicit version-specific schema migration → full state validity validation → install state. A mismatch diagnostic names expected and actual ruleset versions and content digests. Schema migration is explicit and version-specific; it never changes ruleset or content identity. M3 remains the active default until M6 closeout; M6 identities require explicit selection during implementation. Neither version is reinterpreted as the other. Reject impossible cooldowns, queue ownership, duplicate monster IDs, out-of-range levels and learned recipes with impossible provenance according to approved persistence rules. Checksums detect corruption, not malicious authorship. Do not claim anti-cheat guarantees.

Write using a platform atomic replacement strategy with durability policy and interruption tests. Never overwrite the only valid save while migration is incomplete. Initially save only at stable world boundaries outside battle and event transactions. Cross-ruleset reinterpretation is forbidden; schema-only migrations are version-specific, explicit and preserve semantic identity. Keep old replay interpretation exact or reject with instructions. Mid-battle saves remain unavailable until every scheduler/barrier/reservation/RNG/pending-commit field is serialized and proven.

## Replay proposal

Envelope: replay schema, exact ruleset and content identities, RNG revision/state, initial canonical battle state and ordered accepted commands. Record `(logicalTick, barrierId, commandOrdinal, actorId, payload)` so replays do not infer input timing from render frames. For AI, record commands too; deterministic AI regeneration is an additional test, not a required future compatibility promise. The replay runner must revalidate command legality; an accepted-log assertion from a file is untrusted.

Optional checkpoints contain canonical state/event digests; do not replace simulation. Duplicate/out-of-order commands or identity mismatches fail explicitly. Pin content hashing to an approved canonical encoding: sorted object keys, preserved semantic sequence order, exact integer encoding, UTF-8 policy and normalized path rules. Digest algorithm recommendation is SHA-256; its host implementation is trusted/tested, not proved by the gameplay laws.

Golden tests compare canonical bytes or semantic equality, not object addresses. Cross-target differential tests compare interpreter/native/JS only when those targets pass M0. Per-frame playback may interpolate differently; it must never change logical event order.
