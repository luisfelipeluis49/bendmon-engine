# Published contract compatibility

M12 freezes the exact source identities of the 18 published Content-0 JSON
schemas in `schemas/compatibility-lock.json`. The lock is checked against the
actual schema file set, closed object shapes, required fields, version tags,
ID pattern and engine-owned array ceilings. The shipping package includes the
schemas and lock alongside the shipping semantic validator.

A schema pass alone never authorizes content. The loader still checks bounded
files, media, references, event cost, geometry, exact content identity and the
native validator protocol. Unknown fields and executable content remain errors.

Changes to a published schema require compatibility review and an intentional
lock update. Changes that reinterpret accepted data require a new schema or
ruleset version and an explicit migration; changing the lock alone does not
authorize that reinterpretation. Reordering source formatting also changes the
source hash and therefore requires an explained lock update. No remote schema
resolution or downloaded extension participates in validation.

Content and persistence have distinct versions. Content-0 and `m8-1` ruleset
identity remain unchanged in M12. Historical world schema 1 and M11 save schemas
2/3 retain their exact meanings; current save schema 4 separates final progression
from restore-anchor progression. Replay schema 1 retains its exact ruleset,
content digest, RNG revision and command-order checks. Unsupported or ambiguous
historical states reject rather than being silently upgraded. See
`../architecture/M11-RUNTIME-CONTRACT.md` for migration boundaries.

Host safety limits do not add gameplay options. Content intake remains capped
at 1 MiB per JSON document, 8 MiB total referenced content, 64 referenced files,
256 records per entity family, 4096 references and 16 JSON nesting levels.
The native validator has a 15-second deadline and 64 KiB per output stream;
overflow, timeout, incomplete pipe closure and invalid protocol reject loading.
Creator request envelopes have a 32-level nesting budget and at most 250,000
structural separators/container openings, checked before JSON tree allocation.
Existing endpoint byte budgets apply in addition to these limits. Drafts can be
incomplete, but still have to fit the host resource budget.
Draft enumeration stops after 8192 filesystem entries or 64 JSON documents;
each document is read with the same 1 MiB no-follow boundary. Raw and canonical
draft bundles each have a 64 MiB ceiling. This larger draft envelope allows
incomplete editing; shipping content must still meet the 8 MiB aggregate limit.

Diagnostics preserve file, JSON pointer, code and expected shape. Exported
records cap code at 64 characters, file at 240, pointer/message at 512 and claimed
entity ID at 128; shortened locations carry a stable digest suffix. Invalid
non-string claimed entity IDs are omitted. Duplicate-key failures identify the
problem without echoing the raw key. Host limits and filesystem/process behavior
are tested boundaries, outside the Bend proof guarantee.
