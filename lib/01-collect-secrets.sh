#!/usr/bin/env bash
# CODE SHIELD V3 -- Stage 1: Interactive Secret Collection
# Sourced by install.sh -- do not execute directly.
#
# When piped via curl|bash, stdin is the pipe, so we read from /dev/tty.

info "Collecting secrets for CODE SHIELD V3 ..."

SECRETS_FILE="$CS_CONF_DIR/secrets.env"

###############################################################################
# Helper: prompt user (works even when stdin is a pipe)
###############################################################################
prompt_secret() {
    local varname="$1" prompt_text="$2" required="$3" pattern="$4" default="$5"
    local value=""

    while true; do
        printf "${BOLD}%s${RESET}" "$prompt_text" >/dev/tty
        if [ -n "$default" ]; then
            printf " [default: auto-generate]" >/dev/tty
        fi
        printf ": " >/dev/tty
        read -r value </dev/tty

        # Empty input handling
        if [ -z "$value" ]; then
            if [ "$required" = "required" ]; then
                fail "This field is required. Please enter a value." >/dev/tty
                continue
            elif [ -n "$default" ]; then
                value="$default"
                ok "Auto-generated." >/dev/tty
                break
            else
                warn "Skipped." >/dev/tty
                break
            fi
        fi

        # Pattern validation (use -E instead of -P for locale safety)
        if [ -n "$pattern" ] && ! printf '%s' "$value" | grep -qE "$pattern"; then
            fail "Invalid format. Expected pattern: $pattern" >/dev/tty
            continue
        fi

        ok "Accepted." >/dev/tty
        break
    done

    printf -v "$varname" '%s' "$value"
}

###############################################################################
# Load existing secrets if re-running
###############################################################################
declare -A EXISTING_SECRETS
if [ -f "$SECRETS_FILE" ]; then
    info "Found existing secrets file. Press Enter to keep current values."
    while IFS='=' read -r key val; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        EXISTING_SECRETS["$key"]="$val"
    done < "$SECRETS_FILE"
fi

###############################################################################
# Collect secrets
###############################################################################
printf "\n${BOLD}${CYAN}=== CODE SHIELD V3 Secret Configuration ===${RESET}\n" >/dev/tty
printf "Enter your API keys and tokens below.\n" >/dev/tty
printf "Required fields are marked with ${RED}*${RESET}.\n\n" >/dev/tty

# TELEGRAM_BOT_TOKEN (required)
prompt_secret TELEGRAM_BOT_TOKEN \
    "${RED}*${RESET} TELEGRAM_BOT_TOKEN" \
    "required" \
    '^[0-9]+:[A-Za-z0-9_-]{35,}$' \
    ""

# TELEGRAM_CHAT_ID (required)
prompt_secret TELEGRAM_CHAT_ID \
    "${RED}*${RESET} TELEGRAM_CHAT_ID" \
    "required" \
    '^-?[0-9]+$' \
    ""

# BRAVE_API_KEY (optional)
prompt_secret BRAVE_API_KEY \
    "  BRAVE_API_KEY (optional, Enter to skip)" \
    "optional" \
    "" \
    ""

# OPENAI_API_KEY (optional)
prompt_secret OPENAI_API_KEY \
    "  OPENAI_API_KEY (optional, Enter to skip)" \
    "optional" \
    '^sk-' \
    ""

# OpenAI Auth Mode (API Key or OAuth)
printf "\n${CYAN}OpenAI auth mode:${RESET} 1) API Key (default)  2) OAuth\n" >/dev/tty
printf "Choice [1]: " >/dev/tty
OPENAI_AUTH_MODE=""
read -r OPENAI_AUTH_MODE </dev/tty 2>/dev/null || true
if [ "$OPENAI_AUTH_MODE" = "2" ]; then
    # OAuth mode: collect client ID, secret, org ID
    prompt_secret OPENAI_CLIENT_ID \
        "  OPENAI_CLIENT_ID (OAuth client ID)" \
        "optional" \
        "" \
        ""
    prompt_secret OPENAI_CLIENT_SECRET \
        "  OPENAI_CLIENT_SECRET (OAuth client secret)" \
        "optional" \
        "" \
        ""
    prompt_secret OPENAI_ORG_ID \
        "  OPENAI_ORG_ID (Organization ID, Enter to skip)" \
        "optional" \
        "" \
        ""
fi

# ANTHROPIC_API_KEY (optional)
prompt_secret ANTHROPIC_API_KEY \
    "  ANTHROPIC_API_KEY (optional, Enter to skip)" \
    "optional" \
    '^sk-ant-' \
    ""

# GLM_API_KEY (optional -- 智谱 BigModel)
prompt_secret GLM_API_KEY \
    "  GLM_API_KEY (智谱 GLM5, optional, Enter to skip)" \
    "optional" \
    "" \
    ""

# KIMI_API_KEY (optional -- 月之暗面 Moonshot)
prompt_secret KIMI_API_KEY \
    "  KIMI_API_KEY (月之暗面 Kimi 2.5, optional, Enter to skip)" \
    "optional" \
    "" \
    ""

# OPENCLAW_GATEWAY_TOKEN (optional, auto-generate)
AUTO_GATEWAY=$(openssl rand -hex 32)
prompt_secret OPENCLAW_GATEWAY_TOKEN \
    "  OPENCLAW_GATEWAY_TOKEN (Enter to auto-generate)" \
    "optional" \
    "" \
    "$AUTO_GATEWAY"

# QDRANT_API_KEY (optional, auto-generate)
AUTO_QDRANT=$(openssl rand -hex 24)
prompt_secret QDRANT_API_KEY \
    "  QDRANT_API_KEY (Enter to auto-generate 48-char hex)" \
    "optional" \
    "" \
    "$AUTO_QDRANT"

###############################################################################
# Write secrets file
###############################################################################
if [ "$DRY_RUN" -eq 1 ]; then
    info "[DRY-RUN] Would write secrets to $SECRETS_FILE"
else
    # Write secrets using printf for UTF-8 safety (avoids shell expansion issues)
    {
        printf '# CODE SHIELD V3 -- Managed Secrets\n'
        printf '# Generated: %s\n' "$(date -Iseconds)"
        printf '# Do NOT edit manually. Use: codeshield-config edit\n'
        printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN"
        printf 'TELEGRAM_CHAT_ID=%s\n' "$TELEGRAM_CHAT_ID"
        printf 'BRAVE_API_KEY=%s\n' "$BRAVE_API_KEY"
        printf 'OPENAI_API_KEY=%s\n' "$OPENAI_API_KEY"
        # OpenAI OAuth fields (only if OAuth mode selected)
        if [ "${OPENAI_AUTH_MODE:-}" = "2" ]; then
            printf 'OPENAI_CLIENT_ID=%s\n' "${OPENAI_CLIENT_ID:-}"
            printf 'OPENAI_CLIENT_SECRET=%s\n' "${OPENAI_CLIENT_SECRET:-}"
            printf 'OPENAI_ORG_ID=%s\n' "${OPENAI_ORG_ID:-}"
        fi
        printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY:-}"
        printf 'GLM_API_KEY=%s\n' "${GLM_API_KEY:-}"
        printf 'KIMI_API_KEY=%s\n' "${KIMI_API_KEY:-}"
        printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$OPENCLAW_GATEWAY_TOKEN"
        printf 'QDRANT_API_KEY=%s\n' "$QDRANT_API_KEY"
        # Proxy settings: openclaw-svc is network-isolated (iptables blocks
        # non-loopback), so all outbound traffic must go through the Squid proxy.
        # NODE_USE_ENV_PROXY=1: forces Node.js 22+ built-in fetch (undici) to
        # respect HTTP_PROXY/HTTPS_PROXY, enabling web_fetch and tool calls.
        printf '# Proxy (required for network-isolated openclaw-svc)\n'
        printf 'HTTPS_PROXY=http://127.0.0.1:3128\n'
        printf 'HTTP_PROXY=http://127.0.0.1:3128\n'
        printf 'https_proxy=http://127.0.0.1:3128\n'
        printf 'http_proxy=http://127.0.0.1:3128\n'
        printf 'NODE_USE_ENV_PROXY=1\n'
    } > "$SECRETS_FILE"

    chmod 0600 "$SECRETS_FILE"
    chown root:root "$SECRETS_FILE"
    ok "Secrets written to $SECRETS_FILE (mode 0600, owner root:root)"
fi

# Export for subsequent stages
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID BRAVE_API_KEY OPENAI_API_KEY
export OPENCLAW_GATEWAY_TOKEN QDRANT_API_KEY
export ANTHROPIC_API_KEY GLM_API_KEY KIMI_API_KEY
export OPENAI_CLIENT_ID OPENAI_CLIENT_SECRET OPENAI_ORG_ID 2>/dev/null || true
