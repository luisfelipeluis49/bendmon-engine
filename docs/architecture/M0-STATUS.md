# M0 implementation evidence

Status: local foundation implemented; full M0 exit remains pending remote CI and live presentation/device feasibility. This is not a playable RPG or maker editor.

## Verified locally

- Pinned workspace-local Bend 2.0.19, archive and executable SHA-256 verified; no global install. Installed guide, effects guide, parallel/shader guidance and relevant Base declarations read before code.
- Pure `engine/core/bootstrap.bend` transition plus `platform/feasibility/headless.bend` IO adapter. This accumulator is a compiler/host probe, not a game clock or balance rule.
- Initial BOOT-1 law: adding zero preserves every natural-number accumulator state. `bend PROOF.bend` imports the law and proves the actual production function by induction. No existing law was weakened.
- False and unfinished proof fixtures fail; changed normal Bend entries type-check.
- Native executable and emitted JavaScript agree over 26 example/generated command sequences, including a sum exceeding U32 and the maximum 1024-token batch. Negative, nondecimal, overflow and over-count inputs reject explicitly.
- Independent CPU fork/join computation produces identical output with 1, 2 and 4 threads.
- Copied headless executable runs from a clean temporary directory without Bend on PATH. This demonstrates compiler independence on this host, not a full clean-machine portability test.
- A pure Bend presentation snapshot projects into a developer-owned C effect. It emits an original sprite/depth PPM frame and a 180ms mono WAV. File structure, repeatability, invalid host bounds, mismatched snapshot tags, invalid arguments and symlink-output rejection pass. Artifact output uses exclusive temporary files and atomic replacement; a hard-link regression confirms unrelated linked files remain unchanged.
- `python3 scripts/verify.py`: 93 checks pass. Machine-readable evidence and command logs are generated in `build/evidence/`; no committed build binaries are required.

## Formal boundary

Only BOOT-1 is formally proved here. CLI decoding, compiler/code generation, runtime/native arithmetic representation, foreign filesystem/image/audio output and process behavior are covered by tests or remain trusted; they are not certified by the bootstrap law. The compiler explicitly reports foreign-code dependency for the presentation shell. The existing gameplay law catalog remains a future specification catalog, not a list of proved engine properties.

Native Nat representation is bounded by this compiler despite mathematical Nat types. The CLI limits each input to U32 and the batch to 1024, keeping accumulator totals below the native bound. This is a feasibility resource limit, not an engine rule. Future production arithmetic needs its own refinement/overflow proofs and tests.

## Outstanding gates

- GitHub workflow is configured but has not run remotely: this workspace has no usable Git metadata/remote. No push or commit was made.
- Live X11 window/input and hardware sound have not been verified. ALSA headers are absent; the probe uses file-output effects instead. The C effect is a measured file-output bridge, not proof the final renderer/audio stack is ready.
- JavaScript headless execution passes using Node; the presentation JS foreign effect deliberately returns an unsupported error. Browser renderer integration remains unimplemented.
- macOS/Windows/GPU and fresh-machine distribution are not tested.
- No project loader, battle kernel, progression, save system or maker UI exists yet. Approved nonnumerical choices are recorded in DECISIONS.md; numerical rules still need approval before mechanics implementation.

Independent review and corrected findings are recorded in [M0-REVIEW.md](M0-REVIEW.md). Frame and tone output are atomic per file, not as a bundle.

## Next slice

Resolve M0 presentation/CI gates and approve the field-level catalog contract for M2. Implement typed IDs, inert versioned documents, strict reference/semantic validation and useful diagnostics before battle code. Do not turn this accumulator or sample scene into an accidental gameplay ruleset.
