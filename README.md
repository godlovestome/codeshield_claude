# CODE SHIELD V3.1.3

**AI Agent Network Security Hardening System**  
**AI Agent ????????**

CODE SHIELD is a production-oriented defense-in-depth framework for OpenClaw and similar AI agent stacks on Linux servers. It focuses on runtime isolation, encrypted secret handling, outbound traffic control, prompt-injection defense, and automatic recovery after updates.

CODE SHIELD ???????? AI Agent ????????????? Linux ????? OpenClaw ??????????????????????????????????????????????

**Version focus / ?????v3.1.3**  
Adds `codeshield-config qmd-backend` so OpenClaw's built-in QMD retrieval can be managed under the same Codeshield configuration path as the rest of the protected runtime.  
?? `codeshield-config qmd-backend`?? OpenClaw ?? QMD ?????? Codeshield ??????????

---

## Quick Start / ????

### Fresh Install / ????

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

### Non-Destructive Update / ????

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

After installation, use `codeshield-config` for configuration changes instead of rerunning the installer.  
???????????????? `codeshield-config`????????????

---

## Key Features / ????

- Isolates the live OpenClaw service as `openclaw-svc`
- Moves secrets out of `openclaw.json`
- Encrypts secrets at rest with `systemd-creds`
- Forces outbound traffic through Squid
- Preserves loopback access for local services with `NO_PROXY`
- Re-applies hardening automatically after OpenClaw updates
- Keeps OpenClaw QMD backend wiring under Codeshield control

- ??? OpenClaw ????? `openclaw-svc`
- ???? `openclaw.json` ???
- ?? `systemd-creds` ???????
- ??????? Squid
- ?? `NO_PROXY` ????????
- ? OpenClaw ???????????
- ? OpenClaw ? QMD ????? Codeshield ??

---

## `codeshield-config` / ????

Common commands / ?????

```bash
sudo codeshield-config show
sudo codeshield-config add-model anthropic
sudo codeshield-config proxy-allow api.example.com
sudo codeshield-config network-mode show
sudo codeshield-config qmd-backend show
sudo codeshield-config qmd-backend enable
sudo codeshield-config qmd-backend disable
```

### QMD Backend Management / QMD ????

`codeshield-config qmd-backend enable` will:
`codeshield-config qmd-backend enable` ??

- write `memory.backend=qmd`
- register `memory.qmd.command=/home/openclaw/scripts/qmd-openclaw-wrapper.sh`
- point `memory.qmd.paths` at `/home/openclaw/qmd-index/*`
- update both `/home/openclaw/.openclaw/openclaw.json` and `/var/lib/openclaw-svc/.openclaw/openclaw.json`
- optionally restart `openclaw.service`

- ?? `memory.backend=qmd`
- ?? `memory.qmd.command=/home/openclaw/scripts/qmd-openclaw-wrapper.sh`
- ? `memory.qmd.paths` ?? `/home/openclaw/qmd-index/*`
- ???? `/home/openclaw/.openclaw/openclaw.json` ? `/var/lib/openclaw-svc/.openclaw/openclaw.json`
- ???? `openclaw.service`

Use `--no-restart` for staged rollouts.  
????????? `--no-restart`?

---

## OpenClaw Update Safety / OpenClaw ????

- Guardian re-syncs OpenClaw runtime data into `/var/lib/openclaw-svc/.openclaw/`
- Guardian restores systemd drop-ins and policies
- Guardian restarts the service after re-applying protections
- QMD backend wiring can be re-applied with one command after updates

- Guardian ?? OpenClaw ?????????? `/var/lib/openclaw-svc/.openclaw/`
- Guardian ??? systemd drop-in ?????
- Guardian ?????????????
- QMD ??????????????????

---

## Notes / ??

- CODE SHIELD does not replace QMD or Jarvis Memory. It secures the runtime they depend on.
- API keys, gateway tokens, and other secrets should remain under `codeshield-config` management.

- CODE SHIELD ??? QMD ? Jarvis Memory?????????????????
- API Key?gateway token ?????????? `codeshield-config` ???
