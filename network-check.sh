#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/network-check.log"

log_operation() {
    if ! mkdir -p -- "$LOG_DIR"; then
        printf 'Error: unable to create log directory: %s\n' "$LOG_DIR" >&2
        exit 1
    fi
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$1" >> "$LOG_FILE"
}

usage() {
    printf 'Usage: %s <hostname-or-IP> [port 1-65535]\n' "${0##*/}" >&2
}

valid_host_syntax() {
    local host=$1 label

    [[ ${#host} -le 253 ]] || return 1
    if [[ "$host" == *:* ]]; then
        [[ "$host" =~ ^[[:xdigit:]:]+$ ]] && [[ "$host" == *:*:* ]]
        return
    fi

    [[ "$host" =~ ^[[:alnum:].-]+\.?$ ]] || return 1
    [[ "$host" != -* && "$host" != *..* ]] || return 1

    local hostname=${host%.}
    local IFS=.
    read -r -a labels <<< "$hostname"
    for label in "${labels[@]}"; do
        [[ ${#label} -le 63 && "$label" =~ ^[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?$ ]] || return 1
    done
}

if (( $# < 1 || $# > 2 )); then
    usage
    log_operation 'Network check rejected invalid argument count'
    exit 2
fi

host=$1
if ! valid_host_syntax "$host"; then
    usage
    printf 'Error: invalid hostname or IP address: %s\n' "$host" >&2
    log_operation "Network check rejected invalid host syntax: $host"
    exit 2
fi

port=''
if (( $# == 2 )); then
    if [[ ! "$2" =~ ^[0-9]+$ ]]; then
        usage
        printf 'Error: port must be an integer from 1 through 65535.\n' >&2
        log_operation "Network check rejected invalid port: $2"
        exit 2
    fi
    port_normalized=${2#"${2%%[!0]*}"}
    [[ -n "$port_normalized" ]] || port_normalized=0
    if (( ${#port_normalized} > 5 )) || (( port_normalized < 1 || port_normalized > 65535 )); then
        usage
        printf 'Error: port must be an integer from 1 through 65535.\n' >&2
        log_operation "Network check rejected out-of-range port: $2"
        exit 2
    fi
    port=$((10#$port_normalized))
fi

log_operation "Started network check for $host${port:+ on TCP port $port}"

if command -v timeout >/dev/null 2>&1; then
    resolved=$(timeout 5 getent ahosts "$host" 2>/dev/null | awk '!seen[$1]++ {print $1}')
else
    resolved=$(getent ahosts "$host" 2>/dev/null | awk '!seen[$1]++ {print $1}')
fi
if [[ -z "$resolved" ]]; then
    printf 'Error: could not resolve host: %s\n' "$host" >&2
    log_operation "Host resolution failed for $host"
    exit 1
fi

printf 'Host: %s\nResolved address(es):\n' "$host"
while IFS= read -r address; do
    [[ -n "$address" ]] && printf '  %s\n' "$address"
done <<< "$resolved"
log_operation "Resolved $host to: ${resolved//$'\n'/, }"

connectivity_ok=0
if command -v ping >/dev/null 2>&1; then
    first_address=${resolved%%$'\n'*}
    if ping -c 1 -W 2 "$first_address" >/dev/null 2>&1; then
        printf 'Connectivity check: ICMP reachable\n'
        log_operation "ICMP connectivity succeeded for $host ($first_address)"
        connectivity_ok=1
    else
        printf 'Connectivity check: ICMP failed (may be blocked)\n'
        log_operation "ICMP connectivity failed for $host ($first_address)"
    fi
else
    printf 'Connectivity check: ping utility unavailable\n'
    log_operation 'ICMP check skipped because ping is unavailable'
fi

if [[ -n "$port" ]]; then
    if command -v timeout >/dev/null 2>&1; then
        if timeout 5 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null; then
            printf 'TCP port %s: open\n' "$port"
            log_operation "TCP connection succeeded for $host:$port"
            connectivity_ok=1
        else
            printf 'TCP port %s: unavailable\n' "$port"
            log_operation "TCP connection failed for $host:$port"
            tcp_failed=1
        fi
    elif bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null; then
        printf 'TCP port %s: open\n' "$port"
        log_operation "TCP connection succeeded for $host:$port"
        connectivity_ok=1
    else
        printf 'TCP port %s: unavailable\n' "$port"
        log_operation "TCP connection failed for $host:$port"
        tcp_failed=1
    fi
fi

printf 'Network interfaces:\n'
if command -v ip >/dev/null 2>&1; then
    interface_info=$(ip -brief address 2>&1)
elif command -v ifconfig >/dev/null 2>&1; then
    interface_info=$(ifconfig -a 2>&1)
elif [[ -d /sys/class/net ]]; then
    interface_info=$(printf '%s\n' /sys/class/net/* | sed 's#.*/##')
else
    interface_info='Unavailable'
fi
printf '%s\n' "$interface_info"
log_operation 'Displayed network interface information'

if [[ "${tcp_failed:-0}" == 1 ]]; then
    exit 1
fi
if (( connectivity_ok == 0 )); then
    printf 'Warning: no successful connectivity check was completed.\n' >&2
    exit 1
fi
exit 0
