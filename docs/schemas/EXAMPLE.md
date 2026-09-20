# Content-0 original example

`examples/original-demo` is a small declarative Content-0 project. It contains
one catalog with the original species Mosskip and Emberling, one 8×8 map, one
ordered encounter roster, and one original binary P6 sprite.

The fixed documents are `project.json` and `manifest.json`. Manifest paths are
relative to the project directory and are the only content files the loader
should read. The project is deliberately marked `ruleset: "unassigned"`;
Content-0 describes data intake and references, not playable game rules.

The JSON Schemas in this directory are authoring aids. They use draft 2020-12,
close every object, require every Content-0 field, and reject unknown fields.
They do not replace loader validation: the loader must still reject duplicate
JSON keys, invalid UTF-8, unpaired surrogates, floats and booleans in integer
positions, path and ID violations, unresolved typed references, resource-limit
violations, and non-canonical or mismatched asset bytes. In particular, the
schema cannot verify that the PPM has the exact required header/payload or that
`bytes` and `sha256` match the file on disk.
