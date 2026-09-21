# M0 implementation review

Separate Sol reviewer: `toolchain`, reviewing the headless/proof and presentation implementations authored by other Sol contexts. Luna CI/build documentation was separately reviewed by the `headless` Sol context. Astra integrated the results and reviewed the architecture boundary.

## Findings and disposition

1. Existing hard-linked output files could be truncated through the presentation effect. Fixed: write exclusive temporary files, flush/sync, rename into the output directory and sync that directory. Regression confirms the other hard link's contents remain unchanged.
2. The host reported a supplied snapshot tag without validation. Fixed: recompute the bounded field checksum and reject a mismatched tag before opening outputs; a compiled negative fixture covers rejection. This tag is a diagnostic consistency check, not a cryptographic identity or proof of arbitrary state preservation.
3. CLI rejection text conflated parse, numeric range and count limits. Clarified the message without changing accepted inputs or exit codes.

Focused Sol re-review passed after fixes with no remaining code blocker for the tested M0 slice. The reviewer confirmed the universal bootstrap proof calls the actual production transition, has no unsafe/foreign escape and is non-vacuous. False/open-law fixtures reject. The full verification command passed 93 checks; focused presentation regressions also passed independently.

## Astra architecture disposition

The implementation preserves a pure Bend function behind a bounded command shell and keeps presentation/file IO outside the law's formal boundary. No battle, mixing, Harmony or progression formula was introduced. Initial BOOT-1 adoption is a non-gameplay mathematical bootstrap claim; no previous law was modified. The numerical and structural limits in the probe are feasibility limits, not canonical ruleset constants.

Accept the local implementation slice. Do not mark the entire M0 milestone complete: hosted CI, live graphics/input/audio and clean-machine distribution evidence remain outstanding. M1 and later milestones remain unimplemented; no schema or game-rule approval is implied by this review.

## Known limitation

The frame and tone files are atomically replaced individually, not as one transaction. A failure after writing the frame can leave it beside an older tone. They are independent feasibility artifacts; a future production bundle needs generation-directory or manifest commit semantics before claiming atomic bundle publication.

## Formal-exit revalidation

The 2026-09-21 closure pass retained every reviewed boundary and added evidence
that was previously unavailable: a live XWayland/X11 window and input event, a
successful PulseAudio/PipeWire stream of the generated tone, and execution of
the compiler-free binary in a network-disabled clean Ubuntu 24.04 container.
The integrated verifier now includes 133 checks and the M1 architecture contract
suite. Hosted Ubuntu CI remains the final candidate-commit gate; Windows,
macOS, GPU and production renderer/editor work are later milestones under D18.
