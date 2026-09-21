# Candidate semantic law catalog and proof boundary

Status: gameplay entries below remain human-readable candidates, not checked Bend claims. BOOT-1 and the additive REF-EMPTY content lemma now exist in `LAWS.bend`; `PROOF.bend` proves both against production helpers with the pinned compiler. REF-EMPTY proves only that no natural index resolves into a zero-length catalog. It does not prove parsing, filesystem containment, full reference resolution or any gameplay entry below; no existing law was removed or weakened.

## Law inventory

Each candidate must quantify over explicit valid inputs and call the actual implementation transition/validator, not an unrelated idealized function. Representation refinement requires a separate equivalence proof or clearly labeled test coverage.

| ID | Requirement / candidate assertion | Preconditions / dependency | Planned evidence |
|---|---|---|---|
| DET-1 | Equal complete transition inputs yield equal output including RNG/events | Same immutable ruleset/content; total pure transition | Structural proof plus replay goldens; useful companion is absence of hidden host state |
| VAL-1 | Accepted transition preserves ValidState | Validated content, valid initial state, legal command | Per-transition preservation proofs; integration tests for host constructor boundary |
| TIME-1 | Clock nondecreasing; deadlines do not wrap | Checked arithmetic; D01–03 | Arithmetic proofs and boundary traces |
| CD-1 | Cooldown remaining nonnegative; unavailable moves cannot be accepted | Readiness/reservation model | Deadline arithmetic and acceptance proof |
| MIX-1 | Every accepted mix has exactly one component per source | Resolved recipe and source moves | Predicate necessity proof; generated 1/2/3+ cases |
| MIX-2 | Both sources currently known | Individual current move set | Acceptance proof |
| MIX-3 | Accepted pair corresponds to explicit recipe | Valid recipe index | Lookup/reference proof |
| MIX-4 | Both sources engaged atomically with increased cooldown | D05 formula; no timestamp overflow | Transaction/cooldown proof |
| MIX-5 | Both sources eligible before acceptance | Current tick/reservations | No-bypass proof |
| MIX-6 | Swapping unordered sources preserves compatibility/result | Unordered recipes; D10 | Canonical pair proof |
| MIX-7 | No recipe output can be a mix source | Distinct BaseMoveId/RecipeId model | Construction/validation proof |
| MIX-8 | Effects of a mix equal its registered descriptor | Validated recipe reference | Resolution proof |
| LEARN-1 | Observation alone does not add a learned recipe | Witness transition only | Transition separation proof |
| LEARN-2 | Successful training requires observation and both sources | Post-battle; D09 | Guard necessity proof |
| LEARN-3 | Execution requires learned state independent of observation | Valid individual state | Acceptance proof |
| HARM-1 | Harmony remains in [0,H] | H>0, valid h; D06 | Saturating-update proof |
| HARM-2 | Normal successful use never reduces Harmony | Approved growth rule | Monotonicity proof |
| HARM-3 | One action cannot award Harmony twice | Stable action identity / commit model | Idempotence proof or explicit state-machine test boundary |
| DMG-1 | Component allocations sum to declared budget | N>0, D07 allocation approval | Quotient/remainder proof |
| DMG-2 | Immunity zeroes only the corresponding contribution | Approved independent modifier model | Component proof and type-interaction examples |
| HP-1 | Damage/heal preserve 0 <= HP <= maxHP | Valid maxHP; approved effects | Saturation proofs |
| INV-1 | Accepted removals cannot create negative stock; rejection unchanged | Valid quantity/capacity | Arithmetic/transaction proof |
| PROG-1 | Level stays 1..200 through XP/evolution/capture/load | Approved XP/stat formulas, valid prior state | Bounded transition proof; max-input tests |
| CAP-1 | Capture commits one new individual and item use/rewards at most once | D12, transaction identity | Proof candidate plus battle/world integration |
| REF-1 | Successful resolution yields correct-type existing entity | Validated catalog set | Lookup/validator correctness proof |
| EVENT-1 | An event activation cannot exceed engine execution budget | Bounded graph interpreter | Fuel-decrease proof; cycle/exhaustion tests |
| SAVE-1 | Decode(Encode(validState)) equals canonical valid state | Supported schema, same content/ruleset | Pure codec proof where feasible; host byte tests |
| REPLAY-1 | Folding accepted log reproduces reference fold | DET-1, same initial inputs | Induction over commands; golden regression tests |

## Boundary and trust

Target formal scope: pure typed operations, finite data validation, checked arithmetic, ordered transitions and bounded interpreters expressible in the pinned Bend 2 toolchain. Start with small lemmas, compose them, then prove scheduler/state preservation. Avoid a giant opaque global proof obligation. The law file imports production definitions; proof entry imports all approved laws and supplies every obligation.

Outside this boundary: parser/codec host code until modeled, filesystem containment, media decoders, GPU drivers, window/input/audio, native/JS FFI, OS behavior, compiler/code generator/runtime correctness, hardware faults and visual quality. Foreign values require runtime validation. A proof about a typed value says nothing about an unchecked host object claiming that type. The trusted computing base includes the compiler/checker and any accepted arithmetic/serialization primitives; record it per release.

A model using unbounded naturals does not prove the optimized fixed-width implementation absent refinement. Model/implementation equivalence and cross-target tests must precede replacing arithmetic or collection representations. No unsafe recursion/axioms/foreign calls may discharge gameplay obligations. Do not treat a finite test suite as a universal proof, or compiler success as proof of all English requirements.

## Adoption and audit process

Astra drafts exact candidate law with requirement ID, assumptions, implementation target and expected counterexample. Human approves its semantics before adoption to `LAWS.bend`; Sol supplies `PROOF.bend`. A separate reviewer checks for vacuous premises, impossible ValidState predicates, omitted transitions, erased/unsafe escapes, disconnected toy functions and uncovered approved laws. Include positive witnesses showing legal mixes/training/battle transitions remain possible, alongside negative cases.

Canonical gate is `bend PROOF.bend` on the pinned toolchain plus compilation/checking of every changed entry point. In M0 demonstrate the gate fails for an intentionally false or unproved law in an isolated fixture, and that the real proof entry imports the actual law file. Hash/compare the approved law file in review; any semantic change requires explicit owner approval. No proposed exception may be introduced merely to fix a failing implementation.

Current content proof coverage: `REF-EMPTY` calls `engine/content/validation.bend::ref_ok` and establishes `ref_ok(id, 0) == False` for every natural ID. The remaining REF-1 obligations are exercised by native and shell tests and remain future proof work.
