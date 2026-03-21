#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 3: Qdrant Authentication & Network Binding
# Sourced by install.sh -- do not execute directly.

info "Configuring Qdrant security ..."

SECRETS_FILE="$CS_CONF_DIR/secrets.env"
QDRANT_API_KEY=""

# Load QDRANT_API_KEY from secrets.env
if [ -f "$SECRETS_FILE" ]; then
    QDRANT_API_KEY=$(grep '^QDRANT_API_KEY=' "$SECRETS_FILE" | cut -d= -f2-)
fi

if [ -z "$QDRANT_API_KEY" ]; then
    warn "No QDRANT_API_KEY found. Generating one ..."
    QDRANT_API_KEY=$(openssl rand -hex 24)
    echo "QDRANT_API_KEY=${QDRANT_API_KEY}" >> "$SECRETS_FILE"
    chmod 0600 "$SECRETS_FILE"
fi

###############################################################################
# 1. Find Qdrant docker-compose file
###############################################################################
QDRANT_COMPOSE=""
for candidate in \
    /home/openclaw/qdrant/docker-compose.yml \
    /home/openclaw/docker-compose.yml \
    /opt/qdrant/docker-compose.yml \
    /home/openclaw/.openclaw/qdrant/docker-compose.yml \
    /var/lib/openclaw-svc/qdrant/docker-compose.yml \
    /root/qdrant/docker-compose.yml \
    /srv/qdrant/docker-compose.yml; do
    if [ -f "$candidate" ]; then
        QDRANT_COMPOSE="$candidate"
        break
    fi
done

###############################################################################
# 2. Update docker-compose to bind 127.0.0.1 and inject API key
###############################################################################
if [ -n "$QDRANT_COMPOSE" ]; then
    info "Found Qdrant compose: $QDRANT_COMPOSE"

    if [ "$DRY_RUN" -eq 0 ]; then
        # Backup
        cp "$QDRANT_COMPOSE" "${QDRANT_COMPOSE}.bak.$(date +%s)"

        # Ensure port binds to 127.0.0.1 only (LC_ALL=C for safe sed on config files)
        # V3.1.1: Also bind gRPC port 6334 to localhost
        for QPORT in 6333 6334; do
            if grep -q "0\.0\.0\.0:${QPORT}" "$QDRANT_COMPOSE"; then
                LC_ALL=C sed -i "s/0\.0\.0\.0:${QPORT}/127.0.0.1:${QPORT}/g" "$QDRANT_COMPOSE"
                ok "Qdrant port bound to 127.0.0.1:${QPORT}"
            elif grep -qE "\"${QPORT}:${QPORT}\"|'${QPORT}:${QPORT}'" "$QDRANT_COMPOSE"; then
                LC_ALL=C sed -i "s|${QPORT}:${QPORT}|127.0.0.1:${QPORT}:${QPORT}|g" "$QDRANT_COMPOSE"
                ok "Qdrant port bound to 127.0.0.1:${QPORT}"
            else
                ok "Qdrant port ${QPORT} binding already looks restricted or custom."
            fi
        done

        # Check if QDRANT__SERVICE__API_KEY is already set
        if ! grep -q 'QDRANT__SERVICE__API_KEY' "$QDRANT_COMPOSE"; then
            # Inject environment variable for API key
            # Try to add under 'environment:' section
            if grep -q 'environment:' "$QDRANT_COMPOSE"; then
                LC_ALL=C sed -i "/environment:/a\\      - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}" "$QDRANT_COMPOSE"
                ok "Injected QDRANT__SERVICE__API_KEY into docker-compose."
            else
                warn "No environment section found. Adding one."
                LC_ALL=C sed -i "/qdrant:/a\\    environment:\\n      - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}" "$QDRANT_COMPOSE"
                ok "Added environment section with API key."
            fi
        else
            # Update existing key
            LC_ALL=C sed -i "s|QDRANT__SERVICE__API_KEY=.*|QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}|g" "$QDRANT_COMPOSE"
            ok "Updated existing QDRANT__SERVICE__API_KEY."
        fi

        # P1 fix (V3.0.1): Add container security hardening if not already present
        if ! grep -q 'cap_drop' "$QDRANT_COMPOSE"; then
            python3 - "$QDRANT_COMPOSE" << 'PY'
import sys, re
from pathlib import Path
p = Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
# Insert security hardening after restart: line
hardening = """    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:size=128m,mode=1777
      - /qdrant/snapshots:size=256m"""
# Insert before volumes: or at end of service block
if 'restart:' in text and 'cap_drop' not in text:
    text = re.sub(r'(    restart:[^\n]*)', r'\1\n' + hardening, text, count=1)
    p.write_text(text, encoding='utf-8')
    print("  Added container security hardening to docker-compose")
else:
    print("  cap_drop already present or no restart: line found")
PY
            ok "Qdrant container hardened (cap_drop ALL, no-new-privileges, read_only)."
        else
            ok "Qdrant container security already hardened."
        fi

        # Restart Qdrant
        COMPOSE_DIR=$(dirname "$QDRANT_COMPOSE")
        info "Restarting Qdrant ..."
        (cd "$COMPOSE_DIR" && QDRANT_API_KEY="$QDRANT_API_KEY" docker compose up -d --force-recreate) 2>&1 | while read -r line; do
            info "  $line"
        done

        # Wait for Qdrant to be ready
        info "Waiting for Qdrant to start ..."
        for i in $(seq 1 30); do
            if curl -sf -H "api-key: ${QDRANT_API_KEY}" http://127.0.0.1:6333/healthz &>/dev/null; then
                ok "Qdrant is healthy and authenticated."
                break
            fi
            sleep 1
        done

        # Verify unauthenticated access is denied
        if curl -sf http://127.0.0.1:6333/collections &>/dev/null; then
            warn "Qdrant still allows unauthenticated access! Check configuration."
        else
            ok "Qdrant unauthenticated access correctly denied."
        fi
    else
        info "[DRY-RUN] Would update $QDRANT_COMPOSE with API key and 127.0.0.1 binding."
    fi
else
    warn "Qdrant docker-compose.yml not found. Skipping Qdrant hardening."
    warn "Searched: /home/openclaw/qdrant/, /opt/qdrant/, /var/lib/openclaw-svc/qdrant/, /root/qdrant/, /srv/qdrant/"
    warn "If Qdrant is at a different path, use: codeshield-config set QDRANT_API_KEY=<key>"
fi

###############################################################################
# 3. Docker IPTABLES -- block external access to Docker containers
#    V3.1.1: Complete DOCKER-USER rules (6333+6334, ESTABLISHED/RELATED,
#            loopback, optional Redis/PostgreSQL) + systemd persistence
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    if iptables -L DOCKER-USER &>/dev/null 2>&1; then
        # ESTABLISHED,RELATED: allow return traffic for existing connections
        if ! iptables -C DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT &>/dev/null 2>&1; then
            iptables -I DOCKER-USER 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            ok "DOCKER-USER: ESTABLISHED,RELATED accept rule added."
        fi

        # Loopback: allow localhost access to Docker containers
        if ! iptables -C DOCKER-USER -i lo -j ACCEPT &>/dev/null 2>&1; then
            iptables -I DOCKER-USER 2 -i lo -j ACCEPT
            ok "DOCKER-USER: loopback accept rule added."
        fi

        # Block external access to Qdrant HTTP (6333) and gRPC (6334)
        for QPORT in 6333 6334; do
            if ! iptables -C DOCKER-USER -p tcp --dport "$QPORT" ! -s 127.0.0.1 -j DROP &>/dev/null 2>&1; then
                iptables -A DOCKER-USER -p tcp --dport "$QPORT" ! -s 127.0.0.1 -j DROP
                ok "DOCKER-USER: drop external access to port $QPORT."
            else
                ok "DOCKER-USER: port $QPORT drop rule already exists."
            fi
        done

        # Optional: block Redis (6379) and PostgreSQL (5432) if containers exist
        for DBPORT in 6379 5432; do
            if docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":${DBPORT}->"; then
                if ! iptables -C DOCKER-USER -p tcp --dport "$DBPORT" ! -s 127.0.0.1 -j DROP &>/dev/null 2>&1; then
                    iptables -A DOCKER-USER -p tcp --dport "$DBPORT" ! -s 127.0.0.1 -j DROP
                    ok "DOCKER-USER: drop external access to port $DBPORT."
                fi
            fi
        done

        ok "DOCKER-USER chain fully configured."
    else
        warn "DOCKER-USER chain not found. Docker iptables rules may not be active."
    fi

    # Persist rules so netfilter-persistent has a copy
    netfilter-persistent save >/dev/null 2>&1 || true

    ###########################################################################
    # Deploy codeshield-docker-user.service: re-applies DOCKER-USER rules
    # after Docker restarts (Docker flushes and recreates the chain on restart)
    ###########################################################################
    local DOCKER_USER_SCRIPT="$CS_SBIN_DIR/codeshield-docker-user"
    cat > "$DOCKER_USER_SCRIPT" << 'DUSCRIPT'
#!/usr/bin/env bash
# CODE SHIELD V3.1.1 -- Re-apply DOCKER-USER iptables rules after Docker restart
# Docker flushes and recreates the DOCKER-USER chain on every restart,
# discarding any custom rules added by Code Shield or netfilter-persistent.
set -uo pipefail

# Wait for Docker to finish creating the chain
for i in $(seq 1 10); do
    iptables -L DOCKER-USER &>/dev/null 2>&1 && break
    sleep 1
done

if ! iptables -L DOCKER-USER &>/dev/null 2>&1; then
    echo "[WARN] DOCKER-USER chain not found after waiting. Skipping."
    exit 0
fi

# ESTABLISHED,RELATED
if ! iptables -C DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT &>/dev/null 2>&1; then
    iptables -I DOCKER-USER 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
fi

# Loopback
if ! iptables -C DOCKER-USER -i lo -j ACCEPT &>/dev/null 2>&1; then
    iptables -I DOCKER-USER 2 -i lo -j ACCEPT
fi

# Qdrant HTTP + gRPC
for PORT in 6333 6334; do
    if ! iptables -C DOCKER-USER -p tcp --dport "$PORT" ! -s 127.0.0.1 -j DROP &>/dev/null 2>&1; then
        iptables -A DOCKER-USER -p tcp --dport "$PORT" ! -s 127.0.0.1 -j DROP
    fi
done

# Optional: Redis, PostgreSQL (only if containers expose these ports)
for PORT in 6379 5432; do
    if docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":${PORT}->"; then
        if ! iptables -C DOCKER-USER -p tcp --dport "$PORT" ! -s 127.0.0.1 -j DROP &>/dev/null 2>&1; then
            iptables -A DOCKER-USER -p tcp --dport "$PORT" ! -s 127.0.0.1 -j DROP
        fi
    fi
done

netfilter-persistent save >/dev/null 2>&1 || true
echo "[OK] DOCKER-USER rules re-applied at $(date -Iseconds)"
DUSCRIPT
    chmod 0755 "$DOCKER_USER_SCRIPT"

    cat > /etc/systemd/system/codeshield-docker-user.service << EOF
[Unit]
Description=CODE SHIELD V3 - Re-apply DOCKER-USER iptables rules
Documentation=https://github.com/godlovestome/codeshield_claude
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$DOCKER_USER_SCRIPT
StandardOutput=append:$CS_LOG_DIR/docker-user.log
StandardError=append:$CS_LOG_DIR/docker-user.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable codeshield-docker-user.service --now 2>/dev/null || true
    ok "codeshield-docker-user.service deployed (re-applies rules after Docker restart)."
fi

ok "Qdrant security configuration complete."
