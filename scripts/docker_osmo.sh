#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

me=$(basename "$0")
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" > /dev/null 2>&1 && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." > /dev/null 2>&1 && pwd)"

# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"
# shellcheck source=lib/libosmops.sh
. "${SCRIPT_DIR}/lib/libosmops.sh"

export LOG_LEVEL=${LOG_LEVEL:-info}
export QUIET=false

compose_cmd=()
osmo_path="${OSMO_PATH:-${REPO_DIR}/osmo}"
cfg_path="${osmo_path}/config"
log_path="${osmo_path}/logs"
include_bts=false
trx_driver=""
enable_docs=false

show_usage() {
    echo "${BOLD}Usage:${RESET} $me [OPTIONS] COMMAND"
    echo ""
    echo "${BOLD}Commands:${RESET}"
    echo "  ${CYAN}build${RESET}          Build the Docker image."
    echo "  ${CYAN}start${RESET}          Start Osmo services with docker compose."
    echo "  ${CYAN}stop${RESET}           Stop Osmo services."
    echo "  ${CYAN}restart${RESET}        Restart Osmo services."
    echo "  ${CYAN}logs${RESET}           Follow container logs."
    echo "  ${CYAN}shell${RESET}          Open a shell inside the container."
    echo "  ${CYAN}control SERVICE${RESET} Connect to a VTY service from inside the container."
    echo ""
    echo "${BOLD}Service selectors for control:${RESET}"
    echo "  ${CYAN}osmo-stp${RESET}, ${CYAN}--stp${RESET}"
    echo "  ${CYAN}osmo-hlr${RESET}, ${CYAN}--hlr${RESET}"
    echo "  ${CYAN}osmo-mgw${RESET}, ${CYAN}--mgw${RESET}"
    echo "  ${CYAN}osmo-msc${RESET}, ${CYAN}--msc${RESET}"
    echo "  ${CYAN}osmo-bsc${RESET}, ${CYAN}--bsc${RESET}"
    echo "  ${CYAN}osmo-bts-trx${RESET}, ${CYAN}--bts-trx${RESET}"
    echo "  ${CYAN}osmo-trx${RESET}, ${CYAN}--trx${RESET}"
    echo ""
    echo "${BOLD}Options:${RESET}"
    echo "  ${CYAN}-b, --bts${RESET}       Start also osmo-bts-trx."
    echo "  ${CYAN}-t, --trx${RESET} DRV   Start also osmo-trx-DRV."
    echo "  ${CYAN}-d, --docs${RESET}      Build image with documentation tools."
    echo "  ${CYAN}-p, --path${RESET} PATH Use custom Osmo data path (default: ./osmo)."
    echo "  ${CYAN}-c, --cfg${RESET} PATH  Use custom config path."
    echo "  ${CYAN}-l, --log${RESET} PATH  Use custom log path."
    echo "  ${CYAN}-q, --quiet${RESET}     Quiet mode."
    echo "  ${CYAN}-h, --help${RESET}      Show this help message."
    echo ""
    echo "${BOLD}Examples:${RESET}"
    echo "  ./scripts/docker_osmo.sh build"
    echo "  ./scripts/docker_osmo.sh start"
    echo "  ./scripts/docker_osmo.sh -b start"
    echo "  ./scripts/docker_osmo.sh control osmo-msc"
    echo "  ./scripts/docker_osmo.sh control --bsc"
    exit 0
}

detect_compose() {
    if docker compose version > /dev/null 2>&1; then
        compose_cmd=(docker compose)
    elif command -v docker-compose > /dev/null 2>&1; then
        compose_cmd=(docker-compose)
    else
        die "Docker Compose not found. Install Docker Compose v2 or docker-compose."
    fi
}

prepare_paths() {
    mkdir -p "$cfg_path" "$log_path"
    cfg_path="$(cd "$cfg_path" && pwd)"
    log_path="$(cd "$log_path" && pwd)"

    if [ -z "$(find "$cfg_path" -mindepth 1 -maxdepth 1 -type f 2> /dev/null)" ]; then
        log_output "Extracting default configs to ${BOLD}${cfg_path}${RESET}"
        tar -xzf "${SCRIPT_DIR}/config.tar.gz" -C "$cfg_path"
    fi
}

compose() {
    OSMO_INCLUDE_BTS="$include_bts" \
    OSMO_TRX_DRIVER="$trx_driver" \
    OSMO_ENABLE_DOCS="$enable_docs" \
    OSMO_HOST_CFG_PATH="$cfg_path" \
    OSMO_HOST_LOG_PATH="$log_path" \
    "${compose_cmd[@]}" \
        --project-directory "$REPO_DIR" \
        -f "${REPO_DIR}/docker-compose.yml" \
        "$@"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -b | --bts)
            include_bts=true
            shift
            ;;
        -t | --trx)
            trx_driver="$2"
            shift 2
            ;;
        -d | --docs)
            enable_docs=true
            shift
            ;;
        -p | --path)
            osmo_path="$2"
            cfg_path="${osmo_path}/config"
            log_path="${osmo_path}/logs"
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
            show_usage
            ;;
        *)
            break
            ;;
    esac
done

command="${1:-}"
shift || true

if [ -z "$command" ]; then
    show_usage
fi

detect_compose

case "$command" in
    build)
        prepare_paths
        compose build "$@"
        ;;
    start)
        prepare_paths
        compose up -d
        ;;
    stop)
        compose down
        ;;
    restart)
        prepare_paths
        compose up -d --force-recreate
        ;;
    logs)
        compose logs -f osmo
        ;;
    shell)
        compose exec osmo /bin/bash
        ;;
    control)
        service_selector="${1:-}"
        if [ -z "$service_selector" ]; then
            die "No service specified."
        fi
        service="$(get_osmo_service_from_selector "$service_selector")"
        port="$(get_osmo_vty_port "$service")"
        if [ -z "$port" ]; then
            die "Invalid service: $service_selector"
        fi
        compose exec osmo telnet localhost "$port"
        ;;
    *)
        die "Unknown command: $command"
        ;;
esac
