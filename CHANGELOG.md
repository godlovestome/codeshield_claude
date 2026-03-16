# Changelog

All notable changes to CODE SHIELD are documented here.

---

## [3.0.1] — 2026-03-16

### Security Fixes (Professional Audit P1–P4)

#### P1 — Qdrant Container Privilege Reduction
- **Problem:** `qdrant-memory` container ran as `root` (uid=0) with full Linux capabilities and writable filesystem. Container escape would yield host root.
- **Fix:** Added `cap_drop: [ALL]`, `security_opt: no-new-privileges:true`, `read_only: true` with tmpfs mounts for `/tmp` and `/qdrant/snapshots` in `docker-compose.qdrant.yml`.
- **Impact:** Even if Qdrant is exploited, the attacker has no capabilities and cannot write outside mounted volumes.

#### P2 — Forced Outbound Proxy (Comprehensive iptables Rule)
- **Problem:** Previous rules only blocked specific ports (DNS 53, internal services). The agent could still make direct external connections by bypassing `HTTP_PROXY` environment variable. Additionally, the port-6333 block was erroneously preventing the `mem-qdrant-watcher` from writing memories to Qdrant (TRUE RECALL broken since Stage 4).
- **Fix:** Replaced all fragmented port-specific `iptables` rules with one comprehensive rule:
  ```
  iptables -A OUTPUT -m owner --uid-owner <openclaw-svc-uid> ! -d 127.0.0.0/8 -j DROP
  ```
  All external traffic from `openclaw-svc` is now blocked at the kernel level. Only loopback (`127.0.0.0/8`) is allowed, which covers Squid proxy (`:3128`), Qdrant (`:6333`), and Ollama (`:11434`).
- **Impact:** TRUE RECALL memory writes restored. Agent cannot bypass proxy. DNS tunneling impossible.

#### P3 — systemd Service Sandbox Hardening
- **Problem:** `openclaw.service` and `mem-qdrant-watcher.service` ran with full Linux capabilities, writable system filesystem, and access to `/home` and `/root`.
- **Fix:** Added `codeshield-sandbox.conf` drop-ins for both services:
  - `ProtectSystem=strict` — `/usr`, `/boot`, `/etc` are read-only
  - `ProtectHome=yes` — `/home`, `/root`, `/run/user` inaccessible
  - `CapabilityBoundingSet=` (empty) — all capabilities dropped
  - `PrivateDevices=yes`, `ProtectKernelTunables=yes`, `ProtectKernelModules=yes`
  - `RestrictSUIDSGID=yes`, `LockPersonality=yes`
  - `ReadWritePaths=` scoped to required directories only
- **Impact:** Significant reduction in post-exploitation blast radius.

#### P4 — Complete Secret Removal from openclaw.json
- **Problem:** Secret migration (`lib/02-isolation.sh`) was blanking key values (`""`) instead of deleting them. `gateway.auth.token` remained as an empty key in `openclaw.json`, causing inconsistency and potential re-population on OpenClaw updates.
- **Fix:** Migration script now uses Python `dict.pop()` / `del` to fully remove secret keys from `openclaw.json` after copying to `secrets.env`. Also corrected nested key paths (e.g., `gateway.auth.token` was not being reached by the old flat-key logic).
- **Impact:** `openclaw.json` contains zero credential fields after migration.

### New Audit Checks (42 total, up from 36)
- `qdrant cap_drop all` — Verifies Qdrant container has ALL capabilities dropped
- `qdrant no-new-privileges` — Verifies `no-new-privileges:true` security opt
- `force proxy non-loopback block` — Verifies comprehensive iptables outbound rule
- `openclaw protect system` — Verifies `ProtectSystem=strict` on openclaw service
- `openclaw capability bounding` — Verifies empty `CapabilityBoundingSet`
- `no inline gateway token` — Verifies `gateway.auth.token` absent from `openclaw.json`

### Security Score
| Version | Automated Checks | Score |
|---------|-----------------|-------|
| V3.0.0  | 38/38           | 9.3/10 |
| **V3.0.1** | **42/42**   | **9.3+/10** |

Professional audit score (manual review): **7.3 → ~8.2/10** after P1–P4 fixes.

---

## [3.0.0] — 2026-03-15

### Initial Release

Complete AI Agent security hardening system for OpenClaw:

- One-line interactive installer (`curl | bash`) with 6 deployment stages
- Guardian systemd path unit for zero-touch OpenClaw update compatibility
- 38-item automated security audit with scoring
- User isolation (`openclaw-svc`), secret externalization, systemd drop-in
- Qdrant API key authentication + `127.0.0.1` port binding
- SSH hardening, UFW firewall, fail2ban, IPv6 disable, auditd
- Squid outbound proxy whitelist (3 domains) with injection guard
- SOUL.md canary tokens + Prompt Injection Resistance framework (10 rules)
- Skills freeze policy with integrity checksums
- Emergency lockdown with AES-256-CBC encrypted forensic archives
- Session injection scanner (27 patterns, 15-minute cron)
- Cost monitor with multi-threshold burst detection
- Bilingual EN/ZH README
