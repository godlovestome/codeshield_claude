# CODE SHIELD V3.0.7

**AI Agent Network Security Hardening System**

CODE SHIELD V3 is a comprehensive, production-grade security framework designed to protect AI agents running on Linux servers. It provides defense-in-depth through user isolation, secret encryption (systemd-creds), outbound proxy whitelisting, prompt injection detection, container privilege reduction, systemd sandbox hardening, and a guardian service that automatically re-applies protection after agent updates. V3.0.7 fixes a crash in `codeshield-config add-model`/`add-channel` when adding new providers whose API keys don't yet exist in the secrets file. Originally built to harden OpenClaw, CODE SHIELD achieves a security score of **9.5/10** across **56 automated audit checks**.

---

**CODE SHIELD V3.0.7 -- AI Agent 网络安全加固系统**

CODE SHIELD V3 是一套完整的生产级安全框架，专为运行在 Linux 服务器上的 AI Agent 设计。V3.0.7 修复了 `codeshield-config add-model`/`add-channel` 在添加密钥文件中尚不存在的新提供商时崩溃的问题。本系统通过 **56 项**自动化安全审计实现 **9.5/10** 的安全评分。

---

## Quick Start / 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

## 无损更新CODE SHIELD
```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

The installer is interactive only when collecting API keys (Telegram, Brave, OpenAI, Anthropic, GLM5, Kimi 2.5, Qdrant). Everything else runs fully automatically. After installation, use `codeshield-config` to manage configuration without re-running the installer.

安装程序仅在收集 API 密钥时暂停交互（Telegram、Brave、OpenAI、Anthropic、DeepSeek、GLM5、Kimi、MiniMax、Qdrant），其余全部自动执行。安装后可使用 `codeshield-config` 管理配置，无需重新运行安装程序。

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

## Configuration Management / 配置管理 (V3.0.7)

After installation, use `codeshield-config` to manage all settings without re-running the installer or `openclaw onboard`. All built-in providers and channels use **interactive menus** — no manual domain input required.

安装后使用 `codeshield-config` 管理所有设置，无需重新运行安装程序或 `openclaw onboard`。所有内置提供商和通道均使用**交互式菜单**——无需手动输入域名。

```bash
# View current configuration (secrets masked)
# 查看当前配置（密钥脱敏显示）
codeshield-config show

# Set a single key / 设置单个配置项
codeshield-config set ANTHROPIC_API_KEY=sk-ant-xxx

# Interactive edit all secrets / 交互式编辑所有密钥
codeshield-config edit

# Add an LLM provider (interactive menu, domains auto-filled)
# 添加大模型提供商（交互式菜单，域名自动填充）
codeshield-config add-model
#   1) OpenAI (API Key)       2) OpenAI (OAuth)
#   3) Anthropic / Claude     4) DeepSeek (深度求索)
#   5) GLM5 (智谱 BigModel)   6) Kimi (月之暗面 Moonshot)
#   7) MiniMax                8) Custom (自定义)

# Add a messaging channel (interactive menu, domains auto-filled)
# 添加消息通道（交互式菜单，域名自动填充）
codeshield-config add-channel
#   1) 企业微信 (WeCom)    2) 飞书 (Feishu)
#   3) Discord             4) Custom (自定义)

# Add a domain to Squid proxy whitelist / 添加域名到 Squid 白名单
codeshield-config proxy-allow open.feishu.cn

# List configured channels and models / 列出已配置的通道和模型
codeshield-config list-channels
codeshield-config list-models
```

**Key behaviors / 核心行为:**
- Automatically decrypts secrets → modifies → re-encrypts (systemd-creds) / 自动解密 → 修改 → 重新加密
- Automatically updates Squid proxy whitelist when adding channels/models / 添加通道/模型时自动更新 Squid 白名单
- Automatically restarts openclaw.service after changes / 修改后自动重启 openclaw 服务
- Channel and model configs stored in `/etc/openclaw-codeshield/channels.d/` and `models.d/`

**Supported LLM Providers (built-in) / 支持的大模型提供商（内置）:**

| Provider / 提供商 | API Domain | Auth / 认证方式 | Env Vars / 环境变量 |
|----------|-----------|------|----------|
| OpenAI | `api.openai.com` | API Key | `OPENAI_API_KEY` |
| OpenAI OAuth | `api.openai.com`, `auth0.openai.com` | OAuth 2.0 | `OPENAI_CLIENT_ID`, `OPENAI_CLIENT_SECRET`, `OPENAI_ORG_ID` |
| Anthropic / Claude | `api.anthropic.com` | API Key | `ANTHROPIC_API_KEY` |
| DeepSeek (深度求索) | `api.deepseek.com` | API Key | `DEEPSEEK_API_KEY` |
| GLM5 (智谱 BigModel) | `open.bigmodel.cn` | API Key | `GLM_API_KEY` |
| Kimi (月之暗面 Moonshot) | `api.moonshot.cn` | API Key | `KIMI_API_KEY` |
| MiniMax | `api.minimax.io` | API Key | `MINIMAX_API_KEY`, `MINIMAX_GROUP_ID` |
| Custom / 自定义 | User-defined | User-defined | User-defined |

**Supported Channels (built-in) / 支持的消息通道（内置）:**

| Channel / 通道 | API Domain | Env Vars / 环境变量 |
|---------|-----------|----------|
| 企业微信 (WeCom) | `qyapi.weixin.qq.com` | `WECOM_CORP_ID`, `WECOM_AGENT_ID`, `WECOM_SECRET` |
| 飞书 (Feishu) | `open.feishu.cn` | `FEISHU_APP_ID`, `FEISHU_APP_SECRET` |
| Discord | `discord.com`, `cdn.discordapp.com` | `DISCORD_BOT_TOKEN`, `DISCORD_WEBHOOK_URL` |
| Custom / 自定义 | User-defined | User-defined |

---

## Interactive Installation / 交互式安装

The installer runs in 7 stages:

```
[1/7] Environment Pre-Flight     -- Checks OS, dependencies, disk space
[2/7] Secret Collection           -- Interactive: Telegram, Brave, OpenAI (Key/OAuth), Anthropic, GLM5, Kimi 2.5, Qdrant
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
| `--resume` | Resume from last failed stage (V3.0.3) |

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
- firewall active (UFW or netfilter-persistent)
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
 [PASS] firewall active
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
| V3.0.2  | 56/56           | 9.5/10 |
| V3.0.3  | 56/56           | 9.5/10 |
| V3.0.4  | 56/56           | 9.5/10 |
| V3.0.5  | 56/56           | 9.5/10 |
| V3.0.6  | 56/56           | 9.5/10 |
| **V3.0.7** | **56/56**   | **9.5/10** |

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
|   |-- codeshield-config         # Configuration management CLI (V3.0.7)
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
| `/etc/openclaw-codeshield/` | Configuration directory (secrets.env.enc, forensics.key, channels.d/, models.d/) |
| `/run/openclaw-codeshield/` | Tmpfs-backed secrets (RAM only, auto-cleaned) |
| `/usr/local/sbin/` | Executable tools (security-audit.sh, codeshield-secrets-*, etc.) |
| `/usr/local/lib/openclaw-codeshield/` | Library files and templates |
| `/var/log/openclaw-codeshield/` | Log files (guardian, audit, injection scan, reseal) |
| `/var/lib/openclaw-codeshield/` | Data files (baselines, canary, metadata) |
| `/var/lib/openclaw-svc/.openclaw/` | Isolated OpenClaw data directory |

---

## Changelog / 版本历史

### V3.0.7 (2026-03-17) — Bug Fix: `add-model`/`add-channel` crash on new keys / 修复：添加新密钥时崩溃

**Fix: `read_secret()` exits script when key not found / 修复：`read_secret()` 在密钥不存在时导致脚本退出**
- **Root cause / 根因:** `read_secret()` uses a `grep | head | cut` pipeline. When adding a **new** provider (e.g., DeepSeek), the key doesn't exist in `secrets.env`, so `grep` returns exit code 1. With `set -euo pipefail` (line 15), `pipefail` propagates `grep`'s non-zero exit to the pipeline, and `set -e` kills the script silently — the API key prompt never appears.
- **根因描述：** `read_secret()` 使用 `grep | head | cut` 管道。添加**新**提供商（如 DeepSeek）时，密钥在 `secrets.env` 中不存在，`grep` 返回退出码 1。由于 `set -euo pipefail`（第 15 行），`pipefail` 将 `grep` 的非零退出码传播到整个管道，`set -e` 静默终止脚本——API 密钥提示永远不会出现。
- **Fix / 修复:** Added `|| true` to the grep pipeline in `read_secret()` so it returns an empty string (not an error) when a key is missing.
- **修复方式：** 在 `read_secret()` 的 grep 管道末尾添加 `|| true`，使密钥不存在时返回空字符串而非错误。
- **File changed / 修改文件:** `scripts/codeshield-config` (line 101)
- **Impact / 影响:** `codeshield-config add-model` and `add-channel` now correctly prompt for new API keys. Existing keys continue to show `[current: sk-1...xxxx] (Enter to keep):`.

### V3.0.6 (2026-03-17) — Interactive Menu Selection & New Providers / 交互式菜单选择与新增提供商

**New: Interactive Menu-Based LLM Provider Selection / 新增：交互式菜单大模型选择**
- `codeshield-config add-model` now shows a numbered menu (8 choices) with all domains and env vars pre-filled — **no manual domain input required**, eliminating typo errors.
- `codeshield-config add-model` 现在显示编号菜单（8 个选项），所有域名和环境变量自动填充——**无需手动输入域名**，杜绝拼写错误。
- **New providers / 新增提供商:** DeepSeek (`api.deepseek.com`), MiniMax (`api.minimax.io`)
- **Updated providers / 更新提供商:** Anthropic renamed to "Anthropic / Claude", Kimi renamed to "Kimi (月之暗面 Moonshot)"

**New: Built-in Channel Presets / 新增：内置通道预设**
- `codeshield-config add-channel` now shows a numbered menu (4 choices) with built-in presets for common channels — **no manual domain/variable input required**.
- `codeshield-config add-channel` 现在显示编号菜单（4 个选项），内置常用通道预设——**无需手动输入域名和变量名**。
- **Built-in channels / 内置通道:** 企业微信 WeCom (`qyapi.weixin.qq.com`), 飞书 Feishu (`open.feishu.cn`), Discord (`discord.com`)
- Custom channel option retained for user-defined channels / 保留自定义通道选项

**Skills Policy Update / 技能策略更新**
- Added `deepseek-chat` and `minimax-chat` to approved skills list
- 新增 `deepseek-chat` 和 `minimax-chat` 到已批准技能列表

### V3.0.5 (2026-03-17) — DNS Audit Check & Scoring Fix / DNS 审计检查与评分修复

**Fix 1: `dns direct query blocked` audit false failure / 修复 1：`dns direct query blocked` 审计误报**
- **根因：** `iptables -S OUTPUT` 输出对规则字段进行归一化排序，将 `! -d 127.0.0.0/8` 排在 `--uid-owner` **之前**。但审计检查的正则表达式要求 `uid-owner` 出现在 `! -d` 之前，导致模式永远无法匹配。`force proxy non-loopback block` 检查因使用了正确的字段顺序所以通过，但 `dns direct query blocked` 失败。
- **Root cause:** `iptables -S OUTPUT` normalizes rule field order, placing `! -d 127.0.0.0/8` **before** `--uid-owner`. The audit regex required `uid-owner` before `! -d`, so the pattern never matched. The `force proxy non-loopback block` check passed because its regex already used the correct (normalized) field order.
- **修复方式：** 将正则表达式改为 `(uid-owner.*$SVC_UID.*dport 53.*DROP|! -d 127.0.0.0/8.*uid-owner.*$SVC_UID.*DROP)`，第一项匹配专用 DNS 端口规则，第二项按归一化后的字段顺序匹配综合阻断规则。
- **Fix:** Updated regex to `(uid-owner.*$SVC_UID.*dport 53.*DROP|! -d 127.0.0.0/8.*uid-owner.*$SVC_UID.*DROP)` — first alternative matches a dedicated DNS port rule; second matches the comprehensive block in normalized field order.

**Fix 2: Scoring bonus not awarded for `netfilter-persistent` firewall / 修复 2：`netfilter-persistent` 防火墙未获得评分加分**
- **根因：** 评分计算中网络加固加分（+0.1）仅检查 `ufw status`，但系统上 UFW 已被 `iptables-persistent` 替换（V3.0.4 已修复审计检查，但漏掉了评分计算）。
- **Root cause:** The scoring bonus (+0.1 for network hardening) only checked `ufw status`, but UFW was replaced by `iptables-persistent` on the system. V3.0.4 fixed the audit check but missed the scoring calculation.
- **修复方式：** 评分加分逻辑改为同时接受 `ufw status | grep active` 或 `systemctl is-active netfilter-persistent`。
- **Fix:** Scoring bonus now accepts either `ufw status | grep active` or `systemctl is-active netfilter-persistent`.
- **修改文件 / Files changed:** `scripts/security-audit.sh` (lines 120, 340-342, 383)

### V3.0.4 (2026-03-17) — Update Mode & Audit Reliability Fixes / 更新模式与审计可靠性修复

**Fix 1: `--update` mode Stage 6 failure / 修复 1：`--update` 模式第 6 阶段失败**
- `install.sh --update` 的第 6 阶段尝试 `source` 一个不存在的占位符文件 `INLINE_SECRETS_ENCRYPT`，导致执行中断并跳过后续的 Guardian 服务和密钥加密。已移除该错误引用——密钥加密通过内联函数 `setup_secrets_encryption()` 在两种模式下均正常执行。
- Stage 6 in `--update` mode tried to `source` a non-existent placeholder file `INLINE_SECRETS_ENCRYPT`, causing execution to abort and skip Guardian service installation and secrets encryption. Removed the broken reference — secrets encryption runs via the inline `setup_secrets_encryption()` function in both install and update modes.

**Fix 2: Three false audit failures / 修复 2：三项审计误报**
- **`ufw active` → `firewall active`：** 加固脚本安装 `iptables-persistent` 时自动卸载 UFW（Debian 包冲突），导致审计检查永远失败。现已改为同时接受 UFW 或 `netfilter-persistent` 任一防火墙。
- **`ufw active` → `firewall active`:** The hardening script installs `iptables-persistent` which auto-removes UFW (Debian package conflict), causing the audit check to always fail. Now accepts either UFW or `netfilter-persistent`.
- **`dns direct query blocked` + `force proxy non-loopback block`：** 审计脚本硬编码 UID `997`，但 `openclaw-svc` 的 UID 因系统而异（如 `996`）。现已改为运行时通过 `id -u openclaw-svc` 动态获取。
- **`dns direct query blocked` + `force proxy non-loopback block`:** Audit checks hardcoded UID `997`, but `openclaw-svc` UID varies by system (e.g., `996`). Now dynamically resolved via `id -u openclaw-svc` at runtime.

### V3.0.3 (2026-03-16) — Configuration Management & Deployment Reliability / 配置管理与部署可靠性

**New: `codeshield-config` CLI** — Post-install configuration management without re-running installer or `openclaw onboard`:
- `show` / `edit` / `set KEY=VALUE` — View and modify secrets (auto decrypt → edit → re-encrypt)
- `add-model` — Built-in support for OpenAI (API Key + OAuth), Anthropic, GLM5 (智谱), Kimi 2.5 (月之暗面), or custom providers
- `add-channel` — Generic channel framework for Feishu, Slack, Discord, WeChat, or any custom channel
- `proxy-allow` — Add domains to Squid whitelist; `list-channels` / `list-models` — List configs

**Multi-LLM Provider Support:**
- OpenAI: API Key (`sk-*`) and OAuth 2.0 (`client_id` + `client_secret` + `org_id`)
- Anthropic (`api.anthropic.com`), GLM5 (`open.bigmodel.cn`), Kimi 2.5 (`api.moonshot.cn`)
- Interactive secret collection during install now covers all providers
- Secret migration from `openclaw.json` expanded for new provider key paths

**Deployment Reliability Fixes (Unicode/UTF-8 + Error Handling):**
- Force `LC_ALL=en_US.UTF-8` at installer start; locale check + auto `locale-gen` in preflight
- `grep -qP` (PCRE) → `grep -qE` (ERE) for locale-independent pattern matching
- `eval "$var='$val'"` → `printf -v "$var" '%s' "$val"` (safe variable assignment, no shell injection)
- Heredoc secrets writing → `printf` per-line (UTF-8 safe)
- Python `read_text()` / `write_text()` with explicit `encoding='utf-8'`
- `squid-injection-guard.py`: UTF-8 `TextIOWrapper` for stdin/stdout
- `sed -i` operations prefixed with `LC_ALL=C` (binary-safe config editing)
- **`--resume` flag**: checkpoint-based recovery from failed install stage
- **Install logging**: all output tee'd to `/var/log/openclaw-codeshield/install.log`
- **Error trap**: on failure, shows log path and `--resume` command
- Preflight: batch auto-install missing commands, network connectivity check
- Squid whitelist externalized to `/etc/openclaw-codeshield/proxy-whitelist.conf`
- `netfilter-persistent` auto-installed for iptables rule persistence

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

Contact: 
John
Email: iok@outlook.com


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
