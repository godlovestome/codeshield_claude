# Changelog

## [3.1.11] - 2026-03-23

### Fixed

- CODE SHIELD now writes non-native providers such as DeepSeek and GLM-5 into `openclaw.json -> models.providers` instead of the invalid `auth.providers` path.
- `codeshield-config add-model` and `codeshield-config patch-provider` now clean up stale `auth.providers.<provider>` entries when they repair older deployments.
- Existing servers can keep API keys inside CODE SHIELD while converging back to a valid OpenClaw runtime config.
- Refreshed the README in clean UTF-8 bilingual form for the 3.1.11 release.

- CODE SHIELD 现在会把 DeepSeek、GLM-5 这类非原生 provider 写入 `openclaw.json -> models.providers`，不再使用无效的 `auth.providers` 路径。
- `codeshield-config add-model` 和 `codeshield-config patch-provider` 在修复旧部署时，会顺手清理遗留的 `auth.providers.<provider>` 错误条目。
- 现有服务器可以继续把 API Key 保留在 CODE SHIELD 中，同时无损收敛回合法的 OpenClaw runtime 配置。
- 已为 3.1.11 版本重新整理 UTF-8 中英双语 README。

## [3.1.10] - 2026-03-23

### Fixed

- Fixed the non-destructive update path so the installer now fetches `proxy-preload.mjs` before hardening stage 4 runs.
- Fixed the undefined `CS_DIR` reference in `lib/04-hardening.sh`.
- Existing servers can now update cleanly to the OpenClaw-native OpenAI OAuth flow without being asked for `OPENAI_CLIENT_ID` or `OPENAI_CLIENT_SECRET`.

- 修复了无损更新路径：安装器现在会在第 4 阶段 hardening 之前先下发 `proxy-preload.mjs`。
- 修复了 `lib/04-hardening.sh` 中未定义的 `CS_DIR` 引用。
- 现有服务器现在可以正常升级到 OpenClaw 原生 OpenAI OAuth 流程，不会再要求填写 `OPENAI_CLIENT_ID` 或 `OPENAI_CLIENT_SECRET`。

## [3.1.9] - 2026-03-23

### Changed

- `codeshield-config add-model openai-oauth` now uses OpenClaw's native OAuth onboarding flow.
- OpenAI OAuth token state is no longer stored in CODE SHIELD secrets; it stays in the OpenClaw runtime auth store.

- `codeshield-config add-model openai-oauth` 现在改为调用 OpenClaw 原生 OAuth 引导流程。
- OpenAI OAuth token 状态不再写入 CODE SHIELD secrets，而是保留在 OpenClaw 运行时自己的认证存储中。
