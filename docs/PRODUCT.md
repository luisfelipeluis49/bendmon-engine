# Product scope

A visual maker for one developer-controlled 2.5D monster-catching action turn-based RPG ruleset. The target creator journey is download → create project → drag/drop → validate → playtest → package. Creators author data and assets; they need no Bend knowledge, compiler, plugins, or scripting language.

## Fixed requirements

- Pure deterministic rules core; explicit RNG and logical time; renderer follows simulation.
- Timeline combat; compositional closed effects; generic 1..N split-type attacks.
- Explicit mix compatibility, both known single-component source moves, both eligible and engaged, no recursive mixing. Discovery, post-battle training and individual Harmony are separate states.
- Level range 1–200; engine owns formulas, progression, timing semantics, type semantics and hard safety ceilings. Projects may author D13's bounded monotone capacity tiers, using engine defaults when absent.
- Strictly validated versioned content, save and replay identities. Projects cannot override rules beyond the explicit bounded D13 capacity values.
- Original sample content; no franchise-specific names, assets or identifiers in engine code.

## Product boundaries

The editor covers worlds/maps, monsters, moves, items, trainers, encounters, NPCs, dialogue, event graphs, quests, bounded capacity tiers, audio/assets, validation and playtest. Permitted authored values never expose formulas, opcodes or unbounded constants. Reusable catalogs and project placements are separate artifacts.

The engine is not a general-purpose game engine, mod scripting host, arbitrary battle-system designer, unrestricted 3D editor, or asset marketplace. Multiplayer and spectating are future possibilities, not MVP promises. External packs remain separate from engine source and must pass the same validator as bundled examples.

## Vertical slice and acceptance

After foundations, produce a tiny original map with an NPC, encounter, trainer, capture, inventory use and transition. Extend it with a multi-type move, witnessed mix, post-battle training, Harmony growth and progression; then save/load and replay it. Implement the approved rules in `docs/DECISIONS.md` and measure the explicitly deferred balance/budget tables. A non-programmer must build that section through the editor, see field-linked validation errors, play it without compilation, and transfer it to a clean packaged runtime.

Headless and rendered runs using identical accepted commands must end in identical logical state. Visual fidelity, audio timing and editor ergonomics require separate human/visual testing; formal laws do not certify them.
