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

        # Pattern validation
        if [ -n "$pattern" ] && ! echo "$value" | grep -qP "$pattern"; then
            fail "Invalid format. Expected pattern: $pattern" >/dev/tty
            continue
        fi

        ok "Accepted." >/dev/tty
        break
    done

    eval "$varname='$value'"
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
    '^\d+:[A-Za-z0-9_-]{35,}$' \
    ""

# TELEGRAM_CHAT_ID (required)
prompt_secret TELEGRAM_CHAT_ID \
    "${RED}*${RESET} TELEGRAM_CHAT_ID" \
    "required" \
    '^-?\d+$' \
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
    cat > "$SECRETS_FILE" << SECRETS_EOF
# CODE SHIELD V3 -- Managed Secrets
# Generated: $(date -Iseconds)
# Do NOT edit manually unless you know what you are doing.
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
BRAVE_API_KEY=${BRAVE_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
QDRANT_API_KEY=${QDRANT_API_KEY}
SECRETS_EOF

    chmod 0600 "$SECRETS_FILE"
    chown root:root "$SECRETS_FILE"
    ok "Secrets written to $SECRETS_FILE (mode 0600, owner root:root)"
fi

# Export for subsequent stages
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID BRAVE_API_KEY OPENAI_API_KEY
export OPENCLAW_GATEWAY_TOKEN QDRANT_API_KEY
