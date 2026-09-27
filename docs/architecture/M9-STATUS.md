# M9 renderer status

Status: complete. The acceptance contract is
`docs/work-orders/M9-RENDERER.md`; M8 remains the committed headless baseline.

## Implemented boundary

- The pure Bend projection publishes bounded world and M7 battle scenes. The
  world session publishes ordered event cues with occurrence labels derived
  from accepted-input and within-transition ordinals. Projection and cue
  delivery never draw, play sound, consume RNG or advance the engine clock.
- Content-0 validates and hashes PNG RGBA8 sprites/backgrounds, PCM WAV audio,
  bounded camera profiles, NPC sprites and signal-to-audio bindings. Existing
  P6 PPM projects remain supported. The project-owned media adapter rechecks
  file size and SHA-256 before decoding an asset for either host.
- The CPU raster draws a perspective navigation surface with depth-tested
  triangles, billboards, alpha, lighting tint, background art and cue pulses.
  A native SDL3 software window handles resize presentation, key/gamepad
  command mapping and PCM playback. Mapped commands are delivered through
  a caller-owned sink callback; the standalone CLI prints the same codes.
  The browser preview consumes the same
  scene and cue wire contract through a static validated export.

## Loaded-project parity and visual evidence

`scripts/run_m9_journey.py` runs the native and JavaScript Bend fixtures for
the same validated `examples/m8-world` project and initial state. Both routes
activate the NPC, resolve the event signal, move into an encounter, complete an
M7 battle and return to the world. The headless and presentation-observed
routes compare a full stable world signature: content identity, map/point,
meter and RNG, persistent values/entities, terminal status, ordered battle
transition events and captures. The move-scene fixture projects the encounter
state without another battle traversal, which avoids Bend's measured 255-word
continuation-arity limit. The script rejects native/JavaScript or
headless/observed output differences and writes:

- `build/evidence/m9-journey/parity.json`: content hash, exact-comparison
  results, final signature digest, cue occurrence, frame digests and audio
  digest. The sample content hash is
  `579dea2be8e724994ef7187afd6c57cc7b23974dbb89d33dbcca841bba4af652`.
- `build/evidence/m9-journey/sequence-00.png` through `sequence-04.png`:
  rendered initial world, event signal, post-move world, M7 battle and
  returned world. The cue pulse and verified audio start on event frame 1,
  corresponding to the emitted occurrence `42,0`. The
  corresponding `.rgba` files are loaded directly by the SDL3 host.
- `build/evidence/m9-journey/browser/` and `browser-battle/`: static previews
  with the exact Bend scene wires and hash-verified media. The world browser
  preview displayed one NPC and reported `Played 1 signal cue.` after its
  control was clicked; the battle preview displayed its actors and status.
- `build/evidence/m9-journey/cue.pcm`: decoded from the verified greeting WAV
  bound to `Signal{7}`. Cue occurrence `42,0` was emitted and ordered by Bend.

The actual loaded journey was presented through the real Wayland software
window with SDL3 3.4.16 and ALSA, reporting `frame-index=0` through
`frame-index=4`, `cue-frame-index=1` and
`software-window=1280x720 frame=320x180 audio=cue` in one run.
`tests/m9/sdl3_smoke.sh` also checks injected key/gamepad
input, the loaded sample frame, muted/unavailable audio and frame sequencing,
including a forced skipped visual frame that still delivers its crossed cue
and a terminal overrun that displays the final frame and delivers the cue
with deterministic dummy devices. The input smoke verifies that the sink
callback receives the canonical command codes. A physical controller was
not part of this local QA.

The visual captures were inspected for perspective geometry, NPC sprite,
transparent signal pulse, battle actor separation and the returned world.
The example art is deliberately small and functional; creator art and editor
experience remain later milestones.

## Reproduction and proof boundary

Run `python3 scripts/verify.py` to rebuild the Bend fixtures, both hosts and
the ignored evidence bundle. Run `./scripts/bend PROOF.bend` for the canonical
law gate. The native SDL3 setup uses the official 3.4.16 release archive,
verified against SHA-256
`7322236cd12090c3eb40b9728be4d49c76f66ad17d04369584d4ecad5cf77c68`,
and builds into ignored `build/deps/`. On this Wayland host the live commands
were:

```sh
SDL_VIDEODRIVER=wayland SDL_AUDIODRIVER=alsa tests/m9/sdl3_smoke.sh
SDL_VIDEODRIVER=wayland SDL_AUDIODRIVER=alsa LD_LIBRARY_PATH=build/deps/sdl3-prefix/lib/wayland:build/deps/sdl3-prefix/lib build/m9-sdl-host --sequence-cue 320 180 500 1 build/evidence/m9-journey/cue.pcm 1 22050 build/evidence/m9-journey/sequence-00.rgba build/evidence/m9-journey/sequence-01.rgba build/evidence/m9-journey/sequence-02.rgba build/evidence/m9-journey/sequence-03.rgba build/evidence/m9-journey/sequence-04.rgba
```

The `LAWS.bend`/`PROOF.bend` gate still covers the deterministic rules.
Native/JavaScript and headless/observed fixtures cover presentation
noninterference. Foreign SDL/browser pixels, device timing and human visual
judgment are not formal proof claims. The SDL process was run with desktop
socket access for the live check; the repository gate uses dummy devices so
it also runs headlessly.

The repository gate passed all 486 checks, including the M9 native/JavaScript
fixtures, loaded-project parity, SDL3 smoke and loaded graphical sequence.
The standalone `./scripts/bend PROOF.bend` gate passed. A final real
Wayland/ALSA run after the input and cue timing fixes rendered frames 0–4,
played the event cue at frame 1, and exited cleanly. Independent Luna review
found no remaining focused correctness defect after fixes to input delivery,
slow-frame cue crossing, terminal overrun and short-sequence audio playback.
