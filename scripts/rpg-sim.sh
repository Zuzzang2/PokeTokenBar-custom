#!/bin/bash
# Headless RPG simulation checks. XCTest is not available with only the Command Line Tools, so this links
# Tests/RpgSim/main.swift against the app's debug objects (SwiftPM renames the app's main) and runs it.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build >/dev/null
OUT="$(mktemp -d)/rpgsim"
swiftc Tests/RpgSim/*.swift -I .build/debug/Modules -o "$OUT" \
    $(ls .build/debug/PokeTokenBar.build/*.o | grep -v '/main.swift.o') -lsqlite3
"$OUT"
