# CODE SHIELD V3

**AI Agent Network Security Hardening System**

CODE SHIELD V3 is a comprehensive, production-grade security framework designed to protect AI agents running on Linux servers. It provides defense-in-depth through user isolation, secret externalization, outbound proxy whitelisting, prompt injection detection, and a guardian service that automatically re-applies protection after agent updates. Originally built to harden OpenClaw -- an AI agent that manages Telegram bots, vector databases, e-commerce data, and more -- CODE SHIELD V3 achieves a target security score of 9.0/10 across 36 automated audit checks.

---

**CODE SHIELD V3 -- AI Agent 网络安全加固系统**

CODE SHIELD V3 是一套完整的生产级安全框架，专为运行在 Linux 服务器上的 AI Agent 设计。它通过用户隔离、密钥外迁、出站代理白名单、Prompt 注入检测和 Guardian 守护服务提供纵深防御。当 AI Agent 更新时，Guardian 自动重新生效所有安全防护，不影响 Telegram 对接、JARVIS/TRUE RECALL 记忆系统、PostgreSQL/Redis/Qdrant 数据库以及 Agent 本身的运作。本系统针对 OpenClaw AI Agent 构建，通过 36 项自动化安全审计实现 9.0/10 的目标安全评分。

---

## Quick Start / 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

The installer is interactive only when collecting API keys (Telegram, Brave, OpenAI, Qdrant). Everything else runs fully automatically.

安装程序仅在收集 API 密钥时暂停交互，其余全部自动执行。

---

## What It Protects / 保护范围

| Protected Asset / 保护对象 | Threat / 威胁 | Defense / 防护措施 |
|---|---|---|
| API Keys & Tokens | Inline credential exposure | Secrets externalized to `/etc/openclaw-codeshield/secrets.env` (0600 root) with systemd EnvironmentFile injection |
| Qdrant Vector DB (JARVIS + TRUE RECALL) | Unauthorized access, data exfiltration | API key authentication, port bound to 127.0.0.1, DOCKER-USER iptables drop rules |
| Telegram Bot | Token theft, message interception | Keys managed by CODE SHIELD, not stored in openclaw.json |
| OpenClaw Agent Process | Privilege escalation, container escape | Isolated `openclaw-svc` user, removed from docker/sudo groups, systemd hardening (NoNewPrivileges, ProtectSystem=strict) |
| Server SSH | Brute force, password attacks | Password auth disabled, MaxAuthTries=3, fail2ban with 1-hour bans |
| Outbound Network | Data exfiltration, C2 communication | Squid proxy whitelist (3 domains only), 64KB request body limit, delay pools rate limiting |
| AI Prompts / SOUL.md | Prompt injection, identity hijack | Canary tokens, 10-rule injection resistance framework, 15-minute session scanning |
| Skills / Tools | Unauthorized tool invocation | Whitelist-only skills-policy.json, integrity baseline checksums |
| DNS | DNS exfiltration tunneling | iptables uid-owner rules blocking port 53 for openclaw-svc |
| Update Continuity | Security loss after agent updates | Guardian systemd path unit auto-detects updates and re-applies all protections |

---

## Interactive Installation / 交互式安装

The installer runs in 6 stages:

```
[1/6] Environment Pre-Flight     -- Checks OS, dependencies, disk space
[2/6] Secret Collection           -- Interactive: Telegram, Brave, OpenAI, Qdrant keys
[3/6] User Isolation & Migration  -- Creates openclaw-svc, migrates secrets, installs drop-in
[4/6] Qdrant Security             -- API key auth, 127.0.0.1 binding, DOCKER-USER rules
[5/6] System Hardening            -- SSH, UFW, fail2ban, IPv6, Squid, auditd, DNS block
[6/6] Injection Defense           -- SOUL.md canary, skills policy, scanner timer, cost monitor
[POST] Guardian Installation      -- systemd path unit for update detection
[FINAL] Security Audit            -- 36-item check with score
```

Command-line flags:

| Flag | Description |
|---|---|
| `--dry-run` | Show what would be done without making changes |
| `--skip-preflight` | Skip environment pre-checks |
| `--update` | Non-interactive re-apply (used by Guardian after OpenClaw updates) |

---

## OpenClaw Update Compatibility / OpenClaw 更新兼容性

When OpenClaw is updated via:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

The **codeshield-guardian.path** systemd unit detects changes to:
- `/home/openclaw/.npm-global/lib/node_modules/openclaw/package.json`
- `/home/openclaw/.openclaw/openclaw.json`

Upon detection, the Guardian service (`/usr/local/sbin/openclaw-guardian`) executes:

1. Migrates any new inline secrets from openclaw.json to secrets.env
2. Verifies/recreates the systemd drop-in (EnvironmentFile, User=openclaw-svc)
3. Syncs openclaw data to the isolated service home
4. Restores SOUL.md canary token and injection resistance if overwritten
5. Restores skills-policy.json if missing
6. Regenerates skills baseline checksums
7. Runs `systemctl daemon-reload && systemctl restart openclaw`
8. Sends Telegram notification confirming re-application

This ensures zero-downtime protection continuity. No manual intervention required.

Guardian 确保 OpenClaw 每次更新后自动重新生效所有安全防护，无需手动干预。

---

## Security Audit / 安全审计

Run the audit at any time:

```bash
security-audit.sh
```

### 36-Item Checklist / 36 项检查清单

**Network Security (10)**
- ufw active
- ssh password disabled
- ssh keyboard-interactive disabled
- root key-only login
- fail2ban sshd active
- ipv6 disabled
- zerotier online
- zerotier private network
- docker-user drop rules
- dns direct query blocked

**Access Control (8)**
- openclaw not in docker group
- openclaw not in sudo group
- openclaw-svc exists
- openclaw service isolated user
- watcher isolated user
- controlled sudoers present
- secrets file permissions (0600)
- no inline secrets in openclaw.json

**Qdrant Security (2)**
- qdrant unauth rejected
- qdrant auth accepted

**Outbound Proxy (4)**
- squid active
- squid body size limit
- squid delay pools active
- squid injection guard exists

**AI Agent Security (6)**
- skills freeze policy exists
- skills integrity script exists
- soul canary exists
- soul injection rules present
- injection scanner exists
- cost monitor exists

**Database Protection (2 -- optional)**
- redis not deployed
- postgres not deployed

**Incident Response (4)**
- forensics key exists
- emergency lockdown exists
- docker daemon hardened
- baseline exists

**Continuous Monitoring (2)**
- audit timer active
- guardian path active

**Service Health (2)**
- openclaw active
- watcher active

### Sample Output

```
 [PASS] ufw active
 [PASS] ssh password disabled
 [PASS] ssh keyboard-interactive disabled
 ...
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CODE SHIELD V3 -- Security Audit Report
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Pass: 36  Fail: 0  Optional: 2
  Security Score: 9.2 / 10
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Architecture / 架构图

```
                          +-------------------+
                          |   Administrator   |
                          |   (SSH key-only)  |
                          +--------+----------+
                                   |
                          +--------v----------+
                          |   UFW Firewall    |
                          |  (deny incoming)  |
                          +--------+----------+
                                   |
                +------------------+------------------+
                |                                     |
    +-----------v-----------+           +-------------v-----------+
    |  fail2ban (SSH guard) |           |  ZeroTier VPN (private) |
    +-----------+-----------+           +-------------+-----------+
                |                                     |
                +------------------+------------------+
                                   |
          +------------------------v--------------------------+
          |                Ubuntu Server                      |
          |                                                   |
          |  +------------------------------------------+     |
          |  | openclaw.service (User=openclaw-svc)     |     |
          |  | EnvironmentFile=secrets.env              |     |
          |  | NoNewPrivileges / ProtectSystem=strict    |     |
          |  +-----+------+------+-----+----------+----+     |
          |        |      |      |     |          |           |
          |   +----v--+ +-v----+ | +---v---+ +----v-------+  |
          |   |Telegr.| |Brave | | |OpenAI | | Qdrant DB  |  |
          |   | API   | |Search| | | API   | | 127.0.0.1  |  |
          |   +---+---+ +--+---+ | +---+---+ | API-key    |  |
          |       |         |    |     |      +----+-------+  |
          |       +----+----+----+-----+           |          |
          |            |                           |          |
          |       +----v--------------------+      |          |
          |       | Squid Proxy (whitelist) |      |          |
          |       | 3 domains / 64KB limit  |      |          |
          |       | injection guard (py)    |      |          |
          |       | delay_pools rate limit  |      |          |
          |       +-------------------------+      |          |
          |                                        |          |
          |  +-------------------------------------v-----+    |
          |  | PostgreSQL / Redis (store data)           |    |
          |  +-------------------------------------------+    |
          |                                                   |
          |  +-------------------------------------------+    |
          |  | codeshield-guardian.path                   |    |
          |  | Watches: openclaw/package.json             |    |
          |  | Triggers: secret migration, drop-in,      |    |
          |  |           SOUL.md canary, skills policy    |    |
          |  +-------------------------------------------+    |
          |                                                   |
          |  +-------------------------------------------+    |
          |  | auditd rules | DNS block (iptables uid)   |    |
          |  | injection scanner (15min) | cost monitor   |    |
          |  | emergency-lockdown (AES forensics)         |    |
          |  +-------------------------------------------+    |
          +---------------------------------------------------+
```

---

## Scoring / 评分说明

Score formula / 评分公式:

```
base = 7.0
pass_bonus = (pass_count / total_checks) * 2.0
extra_bonus:
  +0.2  if zero failures
  +0.1  if guardian path unit is active
  +0.1  if network hardening (UFW + SSH) fully applied

final_score = min(base + pass_bonus + extra_bonus, 10.0)
```

Target: **9.0 / 10** with all checks passing.

---

## File Structure / 文件结构

```
codeshield-v3/
|-- install.sh                    # One-line installer entry point
|-- lib/
|   |-- 00-preflight.sh           # Environment pre-checks
|   |-- 01-collect-secrets.sh     # Interactive secret collection
|   |-- 02-isolation.sh           # User isolation & secret migration
|   |-- 03-qdrant.sh              # Qdrant auth & network binding
|   |-- 04-hardening.sh           # SSH/UFW/fail2ban/Squid/auditd
|   |-- 05-injection-defense.sh   # Prompt injection defense
|   `-- 06-guardian.sh            # Guardian watchdog service
|-- scripts/
|   |-- security-audit.sh         # 36-item security audit
|   |-- openclaw-injection-scan   # Session injection scanner
|   |-- openclaw-cost-monitor     # API cost monitoring
|   |-- openclaw-guardian         # Update re-application hook
|   |-- emergency-lockdown        # Emergency lockdown with AES forensics
|   `-- squid-injection-guard.py  # Squid URL rewrite injection filter
|-- templates/
|   |-- squid.conf                # Squid proxy configuration template
|   |-- soul-injection.md         # SOUL.md injection resistance chapter
|   `-- skills-policy.json        # Skills whitelist freeze policy
`-- README.md                     # This file (bilingual EN/ZH)
```

### Installation Paths

| Path | Purpose |
|---|---|
| `/etc/openclaw-codeshield/` | Configuration directory (secrets.env, forensics.key) |
| `/usr/local/sbin/` | Executable tools (security-audit.sh, openclaw-guardian, etc.) |
| `/usr/local/lib/openclaw-codeshield/` | Library files and templates |
| `/var/log/openclaw-codeshield/` | Log files (guardian, audit, injection scan) |
| `/var/lib/openclaw-codeshield/` | Data files (baselines, canary, metadata) |
| `/var/lib/openclaw-svc/.openclaw/` | Isolated OpenClaw data directory |

---

## Changelog / 版本历史

### V3.0.0 (Current / 当前版本)
- Complete rewrite as modular installer with 6 stages
- Guardian systemd path unit for automatic update compatibility
- 36-item security audit with scoring formula
- Squid injection guard (Python URL rewriter)
- SOUL.md canary tokens and injection resistance framework
- Skills freeze policy with integrity baselines
- Emergency lockdown with AES-256 encrypted forensics
- Cost monitoring with Telegram alerts
- Session injection scanner (15-minute intervals)
- DNS exfiltration blocking via iptables uid-owner rules
- Docker daemon hardening (icc=false, no-new-privileges)
- One-line `curl | bash` installation with /dev/tty interactive input

### V2.x (Previous Stages / 之前的阶段版本)
- Stage 1: SSH hardening and UFW configuration
- Stage 2: Qdrant authentication and secret migration
- Stage 3: Squid proxy whitelist and fail2ban
- Stage 4: Injection defense and session scanning

---

## License

MIT License

Copyright (c) 2026 CODE SHIELD V3 Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
