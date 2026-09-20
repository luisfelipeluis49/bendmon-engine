# Architecture Decision Records

All records are **PROPOSED**, not accepted. The selected option below is the architecture recommendation for review. Gameplay-affecting choices additionally require the linked owner decision. Constraints common to every ADR: primarily Bend 2, no creator code, deterministic rules, versioned content and honest proof boundaries.

## ADR-01 — Logical clock

- Problem: Rendering cadence cannot own combat time.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Integer ticks; fixed-point elapsed time; render-frame counter.
- Selected option (proposed): Propose integer ticks with checked bounds (D01–02).
- Trade-offs: Simple ordering/replay; tick resolution and maximum must be approved; no wrap.
- Consequences: Logical transitions cannot depend on host time.

## ADR-02 — Command selection

- Problem: Multiple ready actors need a defined input policy.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Pause; slow; continuous.
- Selected option (proposed): Propose a grouped pause barrier (D01).
- Trade-offs: Accessible/reproducible but affects pacing; AI snapshot timing becomes a rule.
- Consequences: Host records commands with barrier IDs; never infer them from frame timing.

## ADR-03 — Renderer/runtime separation

- Problem: Visual animation timing varies across hardware.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Renderer-owned simulation; shared mutable state; core snapshots/events.
- Selected option (proposed): Propose read-only projections and semantic events.
- Trade-offs: Copy/projection cost versus isolated authority; may need measured compact snapshots.
- Consequences: Hit/collision times originate only in core; visual QA remains outside proofs.

## ADR-04 — Editor/runtime separation

- Problem: Draft documents may be incomplete or hostile.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Editor directly mutates runtime; separate simulation; same validated runtime API.
- Selected option (proposed): Propose same shipping loader/core with frozen playtest snapshots.
- Trade-offs: More validation plumbing, fewer editor/runtime divergences.
- Consequences: Draft IDs and undo state do not enter a running simulation until export validates.

## ADR-05 — Content serialization

- Problem: Need inspectable portable inert projects.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Strict JSON; TOML/YAML; binary schema.
- Selected option (proposed): Propose strict UTF-8 JSON with closed versioned schema.
- Trade-offs: Verbose but easy tooling; custom limits and semantic checks still required.
- Consequences: Reject duplicates/unknown fields; canonical encoding specified separately for hashing.

## ADR-06 — Effect algebra

- Problem: Expressive moves cannot execute creator code.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Move-name branches; arbitrary scripts; closed typed effect AST.
- Selected option (proposed): Propose bounded ordered closed AST (D04).
- Trade-offs: New primitive requires engine release; controlled composition can remain expressive.
- Consequences: Each tag needs exact targeting/order/stack/failure/codec/validation contract; unsupported tags rejected.

## ADR-07 — Map representation

- Problem: 2.5D visuals need simple authoring and reliable collision.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Tile grid; nav mesh/grid; hybrid explicit links.
- Selected option (proposed): Propose tile collision with elevation/link metadata (D14).
- Trade-offs: Simple drag/drop; irregular geometry is visual unless links explicitly authorize movement.
- Consequences: No mesh-decoder or renderer callbacks determine movement legality.

## ADR-08 — RNG

- Problem: Replays need identical random draws on each supported backend.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Host random; explicit word-based PRNG; counter-based PRNG.
- Selected option (proposed): Propose explicit algorithm/version/state; evaluate xoshiro128** (D19).
- Trade-offs: Word portability is testable; fixed draw order and unbiased sampling require proof/test work.
- Consequences: No final algorithm until M0 arithmetic and M3 vectors; parallel batches need explicit independent streams.

## ADR-09 — Asset addressing

- Problem: Content paths may escape project or execute host behavior.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Raw paths/URLs; logical AssetId manifest; embedded blobs.
- Selected option (proposed): Propose AssetIds resolved through bounded hashed manifests.
- Trade-offs: Extra index but centralized confinement and offline packages.
- Consequences: Reject symlinks/traversal and remote execution; codec security remains host responsibility.

## ADR-10 — Save format

- Problem: Object memory is unstable and incomplete for persistence.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Memory snapshot; versioned canonical DTO; event-only reconstruction.
- Selected option (proposed): Propose versioned inert DTO with exact identity envelope (D17).
- Trade-offs: Explicit migrations cost work; validation protects invariants.
- Consequences: Initially stable-boundary saves; never silently reinterpret rules; atomic replacement in platform layer.

## ADR-11 — Replay format

- Problem: Rendered frames cannot verify simulation determinism.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Video/frame dumps; state every tick; initial state plus ordered commands.
- Selected option (proposed): Propose command replay with versions/content/RNG and optional state hashes.
- Trade-offs: Compact and reproducible; old semantic runtime/content must remain available or replay fails.
- Consequences: Record AI commands and barrier order; revalidate imported replay commands.

## ADR-12 — Mix recipes

- Problem: Compatibility is explicit and largely sparse.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Combinatorial synthesis; ordered pairs; canonical unordered pair table.
- Selected option (proposed): Propose distinct unordered BaseMoveId pairs and separate RecipeId (D10).
- Trade-offs: Easy symmetry and anti-recursion; future ordered recipes require schema/version work.
- Consequences: Both source checks/reservations/cooldowns are one transaction; no result re-entry.

## ADR-13 — Harmony

- Problem: Individual proficiency must be bounded and engine-controlled.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Integer score/linear curve; tiers; diminishing-return table.
- Selected option (proposed): Propose bounded integer per MonsterId/RecipeId; formulas in MIXING.md await D06.
- Trade-offs: Simple proof and tuning; linear growth may need later balance revision.
- Consequences: No H/g/bonus values hard-coded until approval; content cannot override them.

## ADR-14 — Bend/host boundary

- Problem: Need portable IO without assuming absent bindings.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Native Bend IO; narrow C/JS host adapters; process/IPC.
- Selected option (proposed): Propose pure Bend core and measured trusted host adapter after M0 (D18).
- Trade-offs: Native latency versus browser authoring convenience versus IPC copies; verify actual ABI first.
- Consequences: No arbitrary pack FFI; incoming values validated; proof scope excludes host code.

## ADR-15 — Ruleset and schema identity

- Problem: Mechanical changes must not rewrite old replays.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Loose semver range; exact identity; negotiated migrations.
- Selected option (proposed): Propose exact ruleset/content identity initially (D17).
- Trade-offs: Restricts compatibility but makes behavior explicit and auditable.
- Consequences: Build version separate from semantic ruleset; schemas/migrations do not imply mechanical compatibility.

