# Content-0 kernel contract

Development schema, implemented for the owner's next-part request. This remains an inert content loading slice even though later battle, encounter and world structures are now approved. Fields outside this contract reject. Move/item/effect/recipe/capacity-tier editing awaits additive schemas under approved D13–D16 authority.

## Documents

All files are strict UTF-8 JSON objects. Reject duplicate keys at every depth, unknown/missing fields, booleans as integers, floats/exponents/NaN/Infinity, unpaired surrogates, invalid UTF-8 and nesting beyond 16. Names are nonempty printable Unicode strings of <=128 characters. IDs are lowercase ASCII `namespace:local` with each part matching `[a-z][a-z0-9_-]{0,31}`. Each document has exactly `schemaVersion: "content-0"` plus the fields below.

- `project.json`: `id`, `name`, `ruleset: "unassigned"`, `entryMap` (MapId). `unassigned` means no gameplay ruleset is published; these files cannot yet be played as a game.
- `manifest.json`: `catalogs` (relative JSON paths), `maps` (relative JSON paths), `encounters` (relative JSON paths), `assets` (asset records).
- Each catalog document: `id` (CatalogId), `species` (array of `{id,name,sprite}`; sprite is AssetId).
- Each map document: `id` (MapId), `name`, `width`, `height`, `encounters` (array of EncounterId). Dimensions are metadata only; movement/collision unimplemented.
- Each encounter document: `id` (EncounterId), `entries` (array of `{species,level}`; species is SpeciesId and level must be 1..200). No weights/probability semantics in this version. Entries are an ordered roster, not an executable encounter generator.
- Asset record: `id` (AssetId), `path`, `mediaType: "image/x-portable-pixmap"`, `bytes`, `sha256` (64 lowercase hex characters). Initial media subset: P6 binary PPM, header exactly `P6\n<width> <height>\n255\n` with positive decimal dimensions <=256 and exactly width*height*3 bytes. No comments, alternate encodings, extension dispatch or external references. It is an original sample asset path, not a general media importer.

Namespace spaces are typed; the same textual ID may exist in different kinds. Duplicates within any kind, duplicate catalog IDs, duplicate manifest paths (including assets), and duplicate map encounter references reject. A reference resolves only against its required kind. Declaration/file enumeration order is not semantic; sort typed IDs before dense-ID assignment and process manifest document paths in sorted order. JSON document paths are authoring locations and do not enter the content hash; the parsed semantic records do. Asset paths remain part of hashed asset metadata. Sort declaration containers before hashing. Preserve encounter entries and map encounter reference order as declared. Empty catalogs/encounters are legal; at least one map is required by entryMap resolution.

## Engine resource limits for this development loader

Per JSON file 1 MiB, total loaded bytes 8 MiB (including assets), at most 64 manifest-referenced files plus the two fixed documents, at most 256 entities of each kind including catalogs/assets, at most 256 species per catalog and 256 total, 256 entries per encounter and 256 map references per map, map dimensions 1..512, path length 240 ASCII characters, ID length <=65, PPM dimensions 1..256. These are loader resource ceilings, not gameplay balance. Inputs cannot override them. Record constants in one shell module and mirror semantic dimension/level limits in Bend with conformance tests.

Paths must be normalized relative ASCII slash-separated components `[A-Za-z0-9_.-]+`, no empty/dot/dotdot segment, backslash, colon, NUL, absolute/UNC/drive path. JSON document paths end in `.json`; asset paths end in `.ppm`. Reject symlinks in project-root/file traversal and non-regular files using directory-FD relative O_NOFOLLOW opens; inspect size before bounded reads and actual bytes after. No recursive directory scanning, archive extraction, network fetch, deserialization callbacks, subprocess names/paths from content, or generated executable source. Read only manifest-listed files and the two fixed documents. Reject hard-linked source files (nlink !=1) for this development intake. Content remains data even when text contains code-looking strings.

## Native Bend validation boundary

Python shell handles bounded decoding, field checks, ID syntax/uniqueness, manifest/path/asset validation and canonical identity. It launches only `build/content-kernel`, a trusted developer-built executable, with argument arrays and a 15-second timeout. Never compile pack input or interpolate it into source/shell commands.

Wire protocol version is `1`. Flat unsigned decimal U32 tokens passed after `--`, in this order:

```
1
assetCount
speciesCount  speciesAssetId*speciesCount
encounterCount  (entryCount (speciesId level)*entryCount)*encounterCount
mapCount (width height referenceCount encounterId*referenceCount)*mapCount
entryMapId
```

Maximum tokens 140000; to avoid OS argv limits the shell writes ASCII space-separated tokens to a secure temporary file; native CLI receives exactly one absolute wire-file path. Native input is bounded to 2 MiB and parses only this grammar, rejecting excess/trailing/missing tokens or token/count ceilings before expensive iteration. Shell caps total encounter entries and map references each at 4096 in addition to per-record limits, so normal wire data is much smaller. Unresolved IDs encode as the corresponding kind's count (out-of-bounds); wrong-kind refs cannot resolve accidentally. IDs/counts in Bend are Nat after bounded U32 parse; SpeciesId, AssetId, EncounterId, MapId are distinct constructors.

Core structs: Content(assetCount, species asset refs, encounter entry lists, map records, entryMap). Validation checks every reference against its kind's count, level 1..200, dimensions 1..512, and entryMap. All sources, even wire input without the Python shell, must undergo core semantic validation. Independent species/encounter/map checks may run as balanced parallel calls; merge results in fixed order.

Native stdout is exactly `OK\n` on success and stderr is empty. Invalid content emits one diagnostic per line on stderr:
`ERR <code> <record> <item>\n` with nonzero exit and empty stdout. Codes: 1 species sprite ref, 2 encounter species ref, 3 encounter level, 4 map dimensions, 5 map encounter ref, 6 project entryMap. Record is zero-based canonical species/encounter/map index; item is entry/reference index where relevant, otherwise 0. Code 6 is project-level and always uses record=0,item=0. Bad wire input uses `WIRE <reason>\n` on stderr and nonzero exit, not an accepted content result. Diagnostics may stop at first error per independent category; no requirement to enumerate every error. Shell maps diagnostics to stable original file+JSON pointer+entity ID and actionable messages.

## Shell API and CLI

`platform/content/loader.py` is imported as `content.loader` by adding the developer-owned absolute `platform/` directory to the shell/test Python module path; do not shadow Python's standard `platform` module. `load_project(path, kernel_path=None)` returns an immutable `LoadedProject` with canonical JSON bytes, SHA-256 content hash and typed read-only records, or raises `ContentError` holding stable sorted diagnostics. Kernel path override is developer/test API only, never read from content. Canonical identity covers validated project, parsed catalogs/maps/encounters and asset metadata+verified digests; object keys sorted, compact UTF-8, declaration containers sorted by typed ID, semantic lists preserved. `load_project` must invoke Bend before returning success. No accepted cache supplied by a pack.

`python3 scripts/validate_project.py PROJECT_DIR` emits a JSON success summary (`ok`, `projectId`, `contentHash`, counts) or JSON diagnostics (`ok:false`, diagnostics [{code,file,pointer,entityId,message}]); exit 0 valid, 2 content errors, 1 unavailable/broken infrastructure. No traceback for ordinary content failures. Importing the module has no filesystem or subprocess side effects.

## Proof boundary

Existing BOOT-1 stays byte-for-byte unchanged. New REF-EMPTY candidate: `ref_ok(id,0)` is false for every natural ID, tied to the helper used by actual core validation. This additive law expresses a fixed reference-validity requirement, not a new game mechanic. It proves only empty-catalog rejection for references; it does not prove the Python parser, host IO or the complete loader. Other properties are tested. No law weakening is authorized.
