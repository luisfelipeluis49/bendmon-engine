# Architecture

Status: initial architecture accepted by the 2026-09-21 U13 closure. Names below describe conceptual contracts, not Bend syntax; production representations still require milestone review and proof/test evidence.

## Boundaries and data flow

Editor document → strict export → untrusted project bytes → bounded parse → structural validation → reference and semantic validation → immutable ValidatedContent → deterministic core → ordered events + projection → renderer/audio/UI.

Player/AI inputs → shell command adapter → typed command validation → core transition. Save bytes follow their own strict validation and identity checks before constructing valid runtime state. Editor playtest uses exactly the shipping validator and core, not a permissive editor-only simulation.

Core transition concept: `transition(content, ruleset, state, command, rng) -> Accepted(state, rng, events) | Rejected(diagnostic, unchanged state/rng)`. Ruleset is an engine-owned immutable build artifact, not a field creators can populate with custom rules. Advance-to-event and command submission are distinct operations. All random gameplay decisions are explicit transitions. Render projections exclude mutable core handles.

## Layers

| Layer | Responsibilities | Forbidden dependencies |
|---|---|---|
| Core / domain | Typed identities, valid state, checked arithmetic, deterministic transitions | Filesystem, wall clock, graphics, dynamic imports |
| Content | Closed decoded data, stable resolution, validation certificates/contracts | Running pack code; executing importer-provided callbacks |
| Persistence | Canonical semantic encoding, identity matching, explicit migration | Pointer layout; silently accepting incompatible rules |
| Platform | Bytes, windows, input, audio, clocks for presentation, approved host ABI | Defining damage/timing/progression |
| Renderer | Read-only snapshots and stable event IDs, interpolation, sprites/depth/lighting | Authoritative collision/hits; gameplay in animation callbacks |
| Editor | Draft documents, undo/redo, tools, validation UI, export/playtest | Bypassing runtime validation; overriding constants |

## Proposed repository layout

```text
AGENTS.md  README.md  PLAN.md
LAWS.bend                         # future human-approved semantic specification
PROOF.bend                        # future proof entry importing every approved law
engine/
  core/                          # IDs, arithmetic, ruleset registry, validity
  content/                       # decoded types, references, validation
  battle/  moves/  mixing/        # scheduler, effects, recipes, learning
  progression/  inventory/       # XP, stats, capture/party/storage transactions
  world/                         # grid, encounters, event machine
  save/  replay/                 # pure representations, compatibility
platform/                        # trusted IO and narrow host adapters
renderer/                        # authoritative-state projections
editor/                          # document tools and packaged playtest
schemas/                         # approved versioned authoring/wire contracts
examples/original-demo/           # project, catalogs and original assets
rules/                           # future generated machine registry from one source
scripts/                         # trusted developer build/check tools only
tests/{unit,properties,integration,replay,fixtures,visual}/
docs/{architecture,mechanics,decisions,schemas,work-orders}/
```

The M0 implementation now occupies the bootstrap core, feasibility shell and tests; the remaining tree is proposed. Avoid empty source directories and fake proof placeholders. `docs/RULES.md` is the authoritative planning registry; when an executable registry exists, make this documentation generated or mechanically checked against it, never maintain competing defaults. Rules code should live in `engine/core/`; `rules/` holds generated metadata only. Capture is grouped with progression/party state but battle capture attempts are commands resolved by the battle core.

## Domain model

| Entity | Proposed identity / fields | Invariants / ownership |
|---|---|---|
| Project / Catalog | Namespace, schema version, required ruleset, exact catalog identities | Projects reference catalogs; no rule overrides |
| Species | SpeciesId, presentation AssetIds, permitted authored attributes, learnset/evolution refs | Legal attribute bounds and evolution conditions engine-defined |
| IndividualMonster | persistent MonsterId, SpeciesId, level, XP, stats inputs, current known moves, observed recipes, learned recipe→Harmony | IDs distinct from species; valid level/HP; observations/unlocks individual |
| Move | MoveId, nonempty type components, targeting category, effect sequence, legal authored timing/power inputs | No executable fields; no mix result as a source |
| MixRecipe | RecipeId, unordered source MoveId pair, requirements from finite vocabulary, result descriptor | Unique canonical pair; sources single-component; source/result types distinct |
| Ability / Item / Status | Typed IDs, closed engine effect/behavior tags and bounded data | No behavior callbacks or formulas |
| Type | TypeId in ruleset-owned type registry; content labels/assets by permitted schema | Type interaction mathematics and chart authority cannot be project-overridden |
| BattleState | battle ID, logical tick, combatants, phase/timing, reservations, queue, RNG, completion, observations | Valid queue, alive/eligibility checks, stable ordering |
| Combatant | BattleActorId referencing MonsterId, side/slot, HP/status/stat stages, action phase, source cooldowns | Battle identity distinct from persistent identity; no aliasing of mutable combatants |
| WorldState | map/location/grid elevation, NPC state, inventory, flags, quests, event cursors | Valid collision/location; bounded event transitions |
| Map | MapId, dimensions, layers, collision/elevation/navigation links, spawns/triggers/transitions | Decorative geometry cannot authorize movement |
| Trainer / Encounter | TrainerId/EncounterId, bounded party or weighted entries, refs, conditions | All IDs resolve; legal levels; engine-defined probability sampling |
| Quest / Dialogue / Event | Typed IDs, finite graph nodes, typed predicates/actions, asset/text refs | Bounded execution; no user expressions or calls to code |
| Save / Replay | schema, ruleset and content identities, canonical state or initial state + ordered commands | Exact compatibility; RNG algorithm/state tracked |

IDs are namespace-qualified opaque strings on disk, mapped deterministically to typed internal IDs after validation. Monster IDs are assigned by state-owned counters with overflow rejection, never wall clock. Reference spaces are typed: MoveId cannot satisfy SpeciesId. Internal dense indices are not persistent identities. Cap IDs/text/counts before allocation.

## Transaction and ownership model

One authority owns each simulation state. Battle entry extracts a validated combatant view; battle completion atomically commits HP/progression/observation/capture/inventory deltas back to persistent monsters/world. Abort/retry cannot duplicate rewards. Save policy during a battle must preserve queue, reservations, RNG and pending world transaction or disallow such saves explicitly (D17).

Immutable content is shared. Pure computations over independent entries or battles may run in parallel, then merge in canonical order. Never concurrently mutate shared state or reduce non-associative rounding out of order. Choose Bend representations only after affine ownership, arrays and serialization are tested in M0.

## Review authority

Astra owns contracts/laws/semantics, Sol implements complex code and proofs, Luna implements fixed schemas/fixtures/UI plumbing. A separate reviewer checks implementation; Astra reviews changes affecting rules or architecture. See ADRs and decisions before freezing an API.
