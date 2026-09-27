#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"
if [[ ! -x build/m9-sdl-host ]]; then
  tests/m9/sdl3_smoke.sh >/dev/null
fi
python3 scripts/run_m9_journey.py
evidence="$root/build/evidence/m9-journey"
export LD_LIBRARY_PATH="$root/build/deps/sdl3-prefix/lib/wayland:$root/build/deps/sdl3-prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
video_driver="${SDL_VIDEODRIVER:-dummy}"
audio_driver="${SDL_AUDIODRIVER:-dummy}"

sequence_output=$(SDL_VIDEODRIVER="$video_driver" SDL_AUDIODRIVER="$audio_driver" \
  build/m9-sdl-host --sequence-cue 320 180 500 1 \
  "$evidence/cue.pcm" 1 22050 \
  "$evidence/sequence-00.rgba" "$evidence/sequence-01.rgba" \
  "$evidence/sequence-02.rgba" "$evidence/sequence-03.rgba" \
  "$evidence/sequence-04.rgba")
for index in 0 1 2 3 4; do
  grep -q "frame-index=$index" <<<"$sequence_output"
done
grep -q 'cue-frame-index=1' <<<"$sequence_output"
grep -q 'audio=cue' <<<"$sequence_output"
printf '%s\n' "$sequence_output"
