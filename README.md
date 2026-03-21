# CODE SHIELD V3.1.1

**AI Agent Network Security Hardening System**

CODE SHIELD V3 is a comprehensive, production-grade security framework designed to protect AI agents running on Linux servers. It provides defense-in-depth through user isolation, secret encryption (systemd-creds), outbound proxy whitelisting, prompt injection detection, container privilege reduction, systemd sandbox hardening, and a guardian service that automatically re-applies protection after agent updates. V3.1.1 fixes a critical DOCKER-USER gap: Qdrant gRPC port 6334 was not blocked, and DOCKER-USER rules were lost after Docker restarts. A new `codeshield-docker-user.service` now re-applies all DOCKER-USER rules automatically after Docker restarts. Originally built to harden OpenClaw, CODE SHIELD achieves a security score of **9.5/10** across **58 automated audit checks**.

---

**CODE SHIELD V3.1.1 -- AI Agent 网络安全加固系统**

CODE SHIELD V3 是一套完整的生产级安全框架，专为运行在 Linux 服务器上的 AI Agent 设计。通过用户隔离、密钥加密（systemd-creds）、出站代理白名单、提示注入检测、容器权限削减、systemd 沙箱加固和 Guardian 自动恢复服务，提供纵深防御。V3.1.1 修复 DOCKER-USER 关键缺口：Qdrant gRPC 端口 6334 未被阻断，且 Docker 重启后 DOCKER-USER 规则丢失。新增 `codeshield-docker-user.service`，在 Docker 重启后自动重新应用所有 DOCKER-USER 规则。本系统通过 **58 项**自动化安全审计实现 **9.5/10** 的安全评分。

---

## Quick Start / 快速开始

### Fresh Install / 全新安装

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

### Non-Destructive Update / 无损更新

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

The installer is interactive only when collecting API keys (Telegram, Brave, OpenAI, Anthropic, DeepSeek, GLM5, Kimi, MiniMax, Qdrant). Everything else runs fully automatically. After installation, use `codeshield-config` to manage configuration without re-running the installer.

安装程序仅在收集 API 密钥时暂停交互（Telegram、Brave、OpenAI、Anthropic、DeepSeek、GLM5、Kimi、MiniMax、Qdrant），其余全部自动执行。安装后可使用 `codeshield-config` 管理配置，无需重新运行安装程序。

---

## What It Protects / 保护范围

| Protected Asset / 保护对象 | Threat / 威胁 | Defense / 防护措施 |
|---|---|---|
| API Keys & Tokens | Inline credential exposure, disk theft | **Secrets encrypted at rest** (systemd-creds, host key bound); decrypted to tmpfs (RAM) only at runtime; keys fully deleted from openclaw.json |
| Qdrant Vector DB (JARVIS + TRUE RECALL) | Unauthorized access, container escape, data exfiltration | API key authentication, ports 6333+6334 bound to 127.0.0.1, **DOCKER-USER iptables** (ESTABLISHED/RELATED, loopback, 6333/6334 DROP + optional 6379/5432), **cap_drop ALL**, **no-new-privileges**, **read_only filesystem** with tmpfs, `codeshield-docker-user.service` survives Docker restarts |
| Telegram Bot | Token theft, message interception | Keys managed by CODE SHIELD, encrypted at rest, not stored in openclaw.json |
| OpenClaw Agent Process | Privilege escalation, lateral movement | Isolated `openclaw-svc` user, removed from docker/sudo groups, **systemd sandbox** (ProtectSystem=strict, CapabilityBoundingSet=, RestrictAddressFamilies, SystemCallFilter, ProtectHome=yes) |
| Server SSH | Brute force, tunneling, password attacks | Password auth disabled, MaxAuthTries=3, MaxSessions=3, **AllowTcpForwarding=no**, **AllowAgentForwarding=no**, fail2ban with 1-hour bans, sshd_config.d drop-in |
| Outbound Network | Data exfiltration, C2 communication, proxy bypass | **Comprehensive iptables block** with LOG: all non-loopback outbound from openclaw-svc dropped at kernel level; agent must use Squid at 127.0.0.1:3128 |
| Squid Proxy | Request smuggling, DNS exfiltration | Full-traffic logging, 10MB request body limit, 1MB/s rate limiting, Python injection guard; all traffic forced through proxy by iptables |
| AI Prompts / SOUL.md | Prompt injection, identity hijack | Canary tokens, 10-rule injection resistance framework, 15-minute session scanning |
| Skills / Tools | Unauthorized tool invocation | Whitelist-only skills-policy.json, integrity baseline checksums |
| DNS | DNS exfiltration tunneling | iptables uid-owner comprehensive rule blocks all external DNS for openclaw-svc |
| Update Continuity | Security loss after agent updates | Guardian systemd path unit auto-detects updates and re-applies all protections |
| Kernel / OS | Core dump leaks, privilege escalation | `fs.suid_dumpable=0`, `kernel.kptr_restrict=1`, `kernel.dmesg_restrict=1`, Docker `icc=false` |
| Local Services (Ollama/Qdrant/Redis) | Proxy routing failure (V3.1.0) | `EnvHttpProxyAgent` respects `NO_PROXY`; local services bypass Squid automatically |
| Jarvis Memory Secrets | Plaintext API key in cron environment (V3.1.0) | `QDRANT_API_KEY` exported to restricted tmpfs path (`root:openclaw 640`) instead of plaintext `~/.memory_env` |

---

## Configuration Management / 配置管理

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
# Non-native providers (deepseek, glm5) automatically patch openclaw JS files.
# 非原生提供商（deepseek、glm5）会自动修补 openclaw JS 文件。
codeshield-config add-model
#   1) OpenAI (API Key)       2) OpenAI (OAuth)
#   3) Anthropic / Claude     4) DeepSeek (深度求索)
#   5) GLM5 (智谱 BigModel)   6) Kimi (月之暗面 Moonshot)
#   7) MiniMax                8) Custom (自定义)

# Re-patch openclaw JS files after openclaw update (non-native providers only)
# openclaw 更新后重新修补 JS 文件（仅非原生提供商）
codeshield-config patch-provider deepseek

# Add a messaging channel (interactive menu, domains auto-filled)
# 添加消息通道（交互式菜单，域名自动填充）
codeshield-config add-channel
#   1) 企业微信 (WeCom)    2) 飞书 (Feishu)
#   3) Discord             4) Custom (自定义)

# Add a domain to Squid proxy whitelist / 添加域名到 Squid 白名单
codeshield-config proxy-allow open.feishu.cn

# Toggle network access mode / 切换网络访问模式
# open: all domains allowed through proxy (default, required for web_fetch)
# 开放模式：允许所有域名通过代理（默认，web_fetch 必需）
# strict: only known API domains allowed (disables web_fetch for arbitrary URLs)
# 严格模式：仅允许已知 API 域名（禁用对任意 URL 的 web_fetch）
codeshield-config network-mode              # show current mode / 查看当前模式
codeshield-config network-mode open         # allow all domains / 允许所有域名
codeshield-config network-mode strict       # whitelist only / 仅白名单域名

# List configured channels and models / 列出已配置的通道和模型
codeshield-config list-channels
codeshield-config list-models
```

**Key behaviors / 核心行为:**
- Automatically decrypts secrets → modifies → re-encrypts (systemd-creds) / 自动解密 → 修改 → 重新加密
- Automatically updates Squid proxy whitelist when adding channels/models / 添加通道/模型时自动更新 Squid 白名单
- Automatically restarts openclaw.service after changes / 修改后自动重启 openclaw 服务
- **Non-native providers (deepseek, glm5) auto-patch openclaw JS dist files** — no manual file editing / 非原生提供商（deepseek、glm5）自动修补 openclaw JS 文件——无需手动编辑
- Channel and model configs stored in `/etc/openclaw-codeshield/channels.d/` and `models.d/`
- `proxy-allow` adds domains to the known-domains reference list (logging and future selective enforcement)
- **`network-mode`** toggles Squid between open (all domains) and strict (whitelist only) without affecting security score / `network-mode` 在开放模式（所有域名）和严格模式（仅白名单）之间切换，不影响安全评分

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

安装程序分 7 个阶段执行：

```
[1/7] Environment Pre-Flight     -- Checks OS, dependencies, disk space
                                    检查操作系统、依赖、磁盘空间
[2/7] Secret Collection           -- Interactive: Telegram, Brave, OpenAI (Key/OAuth),
                                    Anthropic, DeepSeek, GLM5, Kimi, MiniMax, Qdrant
                                    交互式：收集各提供商 API 密钥
[3/7] User Isolation & Migration  -- Creates openclaw-svc, migrates secrets, installs drop-in
                                    创建隔离用户、迁移密钥、安装 systemd drop-in
[4/7] Qdrant Security             -- API key auth, 127.0.0.1 binding, cap_drop ALL, read_only
                                    Qdrant 认证、端口绑定、权限削减、只读文件系统
[5/7] System Hardening            -- SSH, UFW, fail2ban, IPv6, Squid, iptables block+LOG,
                                    systemd sandbox, proxy-preload.mjs (EnvHttpProxyAgent)
                                    系统加固：SSH/防火墙/Squid/iptables/systemd 沙箱/代理预加载
[6/7] Injection Defense           -- SOUL.md canary, skills policy, scanner timer, cost monitor
                                    注入防御：SOUL.md 金丝雀、技能策略、扫描定时器、成本监控
[7/7] Secrets Encryption          -- systemd-creds encryption, tmpfs decryption, reseal timer,
                                    Jarvis Memory secret export
                                    密钥加密：systemd-creds 加密、tmpfs 解密、定期重封、
                                    Jarvis Memory 密钥导出
[POST] Guardian Installation      -- systemd path unit for update detection
                                    Guardian 更新检测路径单元
[FINAL] Security Audit            -- 56-item check with score
                                    56 项安全审计评分
```

### Command-line flags / 命令行参数

| Flag / 参数 | Description / 说明 |
|---|---|
| `--dry-run` | Show what would be done without making changes / 预演模式，不做实际修改 |
| `--skip-preflight` | Skip environment pre-checks / 跳过环境预检 |
| `--update` | Non-interactive re-apply (used by Guardian after OpenClaw updates) / 非交互式重新应用（Guardian 更新后使用） |
| `--resume` | Resume from last failed stage / 从上次失败的阶段恢复 |

---

## OpenClaw Update Compatibility / OpenClaw 更新兼容性

When OpenClaw is updated via:

当通过以下命令更新 OpenClaw 时：

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

The **codeshield-guardian.path** systemd unit detects changes to:

**codeshield-guardian.path** systemd 单元检测以下文件变化：

- `/home/openclaw/.npm-global/lib/node_modules/openclaw/package.json`
- `/home/openclaw/.openclaw/openclaw.json`

Upon detection, the Guardian service (`/usr/local/sbin/openclaw-guardian`) executes:

检测到变化后，Guardian 服务（`/usr/local/sbin/openclaw-guardian`）执行：

1. Migrates any new inline secrets from openclaw.json to secrets.env (and fully deletes them from JSON)
   迁移 openclaw.json 中的内联密钥到 secrets.env（并从 JSON 中完全删除）
2. Re-encrypts secrets with `codeshield-secrets-reseal`
   使用 `codeshield-secrets-reseal` 重新加密密钥
3. Verifies/recreates the systemd drop-in (EnvironmentFile, User=openclaw-svc)
   验证/重建 systemd drop-in（EnvironmentFile、User=openclaw-svc）
4. Syncs openclaw data to the isolated service home
   同步 openclaw 数据到隔离的服务主目录
5. Restores SOUL.md canary token and injection resistance if overwritten
   恢复 SOUL.md 金丝雀令牌和注入抵抗规则（如被覆盖）
6. Restores skills-policy.json if missing
   恢复 skills-policy.json（如缺失）
7. Regenerates skills baseline checksums
   重新生成技能基线校验和
8. Re-patches non-native provider JS files (DeepSeek, GLM5) if dist files were replaced
   重新修补非原生提供商 JS 文件（DeepSeek、GLM5，如 dist 文件被替换）
9. Runs `systemctl daemon-reload && systemctl restart codeshield-secrets && systemctl restart openclaw`
   重载 systemd 并重启相关服务
10. Sends Telegram notification confirming re-application
    发送 Telegram 通知确认重新应用

This ensures zero-downtime protection continuity. No manual intervention required.

Guardian 确保 OpenClaw 每次更新后自动重新生效所有安全防护，无需手动干预。

**What OpenClaw updates do NOT touch / OpenClaw 更新不会影响的内容：**

| Item / 项目 | Safe / 安全 |
|---|---|
| CodeShield iptables rules | Not touched by OpenClaw installer / OpenClaw 安装程序不触碰 |
| Squid proxy configuration | Not touched / 不触碰 |
| systemd sandbox (drop-in) | Guardian re-applies if overwritten / Guardian 自动恢复 |
| Encrypted secrets (secrets.env.enc) | Not touched / 不触碰 |
| Jarvis Memory data (Qdrant/Redis) | Not touched / 不触碰 |
| `openclaw.json` memorySearch config | Preserved by `--no-onboard` / `--no-onboard` 保留 |
| CodeShield guardian/audit services | Not touched / 不触碰 |

---

## Security Audit / 安全审计

Run the audit at any time / 随时运行安全审计：

```bash
security-audit.sh
```

### 58-Item Checklist / 58 项检查清单

**Network Security / 网络安全 (12)**
- firewall active (UFW or netfilter-persistent) / 防火墙已激活
- ssh password disabled / SSH 密码登录已禁用
- ssh keyboard-interactive disabled / SSH 键盘交互已禁用
- root key-only login / root 仅限密钥登录
- fail2ban sshd active / fail2ban SSH 防护已激活
- ipv6 disabled / IPv6 已禁用
- zerotier online / ZeroTier 在线
- zerotier private network / ZeroTier 私有网络
- docker-user drop rules / Docker 用户 DROP 规则
- docker-user qdrant grpc blocked / Docker 用户 Qdrant gRPC 已阻断 *(V3.1.1)*
- docker-user rules persist service / Docker 用户规则持久化服务已启用 *(V3.1.1)*
- dns direct query blocked / DNS 直连查询已阻断

**Access Control / 访问控制 (11)**
- openclaw not in docker group / openclaw 不在 docker 组
- openclaw not in sudo group / openclaw 不在 sudo 组
- openclaw-svc exists / openclaw-svc 用户存在
- openclaw service isolated user / openclaw 服务使用隔离用户
- watcher isolated user / watcher 使用隔离用户
- controlled sudoers present / 受控 sudoers 已配置
- secrets file permissions / 密钥文件权限正确
- secrets encrypted at rest / 密钥已静态加密
- secrets decrypted to tmpfs / 密钥解密到 tmpfs
- codeshield-secrets service active / codeshield-secrets 服务已激活
- no inline secrets in openclaw.json / openclaw.json 无内联密钥

**Qdrant Security / Qdrant 安全 (2)**
- qdrant unauth rejected / Qdrant 未授权请求被拒绝
- qdrant auth accepted / Qdrant 授权请求被接受

**Outbound Proxy / 出站代理 (4)**
- squid active / Squid 已激活
- squid body size limit / Squid 请求体大小限制
- squid delay pools active / Squid 延迟池已激活
- squid injection guard exists / Squid 注入防护已存在

**AI Agent Security / AI Agent 安全 (6)**
- skills freeze policy exists / 技能冻结策略已存在
- skills integrity script exists / 技能完整性脚本已存在
- soul canary exists / SOUL 金丝雀已存在
- soul injection rules present / SOUL 注入规则已存在
- injection scanner exists / 注入扫描器已存在
- cost monitor exists / 成本监控已存在

**Database Protection / 数据库保护 (2 -- optional / 可选)**
- redis not deployed / Redis 未部署（或已安全配置）
- postgres not deployed / PostgreSQL 未部署（或已安全配置）

**Incident Response / 事件响应 (4)**
- forensics key exists / 取证密钥已存在
- emergency lockdown exists / 紧急锁定脚本已存在
- docker daemon hardened / Docker 守护进程已加固
- baseline exists / 基线已存在

**V3.0.1 Security Fixes / V3.0.1 安全修复 (6)**
- qdrant cap_drop all / Qdrant 权限全部削减
- qdrant no-new-privileges / Qdrant 禁止新权限
- force proxy non-loopback block / 强制代理非回环阻断
- openclaw protect system / OpenClaw 系统保护
- openclaw capability bounding / OpenClaw 能力边界
- no inline gateway token / 无内联网关令牌

**V3.0.2 Security Fixes / V3.0.2 安全修复 (9)**
- ssh forwarding disabled / SSH 转发已禁用
- ssh agent forwarding disabled / SSH 代理转发已禁用
- ssh max sessions limited / SSH 最大会话已限制
- fs.suid_dumpable disabled / 核心转储已禁用
- docker icc disabled / Docker 容器间通信已禁用
- iptables outbound logging / iptables 出站日志
- reseal timer active / 重封定时器已激活
- systemd restrict address families / systemd 地址族限制
- systemd syscall filter / systemd 系统调用过滤

**Continuous Monitoring / 持续监控 (2)**
- audit timer active / 审计定时器已激活
- guardian path active / Guardian 路径单元已激活

**Service Health / 服务健康 (2)**
- openclaw active / openclaw 服务已激活
- watcher active / watcher 服务已激活

### Sample Output / 示例输出

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
          |        +--→ /run/openclaw-codeshield/secrets.env  |
          |        |    (root:root 600) — all secrets         |
          |        |                                          |
          |        +--→ /run/openclaw-memory/secrets.env      |
          |             (root:openclaw 640) — QDRANT_API_KEY  |
          |             only, for Jarvis Memory cron (V3.1.0) |
          |                                                   |
          |  +-----v------------------------------------+     |
          |  | openclaw.service (User=openclaw-svc)     |     |
          |  | EnvironmentFile=/run/.../secrets.env      |     |
          |  | ProtectSystem=strict / CapabilityBound=  |     |
          |  | RestrictAddressFamilies / SystemCallFilter|     |
          |  | ProtectHome=yes / NoNewPrivileges=yes     |     |
          |  | NODE_OPTIONS=--import proxy-preload.mjs   |     |
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
          |       | Squid Proxy             |      |          |
          |       | EnvHttpProxyAgent       |      |          |
          |       | (respects NO_PROXY)     |      |          |
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
          |  |           drop-in, SOUL.md, skills policy, |    |
          |  |           JS patch (DeepSeek/GLM5)         |    |
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
  +0.2  if zero failures / 零失败
  +0.1  if guardian path unit is active / Guardian 路径单元激活
  +0.1  if network hardening (UFW/netfilter + SSH) fully applied / 网络加固完全应用
  +0.1  if secrets encrypted at rest / 密钥已静态加密

final_score = min(base + pass_bonus + extra_bonus, 10.0)
```

| Version / 版本 | Automated Checks / 自动检查 | Score / 评分 |
|---------|-----------------|-------|
| V3.0.0  | 38/38           | 9.3/10 |
| V3.0.1  | 42/42           | 9.3/10 |
| V3.0.2  | 56/56           | 9.5/10 |
| V3.0.3  | 56/56           | 9.5/10 |
| V3.0.4  | 56/56           | 9.5/10 |
| V3.0.5  | 56/56           | 9.5/10 |
| V3.0.6  | 56/56           | 9.5/10 |
| V3.0.7  | 56/56           | 9.5/10 |
| V3.0.8  | 56/56           | 9.5/10 |
| V3.0.9  | 56/56           | 9.5/10 |
| V3.0.10 | 56/56           | 9.5/10 |
| V3.1.0  | 56/56           | 9.5/10 |
| **V3.1.1** | **58/58**    | **9.5/10** |

Professional audit score (manual review) / 专业审计评分（人工评审）: **~9.0/10** (up from 7.3 in V3.0.0)

---

## File Structure / 文件结构

```
codeshield-v3/
|-- install.sh                    # One-line installer entry point / 一行安装入口
|-- lib/
|   |-- 00-preflight.sh           # Environment pre-checks / 环境预检
|   |-- 01-collect-secrets.sh     # Interactive secret collection / 交互式密钥收集
|   |-- 02-isolation.sh           # User isolation & secret migration / 用户隔离与密钥迁移
|   |-- 03-qdrant.sh              # Qdrant auth, network binding, cap_drop / Qdrant 安全加固
|   |-- 04-hardening.sh           # SSH/UFW/fail2ban/sysctl/Squid/iptables/systemd sandbox
|   |                             # 系统加固（含 proxy-preload.mjs 部署）
|   |-- 05-injection-defense.sh   # Prompt injection defense / 提示注入防御
|   `-- 06-guardian.sh            # Guardian watchdog service / Guardian 看门狗服务
|-- scripts/
|   |-- codeshield-config         # Configuration management CLI / 配置管理命令行工具
|   |-- security-audit.sh         # 56-item security audit / 56 项安全审计
|   |-- proxy-preload.mjs         # Node.js EnvHttpProxyAgent preload (V3.1.0)
|   |                             # Node.js 代理预加载脚本（尊重 NO_PROXY）
|   |-- openclaw-injection-scan   # Session injection scanner / 会话注入扫描器
|   |-- openclaw-cost-monitor     # API cost monitoring / API 成本监控
|   |-- openclaw-guardian         # Update re-application hook / 更新后重新应用钩子
|   |-- emergency-lockdown        # Emergency lockdown with AES forensics / 紧急锁定（AES 取证）
|   |-- squid-injection-guard.py  # Squid URL rewrite injection filter / Squid URL 注入过滤
|   |-- codeshield-secrets-seal   # Encrypt secrets.env → .enc / 加密密钥文件
|   |-- codeshield-secrets-unseal # Decrypt .enc → tmpfs + Jarvis Memory export (V3.1.0)
|   |                             # 解密到 tmpfs + Jarvis Memory 密钥导出
|   |-- codeshield-secrets-reseal # Re-seal after Guardian migration / Guardian 迁移后重封
|   `-- codeshield-secrets-migrate # One-time plaintext → encrypted migration / 一次性明文转加密
|-- templates/
|   |-- squid.conf                # Squid proxy configuration template / Squid 代理配置模板
|   |-- soul-injection.md         # SOUL.md injection resistance chapter / SOUL.md 注入抵抗章节
|   |-- skills-policy.json        # Skills whitelist freeze policy / 技能白名单冻结策略
|   |-- codeshield-secrets.service # systemd unit for secret decryption / 密钥解密 systemd 单元
|   |-- codeshield-reseal.service  # Monthly re-seal oneshot / 月度重封一次性服务
|   `-- codeshield-reseal.timer    # Monthly re-seal timer / 月度重封定时器
|-- CHANGELOG.md                  # Version history with technical details / 版本历史与技术细节
`-- README.md                     # This file (bilingual EN/ZH) / 本文件（中英双语）
```

### Installation Paths / 安装路径

| Path / 路径 | Purpose / 用途 |
|---|---|
| `/etc/openclaw-codeshield/` | Configuration directory (secrets.env.enc, forensics.key, channels.d/, models.d/) / 配置目录 |
| `/run/openclaw-codeshield/` | Tmpfs-backed secrets (RAM only, auto-cleaned) / tmpfs 密钥（仅内存） |
| `/run/openclaw-memory/` | Restricted secret export for Jarvis Memory (V3.1.0) / Jarvis Memory 受限密钥导出 |
| `/usr/local/sbin/` | Executable tools (security-audit.sh, codeshield-secrets-*, etc.) / 可执行工具 |
| `/usr/local/lib/openclaw-codeshield/` | Library files, templates, proxy-preload.mjs / 库文件、模板、代理预加载 |
| `/var/log/openclaw-codeshield/` | Log files (guardian, audit, injection scan, reseal) / 日志文件 |
| `/var/lib/openclaw-codeshield/` | Data files (baselines, canary, metadata) / 数据文件 |
| `/var/lib/openclaw-svc/.openclaw/` | Isolated OpenClaw data directory / 隔离的 OpenClaw 数据目录 |

---

## Changelog / 版本历史

### V3.1.1 (2026-03-21) — DOCKER-USER Security Gap Fix / DOCKER-USER 安全缺口修复

**Fix 1: Qdrant gRPC port 6334 not blocked in DOCKER-USER / 修复 1：Qdrant gRPC 端口 6334 未在 DOCKER-USER 中阻断**
- **Root cause / 根因:** `lib/03-qdrant.sh` only blocked port 6333 (HTTP API) in the DOCKER-USER chain and only bound 6333 to `127.0.0.1` in docker-compose. Port 6334 (gRPC) was left exposed on `0.0.0.0`, allowing external attackers to bypass UFW (Docker bypasses UFW) and access Qdrant directly via gRPC.
- **根因描述：** `lib/03-qdrant.sh` 仅在 DOCKER-USER 链中阻断了端口 6333（HTTP API），且在 docker-compose 中仅将 6333 绑定到 `127.0.0.1`。端口 6334（gRPC）暴露在 `0.0.0.0`，外部攻击者可绕过 UFW（Docker 绕过 UFW）通过 gRPC 直接访问 Qdrant。
- **Fix / 修复:** Both ports 6333 and 6334 now bound to `127.0.0.1` in docker-compose. Both blocked in DOCKER-USER chain. Added ESTABLISHED,RELATED and loopback rules. Optional Redis (6379) and PostgreSQL (5432) rules added when containers detected.
- **修复方式：** docker-compose 中 6333 和 6334 均绑定到 `127.0.0.1`。两者在 DOCKER-USER 链中均被阻断。新增 ESTABLISHED,RELATED 和 loopback 规则。检测到容器时自动添加 Redis (6379) 和 PostgreSQL (5432) 可选规则。

**Fix 2: DOCKER-USER rules lost after Docker restart / 修复 2：Docker 重启后 DOCKER-USER 规则丢失**
- **Root cause / 根因:** Docker flushes and recreates the DOCKER-USER chain every time it restarts. `netfilter-persistent save` saves the rules to disk, but Docker overwrites them on restart. The guardian service only handles OpenClaw updates, not Docker restarts.
- **根因描述：** Docker 每次重启时清空并重建 DOCKER-USER 链。`netfilter-persistent save` 将规则保存到磁盘，但 Docker 重启时会覆盖。Guardian 服务仅处理 OpenClaw 更新，不处理 Docker 重启。
- **Fix / 修复:** New `codeshield-docker-user.service` (systemd oneshot, `After=docker.service`) automatically re-applies all DOCKER-USER rules whenever Docker restarts.
- **修复方式：** 新增 `codeshield-docker-user.service`（systemd oneshot，`After=docker.service`），在 Docker 重启时自动重新应用所有 DOCKER-USER 规则。

**New audit checks / 新增审计检查（58 total，原 56）：**
- `docker-user qdrant grpc blocked` — Verifies DOCKER-USER chain blocks port 6334
- `docker-user rules persist service` — Verifies `codeshield-docker-user.service` is enabled

**Files changed / 修改文件：**

| File / 文件 | Change / 变更 |
|---|---|
| `lib/03-qdrant.sh` | Bind 6334 to 127.0.0.1; complete DOCKER-USER rules (ESTABLISHED/RELATED, loopback, 6333, 6334, optional 6379/5432); deploy `codeshield-docker-user.service` |
| `scripts/security-audit.sh` | 2 new checks (58 total); updated JSON version to 3.1.1 |
| `install.sh` | Version bump to 3.1.1 |
| `scripts/codeshield-config` | Header version bump |

### V3.1.0 (2026-03-21) — Proxy preload fix for local services & Jarvis Memory secret export / 代理预加载修复与 Jarvis Memory 密钥导出

**Fix 1: `ProxyAgent` blocks local services / 修复 1：`ProxyAgent` 阻断本地服务**
- **Root cause / 根因:** V3.0.10's `ProxyAgent` routes ALL `fetch()` traffic through Squid — including requests to local services (Ollama `127.0.0.1:11434`, Qdrant `127.0.0.1:6333`, Redis `127.0.0.1:6379`). Squid blocks `CONNECT` to localhost ports, causing OpenClaw's `memory_search` to fail with `TypeError: fetch failed` when using local Ollama embedding.
- **根因描述：** V3.0.10 的 `ProxyAgent` 将所有 `fetch()` 流量路由到 Squid——包括到本地服务的请求。Squid 阻断到 localhost 端口的 `CONNECT`，导致使用本地 Ollama 嵌入时 `memory_search` 报错。
- **Fix / 修复:** Replaced `ProxyAgent` with `EnvHttpProxyAgent` in `proxy-preload.mjs`. `EnvHttpProxyAgent` reads `NO_PROXY` from environment and bypasses proxy for matching hosts.
- **修复方式：** 将 `proxy-preload.mjs` 中的 `ProxyAgent` 替换为 `EnvHttpProxyAgent`，自动读取 `NO_PROXY` 并绕过匹配主机。

**Fix 2: Secure Jarvis Memory secret export / 修复 2：Jarvis Memory 安全密钥导出**
- **Problem / 问题:** Jarvis Memory cron jobs (running as `openclaw` user) need `QDRANT_API_KEY` but it's only in root-owned `/run/openclaw-codeshield/secrets.env`. Storing in plaintext `~/.memory_env` is a security risk.
- **问题描述：** Jarvis Memory 的 cron 任务（以 `openclaw` 用户运行）需要 `QDRANT_API_KEY`，但该密钥仅存在于 root 拥有的路径中。明文存储有安全风险。
- **Fix / 修复:** `codeshield-secrets-unseal` now exports a restricted subset (`QDRANT_API_KEY` only) to `/run/openclaw-memory/secrets.env` with `root:openclaw 640` permissions.
- **修复方式：** `codeshield-secrets-unseal` 现在将受限子集（仅 `QDRANT_API_KEY`）导出到 `/run/openclaw-memory/secrets.env`，权限为 `root:openclaw 640`。

**Files changed / 修改文件：**
| File / 文件 | Change / 变更 |
|---|---|
| `scripts/proxy-preload.mjs` | `ProxyAgent` → `EnvHttpProxyAgent` (respects `NO_PROXY`) |
| `scripts/codeshield-secrets-unseal` | Export `QDRANT_API_KEY` to `/run/openclaw-memory/` |
| `install.sh` | Version bumped to 3.1.0 |

### V3.0.10 (2026-03-17) — Undici ProxyAgent preload for web_fetch / 代理预加载修复 web_fetch

- Added `proxy-preload.mjs` — Node.js ESM preload script that forces all `fetch()` through Squid via `setGlobalDispatcher(new ProxyAgent(...))`.
- 新增 `proxy-preload.mjs`——Node.js ESM 预加载脚本，强制所有 `fetch()` 通过 Squid。
- Deployed via `NODE_OPTIONS="--import /usr/local/lib/openclaw-codeshield/proxy-preload.mjs"`.

### V3.0.9 (2026-03-17) — Fix OpenClaw network access & add network-mode command / 修复网络访问与新增网络模式命令

- **Fix:** Guardian missing `NODE_USE_ENV_PROXY` and `NO_PROXY` — replaced simple 4-variable loop with 7-variable associative array.
- **修复：** Guardian 遗漏 `NODE_USE_ENV_PROXY` 和 `NO_PROXY`——将 4 变量循环替换为 7 变量关联数组。
- **New:** `codeshield-config network-mode` — toggle between open (all domains) and strict (whitelist only).
- **新增：** `codeshield-config network-mode`——在开放模式和严格模式之间切换。

### V3.0.8 (2026-03-17) — Auto-patch openclaw JS for non-native providers / 自动修补非原生提供商

- `codeshield-config add-model deepseek|glm5` auto-patches openclaw dist JS files.
- `codeshield-config patch-provider deepseek` re-applies after openclaw update.

### V3.0.7 (2026-03-17) — Bug Fix: add-model/add-channel crash / 修复添加密钥崩溃

- `read_secret()` pipeline `grep` exit code 1 + `set -euo pipefail` killed script. Fixed with `|| true`.

### V3.0.6 (2026-03-17) — Interactive menu selection & new providers / 交互式菜单与新增提供商

- `add-model`: 8-choice numbered menu with auto-filled domains.
- `add-channel`: 4-choice numbered menu with built-in presets (WeCom, Feishu, Discord).
- New providers: DeepSeek, MiniMax.

### V3.0.5 (2026-03-17) — DNS audit check & scoring fix / DNS 审计检查与评分修复

- Fixed `dns direct query blocked` regex for normalized `iptables -S` field order.
- Fixed scoring bonus for `netfilter-persistent` firewall.

### V3.0.4 (2026-03-17) — Update mode & audit reliability / 更新模式与审计可靠性

- Fixed `--update` mode Stage 6 failure (broken `source` reference).
- Fixed three false audit failures (firewall check, dynamic UID detection).

### V3.0.3 (2026-03-16) — Configuration management & deployment reliability / 配置管理与部署可靠性

- New: `codeshield-config` CLI (show/edit/set/add-model/add-channel/proxy-allow).
- Multi-LLM provider support (OpenAI Key+OAuth, Anthropic, GLM5, Kimi).
- UTF-8/locale fixes, `--resume` flag, install logging, error trap.

### V3.0.2 (2026-03-16) — Security hardening round 2 / 安全加固第二轮

- 8 fixes from professional audit: SSH tunneling block, kernel hardening, Docker ICC, systemd sandbox, secrets encryption (systemd-creds), outbound logging, monthly reseal timer, auditd expansion.
- 9 new audit checks (56 total). Score: **9.5/10**.

### V3.0.1 (2026-03-16) — Security patch / 安全补丁

- 4 priority fixes: Qdrant privilege reduction, iptables outbound block, systemd sandbox, complete secret removal from openclaw.json.
- 6 new audit checks (42 total).

### V3.0.0 (2026-03-15) — Initial release / 初始版本

- Complete rewrite as modular installer with 6 stages.
- Guardian systemd path unit, 36-item security audit, Squid injection guard, SOUL.md canary, skills policy, emergency lockdown.
- One-line `curl | bash` installation.

See [CHANGELOG.md](CHANGELOG.md) for full technical details / 完整技术细节请参阅 CHANGELOG.md。

---

## Contact / 联系方式

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
