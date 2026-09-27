# M9 renderer work orders

Status: complete. M8 is the verified headless
baseline. Approved D14 and D18 govern the renderer: free-direction 2.5D world
movement, a perspective map camera, billboard sprites in 3D scenes, and a
Linux x86_64 CPU-capable native host. Rendering, interpolation, camera, light,
VFX, animation, audio and input devices cannot change logical state, RNG,
command acceptance, collision, hit timing or encounter distance.

M9 closes when a validated project runs in a graphical host with sprite depth,
camera, light, representative VFX and audio driven by read-only projections and
ordered semantic events; a scripted headless and graphical run with the same
initial state and accepted commands must have identical final logical state.
Visual QA must inspect captured frames and live window/input/audio evidence.
The maker UI, creator export flow and general packaging remain M10/M11.

## M9-A — pure presentation projection and event delivery

TASK: expose a closed, bounded read-only scene projection from M8/M7 state and
deliver world and battle presentation events without losing their order.
OWNER MODEL: Luna, with Sol integration for affine/session changes.
DEPENDENCIES: M8 world session, M7 playable battle and D14/D18.
FILES ALLOWED TO CHANGE: new `engine/presentation/` modules, the narrow
`engine/world/world_session.bend` event-output seam, matching Bend fixtures.
FILES FORBIDDEN TO CHANGE: movement, collision, battle damage/timing, RNG and
event execution semantics without an independently demonstrated defect.
GOAL: one projection contract for world position/elevation/facing, visible
entities, camera anchor, battle state and semantic cues. Preserve world event
`Signal`/`Waited`/`Asked` outputs and yielded kinds across both command-started
activations and resumed `event_step` calls; session routing currently drops
them. Carry ordered typed cues, not animation callbacks or renderer handles.
NON-GOALS: pixels, device audio, content decoding or GUI widgets.
ENGINE INVARIANTS AFFECTED: presentation is observational; event and command
order remains authoritative in the pure core.
LAWS AFFECTED: add a production-linked projection noninterference witness if
expressible without copying a toy transition; do not weaken existing laws.
INPUT CONTRACT: validated catalog, current world/battle session and accepted
transition results.
OUTPUT CONTRACT: bounded immutable scene DTO plus ordered presentation cues;
no mutation path back into the source session.
IMPLEMENTATION NOTES: use actual M8 coordinates and accepted event outputs.
Derive stable presentation occurrence IDs from the accepted-input ordinal and
within-transition cue index; M8 `OutputEvent` has no inherent event ID. Those
IDs are replay labels, never RNG draws, a new logical clock or authored data.
Keep camera smoothing and sprite orientation outside logical state. The M0
`Snapshot` and arithmetic tag are a feasibility example, not this DTO.
EDGE CASES: active event wait/choice, encounter handoff, battle choice,
terminal battle return, empty/missing optional cues and dense entity lists.
TESTS REQUIRED: native/JavaScript projection goldens for a loaded scene and
battle states; cue order/IDs through event start and resume, and state/RNG
noninterference regressions.
PROOF OBLIGATIONS: production-linked observation law or an explicit account
of which host effects remain outside proof.
ACCEPTANCE CRITERIA: render projection and cue extraction cannot alter the
next pure transition; no committed world cue is silently discarded.

## M9-B — validated visual/audio content and camera profiles

TASK: extend the inert content boundary for authored presentation references.
OWNER MODEL: Luna, parallel with M9-A under a reviewed schema contract.
DEPENDENCIES: Content-0 bounded loader and D18 camera/asset requirements.
FILES ALLOWED TO CHANGE: `schemas/content-0/`, `platform/content/`,
`docs/schemas/CONTENT-0.md`, example content and matching loader fixtures.
FILES FORBIDDEN TO CHANGE: gameplay formulas, world navigation authority and
user-authored executable code paths.
GOAL: bind validated AssetIds to immutable visual/audio media, bounded
perspective camera profiles and map presentation metadata. Preserve existing
P6 PPM packs; propose and freeze any added sprite/audio codecs and resource
ceilings before implementation, then version and hash all semantic additions.
NON-GOALS: arbitrary media imports, authored shaders/scripts or renderer-side
acceptance of unvalidated project bytes.
ENGINE INVARIANTS AFFECTED: exact content identity and the inert-data boundary.
LAWS AFFECTED: none unless a production gameplay rule changes.
INPUT CONTRACT: manifest-listed bytes through the existing bounded loader.
OUTPUT CONTRACT: immutable typed presentation records and actionable errors.
IMPLEMENTATION NOTES: map mesh/art never authorizes movement; baked M8 nav
geometry remains the only collision source. Keep third-party decoders behind
project-owned adapters and retain full-digest identity checks.
EDGE CASES: transparent sprites, invalid/truncated media, excessive dimensions
or duration, duplicate IDs, dangling refs, profile bounds and hash mismatch.
TESTS REQUIRED: old-pack compatibility, hostile-file limits, camera/ref
validation, digest changes, native/JS binding conformance where applicable.
PROOF OBLIGATIONS: document the trusted media-decoder/host boundary.
ACCEPTANCE CRITERIA: every displayed asset/profile is validated and bounded
before the renderer sees it; old Content-0 samples still load.

## M9-C — graphical and audio host adapters

TASK: implement the production presentation host against M9-A/B contracts.
OWNER MODEL: Luna agents may own native graphics, browser preview and audio
adapters in parallel after the shared DTO is fixed; Sol integrates.
DEPENDENCIES: M9-A/B and an SDL3 feasibility/dependency check.
FILES ALLOWED TO CHANGE: new `platform/presentation/`, matching host tests,
build/setup scripts and narrowly scoped CI configuration.
FILES FORBIDDEN TO CHANGE: `engine/battle/`, `engine/world/` transition logic
except the agreed M9-A cue seam; no device callback may define a game rule.
GOAL: native Linux x86_64 SDL3 window/input/controller/audio and a browser
preview path over the same projection; CPU-only rendering must work. Draw
perspective map depth, billboard sprites, camera profiles, representative
lighting/VFX and event-driven sound with scalable 1280×720 logical output.
NON-GOALS: GPU-required path, Windows/macOS support claim, maker editing UI.
ENGINE INVARIANTS AFFECTED: host input maps to canonical commands; frames and
audio consume state/events only.
LAWS AFFECTED: none; foreign graphics/audio behavior is test and visual QA.
INPUT CONTRACT: validated media/profile records and M9-A scene/cue DTOs.
OUTPUT CONTRACT: frames and audio plus bounded host diagnostics; accepted
commands are returned to the pure core, never synthesized by animation end.
IMPLEMENTATION NOTES: first prove an SDL3 window and audio device on the
supported Linux CPU target; `pkg-config sdl3` is absent on the current
workspace. If a blocking incompatibility is measured, record evidence before
substituting the host library under D18. Keep UI rebinding outside replay data.
EDGE CASES: resize/fullscreen, missing audio device, invalid/removed asset,
occlusion/sort ties, pause, slow frames and device loss.
TESTS REQUIRED: deterministic artifact checks, native/browser smoke tests,
CPU-only run, live Linux window/input/audio evidence and failure diagnostics.
PROOF OBLIGATIONS: state the trusted host boundary; no claim that pixels or
foreign device behavior are formally proved.
ACCEPTANCE CRITERIA: the loaded M8 world and M7 battle render and sound on a
real supported Linux desktop; browser preview uses the same logical DTO.

## M9-D — integration, visual QA and logical-state parity

TASK: close the renderer milestone with reproducible functional and visual
evidence, then update the repository gate and status record.
OWNER MODEL: Sol integration with an independent Luna review.
DEPENDENCIES: M9-A/B/C.
FILES ALLOWED TO CHANGE: `tests/m9/`, `scripts/verify.py`, visual evidence
scripts, `docs/architecture/M9-STATUS.md`, relevant work-order status.
FILES FORBIDDEN TO CHANGE: gameplay rules merely to satisfy a frame golden.
GOAL: drive one loaded project through movement, NPC/event interaction,
encounter, M7 battle and return with identical accepted commands in headless
and graphical modes; compare exact final logical state, RNG and semantic event
order. Capture representative world elevation/depth, camera, battle, VFX and
audio evidence for visual/human inspection.
NON-GOALS: maker usability acceptance or cross-platform release certification.
ENGINE INVARIANTS AFFECTED: DET-1, M8 world/battle integration and exact
content/ruleset identity.
LAWS AFFECTED: only additive production-linked laws needed by M9-A.
INPUT CONTRACT: one validated project, exact initial state and canonical
accepted command transcript.
OUTPUT CONTRACT: machine-readable parity report and inspectable visual/audio
artifacts linked from M9 status.
IMPLEMENTATION NOTES: compare state after the same commands, not after the same
number of rendered frames. Record host, compiler, SDL and CPU setup.
EDGE CASES: variable frame pacing, repeated playback, event waits, resolution
change, muted/missing audio and graphics fallback.
TESTS REQUIRED: `python3 scripts/verify.py`, `./scripts/bend PROOF.bend`,
native/JavaScript projection fixtures, graphical/headless parity, live desktop
capture and independent review of the final implementation.
PROOF OBLIGATIONS: preserve all existing laws and identify unproved foreign
device behavior honestly.
ACCEPTANCE CRITERIA: all required gates pass; visual evidence is reviewed;
no unresolved correctness defect remains; the project runs graphically without
changing the authoritative simulation.

Reviewer and evidence links: record in `docs/architecture/M9-STATUS.md` during
implementation. Escalation follows `docs/work-orders/TEMPLATE.md`.
