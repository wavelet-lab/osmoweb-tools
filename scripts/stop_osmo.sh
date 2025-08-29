#!/usr/bin/env bash

me=$(basename "$0")

# Configuration
GRACEFUL_TIMEOUT=10  # seconds to wait for graceful shutdown
CHECK_INTERVAL=1     # seconds between checks
FINAL_TIMEOUT=2      # seconds to wait for final termination

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
quiet_mode=false

# Function to show usage
show_usage() {
    echo "${BOLD}Usage:${RESET} $1 [OPTIONS]"
    echo "${BOLD}Options:${RESET}"
    echo "  ${CYAN}-h, --help${RESET}     Show this help message."
    echo "  ${CYAN}-q, --quiet${RESET}    Quiet mode - suppress output messages."
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
        echo "${CYAN}$@${RESET}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
    local bins="${osmo_binaries[@]}"
    local search=${bins// /|}
    ps axo pid,comm | grep -E "${search}" | awk '{print $1}'
}

# Function to wait for processes to terminate
wait_for_termination() {
    local timeout=$1
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        remaining=$(find_osmo_pids)
        if [ -z "$remaining" ]; then
            return 0  # All processes terminated
        fi
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
        log_output "Waiting... ($elapsed/${timeout}s)"
    done
    
    return 1  # Timeout reached
}

# Function to get osmo processes and format them
get_osmo_processes() {
    local pids=$(find_osmo_pids)
    local pids_formatted=""
    
    if [ -n "$pids" ]; then
        pids_formatted=$(echo "$pids" | tr '\n' ',' | sed 's/,/, /g' | sed 's/, $//')
    fi
    
    # Return both values via global variables
    OSMO_PIDS="$pids"
    OSMO_PIDS_FORMATTED="$pids_formatted"
}

# Main

# Find osmo processes
get_osmo_processes

if [ -z "$OSMO_PIDS" ]; then
    log_success "No osmo processes found"
    exit 0
fi

log_output "Found osmo processes: ${BOLD}${OSMO_PIDS_FORMATTED}${RESET}"

# Try graceful termination (SIGTERM)
log_output "Sending SIGTERM to osmo processes..."
if kill $OSMO_PIDS 2>/dev/null; then
    log_success "SIGTERM sent successfully"
else
    log_error "Failed to send SIGTERM"
    exit 1
fi

# Wait for graceful shutdown with progress
log_output "Waiting up to ${GRACEFUL_TIMEOUT} seconds for graceful shutdown..."
if wait_for_termination $GRACEFUL_TIMEOUT; then
    log_success "All osmo processes terminated gracefully"
    exit 0
fi

# Check what's still running
get_osmo_processes

log_output "Processes still running after ${GRACEFUL_TIMEOUT}s: ${BOLD}${OSMO_PIDS_FORMATTED}${RESET}"
log_output "Forcing termination with SIGKILL..."

# Force termination
if kill -SIGKILL $OSMO_PIDS 2>/dev/null; then
    log_success "SIGKILL sent successfully"
else
    log_error "Failed to send SIGKILL"
    exit 1
fi

# Final verification
sleep $FINAL_TIMEOUT
get_osmo_processes

if [ -z "$OSMO_PIDS" ]; then
    log_success "All osmo processes forcefully terminated"
    exit 0
else
    log_error "Failed to terminate processes: $OSMO_PIDS_FORMATTED"
    exit 1
fi