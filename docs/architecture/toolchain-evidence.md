# Bend 2 toolchain evidence

## Pin

The workspace uses the official `bendlang/bend` Bend 2 repository. Source is
pinned at commit `5e23e33e264413f7ab7e00831a0fc8a75ad9c5fe`
(`v2.0.19-1-g5e23e33`, committed 2026-09-19). This is the current upstream
commit selected for M0-A, not the former HigherOrderCO Bend implementation.

The runnable compiler is the official `v2.0.19` Linux x64 release archive. Its
SHA-256 is
`4f50d0a34283bb4e9ad6277a36fd91ef20c5d8992ca857c8185e605b866425b9`,
which matches both upstream `flake.nix` at the pinned commit and the inspected
installer. The source commit is one documentation/packaging commit after that
release tag (commit subject: `The flake names 2.0.19`); its CLI source still
declares version `2.0.19`.

The extracted executable's SHA-256 is
`b4ef4c182e924feffb90921769edf851c157e3412288a7a5bafc41865765f81a`.

Exact machine-readable values are in `toolchain.lock.json`.

## Local installation

No global installer was run. `https://bend-lang.com/install.sh` was downloaded
to `.toolchain/install.sh` and inspected before the release archive was fetched.
The installer declares version 2.0.19, selects this archive for Linux x86_64,
checks the same SHA-256, and would normally write under `$HOME/.bend`. We instead
verified the archive and extracted it only under `.toolchain/release/bend`.

The release binary is an x86-64 glibc ELF. On this baseline it resolves only
glibc system libraries (`libc`, `libpthread`, `libdl`, and `libm`). Compilation
to native output additionally needs Clang 14 or newer according to upstream's
Nix packaging. The verified baseline is Linux x86_64 with glibc 2.39 and Ubuntu
Clang 18.1.3. The archive embeds its Bun runtime, so Bun is not a host
prerequisite for normal CLI use.

## Commands

Run Bend only through the workspace wrapper:

```sh
python3 scripts/setup_toolchain.py
./scripts/bend version
./scripts/bend --version
./scripts/bend guide
./scripts/bend --help
./scripts/bend PROOF.bend
```

Upstream's native version subcommand is `version`; the wrapper maps the common
single argument `--version` form to it. The wrapper also exports
`BEND_NO_TELEMETRY=1`, disabling Bend's optional daily network version check.
It resolves the workspace relative to its own location, so it works from any
current directory.

Installed documentation used by the CLI is located at:

- `.toolchain/release/bend/guide/GUIDE.md`
- `.toolchain/release/bend/guide/EFFECTS.md`
- `.toolchain/release/bend/guide/SHADERS.md`
- `.toolchain/release/bend/bend2/base.bend`

The corresponding inspected source is under `.toolchain/bend/guide` and
`.toolchain/bend/bend2`. Read the complete relevant guides and Base definitions
before writing Bend source, as required by the M0 feasibility order.

## Reproduction

For Linux x86_64, fetch the archive named in `toolchain.lock.json`, verify its
SHA-256 before extraction, and extract it so the locked binary path exists.
`python3 scripts/setup_toolchain.py` performs those steps idempotently. It
rejects paths outside the workspace, archive traversal, links and special file
entries, and verifies the extracted executable against its locked checksum.
It never invokes the upstream installer or writes to a global location. The
locked payload is intentionally platform-specific; another OS or architecture
needs its own upstream archive and checksums recorded before use.
