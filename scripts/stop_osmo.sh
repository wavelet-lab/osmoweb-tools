#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

me=$(basename "$0")

# Source shared library (relative to this script's location)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"
# shellcheck source=lib/libosmops.sh
. "${SCRIPT_DIR}/lib/libosmops.sh"

# Configuration
GRACEFUL_TIMEOUT=10 # seconds to wait for graceful shutdown
CHECK_INTERVAL=1    # seconds between checks
FINAL_TIMEOUT=2     # seconds to wait for final termination

# Default values

# Function to show usage
show_usage() {
	echo "${BOLD}Usage:${RESET} $1 [OPTIONS]"
	echo "${BOLD}Options:${RESET}"
	echo "  ${CYAN}-h, --help${RESET}     Show this help message."
	echo "  ${CYAN}-q, --quiet${RESET}    Quiet mode - suppress output messages."
	exit 0
}

# Use library logging
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
		log_error "Unknown option: $1"
		log_info "Use -h or --help for usage information"
		exit 1
		;;
	esac
done

# Function to wait for processes to terminate
wait_for_termination() {
	local timeout=$1
	local elapsed=0

	while [ "$elapsed" -lt "$timeout" ]; do
		remaining=$(find_osmo_pids)
		if [ -z "$remaining" ]; then
			return 0 # All processes terminated
		fi
		sleep "$CHECK_INTERVAL"
		elapsed=$((elapsed + CHECK_INTERVAL))
		log_output "Waiting... ($elapsed/${timeout}s)"
	done

	return 1 # Timeout reached
}

# Function to get osmo processes and format them
get_osmo_processes() {
	local pids
	pids=$(find_osmo_pids)
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
# shellcheck disable=SC2086 # We want to pass multiple PIDs to kill
if kill $OSMO_PIDS 2>/dev/null; then
	log_success "SIGTERM sent successfully"
else
	log_error "Failed to send SIGTERM"
	exit 1
fi

# Wait for graceful shutdown with progress
log_output "Waiting up to ${GRACEFUL_TIMEOUT} seconds for graceful shutdown..."
if wait_for_termination "$GRACEFUL_TIMEOUT"; then
	log_success "All osmo processes terminated gracefully"
	exit 0
fi

# Check what's still running
get_osmo_processes

log_output "Processes still running after ${GRACEFUL_TIMEOUT}s: ${BOLD}${OSMO_PIDS_FORMATTED}${RESET}"
log_output "Forcing termination with SIGKILL..."

# Force termination
# shellcheck disable=SC2086 # We want to pass multiple PIDs to kill
if kill -SIGKILL $OSMO_PIDS 2>/dev/null; then
	log_success "SIGKILL sent successfully"
else
	log_error "Failed to send SIGKILL"
	exit 1
fi

# Final verification
sleep "$FINAL_TIMEOUT"
get_osmo_processes

if [ -z "$OSMO_PIDS" ]; then
	log_success "All osmo processes forcefully terminated"
	exit 0
else
	log_error "Failed to terminate processes: $OSMO_PIDS_FORMATTED"
	exit 1
fi
