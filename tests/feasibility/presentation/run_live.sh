#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
evidence="$root/build/evidence/live-presentation"
mkdir -p "$evidence"

"$root/scripts/bend" "$root/platform/feasibility/presentation/main.bend" \
  -o "$evidence/presentation"
"$evidence/presentation" "$evidence" >"$evidence/artifact.txt"

cc -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Werror \
  "$root/tests/feasibility/presentation/live_x11.c" \
  -o "$evidence/live_x11" $(pkg-config --cflags --libs x11)
"$evidence/live_x11" "$evidence/frame.ppm" >"$evidence/x11.txt"

pactl info >"$evidence/pulse.txt"
paplay "$evidence/tone.wav"
printf 'live PulseAudio tone stream: PASS\n' >"$evidence/audio.txt"

cat "$evidence/x11.txt"
cat "$evidence/audio.txt"
