#!/usr/bin/env bash
set -euo pipefail

build_path="${OSMO_BUILD_PATH:-/build/osmo}"
cfg_path="${OSMO_CFG_PATH:-/etc/osmo}"
enable_docs="${ENABLE_DOCS:-false}"

args=("-f" "--no-smpp" "-p" "$build_path" "-c" "$cfg_path")

if [ "$enable_docs" = "true" ]; then
    args+=("-d")
fi

echo "Building Osmocom backend with scripts/build_osmo.sh"
echo "Docs: $enable_docs"
echo "SMPP: disabled"
echo "Build path: $build_path"
echo "Config path: $cfg_path"

exec ./scripts/build_osmo.sh "${args[@]}"
