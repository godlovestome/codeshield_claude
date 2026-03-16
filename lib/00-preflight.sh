#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 0: Environment Pre-flight Checks
# Sourced by install.sh -- do not execute directly.

info "Running environment pre-flight checks ..."

PREFLIGHT_FAIL=0

###############################################################################
# Locale check -- ensure UTF-8 is available
###############################################################################
check_locale() {
    if locale -a 2>/dev/null | grep -qi 'en_US\.utf-\?8'; then
        ok "Locale: en_US.UTF-8 available."
    elif locale -a 2>/dev/null | grep -qi 'C\.utf-\?8'; then
        ok "Locale: C.UTF-8 available (fallback)."
    else
        warn "No UTF-8 locale found. Attempting to generate en_US.UTF-8 ..."
        if command -v locale-gen &>/dev/null; then
            locale-gen en_US.UTF-8 2>/dev/null || true
            if locale -a 2>/dev/null | grep -qi 'en_US\.utf-\?8'; then
                ok "Locale: en_US.UTF-8 generated successfully."
            else
                warn "Could not generate en_US.UTF-8. Using C.UTF-8 fallback."
                export LC_ALL=C.UTF-8 LANG=C.UTF-8
            fi
        else
            warn "locale-gen not found. Install 'locales' package for full UTF-8 support."
            warn "Continuing with C.UTF-8 fallback."
            export LC_ALL=C.UTF-8 LANG=C.UTF-8
        fi
    fi
}

check_locale

###############################################################################
# Command checks
###############################################################################
check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        fail "Required command not found: $1"
        PREFLIGHT_FAIL=1
    else
        ok "Found: $1"
    fi
}

# Required commands
REQUIRED_CMDS=(curl systemctl ufw docker openssl python3 jq)
MISSING_CMDS=()

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_CMDS+=("$cmd")
        fail "Required command not found: $cmd"
        PREFLIGHT_FAIL=1
    else
        ok "Found: $cmd"
    fi
done

# Try to install all missing required commands at once
if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
    info "Attempting to install missing commands: ${MISSING_CMDS[*]} ..."
    apt-get update -qq 2>/dev/null && apt-get install -y -qq "${MISSING_CMDS[@]}" 2>/dev/null && {
        ok "Installed missing commands."
        PREFLIGHT_FAIL=0
    } || {
        fail "Could not auto-install missing commands."
        fail "Please install manually: apt-get install ${MISSING_CMDS[*]}"
    }
fi

# Optional but recommended
for opt_cmd in fail2ban-client squid auditctl zerotier-cli; do
    if ! command -v "$opt_cmd" &>/dev/null; then
        warn "Optional command not found: $opt_cmd (will be installed if needed)"
    fi
done

###############################################################################
# Network connectivity check
###############################################################################
check_network() {
    info "Checking network connectivity ..."
    if curl -fsSL --max-time 10 "https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh" -o /dev/null 2>/dev/null; then
        ok "Network: GitHub raw accessible."
    else
        warn "Cannot reach GitHub raw. If using local clone, this is OK."
    fi
    if nslookup github.com &>/dev/null 2>&1 || host github.com &>/dev/null 2>&1; then
        ok "DNS resolution working."
    else
        warn "DNS resolution may not be working. Check /etc/resolv.conf."
    fi
}

check_network

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
