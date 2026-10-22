#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe_dir=$(mktemp -d "${TMPDIR:-/tmp}/ptb-appearance.XXXXXX")
trap 'rm -rf "$probe_dir"' EXIT
cp scripts/diagnostics/menu-appearance-main.swift "$probe_dir/main.swift"
swiftc -swift-version 6 Sources/PokeTokenBar/UI/MenuAppearanceRefresh.swift \
    "$probe_dir/main.swift" -o "$probe_dir/probe"
"$probe_dir/probe"
