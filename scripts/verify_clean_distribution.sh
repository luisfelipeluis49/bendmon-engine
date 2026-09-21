#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary="$root/build/headless"
image="ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3"
evidence="$root/build/evidence/clean-distribution.txt"

if [ ! -x "$binary" ]; then
  printf 'missing executable: run python3 scripts/verify.py first\n' >&2
  exit 1
fi

result=$(docker run --rm --network none \
  -v "$binary:/opt/bendmon-headless:ro" \
  "$image" /opt/bendmon-headless -- 100 23)
test "$result" = 123
{
  printf 'image=%s\n' "$image"
  sha256sum "$binary"
  printf 'result=%s\n' "$result"
  printf 'compiler-free clean Ubuntu runtime: PASS\n'
} >"$evidence"
cat "$evidence"
