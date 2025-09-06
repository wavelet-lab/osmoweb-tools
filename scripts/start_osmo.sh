#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

me=$(basename "$0")

# Source shared library (relative to this script's location)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"
# shellcheck source=lib/libosmops.sh
. "${SCRIPT_DIR}/lib/libosmops.sh"

# Default values
osmo_path="${OSMO_PATH:-}"
include_bts=false

# Set default paths based on whether osmo_path is provided
if [ -z "$osmo_path" ]; then
	use_system_bins=true
	osmo_path="$(pwd)/osmo"
fi
cfg_path="${osmo_path}/config"
log_path="${osmo_path}/logs"

# Function to show usage
show_usage() {
	echo "${BOLD}Usage:${RESET} $1 [OPTIONS]"
	echo "${BOLD}Options:${RESET}"
	echo "  ${CYAN}-b, --bts${RESET}      Start also the BTS (Base Transceiver Station) service."
	echo "  ${CYAN}-p, --path${RESET}     Specify a custom osmo build path (default: ./osmo)."
	echo "                 It also changes the config and log paths accordingly."
	echo "                 So if you need to change config or log paths,"
	echo "                 you need use -c or -l options next after -p option."
	echo "  ${CYAN}-c, --cfg${RESET}      Specify a custom osmo config path (default: ./osmo/config)."
	echo "  ${CYAN}-l, --log${RESET}      Specify a custom osmo log path (default: ./osmo/logs)."
	echo "  ${CYAN}-q, --quiet${RESET}    Quiet mode - suppress output messages."
	echo "  ${CYAN}-h, --help${RESET}     Show this help message."
	echo ""
	echo "${BOLD}Environment variables:${RESET}"
	echo "  ${CYAN}OSMO_PATH${RESET}      Override default build path"
	exit 0
}

# Use library logging; default level info
export LOG_LEVEL=${LOG_LEVEL:-info}
export QUIET=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	-b | --bts)
		include_bts=true
		shift
		;;
	-p | --path)
		osmo_path="$2"
		log_path="${osmo_path}/logs"
		cfg_path="${osmo_path}/config"
		shift 2
		;;
	-c | --cfg)
		cfg_path="$2"
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

# Osmo binaries
declare -a osmo_binaries=(
	"osmo-stp"
	"osmo-hlr"
	"osmo-mgw"
	"osmo-msc"
	"osmo-bsc"
)

osmo_bts_bin="osmo-bts-trx"

# Function to get config path
get_config_path() {
	local cfg_path="$1"
	local program="$2"

	echo "$cfg_path/$program.cfg"
}

# Function to get executable path
get_executable_path() {
	local program="$1"

	if [ "$use_system_bins" = true ]; then
		which "$program"
	else
		case "$program" in
		"osmo-stp")
			echo "${osmo_path}/libosmo-sccp/stp/osmo-stp"
			;;
		"osmo-hlr")
			echo "${osmo_path}/osmo-hlr/src/osmo-hlr"
			;;
		"osmo-mgw")
			echo "${osmo_path}/osmo-mgw/src/osmo-mgw/osmo-mgw"
			;;
		"osmo-msc")
			echo "${osmo_path}/osmo-msc/src/osmo-msc/osmo-msc"
			;;
		"osmo-bsc")
			echo "${osmo_path}/osmo-bsc/src/osmo-bsc/osmo-bsc"
			;;
		"osmo-bts-trx")
			echo "${osmo_path}/osmo-bts/src/osmo-bts/osmo-bts-trx"
			;;
		*)
			log_error "Unknown program: $program"
			exit 1
			;;
		esac
	fi
}

# Check conflicting old libraries
check_conflicting_old_libraries() {
	log_output "Checking for conflicting old libraries:"

	# Get all osmo libraries from ldconfig
	local osmo_libs
	osmo_libs=$(ldconfig -p | grep -E "libosmo.*\\.so" | grep -v 'libosmo-sigtran' | awk '{print $1}' | sort -u)

	if [ -z "$osmo_libs" ]; then
		log_error "No osmo libraries found in system cache"
		exit 1
	fi

	local conflicts_found=false

	# Check each library for multiple versions
	while IFS= read -r lib_name; do
		if [ -n "$lib_name" ]; then
			# Get all paths for this library
			local lib_paths
			lib_paths=$(ldconfig -p | grep "^[[:space:]]*$lib_name" | awk '{print $NF}')

			# Resolve real paths to handle symlinks
			local real_paths=()
			while IFS= read -r path; do
				if [ -f "$path" ]; then
					local real_path
					real_path=$(readlink -f "$path")
					real_paths+=("$real_path")
				fi
			done <<<"$lib_paths"

			# Get unique real paths
			local unique_real_paths
			unique_real_paths=$(printf '%s\n' "${real_paths[@]}" | sort -u)
			local real_path_count
			real_path_count=$(echo "$unique_real_paths" | wc -l)

			if [ "$real_path_count" -gt 1 ]; then
				log_error "Multiple versions of $lib_name found:"
				echo "$lib_paths" | while IFS= read -r path; do
					local real_path
					real_path=$(readlink -f "$path")
					echo "    ${YELLOW}$path${RESET} -> ${CYAN}$real_path${RESET}"
				done
				conflicts_found=true
			fi
		fi
	done <<<"$osmo_libs"

	if [ "$conflicts_found" = true ]; then
		log_error "Library conflicts detected. Consider cleaning old installations."
		log_info "You can run '${CYAN}sudo ldconfig${RESET}' to refresh the cache or remove conflicting libraries."
		exit 1
	else
		log_success "    No library conflicts detected ✓"
	fi
}

# Function to check executable and related config
check_executable_and_config_exists() {
	local binary="$1"
	local exec_path
	exec_path=$(get_executable_path "$binary")
	local cfg_file
	cfg_file=$(get_config_path "$cfg_path" "$binary")
	if [ ! -x "$exec_path" ]; then
		log_error "$binary not found at $exec_path or not executable."
		exit 1
	else
		log_success "    $binary found at $exec_path ✓"
	fi
	if [ ! -f "$cfg_file" ]; then
		log_error "config file for $binary not found at $cfg_path."
		exit 1
	else
		log_success "    config file for $binary found at $cfg_path ✓"
	fi
}

# Function to check system binaries
check_binaries_and_configs() {
	log_output "Checking osmo binaries and configs:"
	for binary in "${osmo_binaries[@]}"; do
		check_executable_and_config_exists "$binary"
	done
	if [ "$include_bts" = true ]; then
		check_executable_and_config_exists "$osmo_bts_bin"
	fi
}

# Function to create osmo log directory if it doesn't exist
create_osmo_log_directory() {
	if [ ! -d "${log_path}" ]; then
		mkdir -p "${log_path}"
		log_output "Created log directory: ${BOLD}${log_path}${RESET}"
	fi
}

# Main

if [ "$use_system_bins" = true ]; then
	log_output "Using system binaries"
fi
log_output "Osmo path: ${BOLD}$osmo_path${RESET}"
log_output "Config path: ${BOLD}$cfg_path${RESET}"
log_output "Log path: ${BOLD}$log_path${RESET}"

# Check osmo already running
if [ -n "$(find_osmo_pids)" ]; then
	log_error "Osmo services are already running."
	exit 1
fi

# Check conflicting old libraries
check_conflicting_old_libraries

# Check required binaries
check_binaries_and_configs

# Create log directory
create_osmo_log_directory

# Start osmo services using the unified approach
log_output "Starting osmo services..."
for service in "${osmo_binaries[@]}"; do
	exec_path=$(get_executable_path "$service")
	"$exec_path" -c "$cfg_path"/"${service}".cfg 1>"${log_path}"/"${service}".log 2>&1 &
done

# Start BTS service if requested
if [ "$include_bts" = true ]; then
	log_output "Starting BTS service..."
	exec_path=$(get_executable_path "$osmo_bts_bin")
	"$exec_path" -c "$cfg_path"/${osmo_bts_bin}.cfg 1>"${log_path}"/${osmo_bts_bin}.log 2>&1 &
fi

log_success "All osmo services started. Logs are being written to ${BOLD}${log_path}${RESET}"
