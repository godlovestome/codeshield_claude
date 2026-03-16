# Changelog

All notable changes to CODE SHIELD are documented here.

---

## [3.0.3] — 2026-03-16

### New Feature: `codeshield-config` CLI

Post-install configuration management tool. Eliminates the need to re-run `openclaw onboard` after CODE SHIELD installation.

#### Commands
- **`codeshield-config show`** — Display all configuration with masked secrets
- **`codeshield-config edit`** — Interactive editor for all secrets
- **`codeshield-config set KEY=VALUE`** — Set individual config keys
- **`codeshield-config add-model [provider]`** — Add LLM provider with built-in presets or custom
- **`codeshield-config add-channel`** — Add messaging channel (generic framework)
- **`codeshield-config proxy-allow <domain>`** — Add Squid whitelist domain
- **`codeshield-config list-channels`** / **`list-models`** — List configured channels/models

#### Multi-LLM Provider Support
- **OpenAI** — API Key (`sk-*`) and OAuth 2.0 (`OPENAI_CLIENT_ID`, `OPENAI_CLIENT_SECRET`, `OPENAI_ORG_ID`)
- **Anthropic** — `api.anthropic.com`, env var `ANTHROPIC_API_KEY`
- **GLM5 (智谱 BigModel)** — `open.bigmodel.cn`, env var `GLM_API_KEY`
- **Kimi 2.5 (月之暗面 Moonshot)** — `api.moonshot.cn`, env var `KIMI_API_KEY`
- **Custom** — User-defined provider name, domains, env vars, and auth type
- Interactive secret collection (`01-collect-secrets.sh`) now prompts for all providers
- Secret migration (`02-isolation.sh`) expanded with new `openclaw.json` key mappings:
  `auth.anthropic.apiKey`, `auth.glm.apiKey`, `auth.kimi.apiKey`, `auth.openai.clientId`, etc.

#### Generic Channel Framework
- Channel definitions stored in `/etc/openclaw-codeshield/channels.d/<name>.conf`
- Format: `CHANNEL_NAME`, `CHANNEL_DOMAINS`, `CHANNEL_VARS`
- `add-channel` interactively collects: name, API domains, env var names, values
- Auto-updates Squid proxy whitelist and secrets.env
- Supports any channel (Feishu, Slack, Discord, WeChat, DingTalk, etc.) without code changes

#### Externalized Squid Whitelist
- Additional domains stored in `/etc/openclaw-codeshield/proxy-whitelist.conf`
- `squid.conf` template uses `dstdomain` ACL with external file include
- `codeshield-config` commands auto-update whitelist and reload Squid

### Deployment Reliability Fixes

#### UTF-8 / Unicode Encoding (10 fixes)
- **`install.sh`**: Force `LC_ALL=en_US.UTF-8` (fallback `C.UTF-8`) at script start
- **`lib/01-collect-secrets.sh`**: `grep -qP` → `grep -qE` (PCRE → ERE, locale-independent)
- **`lib/01-collect-secrets.sh`**: `eval "$var='$val'"` → `printf -v "$var" '%s' "$val"` (safe assignment)
- **`lib/01-collect-secrets.sh`**: Heredoc secrets → `printf` per-line writing (UTF-8 safe)
- **`lib/02-isolation.sh`**: Python `read_text(encoding='utf-8')`, `write_text(encoding='utf-8')`
- **`lib/02-isolation.sh`**: `json.dumps(ensure_ascii=False)` for non-ASCII JSON preservation
- **`lib/03-qdrant.sh`**: All `sed -i` prefixed with `LC_ALL=C` (binary-safe)
- **`lib/03-qdrant.sh`**: Python `read_text`/`write_text` with `encoding='utf-8'`
- **`scripts/squid-injection-guard.py`**: `io.TextIOWrapper` for stdin/stdout with UTF-8 + errors='replace'
- **`lib/00-preflight.sh`**: Locale availability check with auto `locale-gen` fallback

#### Error Handling & Recovery
- **`--resume` flag**: Records checkpoint per stage; on failure, resume from last successful stage
- **Install logging**: `exec > >(tee -a install.log) 2>&1` — all output to terminal + log file
- **Error trap**: On failure, displays log path and `--resume` command
- **Checkpoint cleared** on successful completion

#### Preflight Improvements
- Batch detection and auto-install of all missing required commands
- Network connectivity check (GitHub raw + DNS resolution)
- Qdrant compose search expanded: 7 candidate paths (was 4)
- `netfilter-persistent` auto-installed if missing (iptables persistence)

### Skills Policy Update
- Added `anthropic-chat`, `glm-chat`, `kimi-chat` skills to approved list
- Added generic `channel-send`, `channel-receive` skills (endpoints restricted by Squid whitelist)

---

## [3.0.2] — 2026-03-16

### Security Fixes (Professional Audit Round 2)

#### P1 — SSH Hardening Gaps (sshd_config.d drop-in)
- **Problem:** `AllowTcpForwarding`, `AllowAgentForwarding`, and `MaxSessions` were set in `sshd_config` but overridden by `sshd_config.d/` includes (cloud-init). `sshd -T` showed `allowtcpforwarding yes`, `allowagentforwarding yes`, `maxsessions 10`.
- **Fix:** Added `/etc/ssh/sshd_config.d/90-codeshield.conf` with all 14 SSH hardening settings, ensuring they override cloud-init (50-) and cloudimg (60-) includes.
- **Impact:** SSH tunneling (data exfiltration vector) now fully blocked. Sessions limited to 3.

#### P2 — Kernel Hardening (fs.suid_dumpable)
- **Problem:** `fs.suid_dumpable = 2` allowed setuid programs to produce core dumps, potentially leaking secrets from memory.
- **Fix:** Added `/etc/sysctl.d/99-codeshield-hardening.conf` with `fs.suid_dumpable = 0`, plus explicit `kernel.kptr_restrict = 1` and `kernel.dmesg_restrict = 1`.
- **Impact:** Core dumps from privileged processes disabled; kernel pointer and dmesg exposure restricted.

#### P3 — Docker Inter-Container Communication (icc=false)
- **Problem:** `daemon.json` was missing `"icc": false` on live system despite being in the hardening script. Container-to-container communication was not explicitly blocked.
- **Fix:** Force-apply `"icc": false` with verification step in `harden_docker()`.
- **Impact:** Docker containers can no longer communicate directly unless explicitly linked.

#### P4 — systemd Sandbox Additions
- **Problem:** `RestrictAddressFamilies`, `SystemCallFilter`, and `MemoryDenyWriteExecute` were not set, leaving the openclaw process with unrestricted socket types and syscall access.
- **Fix:** Added to `codeshield-sandbox.conf` drop-in:
  - `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK` — blocks raw/packet/bluetooth sockets
  - `SystemCallFilter=@system-service` with deny list for `@mount @reboot @swap @raw-io @clock @cpu-emulation @debug @obsolete`
  - `MemoryDenyWriteExecute=yes` for watcher service (Node.js JIT requires W^X, so disabled for openclaw)
- **Impact:** Significantly reduced post-exploitation syscall and socket attack surface.

#### P5 — Secrets Encryption at Rest (systemd-creds)
- **Problem:** `secrets.env` stored all API keys (Telegram, Brave, OpenAI, Qdrant, Gateway) in plaintext on disk (0600 root). Root compromise = all keys compromised.
- **Fix:** Four new scripts (`codeshield-secrets-{seal,unseal,reseal,migrate}`) using `systemd-creds` with host key encryption:
  - Disk: `secrets.env.enc` (encrypted, bound to this host)
  - Runtime: `/run/openclaw-codeshield/secrets.env` (tmpfs, RAM only)
  - Plaintext securely wiped with `shred -u` after encryption
  - `codeshield-secrets.service` (oneshot, `RemainAfterExit=yes`) decrypts on boot
  - Drop-in updated: `Requires=codeshield-secrets.service`
  - Credential validity: 90 days, monthly auto-reseal timer
- **Impact:** Secrets never exist as plaintext on disk. Requires physical host key to decrypt.

#### P6 — Outbound Traffic Logging (iptables LOG)
- **Problem:** Blocked outbound traffic from openclaw-svc was silently dropped. No forensic trail for exfiltration attempts.
- **Fix:** Added rate-limited LOG rule before DROP: `CODESHIELD-BLOCK:` prefix, 5/min limit.
- **Impact:** All blocked exfiltration attempts now logged to syslog for forensic analysis.

#### P7 — Monthly Credential Re-seal Timer
- **Problem:** systemd-creds encrypted credentials have a 90-day validity. No automatic renewal mechanism.
- **Fix:** `codeshield-reseal.timer` runs monthly (`*-*-01 03:00:00`), calls `codeshield-secrets-reseal --seal-existing` to re-encrypt with fresh validity period.
- **Impact:** Credentials remain valid indefinitely without manual intervention.

#### P8 — auditd Rule Expansion
- **Problem:** auditd was not monitoring SSH config, sshd_config.d/, sudoers, or squid config changes.
- **Fix:** Added watch rules for `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/`, `/etc/sudoers.d/`, `/etc/squid/squid.conf`.
- **Impact:** All security-critical configuration changes are now audited.

### New Audit Checks (56 total, up from 47)
- `ssh forwarding disabled` — Verifies `sshd -T` shows `allowtcpforwarding no`
- `ssh agent forwarding disabled` — Verifies `allowagentforwarding no`
- `ssh max sessions limited` — Verifies `maxsessions <= 3`
- `fs.suid_dumpable disabled` — Verifies `sysctl -n fs.suid_dumpable` = 0
- `docker icc disabled` — Verifies `"icc": false` in daemon.json
- `iptables outbound logging` — Verifies `CODESHIELD-BLOCK` LOG rule exists
- `reseal timer active` — Verifies monthly credential re-seal timer
- `systemd restrict address families` — Verifies `RestrictAddressFamilies` is set
- `systemd syscall filter` — Verifies `SystemCallFilter` is applied

### Security Score
| Version | Automated Checks | Score |
|---------|-----------------|-------|
| V3.0.0  | 38/38           | 9.3/10 |
| V3.0.1  | 42/42 → 47/47   | 9.3/10 |
| **V3.0.2** | **56/56**   | **9.5/10** |

Professional audit score (manual review): **8.3 → 8.5 → ~9.0/10** after P1–P8 fixes.

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
