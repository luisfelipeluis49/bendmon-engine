#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/bend-presentation.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

"$root/scripts/bend" "$root/tests/feasibility/presentation/projection_test.bend" >"$work/projection.txt"
grep -Fx '../../../platform/feasibility/presentation/projection.Projection{42, 31, 2, 1, 523, 5905}' "$work/projection.txt"

"$root/scripts/bend" "$root/platform/feasibility/presentation/main.bend" -o "$work/presentation"
"$root/scripts/bend" "$root/tests/feasibility/presentation/invalid_projection.bend" -o "$work/invalid_projection"
"$root/scripts/bend" "$root/tests/feasibility/presentation/mismatched_tag.bend" -o "$work/mismatched_tag"
mkdir "$work/out"
"$work/presentation" "$work/out" >"$work/report.txt"
grep -Fx 'frame.ppm 96x64 depth=2; tone.wav 22050Hz 180ms; state_tag=5905' "$work/report.txt"

test "$(head -c 2 "$work/out/frame.ppm")" = P6
test "$(wc -c <"$work/out/frame.ppm")" -eq 18445
test "$(head -c 4 "$work/out/tone.wav")" = RIFF
test "$(wc -c <"$work/out/tone.wav")" -eq 7982

first=$(sha256sum "$work/out/frame.ppm" "$work/out/tone.wav")
"$work/presentation" "$work/out" >/dev/null
second=$(sha256sum "$work/out/frame.ppm" "$work/out/tone.wav")
test "$first" = "$second"

if "$work/presentation" "$work/missing" >"$work/bad.out" 2>"$work/bad.err"; then
  echo 'missing output directory was accepted' >&2
  exit 1
fi
if "$work/presentation" "$work/out" extra >"$work/shape.out" 2>"$work/shape.err"; then
  echo 'invalid argument shape was accepted' >&2
  exit 1
fi
if "$work/invalid_projection" "$work/out" >"$work/range.out" 2>"$work/range.err"; then
  echo 'out-of-bounds projection was accepted' >&2
  exit 1
fi
grep -F 'projected snapshot is outside host bounds' "$work/range.err"
if "$work/mismatched_tag" "$work/out" >"$work/tag.out" 2>"$work/tag.err"; then
  echo 'mismatched state tag was accepted' >&2
  exit 1
fi
grep -F 'projected snapshot state tag mismatch' "$work/tag.err"

mkdir "$work/symlink-out"
ln -s "$work/elsewhere.ppm" "$work/symlink-out/frame.ppm"
if "$work/presentation" "$work/symlink-out" >"$work/link.out" 2>"$work/link.err"; then
  echo 'symlink artifact target was accepted' >&2
  exit 1
fi
test ! -e "$work/elsewhere.ppm"

mkdir "$work/hardlink-out"
printf 'outside bytes stay unchanged\n' >"$work/outside.ppm"
ln "$work/outside.ppm" "$work/hardlink-out/frame.ppm"
"$work/presentation" "$work/hardlink-out" >/dev/null
grep -Fx 'outside bytes stay unchanged' "$work/outside.ppm"
test "$(head -c 2 "$work/hardlink-out/frame.ppm")" = P6

printf '%s\n' "$first"
printf 'presentation boundary: PASS\n'
