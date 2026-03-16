#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 4: SSH / UFW / fail2ban / systemd Hardening
# Sourced by install.sh -- do not execute directly.

info "Applying system hardening ..."

###############################################################################
# 1. SSH Hardening
###############################################################################
SSHD_CONFIG="/etc/ssh/sshd_config"

harden_ssh() {
    if [ ! -f "$SSHD_CONFIG" ]; then
        warn "sshd_config not found. Skipping SSH hardening."
        return
    fi

    # Backup
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.codeshield.$(date +%s)"

    # Settings to enforce
    declare -A SSH_SETTINGS=(
        ["PasswordAuthentication"]="no"
        ["KbdInteractiveAuthentication"]="no"
        ["ChallengeResponseAuthentication"]="no"
        ["MaxAuthTries"]="3"
        ["PermitRootLogin"]="prohibit-password"
        ["X11Forwarding"]="no"
        ["AllowAgentForwarding"]="no"
        ["AllowTcpForwarding"]="no"
        ["MaxSessions"]="3"
        ["ClientAliveInterval"]="300"
        ["ClientAliveCountMax"]="2"
        ["LoginGraceTime"]="30"
    )

    for key in "${!SSH_SETTINGS[@]}"; do
        local val="${SSH_SETTINGS[$key]}"
        if grep -qE "^\s*${key}\s+" "$SSHD_CONFIG"; then
            sed -i "s|^\s*${key}\s.*|${key} ${val}|" "$SSHD_CONFIG"
        elif grep -qE "^\s*#\s*${key}\s+" "$SSHD_CONFIG"; then
            sed -i "s|^\s*#\s*${key}\s.*|${key} ${val}|" "$SSHD_CONFIG"
        else
            echo "${key} ${val}" >> "$SSHD_CONFIG"
        fi
    done

    # Validate and reload
    if sshd -t 2>/dev/null; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
        ok "SSH hardened and reloaded."
    else
        warn "sshd_config validation failed. Restoring backup."
        cp "${SSHD_CONFIG}.bak.codeshield."* "$SSHD_CONFIG" 2>/dev/null || true
    fi
}

if [ "$DRY_RUN" -eq 0 ]; then
    harden_ssh
else
    info "[DRY-RUN] Would harden SSH configuration."
fi

###############################################################################
# 2. UFW Firewall
###############################################################################
setup_ufw() {
    if ! command -v ufw &>/dev/null; then
        info "Installing ufw ..."
        apt-get update -qq && apt-get install -y -qq ufw
    fi

    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH (prevent lockout)
    ufw allow ssh

    # Allow ZeroTier if interface exists
    if ip link show zt+ &>/dev/null 2>&1; then
        ufw allow in on zt+
        ok "UFW: allowed ZeroTier interface."
    fi

    # Enable if not already
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable
    fi
    ok "UFW configured: default deny incoming."
}

if [ "$DRY_RUN" -eq 0 ]; then
    setup_ufw
else
    info "[DRY-RUN] Would configure UFW."
fi

###############################################################################
# 3. Disable IPv6
###############################################################################
disable_ipv6() {
    local SYSCTL_CONF="/etc/sysctl.d/99-codeshield-ipv6.conf"
    cat > "$SYSCTL_CONF" << 'EOF'
# CODE SHIELD V3 -- Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system &>/dev/null
    ok "IPv6 disabled."
}

if [ "$DRY_RUN" -eq 0 ]; then
    disable_ipv6
else
    info "[DRY-RUN] Would disable IPv6."
fi

###############################################################################
# 4. fail2ban
###############################################################################
setup_fail2ban() {
    if ! command -v fail2ban-client &>/dev/null; then
        info "Installing fail2ban ..."
        apt-get update -qq && apt-get install -y -qq fail2ban
    fi

    cat > /etc/fail2ban/jail.d/codeshield-sshd.conf << 'EOF'
# CODE SHIELD V3 -- SSH brute-force protection
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
findtime = 600
EOF

    systemctl enable fail2ban --now 2>/dev/null || true
    systemctl restart fail2ban 2>/dev/null || true
    ok "fail2ban configured for SSH."
}

if [ "$DRY_RUN" -eq 0 ]; then
    setup_fail2ban
else
    info "[DRY-RUN] Would configure fail2ban."
fi

###############################################################################
# 5. Squid Outbound Proxy
###############################################################################
setup_squid() {
    if ! command -v squid &>/dev/null; then
        info "Installing squid ..."
        apt-get update -qq && apt-get install -y -qq squid
    fi

    # Deploy template config
    local SQUID_TEMPLATE="$CS_LIB_DIR/squid.conf"
    if [ -f "$SQUID_TEMPLATE" ]; then
        cp /etc/squid/squid.conf "/etc/squid/squid.conf.bak.$(date +%s)" 2>/dev/null || true
        cp "$SQUID_TEMPLATE" /etc/squid/squid.conf
        ok "Squid config deployed from template."
    fi

    # Deploy injection guard script
    local GUARD_SCRIPT="/usr/local/sbin/squid-injection-guard.py"
    if [ -f "$CS_LIB_DIR/squid-injection-guard.py" ]; then
        cp "$CS_LIB_DIR/squid-injection-guard.py" "$GUARD_SCRIPT"
        chmod 0755 "$GUARD_SCRIPT"
    fi

    systemctl enable squid --now 2>/dev/null || true
    systemctl restart squid 2>/dev/null || true
    ok "Squid proxy configured."
}

if [ "$DRY_RUN" -eq 0 ]; then
    setup_squid
else
    info "[DRY-RUN] Would configure Squid."
fi

###############################################################################
# 6. Force Proxy + DNS Exfiltration Block (V3.0.1: comprehensive non-loopback block)
#
# V3.0.1 replaces individual port-specific rules with ONE rule:
#   Block ALL non-loopback outbound from openclaw-svc.
# Effect:
#   - DNS tunneling prevented (external DNS blocked)
#   - Forced proxy: agent MUST use squid at 127.0.0.1:3128
#   - Watcher can still reach Qdrant at 127.0.0.1:6333 (loopback allowed)
#   - Ollama at 127.0.0.1:11434 still reachable (loopback)
###############################################################################
block_external_outbound() {
    local SVC_UID
    SVC_UID=$(id -u openclaw-svc 2>/dev/null || echo "")
    if [ -z "$SVC_UID" ]; then
        warn "openclaw-svc uid not found. Skipping outbound block."
        return
    fi

    # Remove any legacy specific-port rules if present
    for PORT in 53 6333 6334 6379 5432 27017 18789; do
        iptables -D OUTPUT -p udp -m owner --uid-owner "$SVC_UID" \
            -m udp --dport "$PORT" -j DROP 2>/dev/null || true
        iptables -D OUTPUT -p tcp -m owner --uid-owner "$SVC_UID" \
            -m tcp --dport "$PORT" -j DROP 2>/dev/null || true
        iptables -D OUTPUT -d 127.0.0.1/32 -p tcp -m owner \
            --uid-owner "$SVC_UID" -m tcp --dport "$PORT" -j DROP 2>/dev/null || true
    done

    # Add comprehensive rule: block all non-loopback outbound from openclaw-svc
    if ! iptables -S OUTPUT | grep -q "uid-owner.*${SVC_UID}.*DROP"; then
        iptables -A OUTPUT -m owner --uid-owner "$SVC_UID" ! -d 127.0.0.0/8 -j DROP
    fi

    netfilter-persistent save >/dev/null 2>&1 || true
    ok "All external outbound blocked for openclaw-svc (uid=$SVC_UID). Loopback allowed."
    ok "Force proxy: agent must use squid at 127.0.0.1:3128 for external access."
}

if [ "$DRY_RUN" -eq 0 ]; then
    block_external_outbound
else
    info "[DRY-RUN] Would block all external outbound from openclaw-svc."
fi

###############################################################################
# 6b. systemd Sandbox Hardening (V3.0.1: P3 fix)
#     ProtectSystem=strict, ProtectHome, CapabilityBoundingSet=, etc.
###############################################################################
setup_systemd_sandbox() {
    local DROPIN_DIR="/etc/systemd/system/openclaw.service.d"
    local WATCHER_DROPIN_DIR="/etc/systemd/system/mem-qdrant-watcher.service.d"
    mkdir -p "$DROPIN_DIR" "$WATCHER_DROPIN_DIR"

    cat > "$DROPIN_DIR/codeshield-sandbox.conf" << 'EOF'
[Service]
# CODE SHIELD V3.0.1 — systemd sandbox hardening
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/openclaw-svc /var/log/openclaw-codeshield
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
CapabilityBoundingSet=
EOF

    cat > "$WATCHER_DROPIN_DIR/codeshield-sandbox.conf" << 'EOF'
[Service]
# CODE SHIELD V3.0.1 — systemd sandbox hardening
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/openclaw-svc /var/log/openclaw-codeshield /usr/local/lib/openclaw-codeshield
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
CapabilityBoundingSet=
EOF

    systemctl daemon-reload
    ok "systemd sandbox hardening applied (ProtectSystem=strict, CapabilityBoundingSet=, etc.)."
}

if [ "$DRY_RUN" -eq 0 ]; then
    setup_systemd_sandbox
else
    info "[DRY-RUN] Would add systemd sandbox drop-ins."
fi

###############################################################################
# 7. auditd Rules
###############################################################################
setup_auditd() {
    if ! command -v auditctl &>/dev/null; then
        info "Installing auditd ..."
        apt-get update -qq && apt-get install -y -qq auditd
    fi

    local AUDIT_RULES="/etc/audit/rules.d/codeshield.rules"
    cat > "$AUDIT_RULES" << 'EOF'
# CODE SHIELD V3 -- Audit rules
# Monitor secrets file
-w /etc/openclaw-codeshield/secrets.env -p rwa -k codeshield_secrets
# Monitor openclaw configuration
-w /home/openclaw/.openclaw/ -p rwa -k openclaw_config
# Monitor systemd drop-in
-w /etc/systemd/system/openclaw.service.d/ -p rwa -k openclaw_dropin
# Monitor SSH config
-w /etc/ssh/sshd_config -p rwa -k ssh_config
# Monitor sudoers
-w /etc/sudoers.d/ -p rwa -k sudoers
# Monitor squid config
-w /etc/squid/squid.conf -p rwa -k squid_config
EOF

    systemctl enable auditd --now 2>/dev/null || true
    augenrules --load 2>/dev/null || auditctl -R "$AUDIT_RULES" 2>/dev/null || true
    ok "auditd rules installed."
}

if [ "$DRY_RUN" -eq 0 ]; then
    setup_auditd
else
    info "[DRY-RUN] Would configure auditd."
fi

###############################################################################
# 8. Docker Daemon Hardening
###############################################################################
harden_docker() {
    local DAEMON_JSON="/etc/docker/daemon.json"
    if [ ! -f "$DAEMON_JSON" ]; then
        mkdir -p /etc/docker
        echo '{}' > "$DAEMON_JSON"
    fi

    local tmp
    tmp=$(jq '. + {
        "icc": false,
        "no-new-privileges": true,
        "log-driver": "json-file",
        "log-opts": {"max-size": "10m", "max-file": "3"},
        "live-restore": true
    }' "$DAEMON_JSON" 2>/dev/null || echo '{}')

    if [ "$tmp" != '{}' ]; then
        echo "$tmp" > "$DAEMON_JSON"
        ok "Docker daemon hardened."
    else
        warn "Could not parse daemon.json. Skipping Docker hardening."
    fi
}

if [ "$DRY_RUN" -eq 0 ]; then
    harden_docker
else
    info "[DRY-RUN] Would harden Docker daemon."
fi

ok "System hardening complete."
