#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

me=$(basename "$0")

# Source shared library (relative to this script's location)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" > /dev/null 2>&1 && pwd)"
# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"
# shellcheck source=lib/libosmops.sh
. "${SCRIPT_DIR}/lib/libosmops.sh"

# Default values
service=""
export QUIET=false

# Function to show usage
show_usage() {
    echo "${BOLD}Usage:${RESET} $1 [OPTIONS] [SERVICE]"
    echo "${BOLD}Options:${RESET}"
    echo "  ${CYAN}SERVICE${RESET}        Specify the service to connect via telnet (e.g., osmo-stp,"
    echo "                 osmo-hlr, osmo-mgw, osmo-msc, osmo-bsc, osmo-bts-trx, osmo-trx)."
    echo "  ${CYAN}--stp${RESET}          Connect to the the STP (Signaling Transfer Point) service via telnet."
    echo "  ${CYAN}--hlr${RESET}          Connect to the HLR (Home Location Register) service via telnet."
    echo "  ${CYAN}--mgw${RESET}          Connect to the MGW (Media Gateway) service via telnet."
    echo "  ${CYAN}--msc${RESET}          Connect to the MSC (Mobile Switching Center) service via telnet."
    echo "  ${CYAN}--bsc${RESET}          Connect to the BSC (Base Station Controller) service via telnet."
    echo "  ${CYAN}--bts-trx${RESET}      Connect to the BTS/TRX (Base Transceiver Station/Transceiver) service via telnet."
    echo "  ${CYAN}--trx${RESET}          Connect to the TRX (Transceiver) service via telnet."
    echo "  ${CYAN}-q, --quiet${RESET}    Quiet mode - suppress output messages."
    echo "  ${CYAN}-h, --help${RESET}     Show this help message."
    echo ""
    echo "${BOLD}Environment variables:${RESET}"
    echo "  ${CYAN}OSMO_PATH${RESET}      Override default build path"
    exit 0
}

# Use library logging; map quiet flag to QUIET variable for the lib
export QUIET=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -q | --quiet)
            export QUIET=true
            shift
            ;;
        -h | --help)
            show_usage "$me"
            ;;
        *)
            selected_service=$(get_osmo_service_from_selector "$1")
            if [ -n "$selected_service" ]; then
                service="$selected_service"
                shift
            else
                log_error "Unknown option: $1"
                log_info "Use -h or --help for usage information"
                exit 1
            fi
            ;;
    esac
done

if [ -z "$service" ]; then
    log_error "No service specified."
    show_usage "$me"
fi

osmo_vty_port=$(get_osmo_vty_port "$service")
# Check if the service is valid
if [ -z "$osmo_vty_port" ]; then
    log_error "Invalid service: $service"
    show_usage "$me"
fi

telnet localhost "$osmo_vty_port"
