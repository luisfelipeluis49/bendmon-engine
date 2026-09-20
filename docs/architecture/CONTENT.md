# Content, editor and trust boundaries

## Proposed project format

Use strict UTF-8 JSON for initial authoring/wire envelopes. Reject duplicate keys, unknown fields, non-integral/out-of-range numbers, excessive nesting and invalid encoding. Do not treat a JSON Schema pass as sufficient semantic validation. No comments, expressions, dynamic references, remote schema resolution or code hooks.

```text
game/
  project.json                   # project ID, schema, expected ruleset
  manifest.json                  # exact catalog and asset identities
  catalogs/                      # optional permitted species/moves/items/recipes
  maps/ encounters/ trainers/ npcs/
  dialogue/ events/ quests/
  assets/{sprites,textures,models,tiles,audio,vfx}/
```

Catalog schemas and project schemas are versioned independently. Draft version labels must be explicitly pre-release, e.g. `draft-0`, not a promise of stable compatibility. Engine build version and ruleset semantics version are separate. Require exact ruleset/content matches initially; compatibility ranges need demonstrated migration support.

## Creator permission matrix proposal

| Data | Creator control | Engine ownership |
|---|---|---|
| Maps/story/assets/placements | create within schema | movement, collision, event opcode semantics and resource caps |
| Species/moves/items/recipes | propose permitted authored attributes, legal compositions and references | legal fields/ranges, formulas, primitive semantics, caps, mix restrictions |
| Type/ability/status | labels/assets and approved references initially | type registry/chart and behavior algebra; additions are engine releases |
| Harmony/XP/capture/damage | none through project files | all curves, probability rules, coefficients and compatibility changes |

This matrix is D15, not an authorization to ship an arbitrary balance DSL. Move power/windup/base stats are authored balance inputs only if approved; bounds are engine-owned. Recipe fields cannot override mixing restrictions or global progression.

## Validator stages

1. Bounded intake: count bytes/files/archive expansion before allocating large decoded values. No online fetch while loading.
2. Strict parse to inert raw data; reject unknown tags and executable fields.
3. Structural validation: bounded counts, dimensions, numeric ranges, unique IDs, required fields.
4. Reference resolution: namespaces and expected entity types, exact catalog versions, no ambiguous overrides.
5. Semantic validation: recipe restrictions, effects/graph cost, map/transition consistency, valid encounters and progression states.
6. Canonicalization only of structurally valid data; stable sorting and identity calculation. Never silently repair dangerous input.
7. Produce ValidatedContent or stable diagnostics with file, JSON pointer, entity ID, error code and remedy. Sort diagnostics canonically even if validation is parallel.

## Event machine

Propose closed ShowDialogue, MoveActor, Wait, GiveItem, RemoveItem, StartBattle, SetFlag, ClearFlag, CheckFlag, Branch, Teleport, PlayAnimation, PlaySound, StartQuest, CompleteQuest, ChangeEncounterTable, ChangeNPCState and OpenShop tags. Predicates reference typed flags/quest states, not arbitrary expressions. Nodes serialize as IDs and typed operands.

Recommend acyclic immediate execution within each activation; persistent quest/NPC state machines may revisit nodes across activations. Wait yields on logical time; UI/dialogue choices yield a typed command. Bound total steps per activation across yields, nesting, fan-out, queued activations and allocations. Reject recursive graph calls. Presentation completion must not decide gameplay: PlayAnimation/PlaySound emit visual events; gameplay waits have engine logical durations. Full semantics for every admitted opcode are required before schema enablement.

## Assets and hostile input

AssetId maps to a manifest entry containing relative path, media type, byte size and content digest. Never use an asset string as a URL, command, module or host library name. Reject absolute paths, `..`, alternate-separator escapes, NUL, drive/UNC paths and symlinks; normalize and verify containment using platform-safe opening, not string-prefix checks. Reject archive links, duplicate normalized paths, unsupported media and traversal before extraction. Bound decompression ratios/expanded bytes and decoded image/audio/model dimensions; filenames alone cannot authorize codecs.

Decoders and filesystem are outside formal proof scope: use maintained codecs, bounded isolated import where feasible, negative/fuzz tests and least-privilege host adapters. Revalidate imported/precompiled caches; a boolean `validated` flag from a pack or host caller is not a certificate. Content imports cannot access Bend imports, FFI symbol names, plugins, shell, network or arbitrary JS. Core API wrappers must validate foreign values before treating them as typed domain state.

## Editor contract

Editor draft state may be incomplete, but cannot become runtime state until the shipping validator succeeds. Undo/redo changes authoring data; playtest starts from a frozen validated snapshot, with a new explicit seed. Editing during playtest creates a new snapshot, never mutates a running battle's content identity. Export is deterministic; save/export errors cannot partially replace the user's project. Published schemas enumerate allowed fields and reject all others.
