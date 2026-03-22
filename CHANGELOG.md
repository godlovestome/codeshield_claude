# Changelog

## [3.1.5] - 2026-03-23

### Fixed / 修复

- Added a CODE SHIELD SOUL runtime directive that forces a live retrieval check before OpenClaw answers whether QMD or the knowledge base is available.
- This prevents Telegram sessions from relying only on stale conversation context after the QMD backend has already been repaired.

- 新增 CODE SHIELD 的 SOUL 运行时指令：当 OpenClaw 被问到 QMD 或知识库是否可用时，必须先做一次实时检索验证，再回答。
- 这样可以避免 Telegram 老会话在 QMD 后端已经修好后，仍然只根据过期上下文继续答“还不行”。

## [3.1.4] - 2026-03-23

### Fixed / 修复

- `openclaw-guardian` now reads systemd-style `secrets.env` safely instead of `source`-ing values such as `NODE_OPTIONS=--import ...`.
- `lib/02-isolation.sh` and `openclaw-guardian` now normalize the service runtime workspace to `/var/lib/openclaw-svc/.openclaw/workspace`.
- `codeshield-config qmd-backend enable` now preserves the writable service workspace path when it updates `openclaw.json`.
- `openclaw-cost-monitor`, `openclaw-injection-scan`, and `emergency-lockdown` now read secrets without executing the env file.

- `openclaw-guardian` 现在会安全读取 systemd 风格的 `secrets.env`，不再直接 `source` 像 `NODE_OPTIONS=--import ...` 这样的值。
- `lib/02-isolation.sh` 与 `openclaw-guardian` 现在会把 service runtime 的 workspace 统一修正为 `/var/lib/openclaw-svc/.openclaw/workspace`。
- `codeshield-config qmd-backend enable` 在更新 `openclaw.json` 时会保留可写的 service workspace 路径。
- `openclaw-cost-monitor`、`openclaw-injection-scan` 和 `emergency-lockdown` 现在也会以安全方式读取 secrets，而不是执行 env 文件。

### Docs / 文档

- Rewrote `README.md` and `CHANGELOG.md` as clean UTF-8 bilingual documents.

- 重写 `README.md` 与 `CHANGELOG.md`，修复中文乱码并统一为 UTF-8 双语文档。

## [3.1.3] - 2026-03-22

### Added / 新增

- Added `codeshield-config qmd-backend [enable|show|disable]`.
- Mirrored `.claude.json` into `/var/lib/openclaw-svc/.claude.json`.

- 新增 `codeshield-config qmd-backend [enable|show|disable]`。
- 将 `.claude.json` 镜像到 `/var/lib/openclaw-svc/.claude.json`。
