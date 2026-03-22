# Changelog

All notable changes to CODE SHIELD are documented here.

---

## [3.1.3] - 2026-03-22

### New: manage OpenClaw QMD backend through `codeshield-config` / ????? `codeshield-config` ?? OpenClaw QMD ??

- Added `codeshield-config qmd-backend [enable|show|disable]`.
- The new command writes `memory.qmd` into both the interactive and service-runtime `openclaw.json` files.
- The command points OpenClaw at `/home/openclaw/scripts/qmd-openclaw-wrapper.sh`, keeping QMD retrieval inside the Codeshield-isolated runtime model.
- This makes QMD retrieval re-applicable after OpenClaw, Codeshield, or custom_qmd updates without re-running the installer.

## [3.1.2] - 2026-03-22

### Fix: mirror `.claude.json` into the Codeshield runtime home

- QMD and other external MCP registrations were often written only to `/home/openclaw/.claude.json`, while the live `openclaw.service` process runs as `openclaw-svc` with home `/var/lib/openclaw-svc`.
- `lib/02-isolation.sh` and `scripts/openclaw-guardian` now copy `/home/openclaw/.claude.json` into `/var/lib/openclaw-svc/.claude.json`, set `openclaw-svc` ownership, and preserve restrictive permissions.
