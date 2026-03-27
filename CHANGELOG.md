# Changelog

## [3.2.0] - 2026-03-27

### Added / Changed

1. **Discord concurrency config / Discord并发配置** -- Discord channel now defaults to `maxConcurrent: 4` and `subagents: 12`, preventing message-storm lockups on busy servers.
2. **MiniMax China API restoration / MiniMax中国版API恢复** -- Restored MiniMax China endpoint (`api.minimaxi.com`) with `OPENCLAW_NATIVE_PROVIDER_CONFIG` support. Models: MiniMax-M2.5, MiniMax-M2.5-highspeed, MiniMax-M2.7, MiniMax-M2.7-highspeed. Uses `anthropic-messages` API type with `authHeader: True`.
3. **QMD retrieval failure fix / QMD检索失败修复** -- Fixed QMD retrieval scope to `allow` and updated TOOLS.md so the assistant no longer falsely claims retrieval is unavailable.
4. **exec-approval globally disabled / exec-approval全局关闭** -- Set `tools.exec.ask: "off"` with a three-layer enforcement approach. Removed `shell-exec` from `blocked_actions` in skills-policy.json to support exec functionality.
5. **Discord interactive channel setup / Discord add-channel交互式配置** -- New `cmd_add_channel_discord()` function (~332 lines) provides full interactive Discord setup: queries Discord API for guilds/channels, configures per-channel allowlists, group policy, DM policy, and mention requirements. Telegram added as built-in channel choice 1.
6. **add-model flow improvements / add-model配置流程改进** -- Added `OPENCLAW_NATIVE_PROVIDER_CONFIG` associative array for providers natively supported by OpenClaw that still need explicit config entries. Auth profile writing is now inlined into `update_openclaw_model_provider_config()` instead of using a separate function. Added `gateway.discord.gg` to Discord domains.

### 中文说明

1. **Discord并发配置** -- Discord 通道现在默认 `maxConcurrent: 4`、`subagents: 12`，防止繁忙服务器上的消息风暴导致锁死。
2. **MiniMax中国版API恢复** -- 恢复了 MiniMax 中国端点（`api.minimaxi.com`），增加 `OPENCLAW_NATIVE_PROVIDER_CONFIG` 支持。模型包括 MiniMax-M2.5、MiniMax-M2.5-highspeed、MiniMax-M2.7、MiniMax-M2.7-highspeed，使用 `anthropic-messages` API 类型并带 `authHeader: True`。
3. **QMD检索失败修复** -- 修复了 QMD 检索作用域为 `allow`，更新 TOOLS.md，使助手不再错误声称检索不可用。
4. **exec-approval全局关闭** -- 设置 `tools.exec.ask: "off"`，采用三层执行策略。从 skills-policy.json 的 `blocked_actions` 中移除了 `shell-exec`，以支持 exec 功能。
5. **Discord add-channel交互式配置** -- 新增 `cmd_add_channel_discord()` 函数（约332行），提供完整的 Discord 交互式配置：查询 Discord API 获取服务器/频道列表，配置频道级白名单、群组策略、DM 策略和 @提及要求。Telegram 已作为内建通道选项 1。
6. **add-model配置流程改进** -- 新增 `OPENCLAW_NATIVE_PROVIDER_CONFIG` 关联数组，用于原生支持但仍需显式配置项的 provider。auth profile 写入已内联到 `update_openclaw_model_provider_config()` 中，不再使用独立函数。Discord 域名增加了 `gateway.discord.gg`。

## [Unreleased]

### Added / Changed

- Non-native provider runtime config writes `models.providers.<provider>.apiKey` as an environment-variable reference such as `${DEEPSEEK_API_KEY}` instead of a bare variable name. This prevents `/model` switches from silently falling back to the default model when DeepSeek is selected.
- `qmd-backend enable` also sets `agents.defaults.memorySearch.enabled = true`, so Telegram and other channel sessions expose the built-in retrieval path that QMD uses.
- CODE SHIELD secret migration/export paths preserve `DEEPSEEK_API_KEY`, helping managed runtimes keep non-native provider credentials visible after repairs or migrations.
- `codeshield-config add-model` now refreshes `codeshield-secrets.service` after re-sealing secrets, so the live `openclaw-svc` runtime immediately sees newly added provider keys instead of stale tmpfs secrets.
- Runtime sync now refreshes `auth.json`, `auth-profiles.json`, and `device-auth.json` into `openclaw-svc` when the interactive home copy is newer, preventing service-side model/provider state from sticking to stale Codex auth.
- Runtime sync now rehydrates configured non-native providers from `/etc/openclaw-codeshield/models.d/*.conf`, or directly from managed secrets when the `.conf` file is missing, back into both protected `openclaw.json` files. DeepSeek and GLM-5 runtime provider blocks now survive guardian repairs and service-side syncs even on partially migrated hosts.
- Retrieval-protection wording was tightened so the assistant stops falsely claiming that Jarvis Memory, True Recall, or QMD are unavailable when the managed retrieval backend is enabled.
- Retrieval wording now explicitly forbids placeholder plans when the user directly asks for a QMD or memory search. The assistant must attempt one live retrieval check first.

### 中文说明

- 非原生 provider 的运行时配置会把 `models.providers.<provider>.apiKey` 写成 `${DEEPSEEK_API_KEY}` 这类环境变量引用，不再写入裸变量名，避免 `/model` 静默回退到默认模型。
- `qmd-backend enable` 会同步设置 `agents.defaults.memorySearch.enabled = true`，让 Telegram 等渠道会话暴露 QMD 所需的内建检索入口。
- CODE SHIELD 的 secrets 迁移与导出链路会保留 `DEEPSEEK_API_KEY`，确保修复或迁移后受管运行时仍能看到非原生 provider 的密钥。
- `codeshield-config add-model` 现在会在重新 seal secrets 后立即刷新 `codeshield-secrets.service`，避免 `openclaw-svc` 继续读取旧的 tmpfs secrets。
- runtime sync 现在会在 interactive home 的认证文件更新时，把 `auth.json`、`auth-profiles.json`、`device-auth.json` 刷新到 `openclaw-svc`，避免 service 侧卡在旧的 Codex 认证状态。
- 当用户直接要求检索 QMD 或 memory search 时，助手现在必须先做一次 live retrieval 检查，不能再先回复占位计划。

## [3.1.12] - 2026-03-23

### Added / Changed

- `qmd-backend enable` now writes `limits: { maxResults: 6, timeoutMs: 15000 }` into the managed OpenClaw QMD config.
- `qmd-backend show` now prints the effective QMD timeout and result limit.
- Refreshed the README and changelog in clean UTF-8 bilingual form.

### 中文说明

- `qmd-backend enable` 会把 `limits: { maxResults: 6, timeoutMs: 15000 }` 写入受管的 OpenClaw QMD 配置。
- `qmd-backend show` 会显示当前生效的 QMD 超时和结果数限制。
- README 和 changelog 已整理为干净的 UTF-8 中英双语文本。

## [3.1.11] - 2026-03-23

- Registered non-native providers through `models.providers`.
- Kept OpenAI OAuth on the native OpenClaw onboarding flow.
