# Build and verification

This repository uses a workspace-local, pinned Bend 2 release. The bootstrap
does not modify a global compiler installation. The supported baseline for this
feasibility milestone is Ubuntu 24.04 on an x86-64 CPU with Python 3.12+, clang,
and Node.js 20 available.

From the repository root, bootstrap the compiler and put the wrapper on `PATH`:

```sh
python3 scripts/setup_toolchain.py
export PATH="$PWD/scripts:$PATH"
```

Run the complete local verification suite:

```sh
python3 scripts/verify.py
```

The verifier checks the canonical proof, intentionally failing proof fixtures,
source checks, native and JavaScript headless behavior, CPU parallel behavior,
the presentation boundary, and the native Content-0 kernel plus hostile loader
tests. It writes the machine-readable summary and
presentation evidence under `build/evidence/`. The generated files are local
build outputs and are ignored by Git.

The native headless entry point is `build/headless`. After verification, the
developer-facing smoke test is:

```sh
./build/headless -- 1 2 3
# 6
```

The verifier also builds `build/content-kernel`. Use the supported Python shell
to validate projects; its JSON result is suitable for editor and CI adapters:

```sh
python3 scripts/validate_project.py examples/original-demo
```

The native kernel's wire format is an internal trusted boundary documented in
`docs/schemas/CONTENT-0.md`; project authors do not invoke or generate it.

The native binary can be copied and run from a clean directory without the Bend compiler on this host; it still depends on compatible system libraries. Compilation itself requires the
workspace-pinned Bend release and clang; runtime execution is CPU-only for this
milestone. The parallel fixture can be run with explicit CPU workers, for
example `./build/parallel_cpu --threads 4 --gpu off`.

Headless presentation verification emits `build/evidence/presentation/frame.ppm` and
`build/evidence/presentation/tone.wav` (and a PNG preview where supported).
These are generated boundary artifacts: the tests demonstrate repeatable generation and file format/ABI handling on the tested host. They do not claim a live display or live audio device
playback was available.

On a Linux desktop with X11/XWayland and PulseAudio/PipeWire, run the separate
live gate:

```sh
tests/feasibility/presentation/run_live.sh
```

It displays the generated frame, verifies an input event delivered by the X
server and streams the tone through the active audio server. This gate is not
run in headless CI.

After the main verifier builds `build/headless`, the clean Ubuntu distribution
gate is:

```sh
scripts/verify_clean_distribution.sh
```

It runs the binary with networking disabled in a digest-pinned Ubuntu 24.04
container that contains neither the repository nor the Bend compiler.

GitHub Actions repeats this flow on `ubuntu-24.04`, installs clang, selects
Node.js 20, runs the Python verifier, and uploads `build/evidence/` even when a
check fails. A remote GitHub Actions run has not been claimed by this local
work order. Bend's generated C for the closed Content-0 parser is deeply nested,
so `scripts/bend` selects `scripts/clang-bend`, which raises Clang's parser
bracket-depth limit while preserving the pinned Bend compiler and normal flags.
