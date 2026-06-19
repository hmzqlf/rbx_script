#!/usr/bin/env bash
set -euo pipefail

PRESET="${PROMETHEUS_PRESET:-Medium}"
CLI="${PROMETHEUS_CLI:-prometheus-lua}"

obf() {
  local in="$1"
  local out="$2"
  local preset="${3:-$PRESET}"
  mkdir -p "$(dirname "$out")"
  "$CLI" --LuaU --preset "$preset" --nocolors --out "$out" "$in"
}

copy() {
  local in="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"
  cp "$in" "$out"
}

copy "source/HmzHub.lua" "HmzHub.lua"
copy "source/HmzLoader.lua" "HmzLoader.lua"
copy "source/loader.lua" "loader.lua"
obf "source/HmzHub/core.lua" "HmzHub/core.lua" "$PRESET"
obf "source/HmzHub/games/anime_astral.lua" "HmzHub/games/anime_astral.lua" "$PRESET"
