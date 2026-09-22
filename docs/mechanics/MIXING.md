# Mix recipes, discovery and Harmony

## Fixed invariants

MIX-1: each source has exactly one type component; 2+ components are forbidden. MIX-2: actor currently knows both sources. MIX-3: pair has an explicit recipe. MIX-4: both sources are engaged and receive increased cooldown. MIX-5: neither source may bypass availability. MIX-6: compatibility symmetric unless explicitly ordered. MIX-7: mix results cannot be sources. MIX-8: results come only from registered recipes.

## MixRecipe contract

Conceptual fields: RecipeId, distinct source BaseMoveIds, closed requirements, validated resulting effect sequence/type components, authored timing/power/accuracy descriptors within the approved catalog policy, and animation AssetId. Recipes may select permitted values, not redefine critical formulas, Harmony tiers or cooldown multipliers. The engine registry owns those rules.

Use canonical `(min(sourceA,sourceB), max(...))` pair indexing and one recipe per pair. `BaseMoveId` and `RecipeId` are separate identity types. A mix may produce a multi-component result, but that result has no BaseMoveId usable in another recipe. Disallow self-pairs and ordered recipes for MVP (D10); future ordered pairs require explicit schema/ruleset revision, not an interpretation change.

## Eligibility and atomic engagement

In addition to normal battle readiness: the individual has learned this RecipeId; both current moves equal the recipe sources; each source is single-component, available, unreserved, and off cooldown at the current tick; recipe requirements and target constraints hold. Any failure rejects the whole command without RNG/resource changes.

On acceptance reserve both sources atomically. At attempted mixed execution, set both deadlines atomically using `mixedCooldown(source) = ceil(3 × ordinaryCooldown(source) / 2)`, with a 5400-tick mixed ceiling. Pre-execution actor cancellation releases both reservations without cooldown; invalid-target fizzle charges both sources. Successful execution grants Harmony only under D06's success definition. Store effect output directly in the recipe; never synthesize effects combinatorially.

## Observation → training → learned state

Store `observedRecipes` and `learnedRecipes: RecipeId → Harmony` on each persistent MonsterId. Knowing sources does not imply observation; observation does not imply unlock. At valid mixed execution start, snapshot active conscious combatants that know both sources; allies and enemies qualify. Those witnesses record the execution even on a miss or same-action KO, but cancellation/fizzle produces no observation.

At every committed terminal battle result, including defeat and escape, merge witnessed RecipeIds idempotently to persistent state. Post-battle training is a designated-trainer world transaction requiring that individual's observation, both current sources, valid compatibility, one bounded training token and an unlearned recipe. Training cannot occur mid-battle.

Observations, unlock and Harmony persist when a source is forgotten; execution remains locked until both are known again. Species/evolution changes preserve individual identity and must revalidate current moves. Content removal/migration must never silently map a recipe to a different pair. Exact ruleset and project identity follow D17.

## Harmony mastery tiers

Harmony is per individual and learned recipe. Store successful-use progress in 0–40. Derive tiers and `(accuracyBonus, criticalBonus)` packages as: Novice 0 `(0,0)`, Familiar 5 `(100,125)`, Practiced 10 `(200,250)`, Expert 20 `(300,375)`, Master 30 `(400,500)` and Perfected 40 `(500,625)`. Probability units use the 0–10000 scale and ordinary critical chance still clamps at 2500. Harmony grants no other stat benefit initially.

A successful use is a valid mixed execution producing at least one intended gameplay effect. Miss, protection/immunity blocking every effect, healing at full HP, cancellation and fizzle grant no progress. Award at most once per action, not per hit, component or target. Reusing an event ID must not award twice. Commit progress with the action; later loss or escape does not erase it.

For ruleset `m6-1`, an intended effect succeeds only when the registered program
commits and changes gameplay state through positive actual damage or healing, a
status add/replace/refresh that changes status state, status removal/clear, or a
nonzero stat-stage change. Opportunity aftermath alone does not qualify.
Zero-damage or fully blocked output, a no-op status refresh, saturated stage
change, rejection and engine fault join the non-success cases above. The stable
accepted action sequence is the idempotence key. Harmony accuracy and critical
bonuses are captured with the actor's offensive snapshot at acceptance and do
not add RNG draws.

The initial recipe requirement vocabulary is `Always` plus the target and
execution guards already owned by the registered M4 descriptor. Current move
knowledge is a distinct bounded `BaseMoveId` list on the persistent individual;
slot order does not affect the unordered recipe pair. Training consumes one
token from a U32 balance and installs learned Harmony progress zero atomically.
These representation closures are recorded in D05/D06/D09/D10's M6 closure.

## Obligations

Tests cover all MIX-1–8, unknown/unlearned sources, forgotten sources, 3+ types, reversed pairs, self-pairs, partial resource failures, cooldown boundary, observation without training, training without observation, unrelated individual learning, max-Harmony saturation and duplicate completion events. Laws quantify over valid recipes/individuals and accepted transitions; they must be tied to actual implementation functions.
