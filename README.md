# CODE SHIELD V3.1.12

**AI agent network security hardening for OpenClaw**  
**面向 OpenClaw 的 AI Agent 网络安全加固框架**

## Purpose / 目标

CODE SHIELD keeps OpenClaw inside a controlled Linux service runtime. It isolates the live service as `openclaw-svc`, keeps secrets under CODE SHIELD management, routes outbound traffic through the guarded proxy path, and still allows trusted local integrations such as QMD to run inside the same protected boundary.

CODE SHIELD 用于让 OpenClaw 在受控的 Linux service runtime 中运行。它会把在线服务隔离为 `openclaw-svc`，把密钥交给 CODE SHIELD 管理，把外发流量收束到受控代理路径，同时允许 QMD 这类可信本地集成继续在同一套保护边界内运行。

## Version Focus / 当前版本重点

### v3.1.12

- `codeshield-config qmd-backend enable` writes explicit QMD retrieval limits into `openclaw.json`, raising the timeout to `15000ms` for larger live knowledge bases.
- The QMD backend status output shows `timeoutMs` and `maxResults` directly.
- OpenAI OAuth remains handled by OpenClaw's native login flow, not by storing client secrets in CODE SHIELD.
- Non-native providers such as DeepSeek and GLM-5 remain managed through `models.providers` instead of the invalid legacy path.
- Runtime repair rehydrates configured non-native providers from `/etc/openclaw-codeshield/models.d/*.conf`, or directly from managed secrets when that `.conf` is missing, back into the protected `openclaw.json` files. This prevents Telegram `/model` switches from silently falling back after updates or guardian syncs.

### v3.1.12 中文说明

- `codeshield-config qmd-backend enable` 会把 QMD 检索限制显式写入 `openclaw.json`，把超时提升到 `15000ms`，适配更大的在线知识库。
- QMD backend 的状态输出会直接显示 `timeoutMs` 与 `maxResults`。
- OpenAI OAuth 继续由 OpenClaw 原生登录流程接管，而不是把 client secrets 存进 CODE SHIELD。
- DeepSeek、GLM-5 这类非原生 provider 继续通过 `models.providers` 管理，不再走旧的无效路径。

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

It now enforces all of the following / 现在会额外确保：

- `memory.backend = qmd`
- `memory.citations = auto`
- `memory.qmd.searchMode = search`
- `agents.defaults.memorySearch.enabled = true`
- the managed QMD wrapper remains the retrieval entrypoint for both runtimes

- `memory.backend = qmd`
- `memory.citations = auto`
- `memory.qmd.searchMode = search`
- `agents.defaults.memorySearch.enabled = true`
- 两套运行时都会继续使用受管的 QMD wrapper 作为检索入口

Useful commands / 常用命令：

```bash
sudo codeshield-config qmd-backend show
sudo codeshield-config qmd-backend enable
sudo systemctl status openclaw
sudo systemctl status codeshield-guardian
```

## Telegram + `/model` Repair Notes / Telegram 与 `/model` 修复说明

If Telegram says it switched to DeepSeek but real replies still run on Codex, refresh the installed CODE SHIELD scripts so provider API keys stay environment-backed and QMD retrieval stays enabled for chat sessions.

如果 Telegram 显示已经切到 DeepSeek，但真实回复仍然跑在 Codex 上，请刷新已安装的 CODE SHIELD 脚本，确保 provider API key 继续通过环境变量注入，同时保证聊天会话中的 QMD 检索保持开启。

```bash
sudo curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/scripts/codeshield-config -o /usr/local/sbin/codeshield-config
sudo curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/scripts/openclaw-guardian -o /usr/local/sbin/openclaw-guardian
sudo curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/templates/soul-injection.md -o /usr/local/lib/openclaw-codeshield/soul-injection.md
sudo chmod 755 /usr/local/sbin/codeshield-config /usr/local/sbin/openclaw-guardian
sudo codeshield-config qmd-backend enable
sudo /usr/local/sbin/openclaw-guardian
sudo systemctl restart openclaw.service
```

This refresh path now does two extra things that matter for Telegram reliability:

- it refreshes `codeshield-secrets.service`, so newly added provider keys such as `DEEPSEEK_API_KEY` are visible to the live `openclaw-svc` runtime immediately
- it refreshes the service-side auth files from the interactive OpenClaw home when those source files are newer, so the service does not stay pinned to stale Codex auth/model state
- it rehydrates configured non-native provider runtime blocks from `/etc/openclaw-codeshield/models.d/*.conf`, or directly from managed secrets if the model registration file is missing, so `models.providers.deepseek` and similar entries survive repairs and guardian syncs

这条刷新链路现在还会额外做两件和 Telegram 稳定性直接相关的事：

- 刷新 `codeshield-secrets.service`，让新加入的 provider key（例如 `DEEPSEEK_API_KEY`）立刻对在线的 `openclaw-svc` 运行时可见
- 当 interactive OpenClaw home 里的认证文件更新时，把它们刷新到 service 侧，避免 service 长时间停留在旧的 Codex auth / model state

Validate after the refresh / 刷新后验证：

```bash
sudo codeshield-config qmd-backend show
grep -n "searchMode" /usr/local/sbin/codeshield-config
grep -n "Do not claim that you lack Jarvis Memory, True Recall, QMD" /home/openclaw/.openclaw/SOUL.md
systemctl status codeshield-secrets.service --no-pager
sudo -u openclaw-svc env HOME=/var/lib/openclaw-svc XDG_CONFIG_HOME=/var/lib/openclaw-svc/.config /home/openclaw/.npm-global/bin/openclaw models status --json --probe-provider deepseek
```

Expected / 预期：

- `searchMode: search`
- `backend: qmd`
- the service SOUL contains the managed-retrieval wording
- `models.providers.deepseek` is present in the protected runtime config when DeepSeek is configured
- DeepSeek no longer shows as `configured + missing` in `openclaw models status`
- new Telegram `/new` sessions stop denying Jarvis Memory / True Recall / QMD access

- `searchMode: search`
- `backend: qmd`
- service 运行时的 SOUL 已包含受管检索约束文案
- Telegram 的 `/new` 新会话不再错误否认 Jarvis Memory / True Recall / QMD 的可用性

## Telegram And Secret Ownership / Telegram 与密钥归属

- Telegram bot token should remain under `codeshield-config`
- do not move Telegram secrets back into `openclaw onboard`
- `openclaw.json` should describe channel behavior, not hold the real token

- Telegram bot token 应继续由 `codeshield-config` 接管
- 不要把 Telegram 密钥重新写回 `openclaw onboard`
- `openclaw.json` 应只描述通道行为，而不是保存真实 token
