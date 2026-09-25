When using Bend:
- run `./scripts/bend guide` to learn the pinned compiler
- use `LAWS.bend` to keep important rules
- run `./scripts/bend PROOF.bend` before committing
- parallelize the code whenever possible
- Use Luna subagents

## Code style

- Keep functions focused; aim for roughly 4–20 lines and split longer logic by purpose when Bend's pattern matching and affine types permit it.
- Keep modules focused and preferably under 500 lines. Split by responsibility without duplicating transition logic or weakening validation.
- Use specific names that distinguish domain roles (`encounter_threshold`, `reward_ledger`) instead of generic names such as `data`, `handler`, or `Manager`.
- Keep Bend types explicit. Type Python public boundaries and model records; use typed records after JSON decoding rather than passing unvalidated dictionaries through the engine.
- Prefer small helper functions and early validation. In Bend, use separate helper definitions for computed match conditions and preserve the language's affine and termination rules.
- Make diagnostic and exception messages identify the offending value or location and the expected shape, without printing secret or unbounded input.

## Comments and documentation

- Preserve existing comments during refactors; they record intent and provenance.
- Explain why a rule or boundary exists, not what a nearby expression already says.
- Document public entry points with intent and a short usage example when the API is not self-evident. Keep proof-law comments tied to the production rule they protect.
- Cite an issue or commit when a constraint exists because of a specific bug or upstream limitation.

## Tests and verification

- Run the repository gate with `python3 scripts/verify.py` for completed changes. Run focused Bend fixtures with `./scripts/bend tests/<area>/<fixture>.bend` and Python suites with `python3 -m unittest` while iterating.
- Test new externally observable behavior, boundary cases, and bug regressions. Avoid tests that only mirror a helper's implementation.
- Keep fixtures fast, independent, repeatable, and self-validating. For deterministic core behavior, check native and JavaScript results where the milestone contract requires parity.
- Use named fakes for external I/O in Python tests when a real dependency would make the test slow or nondeterministic.
- Before committing Bend changes, run the canonical `./scripts/bend PROOF.bend` gate. Do not weaken existing laws to make a change pass.

## Dependencies and structure

- Pass gameplay dependencies and random state explicitly through pure transitions. Keep filesystem, clock, graphics, and process I/O outside the deterministic Bend core.
- Keep third-party and platform APIs behind project-owned adapters. Untrusted project content remains inert data and must pass the existing bounded loader and validation boundary.
- Follow the repository layout: `engine/` for pure Bend logic, `platform/` for host adapters, `schemas/` and `docs/` for content contracts, and `tests/` for matching fixtures.

## Formatting

- Match the surrounding Bend, Python, JSON, and Markdown style. Run `git diff --check` to catch whitespace errors.
- This repository has no Deno or GUI npm tasks; do not substitute unrelated formatter or lint commands for the Bend proof and repository verification gates.
