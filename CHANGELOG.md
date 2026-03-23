# Changelog

## [3.1.9] - 2026-03-23

### Fixed / 修复

- Fixed the non-destructive update path so the installer now ships `proxy-preload.mjs` before Stage 4 hardening runs.
- Removed the undefined `CS_DIR` reference from `lib/04-hardening.sh`, which previously caused `install.sh --update` to abort before deploying the new `codeshield-config`.
- This means existing servers can now update cleanly to the OpenClaw-native OpenAI OAuth flow without being asked for `OPENAI_CLIENT_ID` or `OPENAI_CLIENT_SECRET`.

- 修复了无损更新路径：安装器现在会在第 4 阶段 hardening 之前先下发 `proxy-preload.mjs`。
- 移除了 `lib/04-hardening.sh` 里未定义的 `CS_DIR` 引用；这个问题之前会导致 `install.sh --update` 中途退出，新的 `codeshield-config` 根本没有部署成功。
- 这也意味着已有服务器现在可以正常升级到 OpenClaw 原生 OpenAI OAuth 流程，不会再要求填写 `OPENAI_CLIENT_ID` 或 `OPENAI_CLIENT_SECRET`。

### Docs / 文档

- Refreshed the README and changelog in clean UTF-8 bilingual form for the 3.1.9 release.

- 重新整理了 3.1.9 版本的 README 与 changelog，确保使用干净的 UTF-8 中英双语文本。

## [3.1.8] - 2026-03-23

### Fixed / 修复

- `codeshield-config add-model openai-oauth` now uses OpenClaw's native OAuth onboarding flow instead of collecting `OPENAI_CLIENT_ID`, `OPENAI_CLIENT_SECRET`, and `OPENAI_ORG_ID`.
- OpenAI OAuth token state is no longer stored in CODE SHIELD secrets; it stays in the OpenClaw runtime auth store.
- `lib/02-isolation.sh` and `scripts/openclaw-guardian` now preserve service-side auth files during runtime sync and only seed auth state once when the service runtime has no auth state yet.

- `codeshield-config add-model openai-oauth` 现在改为使用 OpenClaw 原生 OAuth 引导流程，不再收集 `OPENAI_CLIENT_ID`、`OPENAI_CLIENT_SECRET` 和 `OPENAI_ORG_ID`。
- OpenAI OAuth token 状态不再写入 CODE SHIELD secrets，而是保留在 OpenClaw 运行时自己的认证存储中。
- `lib/02-isolation.sh` 与 `scripts/openclaw-guardian` 现在会在 runtime 同步时保护 service 侧认证文件，只会在 service runtime 还没有认证状态时做一次初始化同步。
