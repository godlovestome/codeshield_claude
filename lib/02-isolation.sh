#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 2: User Isolation & Secret Migration
# Sourced by install.sh -- do not execute directly.

info "Configuring user isolation and secret migration ..."

SECRETS_FILE="$CS_CONF_DIR/secrets.env"
OPENCLAW_HOME="/home/openclaw"
OPENCLAW_SVC_HOME="/var/lib/openclaw-svc"
OPENCLAW_JSON="$OPENCLAW_HOME/.openclaw/openclaw.json"
DROPIN_DIR="/etc/systemd/system/openclaw.service.d"
DROPIN_FILE="$DROPIN_DIR/codeshield.conf"

###############################################################################
# 1. Ensure openclaw-svc user exists
###############################################################################
if ! id "openclaw-svc" &>/dev/null; then
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Would create user openclaw-svc"
    else
        useradd --system --shell /usr/sbin/nologin \
                --home-dir "$OPENCLAW_SVC_HOME" \
                --create-home openclaw-svc
        ok "Created system user: openclaw-svc"
    fi
else
    ok "User openclaw-svc already exists."
fi

###############################################################################
# 2. Ensure openclaw-svc is NOT in docker or sudo groups
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    for grp in docker sudo; do
        if id -nG openclaw-svc 2>/dev/null | grep -qw "$grp"; then
            gpasswd -d openclaw-svc "$grp" 2>/dev/null || true
            warn "Removed openclaw-svc from $grp group."
        fi
    done
    ok "openclaw-svc group isolation verified."
fi

###############################################################################
# 3. Migrate inline secrets from openclaw.json to secrets.env
###############################################################################
migrate_secrets() {
    # P4 fix (V3.0.1): use del() to fully remove keys, not blank them.
    # Also handles nested paths (e.g. .gateway.auth.token).
    if [ ! -f "$OPENCLAW_JSON" ]; then
        warn "openclaw.json not found at $OPENCLAW_JSON -- skipping migration."
        return 0
    fi

    info "Scanning openclaw.json for inline secrets ..."

    python3 - "$OPENCLAW_JSON" "$SECRETS_FILE" << 'PY'
import json, os, sys, pwd
from pathlib import Path

json_path  = Path(sys.argv[1])
secrets_path = Path(sys.argv[2])

cfg = json.loads(json_path.read_text())

# (json_dotpath, env_var_name)
# Use dotted paths for nested keys — walks cfg recursively
MAPPINGS = [
    ("channels.telegram.botToken",       "TELEGRAM_BOT_TOKEN"),
    ("tools.web.search.apiKey",           "BRAVE_API_KEY"),
    ("gateway.auth.token",                "OPENCLAW_GATEWAY_TOKEN"),
    ("auth.openai.apiKey",                "OPENAI_API_KEY"),
    ("telegramBotToken",                  "TELEGRAM_BOT_TOKEN"),
    ("braveApiKey",                       "BRAVE_API_KEY"),
    ("gatewayToken",                      "OPENCLAW_GATEWAY_TOKEN"),
    ("openaiApiKey",                      "OPENAI_API_KEY"),
    ("qdrantApiKey",                      "QDRANT_API_KEY"),
]

def get_nested(obj, dotpath):
    parts = dotpath.split(".")
    cur = obj
    for p in parts:
        if not isinstance(cur, dict) or p not in cur:
            return None
        cur = cur[p]
    return cur if isinstance(cur, str) and cur.strip() else None

def del_nested(obj, dotpath):
    parts = dotpath.split(".")
    cur = obj
    for p in parts[:-1]:
        if not isinstance(cur, dict) or p not in cur:
            return
        cur = cur[p]
    cur.pop(parts[-1], None)

# Load existing secrets
existing = {}
if secrets_path.exists():
    for line in secrets_path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            existing[k.strip()] = v.strip().strip('"\'')

changed = 0
migrated = []
for dotpath, envkey in MAPPINGS:
    val = get_nested(cfg, dotpath)
    if val:
        if envkey not in existing or not existing[envkey]:
            existing[envkey] = val
        del_nested(cfg, dotpath)   # V3.0.1: fully DELETE, not blank
        changed += 1
        migrated.append(f"{dotpath} -> {envkey}")

if changed:
    # Write back cleaned json
    json_path.write_text(json.dumps(cfg, indent=2) + "\n")
    u = pwd.getpwnam("openclaw")
    os.chown(json_path, u.pw_uid, u.pw_gid)
    os.chmod(json_path, 0o600)
    # Write secrets
    lines = ["# Managed by CODE SHIELD. Keep mode 0600."]
    for k, v in existing.items():
        lines.append(f"{k}={v}")
    secrets_path.write_text("\n".join(lines) + "\n")
    os.chmod(secrets_path, 0o600)
    os.chown(secrets_path, 0, 0)
    for m in migrated:
        print(f"  Migrated & deleted: {m}")
else:
    print("  No inline secrets found.")
PY
}

if [ "$DRY_RUN" -eq 0 ]; then
    migrate_secrets
fi

###############################################################################
# 4. Sync openclaw data to openclaw-svc home
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$OPENCLAW_SVC_HOME/.openclaw"
    if [ -d "$OPENCLAW_HOME/.openclaw" ]; then
        rsync -a --update "$OPENCLAW_HOME/.openclaw/" "$OPENCLAW_SVC_HOME/.openclaw/" 2>/dev/null || \
            cp -a "$OPENCLAW_HOME/.openclaw/"* "$OPENCLAW_SVC_HOME/.openclaw/" 2>/dev/null || true
        chown -R openclaw-svc:openclaw-svc "$OPENCLAW_SVC_HOME/.openclaw"
        ok "Synced openclaw data to $OPENCLAW_SVC_HOME/.openclaw"
    else
        warn "No openclaw data directory found to sync."
    fi
fi

###############################################################################
# 5. Create systemd drop-in for environment injection
###############################################################################
if [ "$DRY_RUN" -eq 1 ]; then
    info "[DRY-RUN] Would create drop-in at $DROPIN_FILE"
else
    mkdir -p "$DROPIN_DIR"
    cat > "$DROPIN_FILE" << 'DROPIN_EOF'
# CODE SHIELD V3 -- systemd drop-in for openclaw.service
# Injects externalized secrets via EnvironmentFile
# This file is regenerated by codeshield-guardian after updates.
[Service]
User=openclaw-svc
Group=openclaw-svc
EnvironmentFile=/etc/openclaw-codeshield/secrets.env

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=yes
ReadWritePaths=/var/lib/openclaw-svc
DROPIN_EOF

    chmod 0644 "$DROPIN_FILE"
    systemctl daemon-reload 2>/dev/null || true
    ok "Created systemd drop-in: $DROPIN_FILE"
fi

###############################################################################
# 6. Controlled sudoers for openclaw-svc
###############################################################################
SUDOERS_FILE="/etc/sudoers.d/openclaw-codeshield"
if [ "$DRY_RUN" -eq 0 ]; then
    cat > "$SUDOERS_FILE" << 'SUDOERS_EOF'
# CODE SHIELD V3 -- Controlled sudo for openclaw-svc
# Only allow restarting its own service
openclaw-svc ALL=(root) NOPASSWD: /usr/bin/systemctl restart openclaw.service
openclaw-svc ALL=(root) NOPASSWD: /usr/bin/systemctl status openclaw.service
SUDOERS_EOF
    chmod 0440 "$SUDOERS_FILE"
    visudo -cf "$SUDOERS_FILE" &>/dev/null || {
        fail "Sudoers file syntax error! Removing."
        rm -f "$SUDOERS_FILE"
    }
    ok "Controlled sudoers installed: $SUDOERS_FILE"
fi

###############################################################################
# 7. Encrypt secrets at rest (systemd-creds)
###############################################################################
if [ "$DRY_RUN" -eq 0 ]; then
    if [ -f "$SECRETS_FILE" ] && command -v systemd-creds &>/dev/null; then
        # Ensure host credential key exists
        if [ ! -f /var/lib/systemd/credential.secret ]; then
            systemd-creds setup 2>/dev/null || true
        fi
        if [ -f /var/lib/systemd/credential.secret ]; then
            info "Encrypting secrets at rest with systemd-creds ..."
            codeshield-secrets-seal --from "$SECRETS_FILE"
            ok "Secrets encrypted. Plaintext removed from disk."
        else
            warn "systemd host key not available. Secrets remain plaintext."
        fi
    fi
fi

ok "User isolation and secret migration complete."
