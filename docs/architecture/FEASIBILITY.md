# Bend 2 feasibility and evidence

Current results: see [M0 implementation status](M0-STATUS.md) and [pinned toolchain evidence](toolchain-evidence.md). The inspection below records the initial planning environment before local installation.

## Initial local inspection

Session environment date: 2026-09-19 (America/Sao_Paulo). Host reports Linux x86_64. `bend --version` and `bend guide` each failed with exit 127: command not found. No existing Bend source was found in the workspace; only AGENTS.md existed. Searches of usual local binary locations and installed documentation did not identify a usable Bend compiler/guide. This is evidence of absence in inspected paths, not proof no installation exists anywhere.

The visible `.git` is read-only and `git status --short` reports not a Git repository. Establish a real writable checkout in M0; do not overwrite the supplied metadata directories. No commit was made. No compiler installation, proof execution, native/JS compilation, GPU benchmark or graphics/audio test occurred. Target support remains unverified locally.

## Upstream reading (not an installed toolchain)

The [Bend 2 upstream repository](https://github.com/bendlang/bend) identifies the current project separately from the [older HigherOrderCO Bend](https://github.com/HigherOrderCO/Bend). Do not install the older toolchain by name and assume compatibility. The [upstream guide](https://github.com/bendlang/bend/blob/main/guide/GUIDE.md) describes laws/proofs, affine ownership, checked recursion, native/JS output and host IO boundaries. This is feasibility evidence, not a substitute for the pinned installed guide or a successful local build. URLs tracking main are mutable; M0 must record an exact revision.

Guide-derived constraints to test: array indices wrap, so validation must precede indexing; unsafe functions/host imports are outside proof guarantees; JS execution and native parallel execution differ; a frame callback must not drive gameplay time. Native graphics/audio dependencies and GPU support must be checked on each target. No advertised performance or formal guarantee is accepted as project verification.

## M0 experiments and go/no-go gates

| Experiment | Required evidence | Failure response |
|---|---|---|
| Toolchain identity | owner-approved Bend 2 source/release, checksum/revision, installed version and complete relevant guide/Base docs | block Bend implementation, do not invent syntax |
| Proof viability | real LAWS→PROOF import, trivial accepted theorem, intentionally false/open fixture rejected, CI same result | block formal claims; escalate to Astra/owner |
| Domain representation | bounded IDs, enums/lists, affine state, checked integer arithmetic, serialization handoff | revise representation with Astra; retain semantics |
| Headless binary | command input → pure transition → deterministic output, repeated execution | do not advance M0 on checker-only output |
| Cross-target | native baseline; JS differential fixture if browser editor proposed | narrow supported target, record limitations |
| Graphics/audio | minimal trusted shell reads snapshot, displays sprite/depth prototype and sound without changing state | compare native host adapters vs browser bridge; no graphics library commitment yet |
| FFI safety | hostile host values rejected; ownership/ABI stable; no pack-controlled symbol/path | refuse unsafe boundary; redesign adapter |
| Distribution | packaged executable launches on clean baseline without creator compiler | adjust packaging/support matrix before UX promises |

Read `bend guide`, relevant subguides and Base/library definitions completely after installation and before any Bend code. This turn writes no Bend code, so it does not attempt to bypass that requirement using remembered or upstream-only syntax.

## Approved initial target matrix

Linux x86_64 CPU is the first supported release target, subject to the release gates. The browser/JavaScript shell is the approved maker host. Windows x64 and macOS arm64 remain validation targets rather than supported initial releases. GPU acceleration is optional and stays behind CPU correctness and workload measurement; CPU-only operation is mandatory. Packaged games use the approved narrow native C/SDL3 adapter unless the recorded feasibility work forces a versioned replacement.

## Top technical risks

1. Missing/new toolchain and evolving proof/ABI behavior: pin revision and run positive/negative gates before domain commitment (Astra/Sol, M0).
2. Proof model diverges from production arithmetic or FFI values: refinement obligations and hostile-boundary tests (Astra/Sol, M1 onward).
3. Timeline ties, cancellation and cooldown rules create incompatible replays: the owner decisions are now fixed; preserve them with the M3 versioned golden traces (Astra).
4. Closed content remains computationally dangerous: global budgets, no immediate cycles, decoder isolation and fuzzing (Sol, M2/M8/M12).
5. Catalog parameters smuggle rules overrides: explicit permission matrix and unknown-field rejection (Astra/Sol, M2).
6. Affine data copying / state history costs: representation spike and measured snapshots; no speculative parallel mutation (Sol, M0/M12).
7. HD-2D editor/runtime integration exceeds built-in rendering capability: early sprite/depth/audio proof of concept and documented host fallback (Sol/Astra, M0/M9).
8. Hashing/migrations reinterpret old content: canonical encoding and exact-match policy before persistence (Sol/Astra, M1/M11).
9. Engine scope overwhelms delivery: headless vertical slices and per-milestone evidence; do not label planning M0 completion (Astra).
10. Capturing, reward commits and save interruptions duplicate state: atomic world/battle transaction model, restart tests (Sol, M7/M11).
