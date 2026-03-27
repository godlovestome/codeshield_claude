# CODE SHIELD V3.2.0

**AI Agent Network Security Framework for OpenClaw**
**面向 OpenClaw 的 AI Agent 网络安全加固框架**

---

## Table of Contents / 目录

- [English](#english)
  - [Overview](#overview)
  - [Version 3.2.0 Highlights](#version-320-highlights)
  - [Features](#features)
  - [Supported LLM Providers](#supported-llm-providers)
  - [Supported Channels](#supported-channels)
  - [Memory Backends](#memory-backends)
  - [Installation](#installation)
  - [CLI Reference](#cli-reference)
  - [Debug and Troubleshooting](#debug-and-troubleshooting)
  - [Architecture](#architecture)
  - [systemd Services](#systemd-services)
  - [Log Locations](#log-locations)
- [中文](#中文)
  - [概述](#概述)
  - [V3.2.0 版本亮点](#v320-版本亮点)
  - [功能列表](#功能列表)
  - [支持的大模型 Provider](#支持的大模型-provider)
  - [支持的通道](#支持的通道)
  - [记忆后端](#记忆后端)
  - [安装说明](#安装说明)
  - [CLI 命令参考](#cli-命令参考)
  - [调试与排障](#调试与排障)
  - [架构设计](#架构设计)
  - [systemd 服务表](#systemd-服务表)
  - [日志路径](#日志路径)

---

# English

## Overview

CODE SHIELD is a security hardening framework designed for OpenClaw, an AI agent platform. It wraps the OpenClaw runtime inside a controlled Linux service boundary, managing secrets, controlling network egress, defending against prompt injection, freezing skills, and monitoring for unauthorized changes.

CODE SHIELD ensures that OpenClaw runs as an isolated `openclaw-svc` system user, with all secrets decrypted only into a tmpfs mount at runtime, outbound traffic routed through a Squid proxy with domain whitelisting, and continuous integrity monitoring via a guardian service.

## Version 3.2.0 Highlights

- **Discord interactive channel setup** -- Full API-based guild/channel selection with allowlists, group policy, DM policy, and mention requirements
- **MiniMax China API restoration** -- Restored `api.minimaxi.com` endpoint with M2.5/M2.7/highspeed model variants via `anthropic-messages` API
- **Discord concurrency config** -- `maxConcurrent: 4`, `subagents: 12` to prevent message-storm lockups
- **QMD retrieval fix** -- Scope set to `allow`, TOOLS.md updated to stop false unavailability claims
- **exec-approval globally disabled** -- `tools.exec.ask: "off"` with three-layer enforcement
- **add-model flow improvements** -- Native provider config support, inline auth profile writing

## Features

| Feature | Description |
|---------|-------------|
| **Secrets Management** | API keys, bot tokens, and credentials stored in encrypted `secrets.env.enc`, decrypted to tmpfs at boot via `systemd-creds` |
| **Proxy Control** | All outbound traffic from `openclaw-svc` routes through Squid proxy with domain whitelist enforcement |
| **Injection Defense** | SOUL.md canary system with integrity checks to detect and resist prompt injection |
| **Skills Freeze** | `skills-policy.json` whitelist controls which skills OpenClaw can use, with rate limiting |
| **Guardian Service** | `codeshield-guardian` watches for OpenClaw updates and re-applies all protections automatically |
| **System Hardening** | systemd sandboxing: `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=read-only`, `PrivateTmp` |
| **Network Isolation** | `openclaw-svc` user has no direct internet access; all egress goes through the proxy |

## Supported LLM Providers

| Provider | API Domain | Auth Type | Native |
|----------|-----------|-----------|--------|
| OpenAI | `api.openai.com` | API Key / OAuth | Yes |
| Anthropic / Claude | `api.anthropic.com` | API Key | Yes |
| DeepSeek (深度求索) | `api.deepseek.com` | API Key | No (JS patch) |
| GLM-5 (智谱 BigModel) | `open.bigmodel.cn` | API Key | No (JS patch) |
| Kimi (月之暗面 Moonshot) | `api.moonshot.cn` | API Key | Yes |
| MiniMax (China) | `api.minimaxi.com` | API Key | Yes (native config) |
| Ollama (local) | `localhost:11434` | None | Custom |

## Supported Channels

| Channel | Domains | Setup |
|---------|---------|-------|
| **Telegram** | `api.telegram.org` | Built-in: `codeshield-config add-channel` (choice 1) |
| **Discord** | `discord.com`, `cdn.discordapp.com`, `gateway.discord.gg` | Interactive: API-based guild/channel selection (choice 4) |
| WeCom (企业微信) | `qyapi.weixin.qq.com` | Built-in |
| Feishu (飞书) | `open.feishu.cn` | Built-in |
| Custom | User-defined | Manual domain + env var configuration |

## Memory Backends

| Backend | Description |
|---------|-------------|
| **QMD** | Managed QMD wrapper for file-based knowledge retrieval. Configured via `codeshield-config qmd-backend enable`. |
| **Qdrant (True Recall / Jarvis Memory)** | Vector database at `127.0.0.1:6333` for semantic memory storage and retrieval. |

## Installation

### Prerequisites

- Ubuntu 22.04+ or Debian 12+
- OpenClaw installed under `/home/openclaw`
- Root access (sudo)
- Python 3.8+, jq, curl

### Fresh Install

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

The installer will:
1. Create `openclaw-svc` system user
2. Install and configure Squid proxy
3. Set up `codeshield-secrets.service` for secret management
4. Configure systemd sandboxing for `openclaw.service`
5. Install the guardian watcher service
6. Deploy skills-policy.json and injection defense templates
7. Migrate any inline secrets from `openclaw.json`

### Lossless (Non-Destructive) Update

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

The `--update` flag preserves all existing secrets, channel configs, model configs, and proxy whitelists. It only updates scripts, templates, and systemd units.

## CLI Reference

### Configuration

```bash
codeshield-config show                  # Display current config (secrets masked)
codeshield-config edit                  # Interactive edit of all secrets
codeshield-config set KEY=VALUE         # Set a single secret
```

### LLM Providers

```bash
codeshield-config list-models           # List configured providers
codeshield-config add-model             # Interactive provider setup menu
codeshield-config add-model deepseek    # Add specific provider directly
codeshield-config add-model minimax     # Add MiniMax (China API)
codeshield-config add-model openai-oauth # OpenAI via native OAuth flow
codeshield-config patch-provider deepseek # Re-patch JS after OpenClaw update
```

### Channels

```bash
codeshield-config list-channels         # List configured channels
codeshield-config add-channel           # Interactive channel setup menu
                                        #   1) Telegram
                                        #   2) WeCom
                                        #   3) Feishu
                                        #   4) Discord (interactive API setup)
                                        #   5) Custom
```

### QMD Backend

```bash
codeshield-config qmd-backend show      # Show QMD config status
codeshield-config qmd-backend enable    # Enable QMD retrieval backend
codeshield-config qmd-backend disable   # Disable QMD backend
```

### Network / Proxy

```bash
codeshield-config proxy-allow <domain>  # Add domain to Squid whitelist
codeshield-config network-mode          # Show current network mode
codeshield-config network-mode open     # Allow all domains through proxy
codeshield-config network-mode strict   # Restrict to known API domains only
```

## Debug and Troubleshooting

### Service Status

```bash
systemctl status openclaw               # OpenClaw service status
systemctl status codeshield-secrets     # Secret decryption service
systemctl status codeshield-guardian    # Guardian watcher service
```

### Live Logs

```bash
journalctl -u openclaw -f              # Stream OpenClaw logs
journalctl -u codeshield-guardian -f   # Stream guardian logs
journalctl -u codeshield-secrets -f    # Stream secrets service logs
```

### Security Checks

```bash
openclaw-injection-scan                 # Check for SOUL.md tampering
security-audit.sh                       # Run daily security audit
```

### Emergency

```bash
emergency-lockdown                      # Kill openclaw service and block all network
```

## Architecture

### Three-Layer Security Model

```
Layer 1: Network Isolation
  openclaw-svc user --> Squid Proxy --> Whitelisted Domains Only
                         |
                         +-- proxy-whitelist.conf (additional domains)
                         +-- squid.conf (known_api_domains ACL)

Layer 2: Secret Management
  secrets.env.enc --> systemd-creds decrypt --> /run/openclaw-codeshield/secrets.env (tmpfs)
                                                  |
                                                  +-- EnvironmentFile in openclaw.service drop-in
                                                  +-- Never written to disk in plaintext at rest

Layer 3: Runtime Integrity
  codeshield-guardian.service --> monitors package.json changes
                                  |
                                  +-- re-migrates inline secrets
                                  +-- re-applies systemd drop-in
                                  +-- syncs runtime config trees
                                  +-- refreshes SOUL.md canary
                                  +-- enforces skills-policy.json
```

## systemd Services

| Service | Description | Type |
|---------|-------------|------|
| `openclaw.service` | Main OpenClaw runtime (runs as `openclaw-svc`) | `simple` |
| `codeshield-secrets.service` | Decrypts `secrets.env.enc` to tmpfs on boot | `oneshot` |
| `codeshield-guardian.service` | Re-applies protections after OpenClaw updates | `oneshot` (path-triggered) |
| `codeshield-guardian.path` | Watches OpenClaw `package.json` for changes | `path` |

## Log Locations

| Log | Path |
|-----|------|
| Guardian | `/var/log/openclaw-codeshield/guardian.log` |
| Security audit | `/var/log/openclaw-codeshield/audit.log` |
| Squid proxy | `/var/log/squid/access.log` |
| OpenClaw (journald) | `journalctl -u openclaw` |

---

# 中文

## 概述

CODE SHIELD 是面向 OpenClaw（AI Agent 平台）的安全加固框架。它将 OpenClaw 运行时封装在受控的 Linux 服务边界内，统一管理密钥、控制网络出口、防御提示注入攻击、冻结技能权限，并持续监控未授权变更。

CODE SHIELD 确保 OpenClaw 以隔离的 `openclaw-svc` 系统用户运行，所有密钥仅在运行时解密到 tmpfs 挂载点，出站流量通过 Squid 代理进行域名白名单过滤，并由 Guardian 服务进行持续完整性监控。

## V3.2.0 版本亮点

- **Discord 交互式通道配置** -- 基于 API 的服务器/频道选择，支持白名单、群组策略、DM 策略和 @提及设置
- **MiniMax 中国版 API 恢复** -- 恢复 `api.minimaxi.com` 端点，支持 M2.5/M2.7/highspeed 模型变体，使用 `anthropic-messages` API
- **Discord 并发配置** -- `maxConcurrent: 4`、`subagents: 12`，防止消息风暴锁死
- **QMD 检索失败修复** -- 作用域设为 `allow`，更新 TOOLS.md 消除错误的不可用声明
- **exec-approval 全局关闭** -- `tools.exec.ask: "off"`，三层执行策略
- **add-model 流程改进** -- 原生 provider 配置支持，auth profile 内联写入

## 功能列表

| 功能 | 说明 |
|------|------|
| **密钥管理 (Secrets Management)** | API key、bot token 等凭证存储在加密的 `secrets.env.enc` 中，启动时通过 `systemd-creds` 解密到 tmpfs |
| **代理控制 (Proxy Control)** | `openclaw-svc` 的所有出站流量通过 Squid 代理，按域名白名单放行 |
| **注入防御 (Injection Defense)** | SOUL.md canary 系统配合完整性校验，检测和抵御提示注入攻击 |
| **技能冻结 (Skills Freeze)** | `skills-policy.json` 白名单控制 OpenClaw 可使用的技能，并设有速率限制 |
| **Guardian 守护服务** | `codeshield-guardian` 监控 OpenClaw 更新事件，自动重新应用所有保护措施 |
| **系统加固 (System Hardening)** | systemd 沙箱：`NoNewPrivileges`、`ProtectSystem=strict`、`ProtectHome=read-only`、`PrivateTmp` |
| **网络隔离 (Network Isolation)** | `openclaw-svc` 用户无法直接访问互联网，所有出口流量必须经过代理 |

## 支持的大模型 Provider

| Provider | API 域名 | 认证方式 | 原生支持 |
|----------|---------|----------|---------|
| OpenAI | `api.openai.com` | API Key / OAuth | 是 |
| Anthropic / Claude | `api.anthropic.com` | API Key | 是 |
| DeepSeek (深度求索) | `api.deepseek.com` | API Key | 否 (JS 补丁) |
| GLM-5 (智谱 BigModel) | `open.bigmodel.cn` | API Key | 否 (JS 补丁) |
| Kimi (月之暗面 Moonshot) | `api.moonshot.cn` | API Key | 是 |
| MiniMax (中国版) | `api.minimaxi.com` | API Key | 是 (原生配置) |
| Ollama (本地) | `localhost:11434` | 无 | 自定义 |

## 支持的通道

| 通道 | 域名 | 配置方式 |
|------|------|---------|
| **Telegram** | `api.telegram.org` | 内建：`codeshield-config add-channel`（选项 1） |
| **Discord** | `discord.com`, `cdn.discordapp.com`, `gateway.discord.gg` | 交互式：基于 API 的服务器/频道选择（选项 4） |
| 企业微信 (WeCom) | `qyapi.weixin.qq.com` | 内建 |
| 飞书 (Feishu) | `open.feishu.cn` | 内建 |
| 自定义 (Custom) | 用户自定义 | 手动配置域名和环境变量 |

## 记忆后端

| 后端 | 说明 |
|------|------|
| **QMD** | 受管的 QMD wrapper，用于基于文件的知识检索。通过 `codeshield-config qmd-backend enable` 配置。 |
| **Qdrant (True Recall / Jarvis Memory)** | 向量数据库，地址为 `127.0.0.1:6333`，用于语义记忆的存储与检索。 |

## 安装说明

### 前置条件

- Ubuntu 22.04+ 或 Debian 12+
- OpenClaw 已安装在 `/home/openclaw`
- Root 权限 (sudo)
- Python 3.8+, jq, curl

### 全新安装

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

安装器会依次完成以下步骤：
1. 创建 `openclaw-svc` 系统用户
2. 安装并配置 Squid 代理
3. 配置 `codeshield-secrets.service` 密钥管理服务
4. 为 `openclaw.service` 配置 systemd 沙箱
5. 安装 Guardian 监控服务
6. 部署 skills-policy.json 和注入防御模板
7. 从 `openclaw.json` 中迁移内联密钥

### 无损更新

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

`--update` 标志会保留所有现有的密钥、通道配置、模型配置和代理白名单，仅更新脚本、模板和 systemd 单元文件。

## CLI 命令参考

### 配置管理

```bash
codeshield-config show                  # 显示当前配置（密钥已脱敏）
codeshield-config edit                  # 交互式编辑所有密钥
codeshield-config set KEY=VALUE         # 设置单个密钥
```

### 大模型 Provider

```bash
codeshield-config list-models           # 列出已配置的 provider
codeshield-config add-model             # 交互式 provider 配置菜单
codeshield-config add-model deepseek    # 直接添加指定 provider
codeshield-config add-model minimax     # 添加 MiniMax（中国版 API）
codeshield-config add-model openai-oauth # 通过原生 OAuth 流程添加 OpenAI
codeshield-config patch-provider deepseek # OpenClaw 更新后重新打补丁
```

### 通道管理

```bash
codeshield-config list-channels         # 列出已配置的通道
codeshield-config add-channel           # 交互式通道配置菜单
                                        #   1) Telegram
                                        #   2) 企业微信 (WeCom)
                                        #   3) 飞书 (Feishu)
                                        #   4) Discord（交互式 API 配置）
                                        #   5) 自定义 (Custom)
```

### QMD 后端

```bash
codeshield-config qmd-backend show      # 显示 QMD 配置状态
codeshield-config qmd-backend enable    # 启用 QMD 检索后端
codeshield-config qmd-backend disable   # 禁用 QMD 后端
```

### 网络 / 代理

```bash
codeshield-config proxy-allow <domain>  # 添加域名到 Squid 白名单
codeshield-config network-mode          # 显示当前网络模式
codeshield-config network-mode open     # 允许所有域名通过代理
codeshield-config network-mode strict   # 限制为已知 API 域名
```

## 调试与排障

### 服务状态

```bash
systemctl status openclaw               # OpenClaw 服务状态
systemctl status codeshield-secrets     # 密钥解密服务状态
systemctl status codeshield-guardian    # Guardian 监控服务状态
```

### 实时日志

```bash
journalctl -u openclaw -f              # 实时查看 OpenClaw 日志
journalctl -u codeshield-guardian -f   # 实时查看 Guardian 日志
journalctl -u codeshield-secrets -f    # 实时查看密钥服务日志
```

### 安全检查

```bash
openclaw-injection-scan                 # 检查 SOUL.md 是否被篡改
security-audit.sh                       # 运行每日安全审计
```

### 紧急处置

```bash
emergency-lockdown                      # 终止 openclaw 服务并阻断所有网络
```

## 架构设计

### 三层安全模型

```
第一层：网络隔离 (Network Isolation)
  openclaw-svc 用户 --> Squid 代理 --> 仅放行白名单域名
                          |
                          +-- proxy-whitelist.conf（额外域名）
                          +-- squid.conf（known_api_domains ACL）

第二层：密钥管理 (Secret Management)
  secrets.env.enc --> systemd-creds 解密 --> /run/openclaw-codeshield/secrets.env (tmpfs)
                                              |
                                              +-- openclaw.service drop-in 的 EnvironmentFile
                                              +-- 明文密钥永远不会写入磁盘持久存储

第三层：运行时完整性 (Runtime Integrity)
  codeshield-guardian.service --> 监控 package.json 变更
                                  |
                                  +-- 重新迁移内联密钥
                                  +-- 重新应用 systemd drop-in
                                  +-- 同步运行时配置树
                                  +-- 刷新 SOUL.md canary
                                  +-- 强制执行 skills-policy.json
```

## systemd 服务表

| 服务 | 说明 | 类型 |
|------|------|------|
| `openclaw.service` | OpenClaw 主运行时（以 `openclaw-svc` 身份运行） | `simple` |
| `codeshield-secrets.service` | 启动时将 `secrets.env.enc` 解密到 tmpfs | `oneshot` |
| `codeshield-guardian.service` | OpenClaw 更新后重新应用保护措施 | `oneshot`（path 触发） |
| `codeshield-guardian.path` | 监控 OpenClaw 的 `package.json` 变更 | `path` |

## 日志路径

| 日志 | 路径 |
|------|------|
| Guardian 日志 | `/var/log/openclaw-codeshield/guardian.log` |
| 安全审计日志 | `/var/log/openclaw-codeshield/audit.log` |
| Squid 代理日志 | `/var/log/squid/access.log` |
| OpenClaw 日志 (journald) | `journalctl -u openclaw` |
