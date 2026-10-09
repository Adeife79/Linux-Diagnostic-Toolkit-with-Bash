# Linux Diagnostic Toolkit

A small Bash toolkit for collecting system details, checking filesystem usage,
and testing basic network connectivity on Linux.

## Requirements

- Bash
- Standard Linux utilities such as `date`, `df`, `getent`, and `ping`
- Optional: `ip` (or `ifconfig`) for network interface details, and `timeout`
  to bound DNS and TCP checks

## Usage

Run the scripts from this directory:

```bash
./system-info.sh
./disk-check.sh 80
./disk-check.sh 90 /home
./network-check.sh example.com
./network-check.sh example.com 443
./grade.sh
```

`disk-check.sh` checks `/` when no path is given. Its threshold must be an
integer from 1 through 100. It exits with status 0 below the threshold, status
1 when usage reaches or exceeds it, and status 2 for invalid arguments or an
unreadable path.

`network-check.sh` accepts a hostname or IP address and an optional TCP port
from 1 through 65535. A failed resolution or connectivity check returns a
non-zero status. ICMP checks may be blocked by the local network or firewall.

## Logs

Each diagnostic script appends timestamped operation entries to its own log
file in `logs/`. The logs are created automatically when the scripts run.
