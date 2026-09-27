# M9 renderer readiness

Status: implementation started. The controlling work order is
`docs/work-orders/M9-RENDERER.md`. This readiness record identifies the first
implementation seams and measurable exit evidence; it is not an M9 completion
claim.

## Baseline and contracts

- M8 is committed on `master` with a 451-check repository gate. Its pure
  `WorldSession` owns movement, event stepping, encounter selection, M7 battle
  handoff and world return. The loaded journey and save/replay fixtures run on
  native and JavaScript. M9 consumes those states and transitions.
- D14 fixes free-direction HD-2D exploration with 2D billboards in 3D scenes;
  baked fixed-point navigation alone owns collision and logical elevation.
- D18 fixes one pure Bend core, a native trusted C host and browser preview
  path, initial Linux x86_64 CPU support, SDL3 as the first host choice, logical
  1280×720 output, perspective map cameras, device input/audio adapters and a
  strict one-way presentation boundary.
- The M0 presentation spike proves a developer-owned Bend-to-C effect can emit
  one PPM/depth frame and WAV tone and drive a live Linux window/audio path. It
  does not provide a production renderer or usable JavaScript media adapter.

## First implementation seams

1. Close the world-session cue gap: `event_step_route` and `command_event` in
   `engine/world/world_session.bend` currently turn committed/progress/yielded
   event outcomes into `Advanced{state}` and drop presentation-relevant event
   output or yielded kind. M9-A must cover command-started and resumed events
   without changing event execution or logical time. M8 emits ordered typed
   cues but no occurrence ID; M9 derives stable labels from accepted-input
   ordinal and cue index outside the gameplay clock.
2. Define a bounded read-only scene projection from authoritative M8/M7 state.
   A stable save snapshot is not this projection: it intentionally excludes
   active events and battles. Native and JavaScript consume the same DTO.
3. Extend the strict asset boundary before using richer sprite/audio files or
   camera profiles. The current manifest accepts only hashed P6 PPM images up
   to 256×256; no audio asset schema exists. Preserve old packs and include
   every new authored field in canonical content identity.
4. Prove the host path before full renderer work. Bend 2.0.27, Node 18 and
   clang 18 are present locally. `pkg-config sdl3` currently reports no SDL3
   package in this workspace. M9-C begins with a measured native SDL3 window
   and audio spike or documents a blocking incompatibility before substitution.

M9-A and M9-B can proceed in parallel after their shared DTO/asset-ID contract
is recorded. Native graphics, browser preview and audio adapters can then be
split across Luna agents; M9-D integrates and independently reviews them.
This order keeps drawing and device callbacks outside the deterministic core.

## Exit evidence to collect

| Requirement | Evidence |
|---|---|
| Sprite depth, billboards and camera | Captured loaded-map frames at different elevations, occlusion orders and camera profiles; visual review of live motion |
| Light, VFX and audio | Representative event/battle cue capture plus live Linux audio playback and timing review |
| Read-only presentation | Native/JavaScript projection fixtures and rejection/noninterference checks; no frame or audio callback enters core transitions |
| Headless/graphical parity | Identical validated content, initial state and accepted command transcript; exact final logical state/RNG/event-order comparison despite varied frame pacing |
| Supported host | Compiler-free CPU-only Linux x86_64 window/input/audio run with recorded host and SDL version; browser preview smoke test |
| Repository quality | `./scripts/bend PROOF.bend`, `python3 scripts/verify.py`, `git diff --check`, independent review and an M9 status record linking artifacts |

Visual fidelity and device behavior require captured artifacts and human review;
they are outside Bend proof claims. Windows and macOS stay validation targets
until their own clean-machine gates pass.
