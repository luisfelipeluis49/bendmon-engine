# M2 Content-0 implementation evidence

Status: the balance-independent M2 content-kernel slice meets its local exit criteria. Valid original sample content loads through the native Bend validator; invalid references, wrong-kind references and unsafe authoring input reject deterministically. This is an inert data boundary, not a playable RPG ruleset.

## Implemented boundary

- Distinct Bend `AssetId`, `SpeciesId`, `EncounterId` and `MapId` constructors, immutable shell records, canonical dense indices and exact-kind reference validation.
- Strict versioned JSON documents for project metadata, manifests, catalogs, encounter rosters, map metadata and original P6 sprite assets. Every object is closed; project data cannot select code, commands, imports, plugins, ruleset constants or kernel paths.
- Directory-FD relative reads with ancestor/component symlink rejection, hard-link/non-regular-file rejection, byte/count/depth/path ceilings, exact asset hashes and bounded PPM decoding.
- A developer-owned shell converts validated records to a bounded unsigned wire format. The native Bend executable parses the wire, validates semantic references/levels/dimensions, and returns a narrow ASCII protocol. Content is never compiled or interpolated into a command.
- Canonical semantic JSON and SHA-256 identity ignore JSON key order, declaration-container order and authoring document location while preserving semantic list order and asset-path metadata.
- Stable diagnostics map native canonical indices back to original files, JSON pointers and typed entity IDs. Malformed, timed-out or contradictory native responses fail closed as infrastructure errors.

The exact accepted format and resource ceilings are frozen in [CONTENT-0.md](../schemas/CONTENT-0.md). JSON Schema files are authoring aids; the shell remains the enforcement boundary and Bend rechecks semantic properties before acceptance.

## Verification

`python3 scripts/verify.py` passes 102 checks on the pinned Bend 2.0.19 Linux x86-64 baseline. The gate includes `bend PROOF.bend`, type-checking every normal Bend entry point, native kernel compilation, 36 content tests, and loading `examples/original-demo` through the built kernel. Evidence is generated under `build/evidence/`, including `verification.json` and the sample project's result.

The content suite covers each typed reference category, wrong-kind IDs, level and dimension boundaries, declaration-order invariance, semantic-order sensitivity, malformed UTF-8/JSON/numbers/surrogates, duplicate keys/IDs/paths/references, absolute/traversal/code-looking paths, symlinks in root ancestry and descendants, hard links, FIFOs, resource ceilings, media hashes and dimensions, kernel timeouts and malformed protocols. Generated native cases compare deterministic results across thread counts.

## Independent review

The Astra architecture review approved this balance-independent slice after corrections for actual Bend fork/join validation, RFC 6901 diagnostic escaping, normalized native file errors and honest milestone status. Its recheck found no remaining architecture blocker and independently passed the proof gate and all 36 content tests.

The Sol implementation review found that an earlier native parser applied the 140000-token ceiling only after `String.split`, so a 2 MiB hostile wire briefly allocated a million-element token list. The final parser scans decimal tokens incrementally, stops at the ceiling before allocating more token records, and checks the file's byte size before decoding. The million-token regression now rejects in about 0.05 seconds at roughly 37 MiB maximum RSS on the local verification host, compared with roughly 232 MiB before the correction. The reviewer's final recheck was interrupted by its service usage limit; the corrected tree was instead rebuilt and covered by the complete local gate above.

The additive `REF-EMPTY` law proves only that the production reference helper rejects every index when the target catalog is empty. Filesystem, parser, protocol and full validator correctness remain test-covered or trusted boundaries as described in [LAW_CATALOG.md](../LAW_CATALOG.md).

## Remaining scope

Content-0 deliberately omits moves, types, effects, items, recipes, trainers, dialogue, quests, executable event graphs and all battle formulas. Those require later additive schemas after their engine-owned semantics are approved. M3 cannot claim deterministic battle completion until timing, damage and RNG decisions have concrete approved values. Remote CI and live presentation/device gates listed in [M0-STATUS.md](M0-STATUS.md) also remain open.
