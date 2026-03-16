#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 0: Environment Pre-flight Checks
# Sourced by install.sh -- do not execute directly.

info "Running environment pre-flight checks ..."

PREFLIGHT_FAIL=0

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        fail "Required command not found: $1"
        PREFLIGHT_FAIL=1
    else
        ok "Found: $1"
    fi
}

# Required commands
check_cmd curl
check_cmd systemctl
check_cmd ufw
check_cmd docker
check_cmd openssl
check_cmd python3
check_cmd jq

# Optional but recommended
for opt_cmd in fail2ban-client squid auditctl zerotier-cli; do
    if ! command -v "$opt_cmd" &>/dev/null; then
        warn "Optional command not found: $opt_cmd (will be installed if needed)"
    fi
done

# Check Ubuntu
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    info "OS detected: $PRETTY_NAME"
    if [[ "$ID" != "ubuntu" ]]; then
        warn "This system is not Ubuntu. Some features may not work."
    fi
else
    warn "Cannot detect OS. /etc/os-release not found."
fi

# Check systemd
if ! pidof systemd &>/dev/null; then
    fail "systemd is not running. CODE SHIELD requires systemd."
    PREFLIGHT_FAIL=1
fi

# Check Docker
if ! docker info &>/dev/null 2>&1; then
    warn "Docker daemon is not running or not accessible."
fi

# Check openclaw-svc user
if id "openclaw-svc" &>/dev/null; then
    ok "User openclaw-svc exists."
else
    warn "User openclaw-svc does not exist (will be created in isolation stage)."
fi

# Check openclaw service
if systemctl list-unit-files openclaw.service &>/dev/null 2>&1; then
    ok "openclaw.service found."
else
    warn "openclaw.service not found (may be installed later)."
fi

# Check Qdrant
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q qdrant; then
    ok "Qdrant container is running."
else
    warn "Qdrant container not detected."
fi

# Check disk space (need at least 500MB free)
FREE_MB=$(df / --output=avail -BM 2>/dev/null | tail -1 | tr -d ' M')
if [ -n "$FREE_MB" ] && [ "$FREE_MB" -lt 500 ]; then
    fail "Insufficient disk space: ${FREE_MB}MB free (need 500MB)."
    PREFLIGHT_FAIL=1
else
    ok "Disk space: ${FREE_MB:-unknown}MB free."
fi

# Summary
if [ "$PREFLIGHT_FAIL" -ne 0 ]; then
    fail "Pre-flight checks failed. Fix the issues above and re-run."
    exit 1
fi

ok "All pre-flight checks passed."
