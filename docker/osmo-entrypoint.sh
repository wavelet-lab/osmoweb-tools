#!/usr/bin/env bash
set -euo pipefail

cfg_path="${OSMO_CFG_PATH:-/etc/osmo}"
log_path="${OSMO_LOG_PATH:-/var/log/osmo}"
include_bts="${OSMO_INCLUDE_BTS:-false}"
trx_driver="${OSMO_TRX_DRIVER:-}"

services=(
    osmo-stp
    osmo-hlr
    osmo-mgw
    osmo-msc
    osmo-bsc
)

children=()

usage() {
    cat <<EOF
Usage: osmo-entrypoint.sh [start|shell|COMMAND...]

Environment:
  OSMO_CFG_PATH       Config directory (default: /etc/osmo)
  OSMO_LOG_PATH       Log directory (default: /var/log/osmo)
  OSMO_INCLUDE_BTS    Start osmo-bts-trx when true
  OSMO_TRX_DRIVER     Start osmo-trx-{driver}, for example usdr or uhd
EOF
}

get_config_arg() {
    case "$1" in
        osmo-trx-*) echo "-C" ;;
        *) echo "-c" ;;
    esac
}

start_service() {
    local service="$1"
    local config="${cfg_path}/${service}.cfg"
    local log_file="${log_path}/${service}.log"
    local config_arg

    if ! command -v "$service" > /dev/null 2>&1; then
        echo "ERROR: $service binary not found" >&2
        exit 1
    fi
    if [ ! -f "$config" ]; then
        echo "ERROR: config for $service not found: $config" >&2
        exit 1
    fi

    config_arg="$(get_config_arg "$service")"
    echo "Starting $service with $config"
    "$service" "$config_arg" "$config" >> "$log_file" 2>&1 &
    children+=("$!")
}

stop_children() {
    if [ "${#children[@]}" -eq 0 ]; then
        exit 0
    fi

    echo "Stopping Osmo services..."
    kill -TERM "${children[@]}" 2> /dev/null || true
    wait "${children[@]}" 2> /dev/null || true
}

show_service_logs() {
    local service
    local log_file

    for service in "${services[@]}"; do
        log_file="${log_path}/${service}.log"
        if [ -f "$log_file" ]; then
            echo "Last log lines for $service:"
            tail -n 20 "$log_file" || true
        fi
    done
}

monitor_children() {
    local pid
    local service
    local running_count

    while true; do
        running_count=0
        for index in "${!children[@]}"; do
            pid="${children[$index]}"
            service="${services[$index]}"

            if kill -0 "$pid" 2> /dev/null; then
                running_count=$((running_count + 1))
            else
                echo "ERROR: $service exited unexpectedly"
                show_service_logs
                return 1
            fi
        done

        if [ "$running_count" -eq 0 ]; then
            echo "ERROR: all Osmo services exited"
            show_service_logs
            return 1
        fi

        sleep 2
    done
}

start_all() {
    mkdir -p "$cfg_path" "$log_path"

    if [ "$include_bts" = "true" ]; then
        services+=(osmo-bts-trx)
    fi
    if [ -n "$trx_driver" ]; then
        services+=("osmo-trx-${trx_driver}")
    fi

    trap stop_children TERM INT

    for service in "${services[@]}"; do
        start_service "$service"
    done

    echo "Osmo services started. Logs: $log_path"
    if ! monitor_children; then
        stop_children
        exit 1
    fi
}

case "${1:-start}" in
    start)
        start_all
        ;;
    shell)
        exec /bin/bash
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        exec "$@"
        ;;
esac
