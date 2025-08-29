#!/usr/bin/env bash

me=$(basename "$0")

# Color definitions
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# Default values
osmo_path="${OSMO_PATH:-}"
quiet_mode=false

# Set default paths if osmo_path is not provided
if [ -z "$osmo_path" ]; then
    osmo_path="$(pwd)/osmo"
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

# Function for output (respects quiet mode)
log_output() {
    if [ "$quiet_mode" = false ]; then
        echo "$@"
    fi
}

# Function for error messages
log_error() {
    echo "${RED}Error:${RESET} $@" >&2
}

# Function for success messages
log_success() {
    if [ "$quiet_mode" = false ]; then
        echo "${GREEN}$@${RESET}"
    fi
}

# Function for warning messages
log_warning() {
    if [ "$quiet_mode" = false ]; then
        echo "${YELLOW}Warning:${RESET} $@"
    fi
}

# Function for info messages
log_info() {
    if [ "$quiet_mode" = false ]; then
        echo "${BLUE}$@${RESET}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            osmo_path="$2"
            log_path="${osmo_path}/logs"
            shift 2
            ;;
        -l|--log)
            log_path="$2"
            shift 2
            ;;
        -q|--quiet)
            quiet_mode=true
            shift
            ;;
        -h|--help)
            show_usage $me
            ;;
        *)
            log_error "Unknown option: $1\n" \
                      "Use ${CYAN}-h${RESET} or ${CYAN}--help${RESET} for usage information"
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
