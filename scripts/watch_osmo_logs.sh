#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

me=$(basename "$0")

# Source shared library (relative to this script's location)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" > /dev/null 2>&1 && pwd)"
# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"

# Default values
osmo_path="${OSMO_PATH:-}"
log_path=""

# Resolve defaults
if [ -z "$osmo_path" ]; then
    osmo_path="$(pwd)/osmo"
fi
if [ -z "$log_path" ]; then
    log_path="${osmo_path}/logs"
fi

# Function to show usage
show_usage() {
    echo "${BOLD}Usage:${RESET} $1 [OPTIONS]"
    echo "${BOLD}Options:${RESET}"
    echo "  ${CYAN}-p, --path${RESET}     Specify a custom osmo build path (default: ./osmo)."
    echo "                 It also changes the config and log paths accordingly"
    echo "                 so if you need to change log paths,"
    echo "                 you need use -l options next after -p option."
    echo "  ${CYAN}-l, --log${RESET}      Specify a custom osmo log path (default: ./osmo/logs)."
    echo "  ${CYAN}-q, --quiet${RESET}    Quiet mode - suppress output messages."
    echo "  ${CYAN}-h, --help${RESET}     Show this help message."
    echo ""
    echo "${BOLD}Environment variables:${RESET}"
    echo "  ${CYAN}OSMO_PATH${RESET}      Override default build path"
    exit 0
}

# Use library logging
export QUIET=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p | --path)
            osmo_path="$2"
            log_path="${osmo_path}/logs"
            shift 2
            ;;
        -l | --log)
            log_path="$2"
            shift 2
            ;;
        -q | --quiet)
            export QUIET=true
            shift
            ;;
        -h | --help)
            show_usage "$me"
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [ ! -d "${log_path}" ]; then
    log_error "Log directory does not exist: ${log_path}"
    exit 1
fi

log_output "Watching log files in: ${BOLD}${log_path}${RESET}"

# Tail the log files
tail -f "${log_path}"/*.log
