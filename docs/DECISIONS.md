# Owner decision register

All currently identified entries are approved for the initial ruleset. Fixed brief requirements (level 200, MIX-1–8, discovery before training, no creator code, pure deterministic core) are preserved. Future changes must record the date, selected replacement, exact constants or semantics, and affected ruleset/law IDs; silence does not change an approved rule.

The balance-independent Content-0 slice has completed local implementation. All currently identified owner decision groups are approved. On 2026-09-21 the owner directed the project to use every remaining recommended option and revise it later through an explicit ruleset change if necessary. The initial constants and catalogs in U01–U13 below therefore close D02–D18 for implementation; measured tuning may change only through the documented version process.

## Owner approval during implementation

The owner explicitly selected “Use the recommended rules” for paused command barriers, sequential event resolution, unordered distinct mix pairs, and retained learning history. The owner subsequently selected D01 Option A: 60 logical ticks per presentation second. For D03 Wait pacing, every new game must choose 30, 60 or 120 ticks for the entire game, every executed action has at least 30 ticks of recovery, and zero-tick windup is legal under deterministic current-tick queueing. D05 ordinary move cooldowns have a 60-tick minimum and begin when execution is attempted. If an actor becomes unable to act before execution, its action is cancelled and its reservation is released without starting cooldown. If its locked target is invalid at execution, the action fizzles, starts full cooldown and applies normal recovery without retargeting. Attacker-side offensive values and tie-breaking speed are snapshotted at acceptance while target-side defenses are read at execution, with pure non-authoritative outcome previews. Complete command batches validate and commit atomically against one barrier snapshot. Exact-tick equal-priority actions order by captured speed, then stable ActorId. Battle completion is checked after each atomic action and its immediate aftermath, then pending events are discarded on a terminal result. Mutual defeat produces a core Draw, which single-player campaign policy treats as a player loss. The later blanket approval adopts every remaining recommendation through the exact entries below. Technical M0 execution is authorized by “Well, then implement it.”

On 2026-09-21 the owner approved every recommendation in the remaining R01–R13 packet except these explicit substitutions: R03/D06 uses Option B mastery tiers; R09/D13 uses a modified Option B with Option A's values as project defaults and creator-authored bounded capacity tiers; R10/D14 uses Octopath Traveler-like free-ranging HD-2D exploration rather than tile-step movement. The approved R10 rule describes observable behavior and this engine's deterministic implementation; it does not claim access to another game's proprietary internals.

## D01 — Command selection and pacing

- Status: APPROVED — paused command barriers and 60 logical ticks per presentation second. Gate: M3 implementation.
- Question/why: Changes accessibility, AI information and replay timing.
- Options: Pause at decision barriers; slow logical clock; fully continuous clock.
- Recommendation: Pause at a barrier for all ready controlled actors; AI commits from the same snapshot. Choose tick-to-presentation scale separately.
- Selected semantics: Rendering does not drive the logical clock. The event-driven scheduler jumps between deadlines; it does not perform 60 mandatory simulation passes per second. Editor and presentation layers may display seconds, but canonical durations and replay data use integer ticks.
- Consequences: No input-latency advantage; requires explicit Wait and grouped command UI. Changing the tick scale is a ruleset and replay compatibility change.

## D02 — Equal-tick resolution and completion

- Status: APPROVED — sequential resolution, completion, Draw/Timeout, escape and reinforcement semantics are fixed for the initial ruleset. Gate: M3 core implementation.
- Question/why: Order changes KO trades, expiry, delayed effects and victory.
- Options: Stable sequential events; snapshot/batched simultaneous resolution; speed-based tie resolution.
- Approved exact-tick key: After due tick, phase rank and explicit move priority, higher speed captured at command acceptance resolves first; stable ActorId ascending resolves equal captured speed. Later speed changes affect future command acceptances and do not reorder already scheduled actions. Same-action aftermath is atomic inside execution and completion follows the approved boundary below.
- Approved completion boundary: After an action and all of its immediate aftermath commit atomically, evaluate completion before the next queued event. On a terminal result, commit the result exactly once and discard every pending event. Discarded actions never reach execution, so release reservations without starting cooldown or consuming action RNG/resources. Mutual nonviability resolves as the approved Draw policy below.
- Approved mutual defeat: If one completed atomic action leaves every side without a viable combatant, the battle core returns `Draw`. The single-player campaign outcome policy maps that Draw to player loss for progression, rewards, recovery and story routing. Preserve `Draw` in the battle record and replay; do not rewrite simulation history to `Defeat`. Non-single-player modes may retain Draw semantics under a future explicit mode policy.
- Approved timeout: The logical battle clock is bounded to 216000 ticks (one hour of active logical time). If advancing or scheduling would exceed that bound, return core result `Timeout`, commit it once and discard pending events. Single-player campaign policy maps Timeout to player loss while records/replays preserve Timeout. Paused wall-clock input time does not advance this bound.
- Approved escape: Escape is a normal action available only in escapable wild encounters. Its chance is `clamp(5000 + 25 × (fastestPlayerSpeed - fastestEnemySpeed) + 1000 × priorFailedEscapes, 1000, 9500)` on the 0–10000 scale. Acceptance locks the two speed values. Failure consumes the action and recovery; success returns core result `Escaped`, discards pending events after the atomic action, grants no XP/currency/items, and still commits observations and Harmony. Trainer, boss and explicitly locked encounters reject escape without cost.
- Approved reinforcements: Reinforcements are finite validated encounter entries, never arbitrary runtime spawns. Each side has at most 12 total battle participants and 4 active participants. A queued reinforcement makes its side viable. After an action and aftermath, fill vacant active slots in encounter order before evaluating victory; arrivals become command-ready at the next normal barrier and cannot act retroactively. Stable ActorId breaks simultaneous arrival ordering.
- Consequences: Speed has no second timing role beyond the approved exact-tick key and escape formula. Changes to escape or reinforcement semantics require a ruleset version.

## D03 — Commitment, snapshots and invalid targets

- Status: APPROVED for the M3 command lifecycle — game-wide player Wait pacing, 30-tick minimum recovery, atomic batches, pre-execution actor cancellation, invalid-target fizzle and hybrid stat snapshots. Later mechanics must preserve these semantics or request an explicit versioned decision. Gate: M3 implementation.
- Question/why: Cancellation and retargeting affect costs, damage and tactical information.
- Options: Snapshot stats/targets at selection; read at execution; mixed snapshot policy.
- Selected policy: Lock target identity at acceptance; use the approved hybrid stat snapshot, fizzle on an invalid target, and never retarget. No voluntary interruption is available. Pre-execution actor invalidation cancels for free under the exact rule below. Require positive recovery and an explicit Wait action with positive engine-owned duration, scheduled readiness, and no source cooldown consumption. Batch reservation is atomic; zero-windup executions enter the normal priority queue only after all batch reservations commit.
- Approved Wait pacing: At new-game creation the player must select 30, 60 or 120 ticks. The selection applies to that entire game, is stored in saves and replay headers, and cannot change mid-game. Respectively these provide more action-like, balanced or more turn-like command cadence. Projects cannot remove choices, add values or override their semantics. The setting controls explicit Wait duration; it does not rescale move timings, damage, RNG or presentation frame rate.
- Approved recovery floor: Every executed action gives its actor at least 30 ticks of recovery. Content may specify a longer bounded recovery but cannot reduce it below half a presentation second. Recovery is actor-wide and distinct from each source move's cooldown.
- Approved windup floor: Creator-authored windup may be zero. A zero-windup action is enqueued for the acceptance tick only after the complete batch validates and commits. It follows the normal event key, cannot execute during the commit loop, and cannot reopen a same-tick command barrier. Positive recovery prevents a zero-time action loop.
- Approved timing ceilings: Windup is 0–600 ticks, recovery is 30–600 ticks, and ordinary cooldown is 60–3600 ticks. Presentation may animate independently but cannot extend logical timing. Project content outside these ranges rejects.
- Approved pre-execution cancellation: If the actor becomes unable to act before its execution phase, the pending action is cancelled, its move reservation is released and no cooldown begins. Voluntary cancellation is unavailable. Battle completion may discard the pending action under D02 without charging it.
- Approved target commitment: Target identity is locked at acceptance. If that target is invalid when execution is attempted, do not retarget and do not apply move effects. Start the move's full cooldown and apply the action's normal recovery. Emit a deterministic fizzle event identifying the original target and reason; consume no hit, critical or damage RNG for the fizzle.
- Approved stat timing: At acceptance snapshot the attacker's offensive inputs required by the selected move, including relevant attacker stages, bonuses and committed move parameters. At execution read the target's current defensive inputs and target-side modifiers. A pure preview function may compute possible outcome ranges from the acceptance snapshot, current visible defense and known queued deterministic changes. Preview consumes no RNG, changes no state and is not authoritative when later state or random draws can vary. Exact damage is computed and committed atomically at the scheduled execution tick; host computation time never advances the logical clock or adds damage delay.
- Approved batch transaction: A barrier collects one legal command or explicit Wait for every required ready controlled actor. Validate the complete batch against the unchanged barrier snapshot, including cross-command reservation conflicts. Commit all commands in stable actor order only if every command is valid. Any error returns stable diagnostics while state, time, RNG, resources, cooldowns and reservations remain unchanged. The UI may retain selections for correction, but retained UI state is not simulation state.
- Approved switching and KO replacement: Voluntary switch is an action with normal 30-tick minimum recovery and no move cooldown. At execution it atomically replaces the actor with a legal reserve; outgoing move cooldowns and persistent state remain with that individual. Actions already locked onto the outgoing active keep that identity and later fizzle under D03 if it is no longer a legal active target. A trapped actor cannot switch. After an action KOs an active actor, choose or deterministically select a legal reserve at a paused replacement barrier before completion; forced replacement costs no action or recovery and becomes ready only after the replacement transaction. If no active or queued reserve remains, the side is nonviable.

## D04 — Damage/effect mechanics and randomness

- Status: APPROVED — the M3 damage subset and R01 closed ordered effect/status algebra are fixed. Type allocation and STAB are fixed separately by D07–D08.
- Question/why: All combat needs exact formulas and stacking; compositional effects alone are insufficient.
- Options: Simple bounded integer base formula; scaled rational formula; engine-owned lookup tables.
- Approved base formula: `floor(movePower × (2 × attackerLevel + 50) × capturedAttack ÷ (300 × currentDefense))`, with one floor after the complete exact ratio. Attacker level/offense use the acceptance snapshot; target defense uses execution state and must be positive. All values and intermediate operations are bounded and checked. Physical and special categories share the structure with their corresponding attack/defense stats. At equal attack and defense the direct level factor is approximately 0.17 at level 1, 0.50 at level 50, 0.83 at level 100 and 1.50 at level 200.
- Approved zero-damage rule: Do not impose a minimum. A successful nonimmune damaging action may deal zero after integer rounding and modifiers. Emit a distinct `NoDamage` outcome, separate from `Miss`, `Immune` and `Fizzle`. After it is observed, the battle UI must clearly mark that the move currently cannot damage that target under the observed offensive snapshot and target state. Recompute or invalidate that knowledge when relevant attacker or defender state changes; never present it as a permanent species-level fact when stats can change.
- Approved move-power bound: A damaging move has integer power in 1–200. Status and utility moves do not carry a damage-power value. Projects cannot define zero-power damaging moves or exceed the upper bound; exceptional engine-owned effects must use explicit effect semantics rather than bypassing the bound.
- Approved effective-stat bound: Effective Attack, Defense, Special Attack, Special Defense and Speed are positive integers in 1–9999 after all progression and temporary modifiers. The runtime rejects or prevents transitions outside this range; it does not wrap. Creator-authored base-stat fields may receive narrower bounds when progression curves are approved. With maximum power, level and effective attack, the base numerator is 899,910,000 before division.
- Approved probability scale: Accuracy, critical, capture and other random chances use integer units in 0–10000, where one unit is 0.01 percentage points. For a random check sample an unbiased integer in `[0,10000)` and succeed iff `draw < chance`. Zero never succeeds and 10000 is certain. Editor percentages are presentation; canonical content/state/replay values are integers.
- Approved accuracy model: Moves carry an authored base accuracy in the shared probability scale or an explicit engine-defined always-hit property. Ordinary final accuracy applies an engine-owned multiplier to `netStage = capturedAttackerAccuracyStage - currentTargetEvasionStage`, with net stage clamped to its approved finite range, then clamps the final chance to its approved bounds. Attacker Accuracy stage follows the acceptance snapshot; target Evasion stage is read at execution. Projects may invoke closed effects that change stages but cannot define the range or multiplier curve.
- Approved accuracy stages: Each Accuracy and Evasion stage is bounded to −6…+6. Clamp their difference to net stage `n` in −6…+6. For `n >= 0`, multiply base accuracy by `(3+n)/3`; for `n < 0`, multiply by `3/(3+abs(n))`. Use exact integers and one floor after the multiplication/division, then apply the final chance bounds. Thus the endpoints are 1/3× and 3×; at net stages −3 and +3 they are 1/2× and 2×.
- Approved ordinary accuracy floor: After the stage calculation, clamp an ordinary legal accuracy chance to 500–10000 (5%–100%). The floor does not override invalid targets, immunity, fizzle or explicit blocking effects. Always-hit moves bypass the ordinary check.
- Approved authored accuracy: Ordinary move base accuracy is an integer in 500–10000. An explicit engine-controlled `alwaysHit` property bypasses the ordinary formula and hit draw; ordinary 10000 accuracy remains subject to Evasion stages. Projects may select `alwaysHit` only where the closed move/effect schema permits it and cannot emulate it with out-of-range numbers.
- Approved baseline critical chance: An eligible damaging action that passed accuracy has a base critical chance of 625/10000 (6.25%) before engine-owned critical modifiers. Nondamaging actions do not make critical checks. The approved multiplier, cap and draw-consumption rules are recorded immediately below.
- Approved critical damage: A critical hit multiplies the fully resolved eligible normal component aggregate by exactly 2 before HP saturation. Normal damage already includes the approved stages, type interactions, per-component STAB and component floors. Zero damage remains zero.
- Approved critical stage behavior: Critical hits respect all attacker and target Attack, Special Attack, Defense and Special Defense stages. They do not bypass unfavorable or favorable stages. Given the same execution state, critical damage is exactly twice the corresponding resolved noncritical damage before HP saturation; a zero result remains zero.
- Approved ordinary critical cap: Sum engine-owned critical bonuses with the 625 baseline and clamp ordinary critical chance to 2500/10000 (25%). The UI must show when the cap makes further bonuses ineffective. A future explicit guaranteed-critical effect is not implied by this cap and would require its own approved engine rule.
- Approved M3 draw policy: Actor cancellation and invalid-target fizzle consume no samples. `alwaysHit` consumes no accuracy sample. An ordinary valid-target attempt consumes one unbiased bounded accuracy sample; a miss stops without critical. Successful nondamaging actions and deterministically blocked/immune damage consume no critical sample. A successful nonimmune damaging hit consumes one unbiased bounded critical sample even if resolved damage later becomes zero. Rejected commands never consume RNG. Internal rejection-sampler candidates belong to one semantic sample and follow D19's remaining termination policy.
- Approved R01 effect/status algebra: Resolve a move's declared effects in author order inside one atomic action transaction. A named status has at most one instance on a target. Reapplication refreshes its duration and retains the stronger magnitude; it does not add an unbounded stack. Check engine-defined protection and immunity before the affected effect. Engine-owned incompatibility entries explicitly reject or replace statuses; project content cannot define new conflict behavior. Actual aggregate HP loss drives drain/recoil. The closed effect catalog and all finite stat-stage clamps remain engine-owned.
- Consequences / implementation detail: Each engine status still needs a declared duration range, magnitude comparison, immunity set and incompatibility outcome in the M4 status table. Those entries implement the approved algebra and do not reopen the stacking model. Content validation and the UI must detect or communicate zero-damage matchups. The strong damage curve makes level progression a major balance input and must be tested exhaustively over levels 1–200.

## D05 — Cooldown origin and mixed penalty

- Status: APPROVED — ordinary cooldowns and R02 mixed-source cooldowns are fixed.
- Question/why: Both sources must receive increased cooldown and cannot bypass eligibility.
- Options: Additive penalty; multiplicative penalty; engine-defined tier table.
- Selected ordinary origin: Acceptance reserves the move but does not start its cooldown. The cooldown begins when the action reaches execution and attempts to use the move. The reservation prevents reuse during windup. Execution-time fizzle costs require the follow-up decision below.
- Approved pre-execution cost: An action cancelled because its actor cannot reach execution releases its reservation without starting cooldown. No ordinary project command may voluntarily cancel a reserved action.
- Approved invalid-target cost: An actor that reaches execution with an invalid locked target starts the move's full cooldown and enters normal recovery. The action emits a fizzle and applies no move effects.
- Approved mixed penalty: At attempted mixed execution, each source receives `ceil(3 × ordinaryCooldown / 2)`. The mixed deadline ceiling is 5400 ticks. Pre-execution actor cancellation remains free; an invalid-target mixed fizzle charges both sources and normal recovery. Check both deadline additions and the battle-clock bound before committing either cooldown or any effect.
- Approved ordinary floor: Every creator-authored ordinary move cooldown is at least 60 ticks. Engine-defined actions may use distinct explicitly documented timing, but project data cannot reduce the ordinary move floor.
- Approved ordinary ceiling: Creator-authored ordinary move cooldown is at most 3600 ticks. Windup/recovery ceilings are governed by D03; checked deadline addition must remain within the D02 battle-clock bound.
- Consequences: The proportional penalty preserves authored cooldown meaning across all three Wait pacing choices. Execution must reject checked-arithmetic overflow atomically; one source can never be charged without the other.

## D06 — Harmony maximum, growth and benefits

- Status: APPROVED — R03 Option B, six mastery tiers. Gate: M6.
- Question/why: Progression must be bounded and individual; success is undefined.
- Options: Linear capped growth/bonuses; tier thresholds; monotone diminishing-return table.
- Selected semantics: Store successful-use progress as an integer 0–40 and derive six tiers: Novice at 0, Familiar at 5, Practiced at 10, Expert at 20, Master at 30 and Perfected at 40. Their fixed accuracy/critical bonuses in the 0–10000 probability scale are respectively `0/0`, `100/125`, `200/250`, `300/375`, `400/500` and `500/625`. Ordinary critical chance still clamps at 2500. Harmony grants no other stat benefit initially.
- Approved success event: Award at most one successful use after a valid mixed execution produces at least one intended gameplay effect. A miss, protection/immunity that blocks every effect, healing at full HP, cancellation or fizzle awards none. Commit the increment with the action transaction; a later battle loss or escape does not erase it.
- Consequences: Tier changes are visible milestones and the UI must show current progress, next threshold, both bonuses and any critical-cap waste.

## D07 — Component allocation and rounding

- Status: APPROVED — R04 Option A. Gate: M5.
- Question/why: Rounding changes damage and can create split-count exploits.
- Options: Canonical quotient/remainder; carry exact rationals to final sum; truncate and discard remainder.
- Selected semantics: A move has 1–4 distinct type components. Divide its total power by component count; distribute the remainder one point at a time in canonical TypeId order. Apply each component's modifier chain independently, floor that component once at its approved boundary, then sum checked component results. Duplicate types reject and zero allocated power remains zero. Allocate any base additive budget once rather than once per component.
- Consequences: The full integer power budget is preserved before modifiers, but final split damage is not required to equal unsplit damage.

## D08 — Multi-type STAB

- Status: APPROVED — R05 Option A. Gate: M5.
- Question/why: Matching and stacking semantics materially change multi-type strength.
- Options: STAB per matching component; attack-wide STAB; no STAB on mixes.
- Selected semantics: Apply exact `3/2` STAB once to each component whose type matches any distinct current actor type. Multiple actor-type matches never stack on one component. Use the actor's accepted offensive/type snapshot unless an explicit future engine effect says otherwise.
- Consequences: STAB stays local to the matching damage; the battle UI must expose component-local matches and modifiers.

## D09 — Witnesses, training and retention

- Status: APPROVED — retained history plus R06 Option A. Gate: M6.
- Question/why: Defines discovery difficulty and persistence after forgetting or losing.
- Options: Active conscious witnesses only; whole conscious party; all owned monsters. Retain or erase history on forgetting.
- Selected semantics: At valid mixed execution start, snapshot active conscious combatants that know both sources; allies and enemies may qualify. Those witnesses observe the mix even if it misses or the same action later KOs them, but not if the action cancels or fizzles before a valid execution. Merge observation at every committed terminal battle result, including loss and escape. Unlock at a designated trainer by consuming one bounded training token while the individual still knows both sources. Execution also requires both sources. Forgetting never erases observation, unlock or Harmony history.
- Consequences: Training tokens and trainer placement are ordinary bounded content/economy data; the knowledge rules remain engine-owned.

## D10 — Recipe orientation and self-pairs

- Status: APPROVED — unordered distinct source pairs, as recommended. Gate: M2 recipe schema; M6 runtime.
- Question/why: Symmetry and identity affect lookup, discovery and recursion prevention.
- Options: Unordered distinct pairs; ordered pairs; unordered including self-pairs.
- Recommendation: Unordered distinct BaseMoveId pairs, one recipe per pair; no ordered recipes in MVP.
- Consequences / still to specify: Later ordered recipes need explicit new schema/version. Mixed outputs never become sources.

## D11 — XP/stat/evolution curves for levels 1–200

- Status: APPROVED structurally — R07 Option A. Gate: M7.
- Question/why: Overflow and scaling cannot be inherited from a level-100 design.
- Options: Polynomial engine curve; explicit monotone threshold table; segmented curve.
- Selected semantics: Ship an engine-owned 200-entry cumulative XP threshold table and bounded integer stat functions/tables validated at every level. Cap stored XP at the level-200 threshold. Evolution uses explicit level/item/event predicates. When maximum HP increases on level-up, current HP increases by the same delta. Move learning/replacement and reward distribution are atomic.
- Consequences / implementation detail: The exact 200 thresholds, species growth parameters, evolution catalog and reward table are balance content of the engine ruleset and require exhaustive generated validation before M7 exits; choosing their tuned entries does not reopen the table-based structure.

## D12 — Capture, party and storage

- Status: APPROVED — R08 Option A. Gate: M7.
- Question/why: Demo promises catching; capture can duplicate creatures or bypass completion.
- Options: Capture consumes an action/item with probability; deterministic threshold; scripted encounter-only capture.
- Selected semantics: Capture is one battle action using one eligible item and an engine-owned bounded probability based on target state. Reject before acceptance when the target is restricted or neither party nor storage has a legal destination. At attempted execution consume the item; failure spends the action and recovery. Success atomically creates exactly one owned individual and routes party first, then storage. Trainer-owned and explicitly uncapturable targets reject.
- Consequences / implementation detail: M7 must tune the exact target-state coefficients and item modifiers within the shared probability scale. Capacity behavior follows D13; no branch may duplicate a creature or partially commit the transaction.

## D13 — Inventory, shops and move/party capacities

- Status: APPROVED — modified R09 Option B with creator-authored bounded tiers. Gate: M2 limits; M7 mechanics.
- Question/why: Capacity semantics affect valid saves, encounters and UI.
- Options: Fixed caps; engine-tiered caps; unbounded conceptual storage.
- Selected defaults: A project with no capacity overrides uses party size 6, equipped move slots 4, storage 1000 individuals, item stacks 999, 512 distinct inventory entries and currency cap 9,999,999.
- Creator authority: A project may declare a finite monotone capacity-tier table, including its initial tier and event-driven unlocks, within engine-owned schema safety ceilings. This is an explicit exception to the original engine-only capacity policy. Capacity values and tiers are part of project content identity and save compatibility. A tier transition cannot invalidate existing state; a downgrade below current occupancy rejects.
- Atomic behavior: Buy, sell, reward, capture and transfer transactions validate their complete result first. Reject any result that cannot fit; never partially grant or silently discard. Eligible captures route party first, then storage.
- Consequences / implementation detail: The engine safety ceilings must be set from measured M7/M10/M11 workloads before the public schema freezes. The defaults above are approved and immediately usable; creator overrides cannot be unbounded.

## D14 — World movement and encounters

- Status: APPROVED — R10 custom Octopath Traveler-like exploration. Gate: M8.
- Question/why: Geometry, elevation and traversal define creator UX and deterministic movement.
- Selected player behavior: Characters move freely in any horizontal direction through an HD-2D diorama: 2D billboard sprites inhabit 3D authored scenes, follow visible traversable routes and elevations, and are not locked to tile steps. Analog magnitude selects walk/run; a sprint input reaches full speed and increases encounter accumulation. Keyboard/digital input maps to normalized directions. Fast travel is a separate explicit world transition.
- Deterministic authority: Use checked fixed-point world coordinates and a baked navigation surface with explicit elevation/ramp/transition links. Resolve swept movement/collision against that surface; rendering interpolation, camera, frame rate and billboard orientation never affect logical position. Interactions use an engine-owned range and facing cone. Simultaneous actor conflicts resolve by stable ActorId after comparing proposed sweeps.
- Encounters: Accumulate authoritative ground distance in eligible encounter regions, multiplied by the movement-mode rate; do not sample per render frame or tile. On region entry and after an encounter, draw one bounded deterministic next-encounter distance. Trigger when accumulated weighted distance reaches it. Full-speed sprint uses a larger accumulation multiplier, matching the intended speed-versus-encounter tradeoff.
- Consequences / implementation detail: M8 must select fixed-point scale, movement speeds, interaction range, region thresholds and sprint multiplier through measured feel tests. Those constants implement this approved free-ranging model; they cannot depend on presentation frame rate.

## D15 — Catalog editing powers and type authority

- Status: APPROVED — R11 Option A, subject to D13's explicit bounded-capacity exception. Gate: M2/M10.
- Question/why: Authored move/species values must not become configurable engine rules.
- Options: Fixed official catalogs; bounded creator-defined catalogs; trusted reviewed extension packs.
- Selected semantics: Projects may author bounded species, trainers, encounters, maps, dialogue, items, moves, unordered recipes and D13 capacity tiers. They select from engine-defined types, targets, effects, statuses and abilities. The type registry/chart, formulas, opcodes, effect/status/ability semantics and all hard safety ceilings change only with an engine release. Projects cannot supply executable code.
- Consequences / implementation detail: M2/M10 must publish and validate a field-level authority matrix and legal ranges. New engine effects or types require a ruleset release.

## D16 — Event limits and content budgets

- Status: APPROVED structurally — R12 Option A. Gate: M2/M8.
- Question/why: Finite opcodes can still cause runaway CPU/memory and graph cycles.
- Options: Acyclic activations; cycles with global fuel; bounded structured loops.
- Selected semantics: The event graph reachable during one activation must be acyclic. Repetition is represented by persistent state and later activations. Enforce hard cumulative activation fuel, queue, nesting, entity and byte budgets across yields, not per frame. Budget exhaustion aborts the activation atomically and emits deterministic diagnostics.
- Consequences / implementation detail: Exact public limits must be measured against representative projects before schema freeze. The acyclic activation model and cumulative accounting are approved.

## D17 — Save/replay compatibility and battle saves

- Status: APPROVED — R13 Option A. Gate: M1 contracts; M11 release.
- Question/why: Incomplete state or silent migrations corrupt deterministic outcomes.
- Options: Exact identity match only; explicit migrations; permissive compatible-version ranges.
- Selected semantics: Loading requires the exact engine ruleset version and project content digest. Initially save only at stable world boundaries outside active battle or event transactions. Replays store the complete initial state plus accepted commands. Later migrations are explicit, version-specific schema transformations; cross-ruleset reinterpretation is forbidden. Mid-battle saves remain unavailable until the full scheduler, barriers, reservations, RNG, queued events and pending atomic commits are serialized and proven.
- Consequences: The UI must communicate save availability and identity mismatch clearly. Every creator capacity override under D13 participates in the project digest.

## D18 — Toolchain and presentation host

- Status: APPROVED for the initial target — hybrid browser maker plus native packaged runtime, with Linux x86_64 as the first supported release target. Gate: remaining M0/M9 work.
- Question/why: The compiler and local baseline are now measured, while live device and cross-platform behavior remain unverified.
- Options: Pinned Bend-native shell; trusted C adapter; compiled JS with browser shell; process/IPC fallback.
- Selected host boundary: Keep one pure Bend rules core. The maker/editor uses the compiled JavaScript core in a browser shell. Packaged games and headless tools use the native core behind a narrow trusted C host adapter. Use SDL3 for the initial window, graphics, controller/input and audio adapter unless the feasibility spike proves a blocking incompatibility; changing the library without changing the pure contracts is an implementation substitution, not a gameplay rule change.
- Initial support promise: Linux x86_64 CPU is the first supported packaged target. Windows x64 and macOS arm64 remain validation targets and must not be advertised as supported until their clean-machine packaging, window, audio and input gates pass. CPU-only operation is mandatory; GPU acceleration is optional.
- Presentation defaults: 1280×720 logical 16:9 output with scalable window/fullscreen presentation; perspective map camera authored from bounded profiles; 2D sprites billboard inside 3D scenes; renderer interpolation, lighting, depth effects, VFX and audio never feed logical state. Keyboard and gamepad are supported by the host mapping and may be rebound outside canonical replay commands.
- Packaging: Creator exports contain validated content, assets and a prebuilt runtime; the player needs no Bend compiler. Content identity and runtime ruleset identity follow D17.

## D19 — Deterministic RNG algorithm and arithmetic

- Status: APPROVED for M3 — xoshiro128** with explicit state, conditional semantic draws, single reducer ownership and bounded rejection sampling. Gate: M3 implementation.
- Question/why: Seed alone does not define behavior across different algorithms/backends.
- Options: 32-bit-word xoshiro family; counter-based generator; PCG with verified wider arithmetic.
- Selected algorithm: xoshiro128** with an explicit version identifier and four U32 state words. Use only specified U32 wraparound, XOR, shifts, rotations and multiplication. Reject the all-zero state. Lock implementation to published/reference-derived known-answer vectors plus repository vectors across native and JavaScript backends. Bounded sampling uses rejection sampling and never modulo-biased reduction.
- Selected initial state: The battle core receives four canonical U32 words directly and rejects the all-zero tuple. Saves and replays preserve all four exact words plus the RNG version. World/new-game shells may derive friendly seed codes separately, but human seed metadata never replaces the canonical state.
- Selected draw consumption: Apply D04's conditional semantic policy for cancellation, fizzle, always-hit, accuracy, miss, nondamage, deterministic block/immunity, damaging hit and critical. Rejected command batches never advance state.
- Selected ownership and sampling bound: The battle reducer exclusively owns one xoshiro state. Pure parallel calculations never copy or mutate it. Semantic samples commit in canonical event order. Each unbiased bounded sample may inspect at most 64 xoshiro candidates; 64 rejections return deterministic engine fault `RngSamplingExhausted` with no partial action commit. This fault is not a gameplay outcome. Replays reproduce it.
- Consequences: Algorithm, ownership, consumption or sampling-budget changes are ruleset/replay changes. Future independent streams require an explicit versioned derivation decision. This RNG is deterministic gameplay infrastructure, not cryptography.

## U01–U13 — Final recommended-default closure

Status: APPROVED on 2026-09-21 by the owner's instruction to use every remaining recommended option and revise later if needed. D02/D03/D18 above contain escape, reinforcement, switching and platform decisions. The remaining defaults are:

### U04 — Initial type system

- Registry: `neutral`, `ember`, `tide`, `verdant`, `stone`, `gale`, `spark`, `frost`, `radiant`, `umbral`.
- Ratios: ordinary `1`, strong `2`, resisted `1/2`; no initial type immunity. Unlisted ordered pairs are ordinary. Neutral has no strong or resisted pairs.
- Strong attack pairs: Ember→Verdant/Frost; Tide→Ember/Stone; Verdant→Tide/Stone; Stone→Ember/Spark; Gale→Verdant/Umbral; Spark→Tide/Gale; Frost→Verdant/Gale; Radiant→Frost/Umbral; Umbral→Radiant/Spark. Reverse-listed defenses use `1/2`; every other ordered pair uses `1`.
- Current actor types are snapshotted with offensive inputs. Type changes are closed effects and affect later accepted actions only. The UI always exposes each component's ratio.

### U05 — Initial status and ability catalog

- Status durations count that affected actor's completed action opportunities. `burn`: 3 opportunities, physical damage dealt ×3/4 and `floor(maxHP/16)` aftermath damage. `poison`: 4 opportunities and `floor(maxHP/8)` aftermath damage. `sleep`: skip 2 action opportunities and then clear. `stun`: skip the next single opportunity and clear. `blind`: 3 opportunities and −2 Accuracy stages while active. Residual positive damage has a minimum of 1 and cannot act after battle completion.
- One named instance, stronger magnitude retention and duration refresh follow D04. Burn and poison are mutually exclusive; the newer application replaces only if its remaining expected residual damage is greater, otherwise it emits `NoEffect`. Sleep and stun are mutually exclusive and the newer application replaces. Blind is independent. Engine cleanse removes explicitly named statuses; full cleanse uses a separate engine effect. No type/status immunities exist by default.
- Abilities are excluded from the initial playable schema. `AbilityId` remains reserved; the first ability catalog requires a versioned engine release rather than inert accepted data.

### U06 — Progression, evolution, learning and rewards

- Cumulative XP threshold at level `L` is the precomputed 200-entry table generated by `25 × (L−1)^3 + 75 × (L−1)` for `1 <= L <= 200`; the shipped table, not runtime floating-point evaluation, is canonical. XP caps at the level-200 threshold.
- Species base HP/Attack/Defense/SpecialAttack/SpecialDefense/Speed are integers 1–500; individual values are 0–31. At level L, max HP is `floor((2×base+individual)×L/100)+L+10`; other base combat stats are `floor((2×base+individual)×L/100)+5`, before bounded stages/effects. Effective combat stats remain 1–9999.
- Evolution rules are ordered, creator-authored selections of engine predicates: minimum level, required item, required project flag, time profile, known move, learned recipe and minimum Harmony tier. A rule has at most four AND predicates; first valid rule in canonical EvolutionRuleId order is offered. Evolution is an explicit transaction, never automatic unless content marks the rule automatic.
- Level-up moves use ordered level/MoveId entries. If all project-configured move slots are full, learning pauses at a choice barrier; declining is legal and recorded. Evolution preserves individual identity, XP, observations, unlocks and Harmony.
- Each defeated opponent has creator-authored `baseXpYield` 1–1000 and `baseCurrencyYield` 0–100000. XP award is `floor(baseXpYield × defeatedLevel / eligibleParticipantCount)` to each living or previously active player participant; currency is awarded once per encounter from the sum of defeated yields. Loss, Draw, Timeout and Escape award none. Item rewards use bounded encounter tables and commit atomically after Victory/Capture resolution.

### U07 — Capture calculation

- Species `captureRate` is 500–9000. Item `captureMultiplier` is an exact rational from 1/2 through 4. Status multiplier is 2 for sleep/stun, 3/2 for burn/poison/blind, otherwise 1.
- Chance is `clamp(floor(captureRate × itemMultiplier × statusMultiplier × (3×maxHP−2×currentHP) / (3×maxHP)), 100, 9500)` in the shared scale. Checked exact arithmetic and one final floor are required.
- Trainer-owned, boss and explicitly uncapturable targets reject before item consumption. A successful capture removes the target, commits the new individual, then runs the normal reinforcement/completion boundary. Failure consumes the item, action and recovery.

### U08 — Capacity tiers and economy

- Defaults remain party 6, moves 4, storage 1000, item stack 999, inventory entries 512 and currency 9,999,999. Hard creator ceilings are party 12, moves 8, storage 10000, item stack 9999, inventory entries 4096 and currency 999,999,999. A project may declare at most 16 monotone capacity tiers.
- Item buy price is creator-authored 0–1,000,000. Zero means not purchasable. Unless explicitly unsellable, sell value is engine-derived as `floor(buyPrice/2)`; projects cannot author a separate arbitrage-producing sell value. Currency overflow, full inventory and invalid tier downgrade reject atomically.

### U09 — World movement and encounters

- Coordinates use signed fixed point with 1024 subunits per world unit. Default speeds are walk 2.5, run 4.5 and sprint 7 world units per presentation second. Collision radius is 0.35 unit. Interaction range is 1.5 units with a 120-degree facing cone.
- Encounter distance is sampled uniformly as an integer fixed-point distance from 24–40 world units on region entry and after battle. Weighted accumulation multipliers are walk 3/4, run 1 and sprint 3/2. After battle, 12 unweighted world units are encounter-safe. Pausing, menus and camera movement never reset or advance the meter.
- Encounter tables contain weighted entries with positive integer weights 1–10000 and optional bounded level ranges 1–200. Sample once at trigger in canonical entry order. Fast travel is available only between unlocked nodes at stable world boundaries and consumes no encounter distance.
- Maps may be painted with tiles, but traversal authority is the baked navigation surface. Baking must produce deterministic fixed-point polygons/links or reject the map; creators never supply executable navigation code.

### U10 — Event and content budgets

- One activation permits 10000 executed nodes, queue length 1024, branch/nesting depth 32, 64 enqueues from one node and 64 yielded resumptions. A map permits 4096 event nodes and 1024 live event-state instances. A project permits 100000 persistent flags/variables combined.
- Full project intake is capped at 512 MiB validated bytes, 65536 manifest files, 10000 entities per catalog kind and JSON depth 32. Per-asset decoded limits are format-specific and must be declared before a decoder is enabled. Content-0 retains its smaller development limits.
- Exhaustion aborts the current activation atomically with a deterministic diagnostic; it does not corrupt persistent state or silently skip nodes.

### U11 — Creator field authority

- Species may author the approved base stats, capture rate, yields, types, assets, evolution rules and level-up move list. Moves may author power 1–200, accuracy 500–10000 or permitted always-hit, windup 0–600, recovery 30–600, cooldown 60–3600, priority −8…+8, 1–4 distinct components and at most 16 closed effects. Items may author buy price, assets and permitted closed item effects. Recipes may reference exactly two distinct single-component BaseMoveIds and an approved result descriptor.
- Trainers, encounters, maps, dialogue, quests, shops, event graphs, capacity tiers and rewards are creator-authored within the approved schemas and budgets. Type identities/chart, statuses, formulas, opcodes, RNG, Harmony tiers, hard ceilings and effect semantics remain engine-owned.

### U12 — Save/replay encoding and user policy

- Canonical content/state encoding is strict UTF-8 JSON with sorted object keys, canonical decimal integers, no insignificant whitespace, preserved semantic array order and normalized paths. Integrity/content digests use SHA-256 over canonical bytes.
- Provide 10 manual slots, one rotating autosave and one previous-version recovery copy per slot. Autosave only at stable map entry, successful healing/rest, completed capture and explicit story checkpoint boundaries. Never autosave during battle/event transactions.
- Identity mismatch refuses load with the exact expected/actual ruleset and content digests. Corrupt primary data offers the verified recovery copy. Migrations write a new slot atomically and retain the original until successful readback.
- Replays store full initial state and accepted commands, with optional canonical state hashes every 1024 accepted commands and at terminal completion.

### U13 — Decision/ADR/law closure policy

- Renderer/runtime separation, editor frozen-snapshot playtest, strict inert JSON, hashed AssetId manifests, command replays, unordered recipes and exact save identity are accepted architecture decisions rather than proposals.
- The old tile-grid ADR is superseded by D14/U09. ADR documents must be updated before the relevant milestone exits.
- An approved gameplay rule may be translated into a Bend law without another option-selection round when the law states exactly that rule. Any stronger/weaker premise, exception or semantic change returns to owner approval.
