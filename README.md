# CODE SHIELD V3.1.12

**AI agent network security hardening for OpenClaw**  
**面向 OpenClaw 的 AI Agent 网络安全加固框架**

## Purpose / 目标

CODE SHIELD keeps OpenClaw inside a controlled Linux service runtime. It isolates the live service as `openclaw-svc`, keeps secrets under CODE SHIELD management, routes outbound traffic through the guarded proxy path, and still allows trusted local integrations such as QMD to run inside the same protected boundary.

CODE SHIELD 用于让 OpenClaw 在受控的 Linux 服务运行时中工作。它会把在线服务隔离为 `openclaw-svc`，把密钥交给 CODE SHIELD 接管，把外发流量统一收束到受控代理路径，同时允许 QMD 这类可信本地集成继续在同一套保护边界内运行。

## Version Focus / 版本重点

### v3.1.12

- `codeshield-config qmd-backend enable` now writes explicit QMD retrieval limits into `openclaw.json`, raising the timeout to `15000ms` for larger live knowledge bases.
- The QMD backend status output now shows `timeoutMs` and `maxResults` directly.
- OpenAI OAuth remains handled by OpenClaw's native login flow, not by storing client secrets in CODE SHIELD.
- Non-native providers such as DeepSeek and GLM-5 remain managed through `models.providers` instead of the invalid legacy path.

### v3.1.12 中文说明

- `codeshield-config qmd-backend enable` 现在会把 QMD 检索限制显式写入 `openclaw.json`，把超时提升到 `15000ms`，适配更大的在线知识库。
- QMD backend 的状态输出现在会直接显示 `timeoutMs` 与 `maxResults`。
- OpenAI OAuth 继续由 OpenClaw 原生登录流程接管，而不是把 client secrets 存进 CODE SHIELD。
- DeepSeek、GLM-5 这类非原生 provider 仍通过 `models.providers` 管理，不再走旧的无效路径。

## Quick Start / 快速开始

### Fresh Install / 一行代码全新安装

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

### Non-Destructive Update / 一行代码无损更新

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

After deployment, keep using `codeshield-config` for configuration changes instead of writing secrets back into `openclaw.json`.

部署完成后，请继续使用 `codeshield-config` 维护配置，不要把密钥重新写回 `openclaw.json`。

## Core Security Model / 核心安全模型

- `openclaw.service` runs as `openclaw-svc`
- secrets are managed by CODE SHIELD and decrypted to `/run/openclaw-codeshield/secrets.env`
- outbound traffic is forced through the controlled proxy path
- local loopback services remain reachable through `NO_PROXY`
- service runtime config lives under `/var/lib/openclaw-svc/.openclaw/`

- `openclaw.service` 以 `openclaw-svc` 身份运行
- 密钥由 CODE SHIELD 接管，并解密到 `/run/openclaw-codeshield/secrets.env`
- 外发流量统一通过受控代理路径
- 本地 loopback 服务通过 `NO_PROXY` 保持可用
- service runtime 配置位于 `/var/lib/openclaw-svc/.openclaw/`

## OpenAI OAuth Under CODE SHIELD / 在 CODE SHIELD 下使用 OpenAI OAuth

Run this first:

```bash
sudo codeshield-config add-model openai-oauth
```

This step registers the provider, updates the whitelist, and prints the native OpenClaw OAuth onboarding command. It does **not** store client id or client secret in CODE SHIELD.

这一步会注册 provider、更新白名单，并打印 OpenClaw 原生 OAuth 引导命令。它**不会**把 client id 或 client secret 存进 CODE SHIELD。

Then complete OAuth in the server terminal:

```bash
sudo systemd-run --pty \
  --uid=openclaw-svc \
  --gid=openclaw-svc \
  -p EnvironmentFile=/run/openclaw-codeshield/secrets.env \
  -p Environment=HOME=/var/lib/openclaw-svc \
  -p Environment=XDG_CONFIG_HOME=/var/lib/openclaw-svc/.config \
  -p WorkingDirectory=/var/lib/openclaw-svc \
  /home/openclaw/.npm-global/bin/openclaw onboard --auth-choice openai-codex
```

## DeepSeek Under CODE SHIELD / 在 CODE SHIELD 下使用 DeepSeek

```bash
sudo codeshield-config add-model deepseek
```

This command will:

- store `DEEPSEEK_API_KEY` in CODE SHIELD secrets
- update the proxy whitelist for `api.deepseek.com`
- write DeepSeek model refs into `agents.defaults.models`
- write `models.providers.deepseek` into the protected OpenClaw runtime config

这条命令会：

- 把 `DEEPSEEK_API_KEY` 存入 CODE SHIELD secrets
- 更新 `api.deepseek.com` 的代理白名单
- 把 DeepSeek 模型引用写入 `agents.defaults.models`
- 把 `models.providers.deepseek` 写入受保护的 OpenClaw runtime 配置

## QMD Under CODE SHIELD / 在 CODE SHIELD 下运行 QMD

`codeshield-config qmd-backend enable` keeps OpenClaw pointed at the managed QMD wrapper and writes the runtime-safe config into the service workspace while preserving the writable `openclaw-svc` workspace.

`codeshield-config qmd-backend enable` 会让 OpenClaw 指向受控的 QMD wrapper，并把适合 service runtime 的配置写入 `openclaw-svc` 工作区，同时保留可写的 service workspace。

Useful commands / 常用命令：

```bash
sudo codeshield-config qmd-backend show
sudo codeshield-config qmd-backend enable
sudo systemctl status openclaw
sudo systemctl status codeshield-guardian
```

## Telegram And Secret Ownership / Telegram 与密钥归属

- Telegram bot token should remain under `codeshield-config`
- do not move Telegram secrets back into `openclaw onboard`
- `openclaw.json` should describe channel behavior, not hold the real token

- Telegram bot token 应继续由 `codeshield-config` 接管
- 不要把 Telegram 密钥重新填回 `openclaw onboard`
- `openclaw.json` 应只描述通道行为，而不是保存真实 token
