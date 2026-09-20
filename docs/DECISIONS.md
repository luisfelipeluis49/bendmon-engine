# Owner decision register

Entries are OPEN except for the specific approved choices recorded below. Unapproved recommendations remain proposals, not adopted rules. Fixed brief requirements (level 200, MIX-1–8, discovery before training, no creator code, pure deterministic core) are preserved. Owner approval should record date, selected option, exact constants/semantics and affected ruleset/law IDs; silence is not approval.

The next implementation slice only needs D18/toolchain feasibility. D01–D05 and D19 gate battle work; D06–D10 gate the full mix system. Independent planning can continue while these remain open.

## Owner approval during implementation

The owner explicitly selected “Use the recommended rules” for paused command barriers, sequential event resolution, unordered distinct mix pairs, and retained learning history. These choices are approved in D01, D02, D09 and D10 only to the extent listed here. Numeric constants and other sub-decisions remain open; this is not blanket approval of all recommendations. Technical M0 execution is authorized by “Well, then implement it.”

## D01 — Command selection and pacing

- Status: PARTIALLY APPROVED — paused command barriers; tick scale remains open. Gate: M3.
- Question/why: Changes accessibility, AI information and replay timing.
- Options: Pause at decision barriers; slow logical clock; fully continuous clock.
- Recommendation: Pause at a barrier for all ready controlled actors; AI commits from the same snapshot. Choose tick-to-presentation scale separately.
- Consequences / still to specify: No input-latency advantage; requires explicit Wait and grouped command UI.

## D02 — Equal-tick resolution and completion

- Status: PARTIALLY APPROVED — sequential event resolution; detailed tie/completion outcomes remain open. Gate: M3.
- Question/why: Order changes KO trades, expiry, delayed effects and victory.
- Options: Stable sequential events; snapshot/batched simultaneous resolution; speed-based tie resolution.
- Recommendation: Sequential order from BATTLE.md: expiry/readiness before execution; priority then stable actor identity. Same-action aftermath is atomic inside execution; check completion immediately after each action outside queue phases and discard pending events on completion; draw if that action leaves no viable side, with capture/escape outcomes explicit.
- Consequences / still to specify: Actor-ID ordering may be unfair; owner must approve tie fairness, reinforcements, escape, timeout and pending-effect behavior.

## D03 — Commitment, snapshots and invalid targets

- Status: OPEN; gate: M3.
- Question/why: Cancellation and retargeting affect costs, damage and tactical information.
- Options: Snapshot stats/targets at selection; read at execution; mixed snapshot policy.
- Recommendation: Lock target identity at acceptance; read stats at execution, fizzle on invalid target, no retargeting. No voluntary interruption initially; KO suppresses action but retains engaged costs. Require positive recovery and an explicit Wait action with positive engine-owned duration, scheduled readiness, and no source cooldown consumption. Batch reservation is atomic; zero-windup executions enter the normal priority queue only after all batch reservations commit.
- Consequences / still to specify: Document switch/KO outcomes and costs before scheduler coding.

## D04 — Damage/effect mechanics and randomness

- Status: OPEN; gate: M3 minimal subset; M4 full.
- Question/why: All combat needs exact formulas and stacking; compositional effects alone are insufficient.
- Options: Simple bounded integer base formula; scaled rational formula; engine-owned lookup tables.
- Recommendation: Choose a bounded integer base damage formula through owner balance review; use one hit/crit draw per action, component-local modifiers, actual aggregate HP loss for drain/recoil. Closed status rules and finite stat-stage clamps.
- Consequences / still to specify: No numerical coefficients selected. Approve accuracy/crit ranges, minimum damage, hit reactions, status duration/stacking, immunities and RNG consumption on every branch.

## D05 — Cooldown origin and mixed penalty

- Status: OPEN; gate: M3 ordinary; M6 mix.
- Question/why: Both sources must receive increased cooldown and cannot bypass eligibility.
- Options: Additive penalty; multiplicative penalty; engine-defined tier table.
- Recommendation: Anchor at acceptance; each source gets ceil(k × ordinary cooldown), k>1 and ordinary cooldown>=1. Reservations persist through action.
- Consequences / still to specify: Approve k, caps, units and fizzle/interrupt semantics; checked overflow rejects acceptance atomically.

## D06 — Harmony maximum, growth and benefits

- Status: OPEN; gate: M6.
- Question/why: Progression must be bounded and individual; success is undefined.
- Options: Linear capped growth/bonuses; tier thresholds; monotone diminishing-return table.
- Recommendation: Use h′=min(H,h+g), bounded linear accuracy/critical bonuses; no other stat benefits initially. Award once per action with an intended gameplay effect, not merely acceptance.
- Consequences / still to specify: H, initial h, g, probability scale, bonus caps await approval. Define misses/protect/immunity/healing at full HP and outcome persistence.

## D07 — Component allocation and rounding

- Status: OPEN; gate: M5.
- Question/why: Rounding changes damage and can create split-count exploits.
- Options: Canonical quotient/remainder; carry exact rationals to final sum; truncate and discard remainder.
- Recommendation: Equal split by canonical TypeId quotient/remainder; reject duplicate types; zero allocated power stays zero; floor after each component modifier chain. Allocate any base additive budget once.
- Consequences / still to specify: Approve exact base-damage allocation, component cap and arithmetic bounds. Do not assert final damage equals unsplit damage.

## D08 — Multi-type STAB

- Status: OPEN; gate: M5.
- Question/why: Matching and stacking semantics materially change multi-type strength.
- Options: STAB per matching component; attack-wide STAB; no STAB on mixes.
- Recommendation: Apply once to each matching component; no duplicate actor-type stacking.
- Consequences / still to specify: Multiplier and interactions with type-change abilities require owner approval.

## D09 — Witnesses, training and retention

- Status: PARTIALLY APPROVED — retain learning/observation history on forgetting; witness/training/outcome details remain open. Gate: M6.
- Question/why: Defines discovery difficulty and persistence after forgetting or losing.
- Options: Active conscious witnesses only; whole conscious party; all owned monsters. Retain or erase history on forgetting.
- Recommendation: Active conscious witnesses knowing both sources observe any actual valid mix execution, including a miss but excluding pre-execution fizzle; both allies/enemies may witness. Persist observation/unlock/Harmony when forgetting; require both sources for training/execution. Merge on battle completion including loss/escape.
- Consequences / still to specify: Training resource cost/location, interrupted battles, witness ordering on same-action KO and outcome Harmony commits remain to approve.

## D10 — Recipe orientation and self-pairs

- Status: APPROVED — unordered distinct source pairs, as recommended. Gate: M2 recipe schema; M6 runtime.
- Question/why: Symmetry and identity affect lookup, discovery and recursion prevention.
- Options: Unordered distinct pairs; ordered pairs; unordered including self-pairs.
- Recommendation: Unordered distinct BaseMoveId pairs, one recipe per pair; no ordered recipes in MVP.
- Consequences / still to specify: Later ordered recipes need explicit new schema/version. Mixed outputs never become sources.

## D11 — XP/stat/evolution curves for levels 1–200

- Status: OPEN; gate: M7.
- Question/why: Overflow and scaling cannot be inherited from a level-100 design.
- Options: Polynomial engine curve; explicit monotone threshold table; segmented curve.
- Recommendation: An engine-owned monotone threshold table for 1–200, with bounded integer stat functions validated over all levels. Cap excess XP at the level-200 threshold.
- Consequences / still to specify: Exact thresholds/stats, evolution conditions, post-level HP adjustment, move replacement and reward distribution require balance approval.

## D12 — Capture, party and storage

- Status: OPEN; gate: M7.
- Question/why: Demo promises catching; capture can duplicate creatures or bypass completion.
- Options: Capture consumes an action/item with probability; deterministic threshold; scripted encounter-only capture.
- Recommendation: One battle action and item, engine probability using target state, atomic item/individual/party-or-storage commit. Reject before consumption if no legal destination.
- Consequences / still to specify: Approve formulas, target restrictions, trainer rules, escape outcomes, failure costs and capacity policy.

## D13 — Inventory, shops and move/party capacities

- Status: OPEN; gate: M2 limits; M7 mechanics.
- Question/why: Capacity semantics affect valid saves, encounters and UI.
- Options: Fixed caps; engine-tiered caps; unbounded conceptual storage.
- Recommendation: Fixed engine-owned bounded quantities/slots; atomic buy/sell and transfer; no partial grants unless explicitly modeled.
- Consequences / still to specify: Exact party/storage/move slot counts, prices/currency limits and over-cap reward behavior TBD. Shop UI under M10, transactions M7, world routing M8.

## D14 — World grid and encounters

- Status: OPEN; gate: M8.
- Question/why: Geometry, elevation and traversal define creator UX and deterministic movement.
- Options: Tile grid; navigation grid; tile-authoring with explicit navigation links.
- Recommendation: Tile-grid collision plus integer elevation and explicit ramps/links; decorative 3D geometry separate. Tile-to-tile authoritative movement, visual interpolation.
- Consequences / still to specify: Approve diagonal rules, encounter sampling per entered cell, actor conflicts/priority, interaction range and transition atomicity.

## D15 — Catalog editing powers and type authority

- Status: OPEN; gate: M2.
- Question/why: Authored move/species values must not become configurable engine rules.
- Options: Fixed official catalogs; bounded creator-defined catalogs; trusted reviewed extension packs.
- Recommendation: Bounded species/move/item/recipe authoring; engine-owned type registry/chart, status/ability semantics and formulas.
- Consequences / still to specify: Owner must approve field-level matrix and legal ranges. New engine effects/types are engine releases; projects cannot supply code.

## D16 — Event limits and content budgets

- Status: OPEN; gate: M2/M8.
- Question/why: Finite opcodes can still cause runaway CPU/memory and graph cycles.
- Options: Acyclic activations; cycles with global fuel; bounded structured loops.
- Recommendation: Acyclic immediate activation graph; persistent state machines across activations; hard cumulative activation and queue budgets.
- Consequences / still to specify: Set byte/file/entity/depth/step caps from measured workloads; cap across yields, not merely per frame. Budget exhaustion produces deterministic diagnostics.

## D17 — Save/replay compatibility and battle saves

- Status: OPEN; gate: M1 contracts; M11 release.
- Question/why: Incomplete state or silent migrations corrupt deterministic outcomes.
- Options: Exact identity match only; explicit migrations; permissive compatible-version ranges.
- Recommendation: Exact match initially; version-specific schema-only migrations later. Initially save at stable world boundaries; mid-battle support only when full queue/reservation/pending commit is serialized.
- Consequences / still to specify: UI must communicate save availability; replay captures full initial state and accepted commands early. Cross-ruleset reinterpretation forbidden.

## D18 — Toolchain and presentation host

- Status: OPEN; gate: M0.
- Question/why: No compiler is currently available; platform promises are unverified.
- Options: Pinned Bend-native shell; trusted C adapter; compiled JS with browser shell; process/IPC fallback.
- Recommendation: Run M0 on owner-identified Bend 2 revision, CPU/native baseline; measure native versus browser presentation bridge before choosing.
- Consequences / still to specify: No language substitution or host commitment without review; creator packages must run without compiler.

## D19 — Deterministic RNG algorithm and arithmetic

- Status: OPEN; gate: M3.
- Question/why: Seed alone does not define behavior across different algorithms/backends.
- Options: 32-bit-word xoshiro family; counter-based generator; PCG with verified wider arithmetic.
- Recommendation: Evaluate xoshiro128** as initial candidate against explicit cross-backend vectors and bounded unbiased sampling.
- Consequences / still to specify: Approve algorithm/revision, seed expansion, invalid-state handling and exhaustion before M3. Algorithm change is a ruleset/replay change.

