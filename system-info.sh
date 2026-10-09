#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/system-info.log"

if ! mkdir -p -- "$LOG_DIR"; then
    printf 'Error: unable to create log directory: %s\n' "$LOG_DIR" >&2
    exit 1
fi

log_operation() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$1" >> "$LOG_FILE"
}

read_os_name() {
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        printf '%s' "${PRETTY_NAME:-${NAME:-Unknown Linux distribution}}"
    else
        printf 'Unknown Linux distribution'
    fi
}

read_cpu_info() {
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | awk -F: '
            /^Model name:/ {sub(/^[[:space:]]+/, "", $2); model=$2}
            /^CPU\(s\):/ {sub(/^[[:space:]]+/, "", $2); count=$2}
            END {
                if (model != "") printf "Model: %s", model
                if (count != "") printf "%sLogical CPUs: %s", (model != "" ? ", " : ""), count
                if (model == "" && count == "") printf "Unavailable"
            }
        '
    elif [[ -r /proc/cpuinfo ]]; then
        awk -F: '/^model name[[:space:]]*:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo
    else
        printf 'Unavailable'
    fi
}

read_memory_info() {
    if [[ -r /proc/meminfo ]]; then
        awk '
            /^MemTotal:/ {total=$2}
            /^MemAvailable:/ {available=$2}
            END {
                if (total != "") {
                    printf "Total: %.1f GiB", total / 1048576
                    if (available != "") printf ", Available: %.1f GiB", available / 1048576
                } else {
                    printf "Unavailable"
                }
            }
        ' /proc/meminfo
    else
        printf 'Unavailable'
    fi
}

log_operation 'Collected runtime system information'
printf 'Hostname: %s\n' "$(hostname 2>/dev/null || printf 'Unavailable')"
printf 'Current user: %s\n' "$(id -un 2>/dev/null || printf 'Unavailable')"
printf 'Date/time: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'Operating system: %s\n' "$(read_os_name)"
printf 'Kernel version: %s\n' "$(uname -r 2>/dev/null || printf 'Unavailable')"
printf 'Uptime: %s\n' "$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'Unavailable')"
printf 'CPU information: %s\n' "$(read_cpu_info)"
printf 'Memory information: %s\n' "$(read_memory_info)"
printf 'Current working directory: %s\n' "$PWD"
