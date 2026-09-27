#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
prefix="$root/build/deps/sdl3-prefix"
if [[ ! -f "$prefix/lib/libSDL3.so" ]]; then
  python3 "$root/scripts/setup_sdl3.py"
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/bend-m9-sdl3.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$root/build"
host="$root/build/m9-sdl-host"
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
  "$root/platform/presentation/raster.c" -lm \
  -o "$root/build/m9-raster.so"
export LD_LIBRARY_PATH="$prefix/lib/wayland:$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cc -std=c11 -O2 -Wall -Wextra -Werror \
  -I"$prefix/include" \
  -I"$root/platform/presentation" \
  "$root/platform/presentation/sdl_host.c" \
  "$root/platform/presentation/raster.c" \
  -L"$prefix/lib" -lSDL3 -lm \
  -Wl,-rpath,"$prefix/lib" -o "$host"
cc -std=c11 -O2 -Wall -Wextra -Werror -Dmain=m9_sdl_host_main \
  -I"$prefix/include" -I"$root/platform/presentation" \
  -c "$root/platform/presentation/sdl_host.c" -o "$work/sdl_host.o"
cc -std=c11 -O2 -Wall -Wextra -Werror \
  -I"$prefix/include" -I"$root/platform/presentation" \
  "$root/tests/m9/sdl_input_sink_test.c" "$work/sdl_host.o" \
  "$root/platform/presentation/raster.c" \
  -L"$prefix/lib" -lSDL3 -lm -Wl,-rpath,"$prefix/lib" \
  -o "$work/sdl_input_sink_test"
sink_output=$(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$work/sdl_input_sink_test")
grep -q 'M9 command sink receives canonical input' <<<"$sink_output"
input_output=$(SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}" \
  SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}" "$host" --smoke)
grep -q 'command=1' <<<"$input_output"
grep -q 'command=6' <<<"$input_output"
python3 - "$root" "$work" <<'PY'
import sys
from pathlib import Path

root, work = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(root / "platform"))
from content.loader import load_project
from presentation.composer import render_frame
from presentation.media import load_audio
from presentation.wire import parse_scene

project = root / "examples/m8-world"
loaded = load_project(project)
identity = int(loaded.content_hash[:8], 16)
scene = parse_scene(
    f"1,{identity},1,0,2048,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1024,0,1024,1,1,0"
)
(work / "frame.rgba").write_bytes(render_frame(
    project, loaded, scene, (), root / "build/m9-raster.so", 320, 180
))
cue_asset = next(asset for asset in loaded.assets if str(asset.id) == "sample:greeting")
cue = load_audio(project, cue_asset)
assert cue.channels == 1 and cue.sample_rate == 22050 and cue.pcm_s16le
(work / "cue.pcm").write_bytes(cue.pcm_s16le)
for index, color in enumerate(([30, 90, 40, 255], [150, 50, 35, 255], [50, 70, 170, 255])):
    (work / f"frame-{index}.rgba").write_bytes(bytes(color) * (16 * 9))
PY
sample_output=$(SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}" \
  SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}" \
  "$host" --frame "$work/frame.rgba" 320 180 120 \
  "$work/cue.pcm" 1 22050)
grep -q 'frame=320x180' <<<"$sample_output"
grep -q 'audio=cue' <<<"$sample_output"
unavailable_audio=$(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=m9-no-audio-device \
  "$host" --frame "$work/frame.rgba" 320 180 120 \
  "$work/cue.pcm" 1 22050 2>&1)
grep -q 'audio=unavailable' <<<"$unavailable_audio"
sequence_output=$(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$host" --sequence 16 9 100 \
  "$work/frame-0.rgba" "$work/frame-1.rgba" "$work/frame-2.rgba")
grep -q 'frame-index=0' <<<"$sequence_output"
grep -q 'frame-index=1' <<<"$sequence_output"
grep -q 'frame-index=2' <<<"$sequence_output"
timed_output=$(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$host" --sequence-cue 16 9 100 1 "$work/cue.pcm" 1 22050 \
  "$work/frame-0.rgba" "$work/frame-1.rgba" "$work/frame-2.rgba")
grep -q 'cue-frame-index=1' <<<"$timed_output"
grep -q 'audio=cue' <<<"$timed_output"
cc -std=c11 -O2 -Wall -Wextra -Werror -DM9_TESTING \
  -I"$prefix/include" -I"$root/platform/presentation" \
  "$root/platform/presentation/sdl_host.c" \
  "$root/platform/presentation/raster.c" \
  -L"$prefix/lib" -lSDL3 -lm -Wl,-rpath,"$prefix/lib" \
  -o "$work/sdl3_host_slow"
slow_output=$(M9_TEST_SKIP_FRAME=1 SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$work/sdl3_host_slow" --sequence-cue 16 9 100 1 \
  "$work/cue.pcm" 1 22050 \
  "$work/frame-0.rgba" "$work/frame-1.rgba" "$work/frame-2.rgba")
grep -q 'cue-frame-index=1 played-at-frame=2' <<<"$slow_output"
grep -q 'audio=cue' <<<"$slow_output"
overrun_output=$(M9_TEST_END_OVERRUN=1 SDL_VIDEODRIVER=dummy \
  SDL_AUDIODRIVER=dummy "$work/sdl3_host_slow" \
  --sequence-cue 16 9 100 1 "$work/cue.pcm" 1 22050 \
  "$work/frame-0.rgba" "$work/frame-1.rgba" "$work/frame-2.rgba")
grep -q 'sequence-overrun=1' <<<"$overrun_output"
grep -q 'cue-frame-index=1 played-at-frame=2' <<<"$overrun_output"
grep -q 'audio=cue' <<<"$overrun_output"
first_frame_output=$(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$host" --sequence-cue 16 9 16 0 "$work/cue.pcm" 1 22050 \
  "$work/frame-0.rgba" "$work/frame-1.rgba" "$work/frame-2.rgba")
grep -q 'cue-tail-ms=' <<<"$first_frame_output"
grep -q 'audio=cue' <<<"$first_frame_output"
if SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$host" --sequence-cue 16 9 100 3 "$work/cue.pcm" 1 22050 \
  "$work/frame-0.rgba" "$work/frame-1.rgba" "$work/frame-2.rgba" \
  >"$work/invalid.out" 2>"$work/invalid.err"; then
  echo 'out-of-range cue frame was accepted' >&2
  exit 1
fi
grep -q 'usage: sdl_host --sequence-cue' "$work/invalid.err"
printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' "$sink_output" \
  "$input_output" "$sample_output" \
  "$sequence_output" "$timed_output" "$slow_output" "$overrun_output" \
  "$first_frame_output"
