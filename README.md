# CODE SHIELD V3.1.9

**AI agent network security hardening for OpenClaw**  
**面向 OpenClaw 的 AI Agent 网络安全加固框架**

## Purpose / 目标

CODE SHIELD keeps OpenClaw inside a controlled Linux service runtime. It isolates the live service as `openclaw-svc`, keeps secrets under CODE SHIELD management, forces outbound traffic through the guarded proxy path, and still allows trusted local integrations such as QMD to run inside the same protected boundary.

CODE SHIELD 用于让 OpenClaw 在受控的 Linux 服务运行时中工作。它会把在线服务隔离为 `openclaw-svc`，把密钥交给 CODE SHIELD 接管，把外发流量统一收束到受控代理链路，同时允许 QMD 这类可信本地集成继续在同一套保护边界内运行。

## Version Focus / 版本重点

### v3.1.9

- Non-destructive updates now correctly deploy the proxy preload asset before hardening runs.
- `install.sh --update` no longer crashes on the undefined `CS_DIR` reference.
- Existing servers can now upgrade cleanly to the OpenClaw-native OpenAI OAuth flow.

- 无损更新现在会先正确下发代理 preload 资源，再执行 hardening。
- `install.sh --update` 不会再因为未定义的 `CS_DIR` 变量中途崩溃。
- 现有服务器现在可以正常升级到 OpenClaw 原生 OpenAI OAuth 流程。

### v3.1.8

- `codeshield-config add-model openai-oauth` now uses OpenClaw's native OAuth onboarding flow instead of asking for `OPENAI_CLIENT_ID` and `OPENAI_CLIENT_SECRET`.
- OpenAI OAuth tokens stay in the OpenClaw runtime auth store instead of being written into CODE SHIELD secrets.
- Runtime sync now preserves service-side OAuth state and no longer overwrites `openclaw-svc` auth files during guardian refreshes.

- `codeshield-config add-model openai-oauth` 现在改为调用 OpenClaw 原生 OAuth 引导流程，不再要求手动填写 `OPENAI_CLIENT_ID` 和 `OPENAI_CLIENT_SECRET`。
- OpenAI OAuth token 会保留在 OpenClaw 自己的运行时认证存储中，不会写入 CODE SHIELD secrets。
- runtime 同步现在会保护 service 侧 OAuth 状态，guardian 刷新时不再覆盖 `openclaw-svc` 的认证文件。

## Quick Start / 快速开始

### Fresh Install / 全新安装

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

### Non-Destructive Update / 无损更新

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

这一步会注册 provider、更新代理白名单，并打印 OpenClaw 原生 OAuth 引导命令。它**不会**把 client id 或 client secret 存进 CODE SHIELD。

Then complete OAuth in the server terminal:

```bash
sudo -u openclaw-svc env HOME=/var/lib/openclaw-svc XDG_CONFIG_HOME=/var/lib/openclaw-svc/.config /home/openclaw/.npm-global/bin/openclaw onboard --auth-choice openai-codex
```

If OpenClaw prints an authorization link, open it in your browser, finish login, and paste the callback/result URL back into the terminal when prompted.

如果 OpenClaw 输出授权链接，请在浏览器中完成登录，并在终端提示时把回调结果链接粘贴回去。

## Common Operations / 常用操作

```bash
sudo codeshield-config show
sudo codeshield-config edit
sudo codeshield-config add-model openai
sudo codeshield-config add-model openai-oauth
sudo codeshield-config add-model deepseek
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
- `openclaw.json` 应负责描述通道行为，而不是保存真实 token

## QMD Under CODE SHIELD / 在 CODE SHIELD 下运行 QMD

`codeshield-config qmd-backend enable` keeps OpenClaw pointed at the managed QMD wrapper and writes the runtime-safe config into the service workspace while preserving the writable `openclaw-svc` workspace.

`codeshield-config qmd-backend enable` 会让 OpenClaw 指向受控的 QMD wrapper，并把适合 service runtime 的配置写入 `openclaw-svc` 工作区，同时保留可写的 service workspace。
