#!/usr/bin/env bash
set -euo pipefail

PRESET="${PROMETHEUS_PRESET:-Medium}"
ENTRY_PRESET="${PROMETHEUS_ENTRY_PRESET:-Weak}"
CLI="${PROMETHEUS_CLI:-prometheus-lua}"

obf() {
  local in="$1"
  local out="$2"
  local preset="${3:-$PRESET}"
  mkdir -p "$(dirname "$out")"
  "$CLI" --LuaU --preset "$preset" --nocolors --out "$out" "$in"
}

obf "source/HmzHub.lua" "HmzHub.lua" "$ENTRY_PRESET"
obf "source/HmzLoader.lua" "HmzLoader.lua" "$ENTRY_PRESET"
obf "source/loader.lua" "loader.lua" "$ENTRY_PRESET"
obf "source/HmzHub/core.lua" "HmzHub/core.lua" "$PRESET"
obf "source/HmzHub/games/anime_astral.lua" "HmzHub/games/anime_astral.lua" "$PRESET"
