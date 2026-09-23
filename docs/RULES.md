# Engine-owned rule registry — planning authority

This is the single planning registry; no executable registry exists yet. Every listed initial value is approved. Runtime content cannot supply engine-owned fields except where a row explicitly permits a bounded creator value. Generate and check this document against one engine source as each runtime table lands. Changed mechanics require a ruleset version change and explicit replay/save compatibility treatment.

| Name | Meaning / unit | Valid range | Canonical value | Rationale / dependents |
|---|---|---|---|---|
| LEVEL_MIN | lowest legal level / level | positive integer | 1 | brief 1–200; PROG-1 |
| LEVEL_MAX | maximum level / level | >= LEVEL_MIN | 200 | explicit requirement; PROG-1 |
| MIX_SOURCE_COMPONENTS | component count per source | exact positive integer | 1 | MIX-1; future 3+ automatically excluded |
| MIX_SOURCE_COUNT | source moves per mix / count | exact integer | 2 | MIX-2–5 |
| MIX_RECURSION_ALLOWED | recipe results as sources / boolean | boolean | false | MIX-7 |
| CUSTOM_CODE_ALLOWED | executable project content / boolean | boolean | false | REF-1, trust boundary |
| RULESET_VERSION | canonical semantics identity / version | exact version identifier | `m6-1` for new M6 saves/replays; `m3-1` for the first complete headless-battle contract and explicit legacy replays | all save/replay laws; cross-version reinterpretation forbidden |
| TICK_UNIT / TICK_MAX | timeline unit / ticks | 60 ticks/presentation second; bounded integer deadline | TICK_UNIT = 1/60 presentation second; TICK_MAX = 216000 (one active hour) | TIME-1; overflow and pacing |
| WAIT_TICKS | duration of explicit Wait / ticks | exactly one of 30, 60, 120 per saved game | player selects at new-game creation; immutable for that game | barrier progress; TIME-1; save/replay header |
| MIN_WINDUP | command acceptance to execution / ticks | >=0 | 0; current-tick execution queues only after atomic batch commit | scheduler ordering; D03 |
| MIN_RECOVERY | actor-wide post-execution lower bound / ticks | >=30 | 30 ticks | avoid zero-time action loops; presentation readability; TIME-1 |
| MIN_COOLDOWN | ordinary per-move reuse lower bound / ticks | >=60 | 60 ticks | move eligibility; CD-1 |
| MAX_WINDUP / MAX_RECOVERY / MAX_COOLDOWN | creator-authored action timing ceilings / ticks | finite within TICK_MAX | 600 / 600 / 3600 | bounded scheduling; D03/D05 |
| MIX_COOLDOWN_FACTOR / MAX | increased source cooldown / rational and ticks | factor >1; checked deadline <= battle clock | 3/2 with ceil; mixed ceiling 5400 | MIX-4–5; D05 |
| HARMONY_PROGRESS / TIERS | successful-use counter and thresholds | integer 0–40; six ordered tiers | 0, 5, 10, 20, 30, 40 | HARM-1–3; D06 |
| HARMONY_ACCURACY / CRIT_BONUS | tier packages / probability units | nondecreasing; ordinary crit remains capped | acc 0/100/200/300/400/500; crit 0/125/250/375/500/625 | D06; only meaningful valid mixed executions progress |
| PROBABILITY_SCALE | denominator for accuracy/critical/capture chances | exact positive integer | 10000; one unit = 0.01 percentage points | RNG, deterministic previews; D04 |
| RNG_ALGORITHM | deterministic gameplay generator | versioned exact U32 transition | `xoshiro128ss-1.1`; four U32 words; all-zero forbidden; rejection-sampled bounds | DET-1, REPLAY-1; D19 |
| RNG_INITIAL_STATE | canonical battle RNG input | four U32 words, not all zero | explicit 128-bit state stored verbatim in save/replay | DET-1, REPLAY-1; D19 |
| RNG_DRAW_POLICY | semantic accuracy/critical sampling | conditional fixed branch contract | no cancel/fizzle/always-hit draw; accuracy on ordinary attempt; critical only on successful nonimmune damaging hit | replay identity; D04/D19 |
| RNG_SAMPLE_BUDGET | maximum U32 candidates per unbiased bounded sample | positive finite attempts | 64; exhaustion is atomic engine fault `RngSamplingExhausted` | bounded execution; D19 |
| ACCURACY_MODEL | authored move chance modified by bounded stages | individual and net stages −6…+6 | net n: `(3+n)/3` for n>=0, `3/(3+abs(n))` for n<0; one floor | hit checks, previews; D04 |
| MIN_HIT_CHANCE | lower bound for an ordinary legal accuracy check | 0–10000 scale | 500 (5%); always-hit bypasses check | battle flow; D04 |
| MOVE_ACCURACY | creator-authored ordinary base chance | integer 500–10000 | staged and clamped; explicit schema-permitted alwaysHit is separate | content validation; D04 |
| BASE_CRIT_CHANCE | eligible damaging action before bonuses | 0–10000 scale | 625 (6.25%) | damage variance; D04 |
| CRIT_MULTIPLIER | eligible critical damage multiplier | exact positive rational | 2× resolved normal damage; respects all attack/defense stages; zero remains zero | damage variance; D04 |
| CRIT_CAP | maximum ordinary critical chance after bonuses | 0–10000 scale | 2500 (25%); guaranteed-critical effects not yet approved | damage variance; D04 |
| STAB | same-type damage modifier | bounded rational | 3/2 once per matching component; no duplicate actor-type stacking | DMG-2; D08 |
| DAMAGE_FORM | base physical/special structure | checked positive-defense integer ratio with one specified floor | `floor(power × (2×level+50) × capturedAttack ÷ (300×currentDefense))` | HP-1, DMG-1–2 |
| MIN_DAMAGE | post-formula damage floor | natural integer result, immunity also zero | 0; UI distinguishes NoDamage, Immune, Miss and Fizzle | HP-1, battle feedback |
| MOVE_POWER | creator-authored damaging move power | integer 1–200 | bounded exact integer; absent for nondamaging moves | damage validation; D04 |
| EFFECTIVE_COMBAT_STAT | post-modifier Attack/Defense/Sp. Attack/Sp. Defense/Speed | integer 1–9999 | bounded exact integer; no wrap | damage safety, tie ordering; D04 |
| EFFECT / STATUS ALGEBRA | ordered effects and named-status multiplicity | finite closed engine definitions | authored order in one atomic action; one instance/name; refresh duration and keep stronger magnitude; engine incompatibility table | D04; M4 |
| M4_EFFECT_BOUNDS | accepted ruleset-1 effect program | top-level 1–16; validated total cost ≤64 | at most one first/top-level damage node; conditional branches are damage-free leaf sequences with no nested conditional; heal 1–9999; derived fraction terms 1–16; stage delta 1–6 | D04; M4 |
| MULTI_TYPE_ALLOCATION | component count and power division | 1–4 distinct TypeIds | quotient plus canonical TypeId remainder; per-component modifier/floor then checked sum | D07; M5 |
| XP_CURVE / STAT_CURVE | progression functions over 1–200 | monotone 200-entry XP table; bounded stats | XP(L)=25×(L−1)^3+75×(L−1); HP=floor((2b+i)L/100)+L+10; other=floor((2b+i)L/100)+5 | PROG-1; U06 |
| CAPTURE_RULE | capture transaction | one action/item; bounded probability; legal destination required | U07 HP/item/status formula; final clamp 100–9500; atomic party-first then storage success | CAP-1; U07 |
| DEFAULT_CAPACITIES | project defaults | positive bounded integers | party 6; moves 4; storage 1000; item stack 999; inventory entries 512; currency 9999999 | INV-1; D13 |
| PROJECT_CAPACITY_TIERS | creator-authored monotone capacity levels | at most 16; finite and within engine ceilings | hard max party 12; moves 8; storage 10000; stack 9999; entries 4096; currency 999999999 | U08 explicit creator-authority exception |
| WORLD_MOVEMENT | authoritative exploration geometry | checked fixed-point coordinates on baked navigation surface | free-direction movement; swept collision; explicit elevation/transition links | D14; M8 |
| ENCOUNTER_PROGRESS | random-encounter accumulation | deterministic weighted ground distance | one threshold draw on region entry/after encounter; sprint increases accumulation; no frame/tile sampling | D14; M8 |
| SAVE_IDENTITY / BOUNDARY | load compatibility and initial save boundary | exact ruleset+content identity | exact match; stable world-boundary saves; explicit migrations only | D17; REPLAY-1 |
| CONTENT_LIMITS | content-0 bytes/counts/depth/dimensions | fixed development loader ceilings below | implemented for content-0 | REF-1, resource tests |
| EVENT_BUDGETS | event steps/queues/depth | finite positive cumulative bounds | nodes 10000; queue 1024; depth 32; per-node fanout 64; resumptions 64 | EVENT-1; U10 |
| ESCAPE_RULE | wild-battle escape chance / probability units | 1000–9500 after clamp | clamp(5000 + 25×speedDelta + 1000×failedAttempts, 1000, 9500) | U01; no rewards on success |
| BATTLE_ROSTER | total/active participants per side | finite positive counts | total 12; active 4 | U02 reinforcement/completion |
| TYPE_MULTIPLIERS | ordinary/strong/resisted | exact positive rationals | 1 / 2 / 1/2; no initial immunity | U04 |
| CAPACITY_HARD_MAX | creator tier ceilings | bounded positive integers | party 12; moves 8; storage 10000; stack 9999; entries 4096; currency 999999999; tiers 16 | U08 |
| WORLD_FIXED_SCALE | subunits per world unit | exact positive power-of-two | 1024 | U09 deterministic movement |
| WORLD_SPEEDS | walk/run/sprint / units per presentation second | positive fixed-point | 2.5 / 4.5 / 7 | U09 |
| ENCOUNTER_DISTANCE | threshold/safety / world units | bounded fixed-point | uniform 24–40; post-battle safe 12; multipliers 3/4,1,3/2 | U09 |
| SAVE_CANONICAL / DIGEST | canonical byte encoding and identity hash | versioned deterministic encoding | strict canonical JSON / SHA-256 | U12; SAVE-1/REPLAY-1 |

Authored values such as permitted move power, species stats, recipe timing and D13 capacity tiers are separate schema fields with engine-owned bounds (D15). They never stand in for formulas. D13 capacity tiers are the sole approved exception that lets ordinary project data select these gameplay capacities; projects still cannot exceed hard engine safety ceilings or redefine transaction behavior. Coefficients not named above must be added to this registry before implementation, not hidden as literals. Engine resource-limit changes affecting accepted content also need compatibility review even if battle arithmetic is unchanged.

## Content-0 development loader ceilings

Authoritative technical limits for the new inert loader: JSON 1 MiB/file; total loaded bytes 8 MiB; 64 manifest files plus project/manifest; 256 entities per kind; 256 entries/references per record; 4096 total roster entries and 4096 total map references; JSON depth 16; display names 128 characters; normalized ASCII paths 240 characters; map metadata dimensions 1..512; P6 sprite dimensions 1..256; native wire 2 MiB and 140000 tokens. These are resource limits, not RPG balance. Exact schema/payload rules are in CONTENT-0.md. Bend and host boundary tests enforce the same limits; projects cannot supply overrides.
