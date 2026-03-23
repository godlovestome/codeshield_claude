# Changelog

## [3.1.10] - 2026-03-23

### Added

- CODE SHIELD now writes non-native providers such as DeepSeek and GLM-5 into `openclaw.json -> auth.providers` during `codeshield-config add-model` and `codeshield-config patch-provider`.
- This keeps provider metadata inside the protected OpenClaw runtime instead of relying only on JS patching and model whitelist entries.

- CODE SHIELD 现在会在执行 `codeshield-config add-model` 和 `codeshield-config patch-provider` 时，把 DeepSeek、GLM-5 这类非原生 provider 写入 `openclaw.json -> auth.providers`。
- 这样 provider 元数据会保留在受保护的 OpenClaw runtime 中，而不是只依赖 JS patch 和模型白名单。

### Fixed

- Fixed DeepSeek on newer OpenClaw builds where `deepseek/deepseek-chat` or `deepseek/deepseek-reasoner` could still return `model_not_found` even though the API key, proxy whitelist, and model whitelist were already present.
- Updated the model whitelist sync so both the service runtime config and the home-side config are refreshed together when they exist.
- Refreshed the README in clean UTF-8 bilingual form for the 3.1.10 release.

- 修复了新版 OpenClaw 上 DeepSeek 仍然可能报 `model_not_found` 的问题，即使 API Key、代理白名单和模型白名单都已经存在。
- 更新了模型白名单同步逻辑：当 service runtime 配置和 home 侧配置同时存在时，会一起刷新。
- 重新整理了 3.1.10 版本 README，确保使用干净的 UTF-8 中英双语文本。

## [3.1.9] - 2026-03-23

### Fixed

- Fixed the non-destructive update path so the installer now fetches `proxy-preload.mjs` before hardening stage 4 runs.
- Fixed the undefined `CS_DIR` reference in `lib/04-hardening.sh`.
- Existing servers can now update cleanly to the OpenClaw-native OpenAI OAuth flow without being asked for `OPENAI_CLIENT_ID` or `OPENAI_CLIENT_SECRET`.

- 修复了无损更新路径：安装器现在会在第 4 阶段 hardening 之前先下发 `proxy-preload.mjs`。
- 修复了 `lib/04-hardening.sh` 中未定义的 `CS_DIR` 引用。
- 现有服务器现在可以正常升级到 OpenClaw 原生 OpenAI OAuth 流程，不会再要求填写 `OPENAI_CLIENT_ID` 或 `OPENAI_CLIENT_SECRET`。

## [3.1.8] - 2026-03-23

### Changed

- `codeshield-config add-model openai-oauth` now uses OpenClaw's native OAuth onboarding flow.
- OpenAI OAuth token state is no longer stored in CODE SHIELD secrets; it stays in the OpenClaw runtime auth store.

- `codeshield-config add-model openai-oauth` 现在改为调用 OpenClaw 原生 OAuth 引导流程。
- OpenAI OAuth token 状态不再写入 CODE SHIELD secrets，而是保留在 OpenClaw 运行时自己的认证存储中。
