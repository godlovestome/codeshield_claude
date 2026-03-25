# Changelog

## [Unreleased]

### Added / Changed

- Non-native provider runtime config now writes `models.providers.<provider>.apiKey` as an environment-variable reference such as `${DEEPSEEK_API_KEY}` instead of a bare variable name. This prevents `/model` switches from silently falling back to the default model when DeepSeek is selected.
- `qmd-backend enable` now also sets `agents.defaults.memorySearch.enabled = true`, so Telegram and other channel sessions expose the built-in retrieval path that QMD uses.
- CODE SHIELD secret migration/export paths now preserve `DEEPSEEK_API_KEY`, helping managed runtimes keep non-native provider credentials visible after repairs or migrations.
- Retrieval-protection wording was tightened so the assistant stops falsely claiming that Jarvis Memory / True Recall / QMD are unavailable when the managed retrieval backend is enabled.

### 新增 / 调整

- 非原生 provider 的运行时配置现在会把 `models.providers.<provider>.apiKey` 写成 `${DEEPSEEK_API_KEY}` 这类环境变量引用，不再写入裸变量名，避免切到 DeepSeek 后 `/model` 静默回退到默认模型。
- `qmd-backend enable` 现在会同步设置 `agents.defaults.memorySearch.enabled = true`，让 Telegram 等渠道会话真正暴露 QMD 所依赖的内建检索入口。
- CODE SHIELD 的 secrets 迁移与导出链路现在会保留 `DEEPSEEK_API_KEY`，确保修复或迁移后受管运行时仍然能看到非原生 provider 的密钥。
- 检索保护文案进一步收紧：当受管检索 backend 已启用时，助手不应再错误声称 Jarvis Memory / True Recall / QMD 不可用。

## [3.1.12] - 2026-03-23

### Added / Changed

- `qmd-backend enable` now writes `limits: { maxResults: 6, timeoutMs: 15000 }` into the managed OpenClaw QMD config.
- `qmd-backend show` now prints the effective QMD timeout and result limit.
- Refreshed the README and changelog in clean UTF-8 bilingual form.

### 新增 / 调整

- `qmd-backend enable` 现在会把 `limits: { maxResults: 6, timeoutMs: 15000 }` 写入受管的 OpenClaw QMD 配置。
- `qmd-backend show` 现在会显示当前生效的 QMD 超时和结果数限制。
- README 与 changelog 已整理为干净的 UTF-8 中英双语文本。

## [3.1.11] - 2026-03-23

- Registered non-native providers through `models.providers`.
- Kept OpenAI OAuth on the native OpenClaw onboarding flow.
