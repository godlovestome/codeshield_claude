# CODE SHIELD V3.1.2

**AI Agent Network Security Hardening System**  
**AI Agent 网络安全加固系统**

CODE SHIELD is a production-oriented defense-in-depth framework for OpenClaw and similar AI agent stacks running on Linux servers. It focuses on user isolation, encrypted secret handling, outbound traffic control, prompt injection defense, container hardening, and automatic re-application after agent updates.

CODE SHIELD 是一套面向生产环境的 AI Agent 安全加固框架，适用于运行在 Linux 服务器上的 OpenClaw 及类似系统。它聚焦于用户隔离、密钥加密、出站流量控制、提示注入防护、容器加固，以及在 Agent 升级后的自动恢复。

**Version focus / 本版重点：v3.1.2**  
Mirror `.claude.json` into the isolated `openclaw-svc` runtime so MCP registrations such as QMD remain visible to the live OpenClaw service after Codeshield isolation.  
将 `.claude.json` 镜像到隔离运行用户 `openclaw-svc` 的环境中，确保 QMD 等 MCP 注册在 Codeshield 隔离后仍可被线上 OpenClaw 服务读取。

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

The installer is interactive only when collecting API keys and secret values. Everything else runs automatically.  
安装程序只会在收集 API Key 和密钥值时进入交互，其余步骤均自动执行。

After installation, use `codeshield-config` for ongoing configuration management instead of rerunning the installer.  
安装完成后，后续请优先使用 `codeshield-config` 管理配置，而不是反复重新执行安装脚本。

---

## What It Protects / 保护范围

- API keys and tokens stored outside `openclaw.json`
- OpenClaw runtime isolated as `openclaw-svc`
- Qdrant, Redis, and other local services from unnecessary exposure
- Outbound traffic forced through Squid
- Prompt and session injection attacks
- Security continuity after OpenClaw updates

- 把 API Key 和令牌从 `openclaw.json` 中剥离出来
- 将 OpenClaw 运行时隔离为 `openclaw-svc`
- 保护 Qdrant、Redis 等本地服务不被不必要暴露
- 强制出站流量经过 Squid
- 防护提示注入与会话注入
- 在 OpenClaw 升级后自动恢复安全策略

---

## Key Features / 核心能力

### 1. User Isolation / 用户隔离

- Creates `openclaw-svc` as the isolated runtime user
- Removes it from `docker` and `sudo` groups
- Uses systemd drop-ins and sandbox settings to reduce blast radius

- 创建 `openclaw-svc` 作为隔离运行用户
- 将其从 `docker`、`sudo` 组中移除
- 通过 systemd drop-in 和沙箱设置降低越权风险

### 2. Secret Management / 密钥管理

- Externalizes inline secrets from `openclaw.json`
- Encrypts secrets at rest with `systemd-creds`
- Decrypts secrets into tmpfs at runtime
- Exports restricted values for Jarvis Memory where needed

- 将 `openclaw.json` 内联密钥迁移出去
- 使用 `systemd-creds` 对静态密钥加密
- 在运行时把密钥解密到 tmpfs
- 在需要时为 Jarvis Memory 导出受限密钥

### 3. Network Control / 网络控制

- Forces outbound traffic through Squid
- Uses iptables and DOCKER-USER rules to block bypass paths
- Preserves local-service access with `NO_PROXY`

- 强制所有出站流量经过 Squid
- 使用 iptables 与 DOCKER-USER 规则封堵绕过路径
- 通过 `NO_PROXY` 保留本地服务直连能力

### 4. Update Continuity / 更新连续性

- Guardian detects OpenClaw changes
- Re-applies drop-ins, policies, and security scripts
- Re-syncs runtime data into the isolated service home
- Mirrors `.claude.json` so MCP registrations remain visible

- Guardian 检测 OpenClaw 变更
- 自动重新应用 drop-in、策略和安全脚本
- 重新同步运行时数据到隔离用户目录
- 镜像 `.claude.json`，确保 MCP 注册持续可见

---

## Configuration Management / 配置管理

Use `codeshield-config` after installation:
安装后使用 `codeshield-config`：

```bash
codeshield-config show
codeshield-config edit
codeshield-config set OPENAI_API_KEY=...
codeshield-config add-model
codeshield-config add-channel
codeshield-config proxy-allow open.feishu.cn
codeshield-config network-mode
codeshield-config network-mode open
codeshield-config network-mode strict
codeshield-config list-models
codeshield-config list-channels
```

### What it does / 它会做什么

- Decrypt, modify, and re-encrypt secrets safely
- Update Squid allow-lists when channels or providers are added
- Restart related services when needed
- Keep model and channel configuration in dedicated config directories

- 安全地解密、修改、再加密密钥
- 在新增消息通道或模型提供商时更新 Squid 白名单
- 在必要时重启相关服务
- 将模型和通道配置存放在独立配置目录中

---

## Installation Flow / 安装流程

The installer runs in staged form:
安装脚本按阶段执行：

1. Pre-flight checks
2. Secret collection
3. User isolation and migration
4. Qdrant security hardening
5. System hardening
6. Injection defense
7. Guardian installation
8. Secret encryption and audit

1. 环境预检
2. 密钥收集
3. 用户隔离与迁移
4. Qdrant 安全加固
5. 系统级加固
6. 注入防护
7. Guardian 安装
8. 密钥加密与审计

### Command Flags / 命令参数

- `--dry-run`
- `--skip-preflight`
- `--update`
- `--resume`

---

## OpenClaw Update Compatibility / OpenClaw 升级兼容

When OpenClaw is updated, Guardian watches for relevant file changes and re-applies Codeshield protections.

当 OpenClaw 升级时，Guardian 会监控关键文件变化，并重新应用 Codeshield 的安全保护。

Typical recovery actions / 常见恢复动作：

- secret migration
- reseal encrypted secrets
- restore systemd drop-ins
- re-sync isolated runtime data
- restore SOUL.md and skills policy
- re-patch non-native provider JS files if needed
- restart related services

- 迁移新出现的内联密钥
- 重新封装加密密钥
- 恢复 systemd drop-in
- 重新同步隔离运行时数据
- 恢复 SOUL.md 与 skills policy
- 必要时重打非原生提供商补丁
- 重启相关服务

---

## Security Audit / 安全审计

Run anytime:
可随时执行：

```bash
security-audit.sh
```

The audit checks areas such as:
审计会覆盖如下领域：

- SSH hardening
- firewall and iptables state
- secrets encryption
- Qdrant exposure and auth
- systemd sandbox settings
- outbound proxy enforcement
- Guardian and reseal timer health

- SSH 加固
- 防火墙与 iptables 状态
- 密钥加密状态
- Qdrant 暴露面与认证
- systemd 沙箱配置
- 出站代理强制执行情况
- Guardian 与 reseal timer 健康状态

---

## Important Paths / 关键路径

- `/etc/openclaw-codeshield/`
- `/run/openclaw-codeshield/`
- `/run/openclaw-memory/`
- `/usr/local/sbin/`
- `/usr/local/lib/openclaw-codeshield/`
- `/var/log/openclaw-codeshield/`
- `/var/lib/openclaw-codeshield/`
- `/var/lib/openclaw-svc/.openclaw/`

---

## File Layout / 文件结构

```text
codeshield_claude/
├─ install.sh
├─ lib/
│  ├─ 00-preflight.sh
│  ├─ 01-collect-secrets.sh
│  ├─ 02-isolation.sh
│  ├─ 03-qdrant.sh
│  ├─ 04-hardening.sh
│  ├─ 05-injection-defense.sh
│  └─ 06-guardian.sh
├─ scripts/
│  ├─ codeshield-config
│  ├─ security-audit.sh
│  ├─ openclaw-guardian
│  ├─ openclaw-injection-scan
│  ├─ openclaw-cost-monitor
│  ├─ codeshield-secrets-seal
│  ├─ codeshield-secrets-unseal
│  ├─ codeshield-secrets-reseal
│  └─ codeshield-secrets-migrate
├─ templates/
├─ CHANGELOG.md
└─ README.md
```

---

## Notes / 备注

- This repo is designed to work with OpenClaw, QMD, Jarvis Memory, Redis, Qdrant, and Codeshield-managed runtime secrets.
- The recommended production path is fresh install once, then non-destructive updates afterwards.
- If OpenClaw runtime behavior changes after an upstream upgrade, rerun the non-destructive update first before making manual edits.

- 本仓库用于和 OpenClaw、QMD、Jarvis Memory、Redis、Qdrant 以及 Codeshield 托管密钥配合使用。
- 生产环境建议先执行一次全新安装，之后统一走无损更新。
- 如果 OpenClaw 上游升级后运行行为异常，优先先执行一次无损更新，再考虑手工排查。

---

## License

MIT License
