# Changelog

## [Unreleased]

### Added / Changed

- Non-native provider runtime config writes `models.providers.<provider>.apiKey` as an environment-variable reference such as `${DEEPSEEK_API_KEY}` instead of a bare variable name. This prevents `/model` switches from silently falling back to the default model when DeepSeek is selected.
- `qmd-backend enable` also sets `agents.defaults.memorySearch.enabled = true`, so Telegram and other channel sessions expose the built-in retrieval path that QMD uses.
- CODE SHIELD secret migration/export paths preserve `DEEPSEEK_API_KEY`, helping managed runtimes keep non-native provider credentials visible after repairs or migrations.
- `codeshield-config add-model` now refreshes `codeshield-secrets.service` after re-sealing secrets, so the live `openclaw-svc` runtime immediately sees newly added provider keys instead of stale tmpfs secrets.
- Runtime sync now refreshes `auth.json`, `auth-profiles.json`, and `device-auth.json` into `openclaw-svc` when the interactive home copy is newer, preventing service-side model/provider state from sticking to stale Codex auth.
- Runtime sync now rehydrates configured non-native providers from `/etc/openclaw-codeshield/models.d/*.conf` back into both protected `openclaw.json` files, so DeepSeek and GLM-5 runtime provider blocks survive guardian repairs and service-side syncs.
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
