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
        if grep -q '0\.0\.0\.0:6333' "$QDRANT_COMPOSE"; then
            LC_ALL=C sed -i 's/0\.0\.0\.0:6333/127.0.0.1:6333/g' "$QDRANT_COMPOSE"
            ok "Qdrant port bound to 127.0.0.1:6333"
        elif grep -q '"6333:6333"' "$QDRANT_COMPOSE" || grep -q "'6333:6333'" "$QDRANT_COMPOSE"; then
            LC_ALL=C sed -i "s|6333:6333|127.0.0.1:6333:6333|g" "$QDRANT_COMPOSE"
            ok "Qdrant port bound to 127.0.0.1:6333"
        else
            ok "Qdrant port binding already looks restricted or custom."
        fi

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
# 3. Docker IPTABLES -- block external access to Qdrant
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    # Add DOCKER-USER chain rule to drop external access to 6333
    if iptables -L DOCKER-USER &>/dev/null 2>&1; then
        if ! iptables -C DOCKER-USER -p tcp --dport 6333 ! -s 127.0.0.1 -j DROP &>/dev/null 2>&1; then
            iptables -I DOCKER-USER -p tcp --dport 6333 ! -s 127.0.0.1 -j DROP
            ok "Iptables DOCKER-USER rule: drop external Qdrant access."
        else
            ok "DOCKER-USER Qdrant drop rule already exists."
        fi
    else
        warn "DOCKER-USER chain not found. Docker iptables rules may not be active."
    fi
fi

ok "Qdrant security configuration complete."
