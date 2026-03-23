# Changelog

## [3.1.12] - 2026-03-23

### Added / Changed

- `qmd-backend enable` now writes `limits: { maxResults: 6, timeoutMs: 15000 }` into the managed OpenClaw QMD config.
- `qmd-backend show` now prints the effective QMD timeout and result limit.
- Refreshed the README and changelog in clean UTF-8 bilingual form.

### 新增 / 调整

- `qmd-backend enable` 现在会把 `limits: { maxResults: 6, timeoutMs: 15000 }` 写入受管的 OpenClaw QMD 配置。
- `qmd-backend show` 现在会显示当前生效的 QMD 超时和结果数限制。
- 重新整理 README 与 changelog，统一为干净的 UTF-8 中英双语文本。

## [3.1.11] - 2026-03-23

- Registered non-native providers through `models.providers`.
- Kept OpenAI OAuth on the native OpenClaw onboarding flow.
