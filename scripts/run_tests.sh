#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not on PATH. Set GODOT=/path/to/godot" >&2
  exit 2
fi

echo "Using $($GODOT --version)"
"$GODOT" --headless --path "$ROOT" --import --quit || true
"$GODOT" --headless --path "$ROOT" -s res://tests/run_tests.gd
"$GODOT" --headless --path "$ROOT" --quit-after 20 res://tests/smoke_play.tscn
