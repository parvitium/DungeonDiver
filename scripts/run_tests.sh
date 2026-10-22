#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not on PATH. Set GODOT=/path/to/godot" >&2
  exit 2
fi

echo "Using $($GODOT --version)"
"$GODOT" --headless --path "$ROOT" --import --quit
"$GODOT" --headless --path "$ROOT" -s res://tests/run_tests.gd

SMOKE_LOG="$(mktemp)"
cleanup() { rm -f "$SMOKE_LOG"; }
trap cleanup EXIT

if command -v timeout >/dev/null 2>&1; then
  timeout --signal=TERM --kill-after=5s 45s \
    "$GODOT" --headless --path "$ROOT" res://tests/smoke_play.tscn | tee "$SMOKE_LOG"
else
  "$GODOT" --headless --path "$ROOT" res://tests/smoke_play.tscn | tee "$SMOKE_LOG"
fi
grep -q "SMOKE_PLAY OK" "$SMOKE_LOG"
