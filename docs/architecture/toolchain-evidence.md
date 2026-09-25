# Bend 2 toolchain evidence

## Current pin

The workspace pins the official `bendlang/bend` release `v2.0.27` at source
commit `63bee70b55a71024d6bdcb49a745111bc54b114e` (committed
2026-09-23T21:48:26Z). The Linux x64 release archive has SHA-256
`58adc86af6605ed0c48f7d84e4c23028f78893ce4a867a20a4f004b11582687b`;
the extracted executable has SHA-256
`38330ad07e228ba7a317836f484648cba93a1a3927357edccc65e3f2a0de253a`.
The archive checksum matches the [official v2.0.27 release](https://github.com/bendlang/bend/releases/tag/v2.0.27), and the source tag resolves to the recorded commit. Exact machine-readable values are in `toolchain.lock.json`.

M0 originally used v2.0.19 at source commit
`5e23e33e264413f7ab7e00831a0fc8a75ad9c5fe`; its completed evidence
remains in M0 and M2 status documents. The M7 upgrade is relevant because the
[2.0.25 release](https://github.com/bendlang/bend/releases/tag/v2.0.25)
fixes wide-record compilation failures reported as `an arity over 255` in some
cases. The v2.0.27 release also disables project-local Bun configuration loading
in the distributed executable. The M7 native and JavaScript overflow rollback
fixture, terminal capture check, and `PROOF.bend` passed with the staged
v2.0.27 archive before the pin was changed. The full repository gate must pass
again under this exact pin before M7 closes.

## Local installation

No global installer was run. The official archive was downloaded into the
workspace, verified before extraction, and installed only under
`.toolchain/release/bend` by `scripts/setup_toolchain.py`. The script rejects
paths outside the workspace, archive traversal, links and special file entries,
and verifies the extracted executable against its locked checksum. It never
runs the upstream installer or writes to a global location.

The release binary is an x86-64 glibc ELF. Native compilation needs Clang; the
verified baseline is Linux x86_64 with glibc 2.39 and Ubuntu Clang 18.1.3. The
archive embeds Bun, so Bun is not a host prerequisite for the normal CLI.

Run Bend through the workspace wrapper:

```sh
python3 scripts/setup_toolchain.py
./scripts/bend version
./scripts/bend --version
./scripts/bend guide
./scripts/bend --help
./scripts/bend PROOF.bend
```

The wrapper maps the conventional single-argument `--version` alias to Bend's
`version` command and exports `BEND_NO_TELEMETRY=1`. Installed documentation
and Base definitions are under `.toolchain/release/bend/`. The old source
checkout under `.toolchain/bend/` is historical M0 material, not the active
compiler. Another OS or architecture requires its own official archive and
recorded checksums before use.
