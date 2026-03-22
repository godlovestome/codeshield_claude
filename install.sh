#!/usr/bin/env bash
# CODE SHIELD V3 -- One-Line Interactive Installer
# curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
#
# Supports:
#   --dry-run        Show what would be done without making changes
#   --skip-preflight Skip environment pre-checks
#   --update         Non-interactive re-apply (used by guardian)
set -euo pipefail

###############################################################################
# Locale: force UTF-8 to prevent encoding errors in all stages
###############################################################################
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 2>/dev/null || \
    export LC_ALL=C.UTF-8 LANG=C.UTF-8 2>/dev/null || true

###############################################################################
# Non-interactive apt: prevent debconf dialogs (e.g. iptables-persistent)
# when running via curl|bash where stdin is a pipe
###############################################################################
export DEBIAN_FRONTEND=noninteractive

###############################################################################
# Constants
###############################################################################
readonly CS_VERSION="3.1.2"
readonly CS_CONF_DIR="/etc/openclaw-codeshield"
readonly CS_LIB_DIR="/usr/local/lib/openclaw-codeshield"
readonly CS_SBIN_DIR="/usr/local/sbin"
readonly CS_LOG_DIR="/var/log/openclaw-codeshield"
readonly CS_DATA_DIR="/var/lib/openclaw-codeshield"
readonly CS_REPO="https://raw.githubusercontent.com/godlovestome/codeshield_claude/main"

###############################################################################
# Color helpers (safe for non-tty)
###############################################################################
if [ -t 1 ] 2>/dev/null || [ -t 2 ] 2>/dev/null; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

info()  { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${RESET}  %s\n" "$*"; }
stage() { printf "\n${BOLD}━━━ [%s] %s ━━━${RESET}\n" "$1" "$2"; }

###############################################################################
# Parse arguments
###############################################################################
DRY_RUN=0
SKIP_PREFLIGHT=0
UPDATE_MODE=0
RESUME_MODE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)        DRY_RUN=1 ;;
        --skip-preflight) SKIP_PREFLIGHT=1 ;;
        --update)         UPDATE_MODE=1 ;;
        --resume)         RESUME_MODE=1 ;;
        --help|-h)
            echo "CODE SHIELD V3 Installer"
            echo "Usage: install.sh [--dry-run] [--skip-preflight] [--update] [--resume]"
            exit 0
            ;;
        *) warn "Unknown argument: $arg" ;;
    esac
done

export DRY_RUN SKIP_PREFLIGHT UPDATE_MODE RESUME_MODE
export CS_VERSION CS_CONF_DIR CS_LIB_DIR CS_SBIN_DIR CS_LOG_DIR CS_DATA_DIR CS_REPO
export RED GREEN YELLOW CYAN BOLD RESET

###############################################################################
# Privilege check
###############################################################################
if [ "$(id -u)" -ne 0 ]; then
    fail "This installer must be run as root."
    exit 1
fi

###############################################################################
# Determine source directory (local clone or remote fetch)
###############################################################################
SCRIPT_DIR=""
if [ -f "$(dirname "${BASH_SOURCE[0]:-$0}")/lib/00-preflight.sh" ] 2>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
fi

fetch_lib() {
    local name="$1"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/lib/$name" ]; then
        cat "$SCRIPT_DIR/lib/$name"
    else
        curl -fsSL "$CS_REPO/lib/$name"
    fi
}

fetch_file() {
    local path="$1"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$path" ]; then
        cat "$SCRIPT_DIR/$path"
    else
        curl -fsSL "$CS_REPO/$path"
    fi
}

export -f fetch_lib fetch_file

###############################################################################
# Create base directories
###############################################################################
mkdir -p "$CS_CONF_DIR" "$CS_LIB_DIR" "$CS_LOG_DIR" "$CS_DATA_DIR"
mkdir -p "$CS_CONF_DIR/channels.d" "$CS_CONF_DIR/models.d"
chmod 0700 "$CS_CONF_DIR"

###############################################################################
# Install logging -- tee all output to install.log
###############################################################################
INSTALL_LOG="$CS_LOG_DIR/install.log"
exec > >(tee -a "$INSTALL_LOG") 2>&1
info "Install log: $INSTALL_LOG"

###############################################################################
# Checkpoint / Resume support
###############################################################################
CHECKPOINT_FILE="$CS_DATA_DIR/.install-checkpoint"

save_checkpoint() {
    printf '%s\n' "$1" > "$CHECKPOINT_FILE"
}

get_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "0"
    fi
}

clear_checkpoint() {
    rm -f "$CHECKPOINT_FILE"
}

RESUME_FROM=0
if [ "$RESUME_MODE" -eq 1 ]; then
    RESUME_FROM=$(get_checkpoint)
    if [ "$RESUME_FROM" -gt 0 ]; then
        info "Resuming from stage $RESUME_FROM ..."
    else
        info "No checkpoint found. Starting from beginning."
    fi
fi

###############################################################################
# Error trap -- show helpful message on failure
###############################################################################
on_error() {
    local exit_code=$?
    fail "Installation failed at stage (exit code $exit_code)."
    fail "Check log: $INSTALL_LOG"
    fail "To resume from last checkpoint: install.sh --resume"
    exit "$exit_code"
}
trap on_error ERR

###############################################################################
# Download and cache lib scripts locally
###############################################################################
LIB_SCRIPTS=(
    00-preflight.sh
    01-collect-secrets.sh
    02-isolation.sh
    03-qdrant.sh
    04-hardening.sh
    05-injection-defense.sh
    06-guardian.sh
)

for lib in "${LIB_SCRIPTS[@]}"; do
    info "Fetching lib/$lib ..."
    fetch_lib "$lib" > "$CS_LIB_DIR/$lib"
    chmod 0700 "$CS_LIB_DIR/$lib"
done

###############################################################################
# Download scripts and templates
###############################################################################
SCRIPTS=(
    scripts/security-audit.sh
    scripts/openclaw-injection-scan
    scripts/openclaw-cost-monitor
    scripts/openclaw-guardian
    scripts/emergency-lockdown
    scripts/squid-injection-guard.py
    scripts/codeshield-secrets-seal
    scripts/codeshield-secrets-unseal
    scripts/codeshield-secrets-reseal
    scripts/codeshield-secrets-migrate
    scripts/codeshield-config
)

for s in "${SCRIPTS[@]}"; do
    info "Fetching $s ..."
    fetch_file "$s" > "$CS_LIB_DIR/$(basename "$s")"
    chmod 0700 "$CS_LIB_DIR/$(basename "$s")"
done

TEMPLATES=(
    templates/squid.conf
    templates/soul-injection.md
    templates/skills-policy.json
    templates/codeshield-secrets.service
    templates/codeshield-reseal.service
    templates/codeshield-reseal.timer
)

for t in "${TEMPLATES[@]}"; do
    info "Fetching $t ..."
    fetch_file "$t" > "$CS_LIB_DIR/$(basename "$t")"
done

###############################################################################
# Banner
###############################################################################
printf "\n${BOLD}"
cat << 'BANNER'
   ____  ___  ____  _____   ____  _   _ ___ _____ _     ____   ____ _____
  / ___|/ _ \|  _ \| ____| / ___|| | | |_ _| ____| |   |  _ \ / ___|___ /
 | |  | | | | | | |  _|   \___ \| |_| || ||  _| | |   | | | | |     |_ \
 | |__| |_| | |_| | |___   ___) |  _  || || |___| |___| |_| | |___ ___) |
  \____\___/|____/|_____| |____/|_| |_|___|_____|_____|____/ \____|____/
BANNER
printf "${RESET}\n"
printf "  ${CYAN}Version %s${RESET} -- AI Agent Network Security Shield\n\n" "$CS_VERSION"

if [ "$DRY_RUN" -eq 1 ]; then
    warn "DRY-RUN MODE: No changes will be made."
fi

###############################################################################
# Execute stages
###############################################################################
run_stage() {
    local num="$1" total="$2" name="$3" script="$4"
    # Skip stages before resume checkpoint
    if [ "$RESUME_MODE" -eq 1 ] && [ "$num" -lt "$RESUME_FROM" ]; then
        info "Skipping stage $num (already completed)."
        return 0
    fi
    stage "$num/$total" "$name"
    save_checkpoint "$num"
    # shellcheck disable=SC1090
    source "$CS_LIB_DIR/$script"
}

TOTAL=7

if [ "$UPDATE_MODE" -eq 1 ]; then
    info "Update mode: skipping interactive stages, re-applying protection."
    run_stage 2 "$TOTAL" "Isolation & secrets migration" "02-isolation.sh"
    run_stage 4 "$TOTAL" "System hardening"             "04-hardening.sh"
    run_stage 5 "$TOTAL" "Injection defense"            "05-injection-defense.sh"
    # Stage 6: Secrets encryption is inline (not a separate lib script)
    # It runs after the if/else block via setup_secrets_encryption()
    run_stage 7 "$TOTAL" "Guardian service"             "06-guardian.sh"
else
    if [ "$SKIP_PREFLIGHT" -eq 0 ]; then
        run_stage 1 "$TOTAL" "Environment pre-flight"       "00-preflight.sh"
    else
        warn "Skipping pre-flight checks."
    fi
    run_stage 2 "$TOTAL" "Collect secrets (interactive)" "01-collect-secrets.sh"
    run_stage 3 "$TOTAL" "Isolation & secrets migration"  "02-isolation.sh"
    run_stage 4 "$TOTAL" "Qdrant authentication"          "03-qdrant.sh"
    run_stage 5 "$TOTAL" "System hardening"               "04-hardening.sh"
    run_stage 6 "$TOTAL" "Injection defense"              "05-injection-defense.sh"
    # Guardian is always last (before secrets encryption)
    source "$CS_LIB_DIR/06-guardian.sh"
fi

###############################################################################
# Stage 7: Secrets Encryption (V3.0.2)
###############################################################################
stage "7/$TOTAL" "Secrets encryption (systemd-creds)"

setup_secrets_encryption() {
    # Install secrets management scripts
    for tool in codeshield-secrets-seal codeshield-secrets-unseal codeshield-secrets-reseal codeshield-secrets-migrate; do
        cp "$CS_LIB_DIR/$tool" "$CS_SBIN_DIR/$tool"
        chmod 0755 "$CS_SBIN_DIR/$tool"
    done
    ok "Secrets management scripts installed."

    # Deploy codeshield-secrets.service
    cp "$CS_LIB_DIR/codeshield-secrets.service" /etc/systemd/system/codeshield-secrets.service
    ok "codeshield-secrets.service deployed."

    # Deploy reseal timer
    cp "$CS_LIB_DIR/codeshield-reseal.service" /etc/systemd/system/codeshield-reseal.service
    cp "$CS_LIB_DIR/codeshield-reseal.timer" /etc/systemd/system/codeshield-reseal.timer
    ok "Monthly credential reseal timer deployed."

    # Check if systemd-creds is available
    if ! command -v systemd-creds &>/dev/null; then
        warn "systemd-creds not available (requires systemd 250+). Secrets will remain plaintext."
        return
    fi

    # Ensure host key exists
    if [ ! -f /var/lib/systemd/credential.secret ]; then
        info "Generating systemd host credential key ..."
        systemd-creds setup 2>/dev/null || true
    fi

    # Run migration if plaintext secrets exist and encrypted don't
    if [ -f "$CS_CONF_DIR/secrets.env" ] && [ ! -f "$CS_CONF_DIR/secrets.env.enc" ]; then
        info "Encrypting secrets at rest ..."
        codeshield-secrets-migrate
    elif [ -f "$CS_CONF_DIR/secrets.env.enc" ]; then
        ok "Secrets already encrypted at rest."
        # Ensure service is running
        systemctl daemon-reload
        systemctl enable codeshield-secrets.service --now 2>/dev/null || true
    else
        warn "No secrets file found. Encryption will be applied after secret collection."
    fi

    # Enable reseal timer
    systemctl daemon-reload
    systemctl enable codeshield-reseal.timer --now 2>/dev/null || true
    ok "Monthly reseal timer enabled."
}

if [ "$DRY_RUN" -eq 0 ]; then
    setup_secrets_encryption
else
    info "[DRY-RUN] Would set up secrets encryption."
fi

###############################################################################
# Install CLI tools to /usr/local/sbin
###############################################################################
info "Installing CLI tools ..."
for tool in security-audit.sh openclaw-injection-scan openclaw-cost-monitor openclaw-guardian emergency-lockdown codeshield-config; do
    cp "$CS_LIB_DIR/$tool" "$CS_SBIN_DIR/$tool"
    chmod 0755 "$CS_SBIN_DIR/$tool"
done

###############################################################################
# Final audit
###############################################################################
stage "DONE" "Running security audit"
bash "$CS_SBIN_DIR/security-audit.sh"

clear_checkpoint
printf "\n${GREEN}${BOLD}CODE SHIELD V3 installation complete.${RESET}\n"
printf "Log: %s/install.log\n" "$CS_LOG_DIR"
printf "Run ${CYAN}security-audit.sh${RESET} anytime to re-check.\n"
printf "Run ${CYAN}codeshield-config help${RESET} to manage configuration (API keys, channels, LLM models).\n\n"
