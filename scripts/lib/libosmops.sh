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
# Core binaries that are typically always present
# shellcheck disable=SC2034 # Exposed for scripts that source this library.
declare -a osmo_core_binaries=(
    "osmo-stp"
    "osmo-hlr"
    "osmo-mgw"
    "osmo-msc"
    "osmo-bsc"
)

# Additional binaries that may be optionally included
# shellcheck disable=SC2034 # Exposed for scripts that source this library.
declare -a osmo_all_binaries=(
    "${osmo_core_binaries[@]}"
    "osmo-bts-trx"
    "osmo-trx-*"
)

get_osmo_service_from_selector() {
    case "$1" in
        osmo-stp | --stp) echo "osmo-stp" ;;
        osmo-hlr | --hlr) echo "osmo-hlr" ;;
        osmo-mgw | --mgw) echo "osmo-mgw" ;;
        osmo-msc | --msc) echo "osmo-msc" ;;
        osmo-bsc | --bsc) echo "osmo-bsc" ;;
        osmo-bts-trx | --bts-trx) echo "osmo-bts-trx" ;;
        osmo-trx | --trx) echo "osmo-trx" ;;
        *) echo "" ;;
    esac
}

get_osmo_vty_port() {
    case "$1" in
        osmo-stp) echo 4239 ;;
        osmo-hlr) echo 4258 ;;
        osmo-mgw) echo 4243 ;;
        osmo-msc) echo 4254 ;;
        osmo-bsc) echo 4242 ;;
        osmo-bts-trx) echo 4241 ;;
        osmo-trx) echo 4237 ;;
        *) echo "" ;;
    esac
}

get_osmo_config_arg() {
    case "$1" in
        osmo-trx*) echo "-C" ;;
        *) echo "-c" ;;
    esac
}

format_pid_list() {
    local pids="$1"

    if [ -z "$pids" ]; then
        echo ""
        return 0
    fi

    echo "$pids" | tr '\n' ',' | sed 's/,/, /g' | sed 's/, $//'
}

# Function to find osmo processes
find_osmo_pids() {
    local bins="${osmo_all_binaries[*]}"
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
