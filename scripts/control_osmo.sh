#!/usr/bin/env bash

me=$(basename "$0")

# Source shared library (relative to this script's location)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"

# Default values
service=$1
export QUIET=false

# Function to show usage
show_usage() {
	echo "${BOLD}Usage:${RESET} $1 [OPTIONS] [SERVICE]"
	echo "${BOLD}Options:${RESET}"
	echo "  ${CYAN}SERVICE${RESET}        Specify the service to connect via telnet (e.g., osmo-stp,"
	echo "                 osmo-hlr, osmo-mgw, osmo-msc, osmo-bsc)."
	echo "  ${CYAN}--bsc${RESET}          Start telnet also the BSC (Base Station Controller) service."
	echo "  ${CYAN}--msc${RESET}          Start telnet also the MSC (Mobile Switching Center) service."
	echo "  ${CYAN}--hlr${RESET}          Start telnet also the HLR (Home Location Register) service."
	echo "  ${CYAN}--mgw${RESET}          Start telnet also the MGW (Media Gateway) service."
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
	osmo-stp | --stp)
		service="osmo-stp"
		shift
		;;
	osmo-hlr | --hlr)
		service="osmo-hlr"
		shift
		;;
	osmo-mgw | --mgw)
		service="osmo-mgw"
		shift
		;;
	osmo-msc | --msc)
		service="osmo-msc"
		shift
		;;
	osmo-bsc | --bsc)
		service="osmo-bsc"
		shift
		;;
	-q | --quiet)
		export QUIET=true
		shift
		;;
	-h | --help)
		show_usage "$me"
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		log_info "Use -h or --help for usage information"
		exit 1
		;;
	esac
done

if [ -z "$service" ]; then
	log_error "No service specified."
	show_usage "$me"
	exit 1
fi

# Function to get the port number for a given service
get_osmo_vty_port() {
	case $1 in
	osmo-stp)
		echo 4239
		;;
	osmo-hlr)
		echo 4258
		;;
	osmo-mgw)
		echo 4243
		;;
	osmo-msc)
		echo 4254
		;;
	osmo-bsc)
		echo 4242
		;;
	*)
		echo ""
		;;
	esac
}

osmo_vty_port=$(get_osmo_vty_port "$service")
# Check if the service is valid
if [ -z "$osmo_vty_port" ]; then
	log_error "Invalid service: $service"
	show_usage "$me"
	exit 1
fi

telnet localhost "$osmo_vty_port"
