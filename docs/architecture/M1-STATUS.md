# M1 architecture and formal-domain status

Status: complete and locally verified on 2026-09-21.

## Closed architecture contract

- The domain, layer boundaries, state authority, transaction ownership, typed
  persistent/runtime identity split and no-code content boundary are accepted in
  `ARCHITECTURE.md`.
- ADR-01–ADR-15 record selected outcomes for logical time, command barriers,
  renderer/editor separation, content serialization, effects, world geometry,
  RNG, assets, saves, replays, mixing, Harmony, host integration and semantic
  identity.
- D01–D19 and U01–U13 are approved. Future semantic changes require an explicit
  dated replacement and ruleset compatibility treatment.
- `m3-1` and `xoshiro128ss-1.1` identify the first complete battle rules and RNG
  transition. Exact ruleset plus content identity remains the save/replay
  compatibility policy.
- `LAW_CATALOG.md` defines the formal-domain candidates and trusted boundary.
  Every currently adopted Bend law calls production code and has a matching
  `PROOF.bend` entry. Laws for unimplemented M4–M11 domains remain candidates
  until their production functions exist.

## Verification

- The M1 architecture contract suite checks decision and ADR closure, frozen
  identities, candidate-law coverage, checked-law/proof pairing and local links.
- The separate architecture review passed after its scheduler consistency
  corrections, and the owner subsequently closed every remaining decision.
- `./scripts/bend PROOF.bend` reports `All terms check.`
- `python3 scripts/verify.py` is the canonical integrated gate.

## Boundary

M1 closes architecture and formal scope. It does not claim that every candidate
law is already proved or that later gameplay, renderer, editor, persistence and
packaging milestones are implemented. Those proofs and implementations remain
attached to their owning milestones.
