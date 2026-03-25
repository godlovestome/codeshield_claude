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

read_env_file_value() {
    local env_file="$1" key="$2"
    [ -f "$env_file" ] || return 0
    grep -E "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2- || true
}

normalize_workspace_config() {
    local json_file="$1" workspace_path="$2" owner="$3"
    [ -f "$json_file" ] || return 0
    python3 - "$json_file" "$workspace_path" <<'PY'
import json, sys
from pathlib import Path

json_file = Path(sys.argv[1])
workspace_path = sys.argv[2]
cfg = json.loads(json_file.read_text(encoding='utf-8'))
defaults = cfg.setdefault('agents', {}).setdefault('defaults', {})
defaults['workspace'] = workspace_path
json_file.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PY
    chown "${owner}:${owner}" "$json_file"
    chmod 0600 "$json_file"
}

sync_openclaw_runtime_tree() {
    [ -d "$OPENCLAW_HOME/.openclaw" ] || return 0
    if command -v rsync &>/dev/null; then
        rsync -a --update \
            --exclude=agents/*/agent/auth.json \
            --exclude=agents/*/agent/auth-profiles.json \
            --exclude=identity/device-auth.json \
            "$OPENCLAW_HOME/.openclaw/" "$OPENCLAW_SVC_HOME/.openclaw/"
        return $?
    fi
    python3 - "$OPENCLAW_HOME/.openclaw" "$OPENCLAW_SVC_HOME/.openclaw" <<'PY'
from pathlib import Path
from shutil import copy2
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
excluded = {
    Path('agents/main/agent/auth.json'),
    Path('agents/main/agent/auth-profiles.json'),
    Path('identity/device-auth.json'),
}

for item in src.rglob('*'):
    rel = item.relative_to(src)
    if rel in excluded:
        continue
    target = dst / rel
    if item.is_dir():
        target.mkdir(parents=True, exist_ok=True)
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.stat().st_mtime >= item.stat().st_mtime:
        continue
    copy2(item, target)
PY
}

sync_service_auth_state() {
    python3 - "$OPENCLAW_HOME/.openclaw" "$OPENCLAW_SVC_HOME/.openclaw" <<'PY'
from pathlib import Path
from shutil import copy2
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
tracked = [
    Path('agents/main/agent/auth.json'),
    Path('agents/main/agent/auth-profiles.json'),
    Path('identity/device-auth.json'),
]

for rel in tracked:
    source = src / rel
    target = dst / rel
    if not source.exists():
        continue
    if target.exists() and not (source.stat().st_mtime > target.stat().st_mtime):
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    copy2(source, target)
PY
    chown openclaw-svc:openclaw-svc \
        "$OPENCLAW_SVC_HOME/.openclaw/agents/main/agent/auth.json" \
        "$OPENCLAW_SVC_HOME/.openclaw/agents/main/agent/auth-profiles.json" \
        "$OPENCLAW_SVC_HOME/.openclaw/identity/device-auth.json" 2>/dev/null || true
    chmod 0600 \
        "$OPENCLAW_SVC_HOME/.openclaw/agents/main/agent/auth.json" \
        "$OPENCLAW_SVC_HOME/.openclaw/agents/main/agent/auth-profiles.json" \
        "$OPENCLAW_SVC_HOME/.openclaw/identity/device-auth.json" 2>/dev/null || true
}

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

    # Validate JSON before migration
    if ! python3 -c "import json, sys; json.loads(open(sys.argv[1], encoding='utf-8').read())" "$OPENCLAW_JSON" 2>/dev/null; then
        warn "openclaw.json is not valid JSON. Skipping migration."
        return 0
    fi

    python3 - "$OPENCLAW_JSON" "$SECRETS_FILE" << 'PY'
import json, os, sys, pwd
from pathlib import Path

json_path  = Path(sys.argv[1])
secrets_path = Path(sys.argv[2])

cfg = json.loads(json_path.read_text(encoding='utf-8'))

# (json_dotpath, env_var_name)
# Use dotted paths for nested keys — walks cfg recursively
MAPPINGS = [
    ("channels.telegram.botToken",       "TELEGRAM_BOT_TOKEN"),
    ("tools.web.search.apiKey",           "BRAVE_API_KEY"),
    ("gateway.auth.token",                "OPENCLAW_GATEWAY_TOKEN"),
    ("auth.openai.apiKey",                "OPENAI_API_KEY"),
    ("auth.openai.clientId",              "OPENAI_CLIENT_ID"),
    ("auth.openai.clientSecret",          "OPENAI_CLIENT_SECRET"),
    ("auth.openai.orgId",                 "OPENAI_ORG_ID"),
    ("auth.anthropic.apiKey",             "ANTHROPIC_API_KEY"),
    ("auth.deepseek.apiKey",              "DEEPSEEK_API_KEY"),
    ("auth.glm.apiKey",                   "GLM_API_KEY"),
    ("auth.kimi.apiKey",                  "KIMI_API_KEY"),
    ("telegramBotToken",                  "TELEGRAM_BOT_TOKEN"),
    ("braveApiKey",                       "BRAVE_API_KEY"),
    ("gatewayToken",                      "OPENCLAW_GATEWAY_TOKEN"),
    ("openaiApiKey",                      "OPENAI_API_KEY"),
    ("anthropicApiKey",                   "ANTHROPIC_API_KEY"),
    ("deepseekApiKey",                    "DEEPSEEK_API_KEY"),
    ("glmApiKey",                         "GLM_API_KEY"),
    ("kimiApiKey",                        "KIMI_API_KEY"),
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
    for line in secrets_path.read_text(encoding='utf-8').splitlines():
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
    json_path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding='utf-8')
    u = pwd.getpwnam("openclaw")
    os.chown(json_path, u.pw_uid, u.pw_gid)
    os.chmod(json_path, 0o600)
    # Write secrets
    lines = ["# Managed by CODE SHIELD. Keep mode 0600."]
    for k, v in existing.items():
        lines.append(f"{k}={v}")
    secrets_path.write_text("\n".join(lines) + "\n", encoding='utf-8')
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
    mkdir -p "$OPENCLAW_SVC_HOME/.openclaw/workspace"
    if [ -d "$OPENCLAW_HOME/.openclaw" ]; then
        sync_openclaw_runtime_tree || true
        sync_service_auth_state
        if [ -f "$OPENCLAW_HOME/.claude.json" ]; then
            install -m 0600 -o openclaw-svc -g openclaw-svc "$OPENCLAW_HOME/.claude.json" "$OPENCLAW_SVC_HOME/.claude.json"
        fi
        normalize_workspace_config \
            "$OPENCLAW_HOME/.openclaw/openclaw.json" \
            "$OPENCLAW_HOME/.openclaw/workspace" \
            "openclaw"
        normalize_workspace_config \
            "$OPENCLAW_SVC_HOME/.openclaw/openclaw.json" \
            "$OPENCLAW_SVC_HOME/.openclaw/workspace" \
            "openclaw-svc"
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
[Unit]
# Secrets must be decrypted to tmpfs before openclaw starts
After=codeshield-secrets.service
Requires=codeshield-secrets.service

[Service]
User=openclaw-svc
Group=openclaw-svc
# Secrets are decrypted to tmpfs by codeshield-secrets.service
EnvironmentFile=/run/openclaw-codeshield/secrets.env
Environment=HOME=/var/lib/openclaw-svc
Environment=XDG_CONFIG_HOME=/var/lib/openclaw-svc/.config
WorkingDirectory=/var/lib/openclaw-svc

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
# 5b. Configure openclaw: Telegram channel, gateway token, policies
#     Ensures openclaw reads secrets from env vars (not inline JSON)
###############################################################################
configure_openclaw() {
    local OPENCLAW_BIN=""
    for candidate in \
        /home/openclaw/.npm-global/bin/openclaw \
        /usr/local/bin/openclaw \
        /usr/bin/openclaw; do
        if [ -x "$candidate" ]; then
            OPENCLAW_BIN="$candidate"
            break
        fi
    done

    if [ -z "$OPENCLAW_BIN" ]; then
        warn "openclaw binary not found. Skipping openclaw configuration."
        return
    fi

    info "Configuring openclaw (channels, gateway, policies) ..."

    local _secrets_src=""
    if [ -f "/run/openclaw-codeshield/secrets.env" ]; then
        _secrets_src="/run/openclaw-codeshield/secrets.env"
    elif [ -f "$SECRETS_FILE" ]; then
        _secrets_src="$SECRETS_FILE"
    fi

    if [ -z "$_secrets_src" ]; then
        warn "No secrets file found. Skipping openclaw configuration."
        return
    fi

    local TELEGRAM_BOT_TOKEN=""
    local OPENCLAW_GATEWAY_TOKEN=""
    TELEGRAM_BOT_TOKEN="$(read_env_file_value "$_secrets_src" TELEGRAM_BOT_TOKEN)"
    OPENCLAW_GATEWAY_TOKEN="$(read_env_file_value "$_secrets_src" OPENCLAW_GATEWAY_TOKEN)"

    # --- Register Telegram channel with --use-env (token stays in env, not JSON) ---
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
        # Export the token so openclaw can read it from env
        export TELEGRAM_BOT_TOKEN
        sudo -u openclaw-svc \
            TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
            "$OPENCLAW_BIN" channels add \
                --channel telegram \
                --use-env \
                --name default 2>/dev/null && \
            ok "Telegram channel registered (token from env)." || \
            warn "Telegram channel registration failed (may already exist)."

        # Set open policies so the bot responds to messages without pairing
        sudo -u openclaw-svc "$OPENCLAW_BIN" config set \
            channels.telegram.dmPolicy "open" 2>/dev/null || true
        sudo -u openclaw-svc "$OPENCLAW_BIN" config set \
            channels.telegram.groupPolicy "open" 2>/dev/null || true
        sudo -u openclaw-svc "$OPENCLAW_BIN" config set \
            channels.telegram.allowFrom '["*"]' 2>/dev/null || true
        ok "Telegram policies set: dmPolicy=open, groupPolicy=open, allowFrom=[*]."
    else
        info "TELEGRAM_BOT_TOKEN not set. Skipping Telegram channel registration."
    fi

    # --- Set gateway auth token from CODE SHIELD secrets ---
    if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
        sudo -u openclaw-svc "$OPENCLAW_BIN" config set \
            gateway.auth.token "$OPENCLAW_GATEWAY_TOKEN" 2>/dev/null && \
            ok "Gateway auth token configured from secrets." || \
            warn "Failed to set gateway auth token."
    else
        warn "OPENCLAW_GATEWAY_TOKEN not set. Gateway may fail to authenticate."
    fi

    # --- Remove any inline botToken from openclaw.json (defense in depth) ---
    local SVC_JSON="$OPENCLAW_SVC_HOME/.openclaw/openclaw.json"
    if [ -f "$SVC_JSON" ] && command -v python3 &>/dev/null; then
        python3 -c "
import json, sys, os
p = sys.argv[1]
try:
    cfg = json.loads(open(p, encoding='utf-8').read())
    changed = False
    # Remove inline botToken
    tg = cfg.get('channels', {}).get('telegram', {})
    if 'botToken' in tg:
        del tg['botToken']
        changed = True
    # Remove inline gateway token
    gw = cfg.get('gateway', {}).get('auth', {})
    if 'token' in gw and gw['token'] == os.environ.get('OPENCLAW_GATEWAY_TOKEN', ''):
        pass  # keep it — it matches the env var (openclaw needs it in config)
    if changed:
        open(p, 'w', encoding='utf-8').write(json.dumps(cfg, indent=2, ensure_ascii=False) + '\n')
        print('  Removed inline botToken from openclaw.json')
except Exception as e:
    print(f'  WARN: Could not clean openclaw.json: {e}', file=sys.stderr)
" "$SVC_JSON" 2>/dev/null || true
    fi

    normalize_workspace_config \
        "$OPENCLAW_HOME/.openclaw/openclaw.json" \
        "$OPENCLAW_HOME/.openclaw/workspace" \
        "openclaw"
    normalize_workspace_config \
        "$OPENCLAW_SVC_HOME/.openclaw/openclaw.json" \
        "$OPENCLAW_SVC_HOME/.openclaw/workspace" \
        "openclaw-svc"
}

if [ "$DRY_RUN" -eq 0 ]; then
    configure_openclaw
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
