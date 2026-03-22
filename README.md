# CODE SHIELD V3.1.5

**AI Agent network security hardening for OpenClaw**  
**面向 OpenClaw 的 AI Agent 网络安全加固框架**

## Purpose / 目标

CODE SHIELD is a defense-in-depth framework for OpenClaw on Linux servers. It isolates the live service as `openclaw-svc`, externalizes secrets into CODE SHIELD management, forces outbound traffic through the controlled proxy path, and keeps local integrations such as QMD under the same guarded runtime model.

CODE SHIELD 是面向 Linux 服务器上 OpenClaw 的纵深防御框架。它会把在线服务隔离为 `openclaw-svc` 用户，把密钥统一移交给 CODE SHIELD 管理，把外发网络强制收敛到受控代理路径，并让 QMD 这类本地集成也运行在同一套受保护模型下。

**Version focus / 版本重点：v3.1.5**

- Adds a runtime SOUL guardrail that forces a live retrieval check before answering whether QMD or the knowledge base is available.
- Keeps the Telegram/OpenClaw runtime under the same CODE SHIELD-managed secret and workspace model.
- Preserves the earlier systemd secret-loading and writable workspace fixes.

- 新增运行时 SOUL 护栏：当用户询问 QMD 或知识库是否可用时，先做一次实时检索验证，再回答。
- 继续保持 Telegram / OpenClaw 运行时处于同一套 CODE SHIELD 管理的密钥与 workspace 模型之下。
- 保留此前对 systemd 密钥读取和可写 workspace 的修复。

## Quick Start / 快速开始

### Fresh Install / 全新安装

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

### Non-Destructive Update / 无损更新

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

After deployment, use `codeshield-config` for configuration changes instead of rerunning onboarding or writing secrets into `openclaw.json`.

部署完成后，请使用 `codeshield-config` 变更配置，不要重新跑 onboard，也不要把密钥直接写回 `openclaw.json`。

## Core Security Model / 核心安全模型

- `openclaw.service` runs as `openclaw-svc`
- secrets live in CODE SHIELD, not inline in `openclaw.json`
- secrets are decrypted to `/run/openclaw-codeshield/secrets.env`
- outbound traffic is forced through the controlled proxy path
- local loopback services remain reachable with `NO_PROXY`
- runtime config is mirrored into `/var/lib/openclaw-svc/.openclaw/`

- `openclaw.service` 以 `openclaw-svc` 身份运行
- 密钥由 CODE SHIELD 管理，不以内联形式留在 `openclaw.json`
- 密钥解密后只落在 `/run/openclaw-codeshield/secrets.env`
- 外发流量强制经过受控代理路径
- 本地 loopback 服务通过 `NO_PROXY` 保持可用
- 运行时配置镜像到 `/var/lib/openclaw-svc/.openclaw/`

## Important Operations / 重要操作

```bash
sudo codeshield-config show
sudo codeshield-config edit
sudo codeshield-config add-model deepseek
sudo codeshield-config qmd-backend show
sudo codeshield-config qmd-backend enable
sudo codeshield-config qmd-backend disable
```

### Telegram and Secret Ownership / Telegram 与密钥归属

- Telegram bot token and chat id must remain under `codeshield-config` management.
- Do not put Telegram secrets back into `openclaw onboard` prompts or inline `openclaw.json`.
- `openclaw.json` should describe channel behavior, not store the actual token.

- Telegram bot token 和 chat id 必须继续由 `codeshield-config` 接管。
- 不要再把 Telegram 密钥重新填回 `openclaw onboard` 或内联到 `openclaw.json`。
- `openclaw.json` 负责描述通道行为，不负责保存真实 token。

## QMD Under CODE SHIELD / 在 CODE SHIELD 下运行 QMD

`codeshield-config qmd-backend enable` will:

- keep `memory.backend=qmd`
- point OpenClaw to `/home/openclaw/scripts/qmd-openclaw-wrapper.sh`
- keep the QMD data source under `/home/openclaw/qmd-index/*`
- write the runtime-safe config into `/var/lib/openclaw-svc/.openclaw/openclaw.json`
- preserve the writable service workspace at `/var/lib/openclaw-svc/.openclaw/workspace`

`codeshield-config qmd-backend enable` 会：

- 保持 `memory.backend=qmd`
- 把 OpenClaw 指向 `/home/openclaw/scripts/qmd-openclaw-wrapper.sh`
- 继续使用 `/home/openclaw/qmd-index/*` 作为 QMD 数据源
- 把适用于 runtime 的配置写入 `/var/lib/openclaw-svc/.openclaw/openclaw.json`
- 保留可写的 service workspace：`/var/lib/openclaw-svc/.openclaw/workspace`

## Recommended Checks / 推荐检查命令

```bash
sudo codeshield-config show
sudo codeshield-config qmd-backend show
sudo systemctl status openclaw
sudo systemctl status codeshield-secrets
sudo systemctl status qmd-mcp
sudo /usr/local/sbin/security-audit.sh
```

## OpenClaw Update Safety / OpenClaw 更新安全

- Use the CODE SHIELD update command above.
- Do not overwrite `/etc/openclaw-codeshield/` manually.
- Guardian should re-sync runtime data after updates.
- If needed, re-run:

```bash
sudo codeshield-config qmd-backend enable
```

## QMD Verification Behavior / QMD 可用性验证行为

- When a user asks whether QMD or knowledge-base retrieval is working, the live runtime should verify via an approved retrieval call before answering.
- This reduces false "still unavailable" replies caused by stale Telegram session context after backend repairs.

- 当用户询问 QMD 或知识库检索是否正常时，运行时会先做一次受控检索验证，再给出结论。
- 这样可以减少后端已经修好但 Telegram 老会话仍沿用旧上下文、继续答“还不行”的误报。

- 请使用上面的 CODE SHIELD 无损更新命令。
- 不要手工覆盖 `/etc/openclaw-codeshield/`。
- OpenClaw 更新后，guardian 应重新同步 runtime 数据。
- 如有需要，可重新执行：

```bash
sudo codeshield-config qmd-backend enable
```
