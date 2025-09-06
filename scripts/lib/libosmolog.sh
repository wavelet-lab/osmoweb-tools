#!/usr/bin/env bash

# Idempotency guard
if [[ -n "${LIBOSMOLOG_LOADED:-}" ]]; then
	return 0
fi
LIBOSMOLOG_LOADED=1

# Determine this script's directory for relative sourcing
# shellcheck disable=SC2034  # Exposed for external scripts that source this file
LIBOSMOLOG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Basic environment detection
: "${NO_COLOR:=0}"     # respect NO_COLOR=1 to disable colors
: "${LOG_LEVEL:=info}" # debug|info|warn|error

# Colors to stderr if TTY
if [[ -t 2 && "${NO_COLOR}" != 1 ]] && command -v tput >/dev/null 2>&1; then
	RED=$(tput setaf 1)
	GREEN=$(tput setaf 2)
	YELLOW=$(tput setaf 3)
	BLUE=$(tput setaf 4)
	CYAN=$(tput setaf 6)
	# shellcheck disable=SC2034  # Exposed for callers to use for their own messages
	BOLD=$(tput bold)
	RESET=$(tput sgr0)
else
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	CYAN=""
	# shellcheck disable=SC2034  # Exposed for callers to use for their own messages
	BOLD=""
	RESET=""
fi

# Internal level numeric mapping
__lvl_num() {
	case "$1" in
	debug) echo 10 ;;
	info) echo 20 ;;
	warn) echo 30 ;;
	error) echo 40 ;;
	*) echo 20 ;;
	esac
}

# Returns 0 if message should be emitted given LOG_LEVEL
__lvl_enabled() {
	local want="$1"
	shift || true
	[ "$(__lvl_num "$want")" -ge "$(__lvl_num "$LOG_LEVEL")" ]
}

__is_not_quiet() {
	[ "${QUIET:-false}" != true ]
}

get_timestamp() {
	date '+%Y-%m-%d %H:%M:%S';
}

# Logging helpers; send errors/warnings to stderr
log_debug() {
	__is_not_quiet && __lvl_enabled debug && echo "${BLUE}DEBUG  ${RESET} $@" >&2
}

log_info() {
	__is_not_quiet && __lvl_enabled info && echo "${CYAN}INFO   ${RESET} $@"
}

log_warning() {
	__is_not_quiet && __lvl_enabled warn && echo "${YELLOW}WARN   ${RESET} $@" >&2
}

log_error() {
	#__is_not_quiet && - We want errors always visible
	__lvl_enabled error && echo "${RED}ERROR  ${RESET} $@" >&2
}

log_success() {
	__is_not_quiet && __lvl_enabled info && echo "${GREEN}SUCCESS${RESET} $@"
}

log_output() {
	__is_not_quiet && echo "$@"
}

die() {
	log_error "$@"
	exit 1
}
