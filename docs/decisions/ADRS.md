# Architecture Decision Records

Status: accepted initial architecture as of the owner's 2026-09-21 instruction to use every remaining recommended option. D14/U09 supersede ADR-07's old tile-authority wording, D06 supersedes ADR-13's linear Harmony proposal, and D18/U13 close the host and approval policies. Future semantic changes require explicit versioning and owner approval. Constraints common to every ADR: primarily Bend 2, no creator code, deterministic rules, versioned content and honest proof boundaries.

## ADR-01 — Logical clock

- Problem: Rendering cadence cannot own combat time.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Integer ticks; fixed-point elapsed time; render-frame counter.
- Selected option (approved): Integer ticks with checked bounds (D01–02).
- Trade-offs: Simple ordering/replay; the approved tick resolution and maximum become compatibility-sensitive; no wrap.
- Consequences: Logical transitions cannot depend on host time.

## ADR-02 — Command selection

- Problem: Multiple ready actors need a defined input policy.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Pause; slow; continuous.
- Selected option (approved): Grouped pause barriers (D01).
- Trade-offs: Accessible/reproducible but affects pacing; AI snapshot timing becomes a rule.
- Consequences: Host records commands with barrier IDs; never infer them from frame timing.

## ADR-03 — Renderer/runtime separation

- Problem: Visual animation timing varies across hardware.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Renderer-owned simulation; shared mutable state; core snapshots/events.
- Selected option (approved): Read-only projections and semantic events.
- Trade-offs: Copy/projection cost versus isolated authority; may need measured compact snapshots.
- Consequences: Hit/collision times originate only in core; visual QA remains outside proofs.

## ADR-04 — Editor/runtime separation

- Problem: Draft documents may be incomplete or hostile.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Editor directly mutates runtime; separate simulation; same validated runtime API.
- Selected option (approved): The shipping loader/core with frozen playtest snapshots.
- Trade-offs: More validation plumbing, fewer editor/runtime divergences.
- Consequences: Draft IDs and undo state do not enter a running simulation until export validates.

## ADR-05 — Content serialization

- Problem: Need inspectable portable inert projects.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Strict JSON; TOML/YAML; binary schema.
- Selected option (approved): Strict UTF-8 JSON with a closed versioned schema.
- Trade-offs: Verbose but easy tooling; custom limits and semantic checks still required.
- Consequences: Reject duplicates/unknown fields; canonical encoding specified separately for hashing.

## ADR-06 — Effect algebra

- Problem: Expressive moves cannot execute creator code.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Move-name branches; arbitrary scripts; closed typed effect AST.
- Selected option (approved): A bounded ordered closed AST (D04).
- Trade-offs: New primitive requires engine release; controlled composition can remain expressive.
- Consequences: Each tag needs exact targeting/order/stack/failure/codec/validation contract; unsupported tags rejected.

## ADR-07 — Map representation (superseded)

- Problem: 2.5D visuals need simple authoring and reliable collision.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Tile grid; nav mesh/grid; hybrid explicit links.
- Selected option (approved replacement): Tile-based painting may assist authoring, but deterministic baked fixed-point navigation surfaces and explicit links own movement under D14/U09.
- Trade-offs: Free-ranging HD-2D traversal requires a bake/validation step and more editor tooling than tile-step movement.
- Consequences: No mesh-decoder or renderer callback determines movement at runtime; only the validated baked navigation artifact does.

## ADR-08 — RNG

- Problem: Replays need identical random draws on each supported backend.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Host random; explicit word-based PRNG; counter-based PRNG.
- Selected option (approved): Explicit xoshiro128** algorithm/version/state (D19).
- Trade-offs: Word portability is testable; fixed draw order and unbiased sampling require proof/test work.
- Consequences: No final algorithm until M0 arithmetic and M3 vectors; parallel batches need explicit independent streams.

## ADR-09 — Asset addressing

- Problem: Content paths may escape project or execute host behavior.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Raw paths/URLs; logical AssetId manifest; embedded blobs.
- Selected option (approved): AssetIds resolved through bounded hashed manifests.
- Trade-offs: Extra index but centralized confinement and offline packages.
- Consequences: Reject symlinks/traversal and remote execution; codec security remains host responsibility.

## ADR-10 — Save format

- Problem: Object memory is unstable and incomplete for persistence.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Memory snapshot; versioned canonical DTO; event-only reconstruction.
- Selected option (approved): A versioned inert DTO with an exact identity envelope (D17).
- Trade-offs: Explicit migrations cost work; validation protects invariants.
- Consequences: Initially stable-boundary saves; never silently reinterpret rules; atomic replacement in platform layer.

## ADR-11 — Replay format

- Problem: Rendered frames cannot verify simulation determinism.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Video/frame dumps; state every tick; initial state plus ordered commands.
- Selected option (approved): Command replay with versions, content identity, RNG state and optional state hashes.
- Trade-offs: Compact and reproducible; old semantic runtime/content must remain available or replay fails.
- Consequences: Record AI commands and barrier order; revalidate imported replay commands.

## ADR-12 — Mix recipes

- Problem: Compatibility is explicit and largely sparse.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Combinatorial synthesis; ordered pairs; canonical unordered pair table.
- Selected option (approved): Distinct unordered BaseMoveId pairs and a separate RecipeId (D10).
- Trade-offs: Easy symmetry and anti-recursion; future ordered recipes require schema/version work.
- Consequences: Both source checks/reservations/cooldowns are one transaction; no result re-entry.

## ADR-13 — Harmony

- Problem: Individual proficiency must be bounded and engine-controlled.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Integer score/linear curve; tiers; diminishing-return table.
- Selected option (approved): Store successful uses 0–40 per MonsterId/RecipeId and derive the six fixed mastery tiers and bonus packages in D06.
- Trade-offs: Visible milestones create discrete power steps but remain simple to serialize, test and explain.
- Consequences: Content cannot override thresholds or packages; balance changes require a ruleset version.

## ADR-14 — Bend/host boundary

- Problem: Need portable IO without assuming absent bindings.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Native Bend IO; narrow C/JS host adapters; process/IPC.
- Selected option (approved): One pure Bend core, JavaScript/browser shell for the maker, native core plus narrow trusted C/SDL3 adapter for packaged games/headless tools, Linux x86_64 first supported target.
- Trade-offs: Two shells require differential tests; the shared pure contracts prevent gameplay divergence.
- Consequences: No arbitrary pack FFI; incoming values are validated; proof scope excludes host/SDL/browser code; other operating systems remain unsupported until their gates pass.

## ADR-15 — Ruleset and schema identity

- Problem: Mechanical changes must not rewrite old replays.
- Constraints: preserve the common constraints above and the associated domain invariants.
- Considered options: Loose semver range; exact identity; negotiated migrations.
- Selected option (approved): Exact ruleset/content identity initially (D17).
- Trade-offs: Restricts compatibility but makes behavior explicit and auditable.
- Consequences: Build version separate from semantic ruleset; schemas/migrations do not imply mechanical compatibility.
