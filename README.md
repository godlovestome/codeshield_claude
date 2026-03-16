# CODE SHIELD V3.0.2

**AI Agent Network Security Hardening System**

CODE SHIELD V3 is a comprehensive, production-grade security framework designed to protect AI agents running on Linux servers. It provides defense-in-depth through user isolation, secret encryption (systemd-creds), outbound proxy whitelisting, prompt injection detection, container privilege reduction, systemd sandbox hardening, and a guardian service that automatically re-applies protection after agent updates. Originally built to harden OpenClaw -- an AI agent that manages Telegram bots, vector databases, e-commerce data, and more -- CODE SHIELD V3.0.2 achieves a security score of **9.5/10** across **56 automated audit checks**.

---

**CODE SHIELD V3.0.2 -- AI Agent 网络安全加固系统**

CODE SHIELD V3 是一套完整的生产级安全框架，专为运行在 Linux 服务器上的 AI Agent 设计。它通过用户隔离、密钥加密存储（systemd-creds）、出站代理白名单、Prompt 注入检测、容器权限限制、systemd 沙箱加固和 Guardian 守护服务提供纵深防御。当 AI Agent 更新时，Guardian 自动重新生效所有安全防护，不影响 Telegram 对接、JARVIS/TRUE RECALL 记忆系统、PostgreSQL/Redis/Qdrant 数据库以及 Agent 本身的运作。本系统针对 OpenClaw AI Agent 构建，通过 **56 项**自动化安全审计实现 **9.5/10** 的安全评分。

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
| API Keys & Tokens | Inline credential exposure, disk theft | **Secrets encrypted at rest** (systemd-creds, host key bound); decrypted to tmpfs (RAM) only at runtime; keys fully deleted from openclaw.json |
| Qdrant Vector DB (JARVIS + TRUE RECALL) | Unauthorized access, container escape, data exfiltration | API key authentication, port bound to 127.0.0.1, DOCKER-USER iptables rules, **cap_drop ALL**, **no-new-privileges**, **read_only filesystem** with tmpfs |
| Telegram Bot | Token theft, message interception | Keys managed by CODE SHIELD, encrypted at rest, not stored in openclaw.json |
| OpenClaw Agent Process | Privilege escalation, lateral movement | Isolated `openclaw-svc` user, removed from docker/sudo groups, **systemd sandbox** (ProtectSystem=strict, CapabilityBoundingSet=, RestrictAddressFamilies, SystemCallFilter, ProtectHome=yes) |
| Server SSH | Brute force, tunneling, password attacks | Password auth disabled, MaxAuthTries=3, MaxSessions=3, **AllowTcpForwarding=no**, **AllowAgentForwarding=no**, fail2ban with 1-hour bans, sshd_config.d drop-in |
| Outbound Network | Data exfiltration, C2 communication, proxy bypass | **Comprehensive iptables block** with LOG: all non-loopback outbound from openclaw-svc dropped at kernel level; agent must use Squid at 127.0.0.1:3128 |
| Squid Proxy | Request smuggling, DNS exfiltration | Whitelist (3 domains only), 64KB request body limit, delay pools rate limiting, Python injection guard |
| AI Prompts / SOUL.md | Prompt injection, identity hijack | Canary tokens, 10-rule injection resistance framework, 15-minute session scanning |
| Skills / Tools | Unauthorized tool invocation | Whitelist-only skills-policy.json, integrity baseline checksums |
| DNS | DNS exfiltration tunneling | iptables uid-owner comprehensive rule blocks all external DNS for openclaw-svc |
| Update Continuity | Security loss after agent updates | Guardian systemd path unit auto-detects updates and re-applies all protections |
| Kernel / OS | Core dump leaks, privilege escalation | `fs.suid_dumpable=0`, `kernel.kptr_restrict=1`, `kernel.dmesg_restrict=1`, Docker `icc=false` |

---

## Interactive Installation / 交互式安装

The installer runs in 7 stages:

```
[1/7] Environment Pre-Flight     -- Checks OS, dependencies, disk space
[2/7] Secret Collection           -- Interactive: Telegram, Brave, OpenAI, Qdrant keys
[3/7] User Isolation & Migration  -- Creates openclaw-svc, migrates secrets, installs drop-in
[4/7] Qdrant Security             -- API key auth, 127.0.0.1 binding, cap_drop ALL, read_only
[5/7] System Hardening            -- SSH, UFW, fail2ban, IPv6, Squid, iptables block+LOG, systemd sandbox
[6/7] Injection Defense           -- SOUL.md canary, skills policy, scanner timer, cost monitor
[7/7] Secrets Encryption          -- systemd-creds encryption, tmpfs decryption, reseal timer
[POST] Guardian Installation      -- systemd path unit for update detection
[FINAL] Security Audit            -- 56-item check with score
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

1. Migrates any new inline secrets from openclaw.json to secrets.env (and fully deletes them from JSON)
2. Re-encrypts secrets with `codeshield-secrets-reseal`
3. Verifies/recreates the systemd drop-in (EnvironmentFile, User=openclaw-svc)
4. Syncs openclaw data to the isolated service home
5. Restores SOUL.md canary token and injection resistance if overwritten
6. Restores skills-policy.json if missing
7. Regenerates skills baseline checksums
8. Runs `systemctl daemon-reload && systemctl restart codeshield-secrets && systemctl restart openclaw`
9. Sends Telegram notification confirming re-application

This ensures zero-downtime protection continuity. No manual intervention required.

Guardian 确保 OpenClaw 每次更新后自动重新生效所有安全防护，无需手动干预。

---

## Security Audit / 安全审计

Run the audit at any time:

```bash
security-audit.sh
```

### 56-Item Checklist / 56 项检查清单

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

**Access Control (11)**
- openclaw not in docker group
- openclaw not in sudo group
- openclaw-svc exists
- openclaw service isolated user
- watcher isolated user
- controlled sudoers present
- secrets file permissions
- secrets encrypted at rest
- secrets decrypted to tmpfs
- codeshield-secrets service active
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

**V3.0.1 Security Fixes (6)**
- qdrant cap_drop all
- qdrant no-new-privileges
- force proxy non-loopback block
- openclaw protect system
- openclaw capability bounding
- no inline gateway token

**V3.0.2 Security Fixes (9)** *(new)*
- ssh forwarding disabled
- ssh agent forwarding disabled
- ssh max sessions limited
- fs.suid_dumpable disabled
- docker icc disabled
- iptables outbound logging
- reseal timer active
- systemd restrict address families
- systemd syscall filter

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
 ...
 [PASS] secrets encrypted at rest
 [PASS] secrets decrypted to tmpfs
 ...
 [PASS] ssh forwarding disabled
 [PASS] docker icc disabled
 [PASS] systemd syscall filter
 ...
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CODE SHIELD V3 -- Security Audit Report
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Pass: 56  Fail: 0  Optional: 2
  Security Score: 9.5 / 10
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
          |  | codeshield-secrets.service (oneshot)      |     |
          |  | secrets.env.enc → tmpfs (systemd-creds)  |     |
          |  +-----+------------------------------------+     |
          |        |                                          |
          |  +-----v------------------------------------+     |
          |  | openclaw.service (User=openclaw-svc)     |     |
          |  | EnvironmentFile=/run/.../secrets.env      |     |
          |  | ProtectSystem=strict / CapabilityBound=  |     |
          |  | RestrictAddressFamilies / SystemCallFilter|     |
          |  | ProtectHome=yes / NoNewPrivileges=yes     |     |
          |  +-----+------+------+-----+----------+----+     |
          |        |      |      |     |          |           |
          |   +----v--+ +-v----+ | +---v---+ +----v-------+  |
          |   |Telegr.| |Brave | | |OpenAI | | Qdrant DB  |  |
          |   | API   | |Search| | | API   | | 127.0.0.1  |  |
          |   +---+---+ +--+---+ | +---+---+ | cap_drop   |  |
          |       |         |    |     |      | read_only  |  |
          |       +----+----+----+-----+      +----+-------+  |
          |            |                           |          |
          |       +----v--------------------+      |          |
          |       | Squid Proxy (whitelist) |      |          |
          |       | 3 domains / 64KB limit  |      |          |
          |       | injection guard (py)    |      |          |
          |       | delay_pools rate limit  |      |          |
          |       +-------------------------+      |          |
          |                                        |          |
          |  iptables: uid-owner openclaw-svc      |          |
          |  ! -d 127.0.0.0/8 -j LOG + DROP       |          |
          |  (all external blocked at kernel)      |          |
          |                                        |          |
          |  +-------------------------------------------+    |
          |  | codeshield-guardian.path                   |    |
          |  | Watches: openclaw/package.json             |    |
          |  | Triggers: secret migration, re-seal,      |    |
          |  |           drop-in, SOUL.md, skills policy  |    |
          |  +-------------------------------------------+    |
          |                                                   |
          |  +-------------------------------------------+    |
          |  | auditd rules | DNS block (iptables uid)   |    |
          |  | injection scanner (15min) | cost monitor   |    |
          |  | emergency-lockdown (AES forensics)         |    |
          |  | codeshield-reseal.timer (monthly)          |    |
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
  +0.1  if secrets encrypted at rest (V3.0.2)

final_score = min(base + pass_bonus + extra_bonus, 10.0)
```

| Version | Automated Checks | Score |
|---------|-----------------|-------|
| V3.0.0  | 38/38           | 9.3/10 |
| V3.0.1  | 42/42           | 9.3/10 |
| **V3.0.2** | **56/56**   | **9.5/10** |

Professional audit score (manual review): **~9.0/10** (up from 7.3 in V3.0.0)

---

## File Structure / 文件结构

```
codeshield-v3/
|-- install.sh                    # One-line installer entry point
|-- lib/
|   |-- 00-preflight.sh           # Environment pre-checks
|   |-- 01-collect-secrets.sh     # Interactive secret collection
|   |-- 02-isolation.sh           # User isolation & secret migration + encryption
|   |-- 03-qdrant.sh              # Qdrant auth, network binding, cap_drop
|   |-- 04-hardening.sh           # SSH/UFW/fail2ban/sysctl/Squid/iptables/systemd sandbox
|   |-- 05-injection-defense.sh   # Prompt injection defense
|   `-- 06-guardian.sh            # Guardian watchdog service
|-- scripts/
|   |-- security-audit.sh         # 56-item security audit
|   |-- openclaw-injection-scan   # Session injection scanner
|   |-- openclaw-cost-monitor     # API cost monitoring
|   |-- openclaw-guardian         # Update re-application hook
|   |-- emergency-lockdown        # Emergency lockdown with AES forensics
|   |-- squid-injection-guard.py  # Squid URL rewrite injection filter
|   |-- codeshield-secrets-seal   # Encrypt secrets.env → .enc
|   |-- codeshield-secrets-unseal # Decrypt .enc → tmpfs at service start
|   |-- codeshield-secrets-reseal # Re-seal after Guardian migration
|   `-- codeshield-secrets-migrate # One-time plaintext → encrypted migration
|-- templates/
|   |-- squid.conf                # Squid proxy configuration template
|   |-- soul-injection.md         # SOUL.md injection resistance chapter
|   |-- skills-policy.json        # Skills whitelist freeze policy
|   |-- codeshield-secrets.service # systemd unit for secret decryption
|   |-- codeshield-reseal.service  # Monthly re-seal oneshot
|   `-- codeshield-reseal.timer    # Monthly re-seal timer
|-- CHANGELOG.md                  # Version history and fix details
`-- README.md                     # This file (bilingual EN/ZH)
```

### Installation Paths

| Path | Purpose |
|---|---|
| `/etc/openclaw-codeshield/` | Configuration directory (secrets.env.enc, forensics.key) |
| `/run/openclaw-codeshield/` | Tmpfs-backed secrets (RAM only, auto-cleaned) |
| `/usr/local/sbin/` | Executable tools (security-audit.sh, codeshield-secrets-*, etc.) |
| `/usr/local/lib/openclaw-codeshield/` | Library files and templates |
| `/var/log/openclaw-codeshield/` | Log files (guardian, audit, injection scan, reseal) |
| `/var/lib/openclaw-codeshield/` | Data files (baselines, canary, metadata) |
| `/var/lib/openclaw-svc/.openclaw/` | Isolated OpenClaw data directory |

---

## Changelog / 版本历史

### V3.0.2 (2026-03-16) — Security Hardening Round 2 / 安全加固第二轮

Eight fixes from professional security audit round 2:

- **P1** SSH tunneling blocked (`AllowTcpForwarding=no`, `AllowAgentForwarding=no`, `MaxSessions=3` via sshd_config.d drop-in)
- **P2** Kernel hardening (`fs.suid_dumpable=0`, `kernel.kptr_restrict=1`, `kernel.dmesg_restrict=1`)
- **P3** Docker inter-container communication disabled (`icc=false` force-applied)
- **P4** systemd sandbox enhanced (`RestrictAddressFamilies`, `SystemCallFilter=@system-service`)
- **P5** **Secrets encrypted at rest** (systemd-creds + host key, tmpfs runtime decryption, 4 management scripts)
- **P6** Outbound traffic logging (`iptables LOG` with `CODESHIELD-BLOCK:` prefix)
- **P7** Monthly credential re-seal timer (`codeshield-reseal.timer`)
- **P8** auditd expanded to monitor SSH, sudoers, and squid configs

9 new audit checks added (56 total, up from 47). Score: **9.5/10**.

### V3.0.1 (2026-03-16) — Security Patch / 安全补丁

Four priority fixes from professional security audit:

- **P1** Qdrant container privilege reduction (cap_drop ALL, no-new-privileges, read_only)
- **P2** Comprehensive iptables outbound block (non-loopback DROP, TRUE RECALL restored)
- **P3** systemd service sandbox (ProtectSystem=strict, CapabilityBoundingSet=, ProtectHome=yes)
- **P4** Complete secret removal from openclaw.json (del/pop, not blank)

6 new audit checks added (42 total, up from 36).

### V3.0.0 (2026-03-15) — Initial Release

- Complete rewrite as modular installer with 6 stages
- Guardian systemd path unit for automatic update compatibility
- 36-item security audit with scoring formula
- Squid injection guard, SOUL.md canary, skills policy, emergency lockdown
- One-line `curl | bash` installation

See [CHANGELOG.md](CHANGELOG.md) for full technical details.

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
