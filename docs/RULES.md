# Engine-owned rule registry — planning authority

This is the single planning registry; no executable registry exists. TBD means not approved, not a value of zero. Runtime content cannot supply these fields. Freeze exact values only after owner decisions; then generate/check this document against a single engine source. Changed mechanics require a ruleset version change and explicit replay/save compatibility treatment.

| Name | Meaning / unit | Valid range | Canonical value | Rationale / dependents |
|---|---|---|---|---|
| LEVEL_MIN | lowest legal level / level | positive integer | 1 | brief 1–200; PROG-1 |
| LEVEL_MAX | maximum level / level | >= LEVEL_MIN | 200 | explicit requirement; PROG-1 |
| MIX_SOURCE_COMPONENTS | component count per source | exact positive integer | 1 | MIX-1; future 3+ automatically excluded |
| MIX_SOURCE_COUNT | source moves per mix / count | exact integer | 2 | MIX-2–5 |
| MIX_RECURSION_ALLOWED | recipe results as sources / boolean | boolean | false | MIX-7 |
| CUSTOM_CODE_ALLOWED | executable project content / boolean | boolean | false | REF-1, trust boundary |
| RULESET_VERSION | canonical semantics identity / version | exact version identifier | unassigned pre-release | M1 approval required; all save/replay laws |
| TICK_UNIT / TICK_MAX | timeline unit / ticks | positive / bounded integer | TBD D01–02 | TIME-1; overflow and pacing |
| WAIT_TICKS | duration of explicit Wait / ticks | positive integer | TBD D03 | barrier progress; TIME-1 |
| MIN_RECOVERY / MIN_COOLDOWN | timing lower bounds / ticks | proposed >=1 | TBD D03/D05 | avoid zero-time action loops; CD-1 |
| MIX_COOLDOWN_FACTOR | increased cooldown ratio / rational | proposed >1 | TBD D05 | MIX-4–5 |
| HARMONY_MAX / INITIAL / GROWTH | proficiency bounds/update / points | H>0; 0<=initial<=H; growth>0 | TBD D06 | HARM-1–3 |
| HARMONY_ACCURACY / CRIT_CAP | maximum bonuses / probability units | within approved probability range | TBD D06 | bounded monotone bonuses |
| PROBABILITY_SCALE / STAB / CRIT | probability denominator and modifiers | positive scale, bounded rationals | TBD D04/D08 | DMG-2, RNG |
| DAMAGE / TYPE_CHART / STATUS_RULES | base formula, type ratios, stacking | finite engine definitions | TBD D04/D15 | HP-1, DMG-1–2 |
| XP_CURVE / STAT_CURVE | progression functions over 1–200 | monotone XP thresholds, bounded stats | TBD D11 | PROG-1 |
| CAPTURE_RULE / PARTY_SIZE / MOVE_SLOTS / INVENTORY_CAP | capture probability and capacities | bounded engine values | TBD D12–13 | CAP-1, INV-1, MIX-2 |
| CONTENT_LIMITS | content-0 bytes/counts/depth/dimensions | fixed development loader ceilings below | implemented for content-0 | REF-1, resource tests |
| EVENT_BUDGETS | event steps/queues/depth | finite positive bounds | TBD D16 | EVENT-1; events not implemented |

Authored values such as permitted move power, species stats and recipe timing are separate schema fields with engine-owned bounds (D15). They never stand in for formulas. Coefficients not named above must be added to this registry before implementation, not hidden as literals. Engine resource-limit changes affecting accepted content also need compatibility review even if battle arithmetic is unchanged.

## Content-0 development loader ceilings

Authoritative technical limits for the new inert loader: JSON 1 MiB/file; total loaded bytes 8 MiB; 64 manifest files plus project/manifest; 256 entities per kind; 256 entries/references per record; 4096 total roster entries and 4096 total map references; JSON depth 16; display names 128 characters; normalized ASCII paths 240 characters; map metadata dimensions 1..512; P6 sprite dimensions 1..256; native wire 2 MiB and 140000 tokens. These are resource limits, not RPG balance. Exact schema/payload rules are in CONTENT-0.md. Bend and host boundary tests enforce the same limits; projects cannot supply overrides.
