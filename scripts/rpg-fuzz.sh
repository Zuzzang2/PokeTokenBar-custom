#!/bin/bash
# Random-action fuzz probe for the RPG world. Usage: scripts/rpg-fuzz.sh [seeds] [steps]
set -euo pipefail
cd "$(dirname "$0")/.."
swift build >/dev/null
OUT="$(mktemp -d)/rpgfuzz"
swiftc Tests/RpgFuzz/*.swift -I .build/debug/Modules -o "$OUT" \
    $(ls .build/debug/PokeTokenBar.build/*.o | grep -v '/main.swift.o') -lsqlite3
PTB_STATE_DIR="$(mktemp -d)" "$OUT" "$@"
