# Changelog

## [3.1.8] - 2026-03-23

### Fixed / 修复

- `codeshield-config add-model openai-oauth` now uses OpenClaw's native OAuth onboarding flow instead of collecting `OPENAI_CLIENT_ID`, `OPENAI_CLIENT_SECRET`, and `OPENAI_ORG_ID`.
- OpenAI OAuth token state is no longer stored in CODE SHIELD secrets; it stays in the OpenClaw runtime auth store.
- `lib/02-isolation.sh` and `scripts/openclaw-guardian` now preserve service-side auth files during runtime sync and only seed auth state once when the service runtime has no auth state yet.

- `codeshield-config add-model openai-oauth` 现在改为使用 OpenClaw 原生 OAuth 引导流程，不再收集 `OPENAI_CLIENT_ID`、`OPENAI_CLIENT_SECRET` 和 `OPENAI_ORG_ID`。
- OpenAI OAuth token 状态不再写入 CODE SHIELD secrets，而是保留在 OpenClaw 运行时自己的认证存储中。
- `lib/02-isolation.sh` 与 `scripts/openclaw-guardian` 现在会在 runtime 同步时保护 service 侧认证文件，只会在 service runtime 还没有任何认证状态时做一次初始迁移。

### Docs / 文档

- Rewrote `README.md` and `CHANGELOG.md` as clean UTF-8 bilingual documents.

- 将 `README.md` 和 `CHANGELOG.md` 重写为干净的 UTF-8 双语文档。

## [3.1.7] - 2026-03-23

### Fixed / 修复

- `openclaw-guardian` now exits explicitly with success after completing the SOUL refresh path, preventing false systemd failures from trailing control-character noise after hot syncs.

- `openclaw-guardian` 在完成 SOUL 刷新路径后会显式成功退出，避免热同步后因尾部控制字符噪声造成的假性 systemd 失败。

## [3.1.6] - 2026-03-23

### Fixed / 修复

- `openclaw-guardian` and the install-time injection step now refresh the managed SOUL protection block on existing deployments instead of only appending it once.
- Existing runtimes can now pick up the new live QMD verification guardrail without reinstalling or manually editing `SOUL.md`.

- `openclaw-guardian` 与安装期的注入步骤现在会刷新已有部署中的受管 SOUL 保护块，而不只是首次追加一次。
- 这让旧部署也可以直接拿到新的 QMD 实时验证护栏，而无需重装或手工修改 `SOUL.md`。

## [3.1.5] - 2026-03-23

### Fixed / 修复

- Added a CODE SHIELD SOUL runtime directive that forces a live retrieval check before OpenClaw answers whether QMD or the knowledge base is available.
- This prevents Telegram sessions from relying only on stale conversation context after the QMD backend has already been repaired.

- 新增 CODE SHIELD 的 SOUL 运行时指令：当 OpenClaw 被问到 QMD 或知识库是否可用时，必须先做一次实时检索验证，再给出回答。
- 这样可以避免 Telegram 老会话在 QMD 后端已经修好后，仍然只依赖过期上下文继续误答。
