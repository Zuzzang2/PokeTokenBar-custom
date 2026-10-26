#!/bin/bash
# Balance probe: bots hunt with every class at several levels. Usage: scripts/rpg-balance.sh [seconds] [levels]
set -euo pipefail
cd "$(dirname "$0")/.."
swift build >/dev/null
OUT="$(mktemp -d)/rpgbalance"
swiftc Tests/RpgBalance/*.swift -I .build/debug/Modules -o "$OUT" \
    $(ls .build/debug/PokeTokenBar.build/*.o | grep -v '/main.swift.o') -lsqlite3
PTB_STATE_DIR="$(mktemp -d)" "$OUT" "$@"
