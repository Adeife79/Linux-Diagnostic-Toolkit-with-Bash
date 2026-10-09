#!/usr/bin/env bash
set -u

PASS=0
FAIL=0

pass() {
    echo "PASS:$1"
    PASS=$((PASS+1))
}

fail() {
    echo "FAIL:$1"
    FAIL=$((FAIL+1))
}

echo "======================================"
echo "Assignment1-LocalGrader"
echo "Linux/Bash/Networking/Git"
echo "======================================"

#Required files for final submission
for f in README.md system-info.sh disk-check.sh network-check.sh; do
    [[ -f "$f" ]] && pass "Required file exists: $f" || fail "Missing required file: $f"
done

mkdir -p logs

#Syntax checks for scripts
for f in system-info.sh disk-check.sh network-check.sh; do
    if [[ -f "$f" ]]; then
        bash -n "$f" >/dev/null 2>&1 && pass "Bash syntax: $f" || fail "Bash syntax error: $f"
    fi
done

#Executable checks for scripts
for f in system-info.sh disk-check.sh network-check.sh; do
    if [[ -f "$f" && -x "$f" ]]; then
        pass "Executable: $f"
    else
        fail "Not executable: $f"
    fi
done

#system-info.sh validation
if [[ -x ./system-info.sh ]]; then
    output=$(./system-info.sh 2>&1)
    rc=$?
    [[ $rc -eq 0 ]] && pass "system-info.sh exits successfully" || fail "system-info.sh exit code is $rc"

    for term in "hostname" "user" "kernel" "uptime"; do
        echo "$output" | grep -qi "$term" && \
            pass "system-info.sh contains '$term' information" || \
            fail "system-info.sh does not appear to contain '$term' information"
    done
fi

#disk-check.sh argument validation
if [[ -x ./disk-check.sh ]]; then
    ./disk-check.sh 0 >/dev/null 2>&1; rc=$?
    [[ $rc -eq 2 ]] && pass "disk-check rejects threshold 0 with exit code 2" || fail "disk-check should reject threshold 0 with exit code 2 (got $rc)"

    ./disk-check.sh 101 >/dev/null 2>&1; rc=$?
    [[ $rc -eq 2 ]] && pass "disk-check rejects threshold 101 with exit code 2" || fail "disk-check should reject threshold 101 with exit code 2 (got $rc)"

    ./disk-check.sh abc >/dev/null 2>&1; rc=$?
    [[ $rc -eq 2 ]] && pass "disk-check rejects non-numeric threshold" || fail "disk-check should reject non-numeric threshold (got $rc)"

    ./disk-check.sh 100 >/dev/null 2>&1; rc=$?
    [[ $rc -eq 0 || $rc -eq 1 ]] && pass "disk-check accepts valid threshold/path" || fail "disk-check failed valid input"
fi

#network-check.sh validation

if [[ -x ./network-check.sh ]]; then
    ./network-check.sh >/dev/null 2>&1; rc=$?
    [[ $rc -eq 2 ]] && pass "network-check rejects missing host" \
                    || fail "network-check should reject missing host with exit code 2 (got $rc)"
fi