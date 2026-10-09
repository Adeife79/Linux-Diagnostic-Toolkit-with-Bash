#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/disk-check.log"

log_operation() {
    if ! mkdir -p -- "$LOG_DIR"; then
        printf 'Error: unable to create log directory: %s\n' "$LOG_DIR" >&2
        exit 1
    fi
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$1" >> "$LOG_FILE"
}

usage() {
    printf 'Usage: %s <threshold 1-100> [path]\n' "${0##*/}" >&2
}

if (( $# < 1 || $# > 2 )); then
    usage
    log_operation 'Disk check rejected invalid argument count'
    exit 2
fi

threshold_input=$1
if [[ ! "$threshold_input" =~ ^[0-9]+$ ]]; then
    usage
    log_operation 'Disk check rejected a non-integer threshold'
    exit 2
fi

threshold_normalized=${threshold_input#"${threshold_input%%[!0]*}"}
if [[ -z "$threshold_normalized" ]]; then
    threshold_normalized=0
fi
if (( ${#threshold_normalized} > 3 )) || (( threshold_normalized < 1 || threshold_normalized > 100 )); then
    usage
    log_operation 'Disk check rejected an out-of-range threshold'
    exit 2
fi
threshold=$((10#$threshold_normalized))
path=${2:-/}

if [[ ! -e "$path" ]]; then
    printf 'Error: path does not exist: %s\n' "$path" >&2
    log_operation "Disk check failed because path does not exist: $path"
    exit 2
fi


usage_percent=$(df -P -- "$path" 2>/dev/null | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
if [[ ! "$usage_percent" =~ ^[0-9]+$ ]]; then
    printf 'Error: unable to determine disk usage for: %s\n' "$path" >&2
    log_operation "Disk check could not determine usage for path: $path"
    exit 1
fi

printf 'Disk usage for %s: %s%% (threshold: %s%%)\n' "$path" "$usage_percent" "$threshold"
log_operation "Checked disk usage for $path: ${usage_percent}% (threshold ${threshold}%)"

if (( usage_percent >= threshold )); then
    printf 'Warning: disk usage has reached or exceeded the threshold.\n'
    exit 1
fi

printf 'Disk usage is below the threshold.\n'
exit 0
