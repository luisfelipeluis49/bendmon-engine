# Mix recipes, discovery and Harmony

## Fixed invariants

MIX-1: each source has exactly one type component; 2+ components are forbidden. MIX-2: actor currently knows both sources. MIX-3: pair has an explicit recipe. MIX-4: both sources are engaged and receive increased cooldown. MIX-5: neither source may bypass availability. MIX-6: compatibility symmetric unless explicitly ordered. MIX-7: mix results cannot be sources. MIX-8: results come only from registered recipes.

## Proposed MixRecipe contract

Conceptual fields: RecipeId, distinct source BaseMoveIds, closed requirements, validated resulting effect sequence/type components, authored timing/power/accuracy descriptors within the approved catalog policy, and animation AssetId. Recipes may select permitted values, not redefine critical formulas or Harmony curves. Recommend excluding recipe-specific Harmony progression and cooldown multipliers from initial schema: engine registry owns these rules. If variation is needed, expose engine-defined profile IDs only after approval.

Use canonical `(min(sourceA,sourceB), max(...))` pair indexing and one recipe per pair. `BaseMoveId` and `RecipeId` are separate identity types. A mix may produce a multi-component result, but that result has no BaseMoveId usable in another recipe. Disallow self-pairs and ordered recipes for MVP (D10); future ordered pairs require explicit schema/ruleset revision, not an interpretation change.

## Eligibility and atomic engagement proposal

In addition to normal battle readiness: the individual has learned this RecipeId; both current moves equal the recipe sources; each source is single-component, available, unreserved, and off cooldown at the current tick; recipe requirements and target constraints hold. Any failure rejects the whole command without RNG/resource changes.

On acceptance reserve both sources and set both increased cooldown deadlines atomically. Recommend `mixedCooldown(source) = ceil(k × ordinaryCooldown(source))`, with k > 1 an owner-approved engine rational and ordinary cooldown >= 1. This is a candidate formula, not a selected k or compiled constant. Failure after acceptance does not release cooldowns; successful execution grants Harmony only under D06's success definition. Store effect output directly in the recipe; never synthesize effects combinatorially.

## Observation → training → learned state

Store `observedRecipes` and `learnedRecipes: RecipeId → Harmony` on each persistent MonsterId. Knowing sources does not imply observation; observation does not imply unlock. Recommend an actual valid mix execution emits MixPerformed; an active conscious witness that currently knows both sources records it in battle-local observations. Party-wide learning, fainted observers and own-use witnessing are explicit D09 choices, not assumptions.

At battle finalization merge witnessed RecipeIds idempotently to persistent state, including defeat under the recommended policy. Post-battle Training is a separate world transaction requiring that individual's observation, both current sources, valid compatibility and not already learned. Training cannot occur mid-battle. Whether it costs resources is unresolved.

Recommend observations and learned Harmony persist when a source is forgotten; execution remains locked until both are known again. Species/evolution changes preserve individual identity and must revalidate current moves. Content removal/migration must never silently map a recipe to a different pair. Persistence and end-of-battle outcomes require D09/D17 approval.

## Harmony proposal — no hard-coded curve

Harmony is per individual and learned recipe. Proposed representation: bounded nonnegative integer h, with engine maximum H. Candidate successful-use update: `h' = min(H, h + g)` using checked or proof-safe saturating addition, g a positive engine value. Candidate accuracy bonus: `floor(A × h/H)`; candidate critical bonus: `floor(C × h/H)`, each capped by the engine probability ceiling. Require H > 0 and legal A/C bounds. Alternatives: tiered thresholds or a monotone diminishing-returns table. Recommend the linear bounded form for first testing because its monotonicity and limits are simple to audit; balance still needs playtests.

H, g, A, C, initial learned value and probability scale are all TBD; these are DESIGN DECISIONS D06. Recommend successful use means a valid execution producing at least one intended gameplay effect; miss, immunity-only, cancellation and fizzle grant no progress. Award once per action, not per hit, component or target. Recommend no other Harmony stat bonuses initially. Reusing an event ID must not award twice. None of these proposed meanings is an approved rule yet.

## Obligations

Tests cover all MIX-1–8, unknown/unlearned sources, forgotten sources, 3+ types, reversed pairs, self-pairs, partial resource failures, cooldown boundary, observation without training, training without observation, unrelated individual learning, max-Harmony saturation and duplicate completion events. Laws quantify over valid recipes/individuals and accepted transitions; they must be tied to actual implementation functions.
