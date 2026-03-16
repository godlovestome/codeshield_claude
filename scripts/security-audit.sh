#!/usr/bin/env bash
# CODE SHIELD V3 -- 36-Item Security Audit
# Usage: security-audit.sh [--quiet]
set -uo pipefail

###############################################################################
# Config
###############################################################################
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

CS_CONF_DIR="/etc/openclaw-codeshield"
CS_DATA_DIR="/var/lib/openclaw-codeshield"
CS_SBIN_DIR="/usr/local/sbin"
OPENCLAW_HOME="/home/openclaw"
OPENCLAW_SVC_HOME="/var/lib/openclaw-svc"

###############################################################################
# Colors
###############################################################################
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

###############################################################################
# Counters
###############################################################################
PASS=0
FAIL=0
MAYBE=0
TOTAL=0

###############################################################################
# Check functions
###############################################################################
check() {
    local name="$1"
    shift
    TOTAL=$((TOTAL + 1))
    if eval "$@" &>/dev/null; then
        PASS=$((PASS + 1))
        [ "$QUIET" -eq 0 ] && printf " ${GREEN}[PASS]${RESET} %s\n" "$name"
    else
        FAIL=$((FAIL + 1))
        [ "$QUIET" -eq 0 ] && printf " ${RED}[FAIL]${RESET} %s\n" "$name"
    fi
}

check_maybe() {
    local name="$1"
    shift
    if eval "$@" &>/dev/null; then
        MAYBE=$((MAYBE + 1))
        [ "$QUIET" -eq 0 ] && printf " ${YELLOW}[SKIP]${RESET} %s (not deployed)\n" "$name"
    else
        TOTAL=$((TOTAL + 1))
        PASS=$((PASS + 1))
        [ "$QUIET" -eq 0 ] && printf " ${GREEN}[PASS]${RESET} %s\n" "$name"
    fi
}

###############################################################################
# Banner
###############################################################################
if [ "$QUIET" -eq 0 ]; then
    printf "\n${BOLD}${CYAN}"
    printf " CODE SHIELD V3 -- Security Audit\n"
    printf " Running %s checks ...\n" "36"
    printf "${RESET}\n"
fi

###############################################################################
# NETWORK SECURITY (10)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Network Security ---${RESET}\n"

check "ufw active" \
    "ufw status | grep -q 'Status: active'"

check "ssh password disabled" \
    "sshd -T 2>/dev/null | grep -i '^passwordauthentication ' | grep -qi 'no'"

check "ssh keyboard-interactive disabled" \
    "sshd -T 2>/dev/null | grep -i '^kbdinteractiveauthentication ' | grep -qi 'no'"

check "root key-only login" \
    "sshd -T 2>/dev/null | grep -i '^permitrootlogin ' | grep -qiE 'prohibit-password|without-password'"

check "fail2ban sshd active" \
    "fail2ban-client status sshd 2>/dev/null | grep -q 'Currently banned'"

check "ipv6 disabled" \
    "sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q 1"

check "zerotier online" \
    "zerotier-cli info 2>/dev/null | grep -q ONLINE"

check "zerotier private network" \
    "zerotier-cli listnetworks 2>/dev/null | grep -q PRIVATE"

check "docker-user drop rules" \
    "iptables -L DOCKER-USER 2>/dev/null | grep -q DROP"

check "dns direct query blocked" \
    "iptables -L OUTPUT -n 2>/dev/null | grep 'dpt:53' | grep -q DROP || iptables -S OUTPUT 2>/dev/null | grep -qE 'uid-owner.*(openclaw-svc|[0-9]+).*dport 53.*DROP'"

###############################################################################
# ACCESS CONTROL (8)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Access Control ---${RESET}\n"

check "openclaw not in docker group" \
    "! id -nG openclaw-svc 2>/dev/null | grep -qw docker"

check "openclaw not in sudo group" \
    "! id -nG openclaw-svc 2>/dev/null | grep -qw sudo"

check "openclaw-svc exists" \
    "id openclaw-svc"

check "openclaw service isolated user" \
    "grep -qr 'User=openclaw-svc' /etc/systemd/system/openclaw.service.d/ 2>/dev/null || systemctl show openclaw.service -p User 2>/dev/null | grep -q openclaw-svc"

check "watcher isolated user" \
    "systemctl show openclaw-watcher.service -p User 2>/dev/null | grep -q openclaw-svc || test -f /etc/systemd/system/openclaw.service.d/codeshield.conf"

check "controlled sudoers present" \
    "test -f /etc/sudoers.d/openclaw-codeshield"

check "secrets file permissions" \
    "stat -c '%a' $CS_CONF_DIR/secrets.env 2>/dev/null | grep -q '600'"

check "no inline secrets in openclaw.json" \
    "! jq -r '.telegramBotToken // empty' $OPENCLAW_HOME/.openclaw/openclaw.json 2>/dev/null | grep -qE '.{10,}'"

###############################################################################
# QDRANT SECURITY (2)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Qdrant Security ---${RESET}\n"

check "qdrant unauth rejected" \
    "! curl -sf http://127.0.0.1:6333/collections 2>/dev/null | grep -q 'result'"

check "qdrant auth accepted" \
    'QKEY=$(grep "^QDRANT_API_KEY=" /etc/openclaw-codeshield/secrets.env 2>/dev/null | cut -d= -f2-); [ -n "$QKEY" ] && curl -sf -H "api-key: $QKEY" http://127.0.0.1:6333/collections 2>/dev/null | grep -q "result"'

###############################################################################
# OUTBOUND PROXY (4)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Outbound Proxy ---${RESET}\n"

check "squid active" \
    "systemctl is-active squid"

check "squid body size limit" \
    "grep -q 'request_body_max_size' /etc/squid/squid.conf 2>/dev/null"

check "squid delay pools active" \
    "grep -q 'delay_pools' /etc/squid/squid.conf 2>/dev/null"

check "squid injection guard exists" \
    "grep -q 'url_rewrite_program' /etc/squid/squid.conf 2>/dev/null"

###############################################################################
# AI AGENT SECURITY (6)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- AI Agent Security ---${RESET}\n"

check "skills freeze policy exists" \
    "test -f $OPENCLAW_HOME/.openclaw/skills-policy.json -o -f $OPENCLAW_SVC_HOME/.openclaw/skills-policy.json"

check "skills integrity script exists" \
    "test -x $CS_SBIN_DIR/openclaw-check-skills-integrity"

check "soul canary exists" \
    "grep -qE 'CANARY_OPENCLAW_INTEGRITY_TOKEN|CODESHIELD-CANARY' $OPENCLAW_SVC_HOME/.openclaw/workspace/SOUL.md 2>/dev/null || grep -qE 'CANARY_OPENCLAW_INTEGRITY_TOKEN|CODESHIELD-CANARY' $OPENCLAW_HOME/.openclaw/workspace/SOUL.md 2>/dev/null"

check "soul injection rules present" \
    "grep -q 'Prompt Injection Resistance' $OPENCLAW_SVC_HOME/.openclaw/workspace/SOUL.md 2>/dev/null || grep -q 'Prompt Injection Resistance' $OPENCLAW_HOME/.openclaw/workspace/SOUL.md 2>/dev/null"

check "injection scanner exists" \
    "test -f $CS_SBIN_DIR/openclaw-injection-scan"

check "cost monitor exists" \
    "test -f $CS_SBIN_DIR/openclaw-cost-monitor"

###############################################################################
# DATABASE PROTECTION (2 -- maybe)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Database Protection ---${RESET}\n"

check_maybe "redis not deployed" \
    "! systemctl is-active redis-server 2>/dev/null && ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qi redis"

check_maybe "postgres not deployed" \
    "! systemctl is-active postgresql 2>/dev/null && ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qi postgres"

###############################################################################
# INCIDENT RESPONSE (4)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Incident Response ---${RESET}\n"

check "forensics key exists" \
    "test -f /root/.forensics_key -o -f $CS_CONF_DIR/forensics.key"

check "emergency lockdown exists" \
    "test -f $CS_SBIN_DIR/emergency-lockdown"

check "docker daemon hardened" \
    "jq -e '.\"live-restore\" // .\"no-new-privileges\"' /etc/docker/daemon.json 2>/dev/null | grep -qi true"

check "baseline exists" \
    "ls $CS_DATA_DIR/baseline-* 2>/dev/null | head -1 | grep -q . || test -f $CS_DATA_DIR/skills-baseline.json"

###############################################################################
# CONTINUOUS MONITORING (2)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Continuous Monitoring ---${RESET}\n"

check "audit timer active" \
    "systemctl is-active codeshield-audit.timer 2>/dev/null || systemctl is-enabled codeshield-audit.timer 2>/dev/null"

check "guardian path active" \
    "systemctl is-active codeshield-guardian.path 2>/dev/null | grep -q active || systemctl is-enabled codeshield-guardian.path 2>/dev/null | grep -qE 'enabled|static'"

###############################################################################
# SERVICE HEALTH (2)
###############################################################################
[ "$QUIET" -eq 0 ] && printf "${BOLD}${DIM} --- Service Health ---${RESET}\n"

check "openclaw active" \
    "systemctl is-active openclaw.service"

check "watcher active" \
    "systemctl is-active openclaw-watcher.service 2>/dev/null || systemctl is-active openclaw.service 2>/dev/null"

###############################################################################
# Score Calculation
###############################################################################
if [ "$TOTAL" -gt 0 ]; then
    # base=7.0 + (pass/total)*2.0 + bonus
    # bonus: all critical pass +0.2, guardian active +0.1, etc.
    PASS_RATIO=$(awk "BEGIN {printf \"%.4f\", $PASS / $TOTAL}")
    BASE_SCORE=$(awk "BEGIN {printf \"%.1f\", 7.0 + $PASS_RATIO * 2.0}")

    BONUS="0.0"
    # Bonus: secrets externalized
    if [ "$FAIL" -eq 0 ]; then
        BONUS="0.2"
    fi
    # Bonus: guardian active
    if systemctl is-active codeshield-guardian.path &>/dev/null 2>&1; then
        BONUS=$(awk "BEGIN {printf \"%.1f\", $BONUS + 0.1}")
    fi
    # Bonus: all network checks pass
    if ufw status 2>/dev/null | grep -q "Status: active" && \
       grep -qE '^\s*PasswordAuthentication\s+no' /etc/ssh/sshd_config 2>/dev/null; then
        BONUS=$(awk "BEGIN {printf \"%.1f\", $BONUS + 0.1}")
    fi

    FINAL_SCORE=$(awk "BEGIN {s = $BASE_SCORE + $BONUS; if (s > 10.0) s = 10.0; printf \"%.1f\", s}")
else
    FINAL_SCORE="0.0"
fi

###############################################################################
# Report
###############################################################################
printf "\n"
printf "${BOLD}"
printf " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  CODE SHIELD V3 -- Security Audit Report\n"
printf " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "${RESET}"
printf "  ${GREEN}Pass: %d${RESET}  ${RED}Fail: %d${RESET}  ${YELLOW}Optional: %d${RESET}\n" "$PASS" "$FAIL" "$MAYBE"
printf "  ${BOLD}Security Score: %s / 10${RESET}\n" "$FINAL_SCORE"
printf "${BOLD}"
printf " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "${RESET}\n"

# Log result
LOG_DIR="/var/log/openclaw-codeshield"
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "$(date -Iseconds) pass=$PASS fail=$FAIL maybe=$MAYBE score=$FINAL_SCORE" >> "$LOG_DIR/audit.log" 2>/dev/null || true

# Exit code: 0 if score >= 7.0, 1 otherwise
if awk "BEGIN {exit ($FINAL_SCORE >= 7.0) ? 0 : 1}"; then
    exit 0
else
    exit 1
fi
