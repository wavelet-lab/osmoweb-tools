#!/usr/bin/env bash

# Idempotency guard
if [[ -n "${LIBOSMOPS_LOADED:-}" ]]; then
    return 0
fi
LIBOSMOPS_LOADED=1

# Determine this script's directory for relative sourcing
# shellcheck disable=SC2034  # Exposed for external scripts that source this file
LIBOSMOPS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# Osmo binaries
declare -a osmo_binaries=(
    "osmo-stp"
    "osmo-hlr"
    "osmo-mgw"
    "osmo-msc"
    "osmo-bsc"
    "osmo-bts-trx"
)

# Function to find osmo processes
find_osmo_pids() {
    local bins="${osmo_binaries[*]}"
    local search=${bins// /|}
    # Use pgrep to match any of the osmo binaries; return empty if none found
    if command -v pgrep > /dev/null 2>&1; then
        pgrep -f -- "${search}"
    else
        # Fallback to ps|grep if pgrep is not available
        # shellcheck disable=SC2009 # ps|grep used intentionally to support regex alternation
        ps axo pid,comm | grep -E -- "${search}" | awk '{print $1}'
    fi
}
