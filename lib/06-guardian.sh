#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 6: Guardian Service (Update Compatibility)
# Sourced by install.sh -- do not execute directly.

info "Installing CODE SHIELD Guardian service ..."

GUARDIAN_SCRIPT="$CS_SBIN_DIR/openclaw-guardian"
GUARDIAN_PATH_UNIT="/etc/systemd/system/codeshield-guardian.path"
GUARDIAN_SVC_UNIT="/etc/systemd/system/codeshield-guardian.service"

###############################################################################
# 1. Install guardian script
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    cp "$CS_LIB_DIR/openclaw-guardian" "$GUARDIAN_SCRIPT"
    chmod 0755 "$GUARDIAN_SCRIPT"
    ok "Guardian script installed: $GUARDIAN_SCRIPT"
fi

###############################################################################
# 2. systemd path unit -- monitors openclaw package.json changes
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    cat > "$GUARDIAN_PATH_UNIT" << 'EOF'
[Unit]
Description=CODE SHIELD V3 - Monitor OpenClaw updates
Documentation=https://github.com/godlovestome/codeshield_claude

[Path]
# Primary: openclaw npm package
PathChanged=/home/openclaw/.npm-global/lib/node_modules/openclaw/package.json
# Fallback: openclaw config directory
PathChanged=/home/openclaw/.openclaw/openclaw.json

[Install]
WantedBy=multi-user.target
EOF

    cat > "$GUARDIAN_SVC_UNIT" << EOF
[Unit]
Description=CODE SHIELD V3 - Re-apply protection after OpenClaw update
After=network.target

[Service]
Type=oneshot
ExecStart=$GUARDIAN_SCRIPT
StandardOutput=append:$CS_LOG_DIR/guardian.log
StandardError=append:$CS_LOG_DIR/guardian.log
# Give openclaw time to finish its update before we intervene
ExecStartPre=/bin/sleep 5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable codeshield-guardian.path --now 2>/dev/null || true
    ok "Guardian path unit enabled: watches openclaw package.json"
fi

###############################################################################
# 3. Audit timer (periodic full security check)
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    cat > /etc/systemd/system/codeshield-audit.service << EOF
[Unit]
Description=CODE SHIELD V3 - Periodic Security Audit
After=network.target

[Service]
Type=oneshot
ExecStart=$CS_SBIN_DIR/security-audit.sh --quiet
StandardOutput=append:$CS_LOG_DIR/audit.log
StandardError=append:$CS_LOG_DIR/audit.log
EOF

    cat > /etc/systemd/system/codeshield-audit.timer << 'EOF'
[Unit]
Description=CODE SHIELD V3 - Daily Security Audit

[Timer]
OnCalendar=*-*-* 06:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable codeshield-audit.timer --now 2>/dev/null || true
    ok "Audit timer installed (daily at 06:00)."
fi

###############################################################################
# 4. Save installation metadata
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    cat > "$CS_DATA_DIR/install-meta.json" << EOF
{
    "version": "$CS_VERSION",
    "installed": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)"
}
EOF
    ok "Installation metadata saved."
fi

ok "Guardian service installation complete."
