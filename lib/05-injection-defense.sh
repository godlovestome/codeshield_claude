#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 5: Prompt Injection Defense
# Sourced by install.sh -- do not execute directly.

info "Configuring prompt injection defenses ..."

OPENCLAW_HOME="/home/openclaw"
OPENCLAW_SVC_HOME="/var/lib/openclaw-svc"
OPENCLAW_DIR="$OPENCLAW_HOME/.openclaw"
SVC_OPENCLAW_DIR="$OPENCLAW_SVC_HOME/.openclaw"

###############################################################################
# 1. Skills Freeze Policy
###############################################################################
deploy_skills_policy() {
    local POLICY_SRC="$CS_LIB_DIR/skills-policy.json"
    local TARGETS=(
        "$OPENCLAW_DIR/skills-policy.json"
        "$SVC_OPENCLAW_DIR/skills-policy.json"
    )

    if [ ! -f "$POLICY_SRC" ]; then
        warn "skills-policy.json template not found in lib."
        return
    fi

    for target in "${TARGETS[@]}"; do
        local dir
        dir=$(dirname "$target")
        mkdir -p "$dir"
        cp "$POLICY_SRC" "$target"
        ok "Skills policy deployed: $target"
    done
}

###############################################################################
# 2. SOUL.md Canary Token + Injection Resistance
###############################################################################
deploy_soul_protection() {
    local SOUL_INJECTION="$CS_LIB_DIR/soul-injection.md"
    local CANARY="CODESHIELD-CANARY-$(openssl rand -hex 16)"

    if [ ! -f "$SOUL_INJECTION" ]; then
        warn "soul-injection.md template not found."
        return
    fi

    # Store canary for later verification
    echo "$CANARY" > "$CS_DATA_DIR/soul-canary.txt"
    chmod 0600 "$CS_DATA_DIR/soul-canary.txt"

    for soul_dir in "$OPENCLAW_DIR" "$SVC_OPENCLAW_DIR"; do
        local soul_file="$soul_dir/SOUL.md"
        mkdir -p "$soul_dir"

        if [ -f "$soul_file" ]; then
            # Check if injection defense is already present
            if grep -q 'CODESHIELD-CANARY' "$soul_file"; then
                ok "SOUL.md at $soul_file already has canary token."
            else
                # Append injection defense section
                printf "\n\n" >> "$soul_file"
                sed "s/{{CANARY}}/$CANARY/g" "$SOUL_INJECTION" >> "$soul_file"
                ok "Appended injection defense to $soul_file"
            fi
        else
            # Create minimal SOUL.md with injection defense
            sed "s/{{CANARY}}/$CANARY/g" "$SOUL_INJECTION" > "$soul_file"
            ok "Created SOUL.md with injection defense at $soul_file"
        fi
    done
}

###############################################################################
# 3. Skills Baseline Generation
###############################################################################
generate_skills_baseline() {
    local BASELINE_FILE="$CS_DATA_DIR/skills-baseline.json"

    # Find all skill files
    local skills_dir=""
    for candidate in "$OPENCLAW_DIR/skills" "$SVC_OPENCLAW_DIR/skills"; do
        if [ -d "$candidate" ]; then
            skills_dir="$candidate"
            break
        fi
    done

    if [ -z "$skills_dir" ]; then
        warn "No skills directory found. Creating empty baseline."
        echo '{"skills":[],"generated":"'"$(date -Iseconds)"'"}' > "$BASELINE_FILE"
        return
    fi

    # Generate checksums of all skill files
    info "Generating skills baseline from $skills_dir ..."
    local baseline='{"skills":['
    local first=1
    while IFS= read -r -d '' skill_file; do
        local hash
        hash=$(sha256sum "$skill_file" | awk '{print $1}')
        local name
        name=$(basename "$skill_file")
        if [ "$first" -eq 0 ]; then
            baseline+=","
        fi
        baseline+="{\"name\":\"$name\",\"sha256\":\"$hash\"}"
        first=0
    done < <(find "$skills_dir" -type f -print0 2>/dev/null)
    baseline+="],"
    baseline+="\"generated\":\"$(date -Iseconds)\"}"

    echo "$baseline" | jq . > "$BASELINE_FILE" 2>/dev/null || echo "$baseline" > "$BASELINE_FILE"
    ok "Skills baseline saved: $BASELINE_FILE"
}

###############################################################################
# 4. Session Injection Scanner (cron/timer)
###############################################################################
install_injection_scanner() {
    # Copy scanner script
    cp "$CS_LIB_DIR/openclaw-injection-scan" "$CS_SBIN_DIR/openclaw-injection-scan" 2>/dev/null || true
    chmod 0755 "$CS_SBIN_DIR/openclaw-injection-scan"

    # Create systemd timer for periodic scanning
    cat > /etc/systemd/system/codeshield-scan.service << EOF
[Unit]
Description=CODE SHIELD V3 - Session Injection Scanner
After=network.target

[Service]
Type=oneshot
ExecStart=$CS_SBIN_DIR/openclaw-injection-scan
StandardOutput=append:$CS_LOG_DIR/injection-scan.log
StandardError=append:$CS_LOG_DIR/injection-scan.log
EOF

    cat > /etc/systemd/system/codeshield-scan.timer << 'EOF'
[Unit]
Description=CODE SHIELD V3 - Run injection scan every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable codeshield-scan.timer --now 2>/dev/null || true
    ok "Injection scanner timer installed (every 15 minutes)."
}

###############################################################################
# 5. Cost Monitor
###############################################################################
install_cost_monitor() {
    cp "$CS_LIB_DIR/openclaw-cost-monitor" "$CS_SBIN_DIR/openclaw-cost-monitor" 2>/dev/null || true
    chmod 0755 "$CS_SBIN_DIR/openclaw-cost-monitor"
    ok "Cost monitor installed: $CS_SBIN_DIR/openclaw-cost-monitor"
}

###############################################################################
# 6. Emergency Lockdown + Forensics Key
###############################################################################
install_emergency() {
    cp "$CS_LIB_DIR/emergency-lockdown" "$CS_SBIN_DIR/emergency-lockdown" 2>/dev/null || true
    chmod 0755 "$CS_SBIN_DIR/emergency-lockdown"

    # Generate forensics AES key if not exists
    local FORENSICS_KEY="$CS_CONF_DIR/forensics.key"
    if [ ! -f "$FORENSICS_KEY" ]; then
        openssl rand -base64 32 > "$FORENSICS_KEY"
        chmod 0600 "$FORENSICS_KEY"
        chown root:root "$FORENSICS_KEY"
        ok "Forensics AES key generated: $FORENSICS_KEY"
    else
        ok "Forensics key already exists."
    fi

    ok "Emergency lockdown installed: $CS_SBIN_DIR/emergency-lockdown"
}

###############################################################################
# Execute
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    deploy_skills_policy
    deploy_soul_protection
    generate_skills_baseline
    install_injection_scanner
    install_cost_monitor
    install_emergency
else
    info "[DRY-RUN] Would deploy injection defenses."
fi

ok "Prompt injection defense configuration complete."
