# M0 implementation evidence

Status: formal exit candidate on 2026-09-21. The pinned foundation, local verification, live Linux desktop presentation and clean Ubuntu runtime gates pass. One hosted GitHub Actions run of the candidate commit remains before the status becomes complete.

## Verified locally

- Pinned workspace-local Bend 2.0.19, archive and executable SHA-256 verified; no global install. Installed guide, effects guide, parallel/shader guidance and relevant Base declarations read before code.
- Pure `engine/core/bootstrap.bend` transition plus `platform/feasibility/headless.bend` IO adapter. This accumulator is a compiler/host probe, not a game clock or balance rule.
- Initial BOOT-1 law: adding zero preserves every natural-number accumulator state. `bend PROOF.bend` imports the law and proves the actual production function by induction. No existing law was weakened.
- False and unfinished proof fixtures fail; changed normal Bend entries type-check.
- Native executable and emitted JavaScript agree over 26 example/generated command sequences, including a sum exceeding U32 and the maximum 1024-token batch. Negative, nondecimal, overflow and over-count inputs reject explicitly.
- Independent CPU fork/join computation produces identical output with 1, 2 and 4 threads.
- Copied headless executable runs from a clean temporary directory without Bend on PATH. This demonstrates compiler independence on this host, not a full clean-machine portability test.
- A pure Bend presentation snapshot projects into a developer-owned C effect. It emits an original sprite/depth PPM frame and a 180ms mono WAV. File structure, repeatability, invalid host bounds, mismatched snapshot tags, invalid arguments and symlink-output rejection pass. Artifact output uses exclusive temporary files and atomic replacement; a hard-link regression confirms unrelated linked files remain unchanged.
- The Linux desktop gate maps the generated frame in a real XWayland/X11 window, receives a key event through the X server and streams the generated WAV through PulseAudio on PipeWire. It writes evidence under `build/evidence/live-presentation/`.
- The compiler-free native executable runs with networking disabled inside the pinned clean `ubuntu:24.04` image digest `sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3`; it has no repository or Bend compiler inside the container.
- `python3 scripts/verify.py`: 133 checks pass, including the M1 architecture contract, generated XP table, complete M3 fixture corpus, battle scheduler/reducer/runtime/RNG/combat goldens, native/JavaScript replay agreement, replay checkpoints and canonical persistence boundary. Machine-readable evidence and command logs are generated in `build/evidence/`; no committed build binaries are required.

## Formal boundary

Only BOOT-1 is formally proved here. CLI decoding, compiler/code generation, runtime/native arithmetic representation, foreign filesystem/image/audio output and process behavior are covered by tests or remain trusted; they are not certified by the bootstrap law. The compiler explicitly reports foreign-code dependency for the presentation shell. The existing gameplay law catalog remains a future specification catalog, not a list of proved engine properties.

Native Nat representation is bounded by this compiler despite mathematical Nat types. The CLI limits each input to U32 and the batch to 1024, keeping accumulator totals below the native bound. This is a feasibility resource limit, not an engine rule. Future production arithmetic needs its own refinement/overflow proofs and tests.

## Final hosted gate

- `.github/workflows/verify.yml` runs the canonical verifier on Ubuntu 24.04 with Node 20 and clang, bootstraps the checksum-pinned local Bend toolchain and uploads evidence. M0 closes when that workflow passes on the commit containing this candidate.

Browser presentation, SDL3 production rendering, GPU acceleration, Windows and macOS support belong to M9/M10 and later platform validation. They are outside the approved M0 Linux x86-64 CPU feasibility exit and must not be advertised as supported. The M3 headless battle kernel is implemented; progression, the production renderer, full persistence and maker UI remain later milestones.

Independent review and corrected findings are recorded in [M0-REVIEW.md](M0-REVIEW.md). Frame and tone output are atomic per file, not as a bundle.

## Next slice

Publish this candidate and obtain the hosted Ubuntu workflow result. M1–M3 are complete, so the next gameplay slice is M4's closed effect algebra.
