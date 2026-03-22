# CODE SHIELD V3.1.2

**AI Agent Network Security Hardening System**

CODE SHIELD V3 is a comprehensive, production-grade security framework designed to protect AI agents running on Linux servers. It provides defense-in-depth through user isolation, secret encryption (systemd-creds), outbound proxy whitelisting, prompt injection detection, container privilege reduction, systemd sandbox hardening, and a guardian service that automatically re-applies protection after agent updates. V3.1.2 adds `.claude.json` mirroring into the isolated `openclaw-svc` runtime so MCP registrations such as QMD stay visible to the live OpenClaw service after Codeshield isolation. Originally built to harden OpenClaw, CODE SHIELD achieves a security score of **9.5/10** across **58 automated audit checks**.

---

**CODE SHIELD V3.1.2 -- AI Agent 缃戠粶瀹夊叏鍔犲浐绯荤粺**

CODE SHIELD V3 是一套完整的生产级安全框架，专为运行在 Linux 服务器上的 AI Agent 设计。通过用户隔离、密钥加密（systemd-creds）、出站代理白名单、提示注入检测、容器权限削减、systemd 沙箱加固和 Guardian 自动恢复服务，提供纵深防御。V3.1.2 新增将 `.claude.json` 镜像到隔离运行用户 `openclaw-svc` 的能力，使 QMD 等 MCP 注册在 Codeshield 隔离后仍能被线上 OpenClaw 服务读取。本系统通过 **58 项**自动化安全审计实现 **9.5/10** 的安全评分。
---

## Quick Start / 蹇€熷紑濮?
### Fresh Install / 鍏ㄦ柊瀹夎

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | bash
```

### Non-Destructive Update / 鏃犳崯鏇存柊

```bash
curl -fsSL https://raw.githubusercontent.com/godlovestome/codeshield_claude/main/install.sh | sudo bash -s -- --update
```

The installer is interactive only when collecting API keys (Telegram, Brave, OpenAI, Anthropic, DeepSeek, GLM5, Kimi, MiniMax, Qdrant). Everything else runs fully automatically. After installation, use `codeshield-config` to manage configuration without re-running the installer.

瀹夎绋嬪簭浠呭湪鏀堕泦 API 瀵嗛挜鏃舵殏鍋滀氦浜掞紙Telegram銆丅rave銆丱penAI銆丄nthropic銆丏eepSeek銆丟LM5銆並imi銆丮iniMax銆丵drant锛夛紝鍏朵綑鍏ㄩ儴鑷姩鎵ц銆傚畨瑁呭悗鍙娇鐢?`codeshield-config` 绠＄悊閰嶇疆锛屾棤闇€閲嶆柊杩愯瀹夎绋嬪簭銆?
---

## What It Protects / 淇濇姢鑼冨洿

| Protected Asset / 淇濇姢瀵硅薄 | Threat / 濞佽儊 | Defense / 闃叉姢鎺柦 |
|---|---|---|
| API Keys & Tokens | Inline credential exposure, disk theft | **Secrets encrypted at rest** (systemd-creds, host key bound); decrypted to tmpfs (RAM) only at runtime; keys fully deleted from openclaw.json |
| Qdrant Vector DB (JARVIS + TRUE RECALL) | Unauthorized access, container escape, data exfiltration | API key authentication, ports 6333+6334 bound to 127.0.0.1, **DOCKER-USER iptables** (ESTABLISHED/RELATED, loopback, 6333/6334 DROP + optional 6379/5432), **cap_drop ALL**, **no-new-privileges**, **read_only filesystem** with tmpfs, `codeshield-docker-user.service` survives Docker restarts |
| Telegram Bot | Token theft, message interception | Keys managed by CODE SHIELD, encrypted at rest, not stored in openclaw.json |
| OpenClaw Agent Process | Privilege escalation, lateral movement | Isolated `openclaw-svc` user, removed from docker/sudo groups, **systemd sandbox** (ProtectSystem=strict, CapabilityBoundingSet=, RestrictAddressFamilies, SystemCallFilter, ProtectHome=yes) |
| Server SSH | Brute force, tunneling, password attacks | Password auth disabled, MaxAuthTries=3, MaxSessions=3, **AllowTcpForwarding=no**, **AllowAgentForwarding=no**, fail2ban with 1-hour bans, sshd_config.d drop-in |
| Outbound Network | Data exfiltration, C2 communication, proxy bypass | **Comprehensive iptables block** with LOG: all non-loopback outbound from openclaw-svc dropped at kernel level; agent must use Squid at 127.0.0.1:3128 |
| Squid Proxy | Request smuggling, DNS exfiltration | Full-traffic logging, 10MB request body limit, 1MB/s rate limiting, Python injection guard; all traffic forced through proxy by iptables |
| AI Prompts / SOUL.md | Prompt injection, identity hijack | Canary tokens, 10-rule injection resistance framework, 15-minute session scanning |
| Skills / Tools | Unauthorized tool invocation | Whitelist-only skills-policy.json, integrity baseline checksums |
| DNS | DNS exfiltration tunneling | iptables uid-owner comprehensive rule blocks all external DNS for openclaw-svc |
| Update Continuity | Security loss after agent updates | Guardian systemd path unit auto-detects updates and re-applies all protections |
| Kernel / OS | Core dump leaks, privilege escalation | `fs.suid_dumpable=0`, `kernel.kptr_restrict=1`, `kernel.dmesg_restrict=1`, Docker `icc=false` |
| Local Services (Ollama/Qdrant/Redis) | Proxy routing failure (V3.1.0) | `EnvHttpProxyAgent` respects `NO_PROXY`; local services bypass Squid automatically |
| Jarvis Memory Secrets | Plaintext API key in cron environment (V3.1.0) | `QDRANT_API_KEY` exported to restricted tmpfs path (`root:openclaw 640`) instead of plaintext `~/.memory_env` |

---

## Configuration Management / 閰嶇疆绠＄悊

After installation, use `codeshield-config` to manage all settings without re-running the installer or `openclaw onboard`. All built-in providers and channels use **interactive menus** 鈥?no manual domain input required.

瀹夎鍚庝娇鐢?`codeshield-config` 绠＄悊鎵€鏈夎缃紝鏃犻渶閲嶆柊杩愯瀹夎绋嬪簭鎴?`openclaw onboard`銆傛墍鏈夊唴缃彁渚涘晢鍜岄€氶亾鍧囦娇鐢?*浜や簰寮忚彍鍗?*鈥斺€旀棤闇€鎵嬪姩杈撳叆鍩熷悕銆?
```bash
# View current configuration (secrets masked)
# 鏌ョ湅褰撳墠閰嶇疆锛堝瘑閽ヨ劚鏁忔樉绀猴級
codeshield-config show

# Set a single key / 璁剧疆鍗曚釜閰嶇疆椤?codeshield-config set ANTHROPIC_API_KEY=sk-ant-xxx

# Interactive edit all secrets / 浜や簰寮忕紪杈戞墍鏈夊瘑閽?codeshield-config edit

# Add an LLM provider (interactive menu, domains auto-filled)
# 娣诲姞澶фā鍨嬫彁渚涘晢锛堜氦浜掑紡鑿滃崟锛屽煙鍚嶈嚜鍔ㄥ～鍏咃級
# Non-native providers (deepseek, glm5) automatically patch openclaw JS files.
# 闈炲師鐢熸彁渚涘晢锛坉eepseek銆乬lm5锛変細鑷姩淇ˉ openclaw JS 鏂囦欢銆?codeshield-config add-model
#   1) OpenAI (API Key)       2) OpenAI (OAuth)
#   3) Anthropic / Claude     4) DeepSeek (娣卞害姹傜储)
#   5) GLM5 (鏅鸿氨 BigModel)   6) Kimi (鏈堜箣鏆楅潰 Moonshot)
#   7) MiniMax                8) Custom (鑷畾涔?

# Re-patch openclaw JS files after openclaw update (non-native providers only)
# openclaw 鏇存柊鍚庨噸鏂颁慨琛?JS 鏂囦欢锛堜粎闈炲師鐢熸彁渚涘晢锛?codeshield-config patch-provider deepseek

# Add a messaging channel (interactive menu, domains auto-filled)
# 娣诲姞娑堟伅閫氶亾锛堜氦浜掑紡鑿滃崟锛屽煙鍚嶈嚜鍔ㄥ～鍏咃級
codeshield-config add-channel
#   1) 浼佷笟寰俊 (WeCom)    2) 椋炰功 (Feishu)
#   3) Discord             4) Custom (鑷畾涔?

# Add a domain to Squid proxy whitelist / 娣诲姞鍩熷悕鍒?Squid 鐧藉悕鍗?codeshield-config proxy-allow open.feishu.cn

# Toggle network access mode / 鍒囨崲缃戠粶璁块棶妯″紡
# open: all domains allowed through proxy (default, required for web_fetch)
# 寮€鏀炬ā寮忥細鍏佽鎵€鏈夊煙鍚嶉€氳繃浠ｇ悊锛堥粯璁わ紝web_fetch 蹇呴渶锛?# strict: only known API domains allowed (disables web_fetch for arbitrary URLs)
# 涓ユ牸妯″紡锛氫粎鍏佽宸茬煡 API 鍩熷悕锛堢鐢ㄥ浠绘剰 URL 鐨?web_fetch锛?codeshield-config network-mode              # show current mode / 鏌ョ湅褰撳墠妯″紡
codeshield-config network-mode open         # allow all domains / 鍏佽鎵€鏈夊煙鍚?codeshield-config network-mode strict       # whitelist only / 浠呯櫧鍚嶅崟鍩熷悕

# List configured channels and models / 鍒楀嚭宸查厤缃殑閫氶亾鍜屾ā鍨?codeshield-config list-channels
codeshield-config list-models
```

**Key behaviors / 鏍稿績琛屼负:**
- Automatically decrypts secrets 鈫?modifies 鈫?re-encrypts (systemd-creds) / 鑷姩瑙ｅ瘑 鈫?淇敼 鈫?閲嶆柊鍔犲瘑
- Automatically updates Squid proxy whitelist when adding channels/models / 娣诲姞閫氶亾/妯″瀷鏃惰嚜鍔ㄦ洿鏂?Squid 鐧藉悕鍗?- Automatically restarts openclaw.service after changes / 淇敼鍚庤嚜鍔ㄩ噸鍚?openclaw 鏈嶅姟
- **Non-native providers (deepseek, glm5) auto-patch openclaw JS dist files** 鈥?no manual file editing / 闈炲師鐢熸彁渚涘晢锛坉eepseek銆乬lm5锛夎嚜鍔ㄤ慨琛?openclaw JS 鏂囦欢鈥斺€旀棤闇€鎵嬪姩缂栬緫
- Channel and model configs stored in `/etc/openclaw-codeshield/channels.d/` and `models.d/`
- `proxy-allow` adds domains to the known-domains reference list (logging and future selective enforcement)
- **`network-mode`** toggles Squid between open (all domains) and strict (whitelist only) without affecting security score / `network-mode` 鍦ㄥ紑鏀炬ā寮忥紙鎵€鏈夊煙鍚嶏級鍜屼弗鏍兼ā寮忥紙浠呯櫧鍚嶅崟锛変箣闂村垏鎹紝涓嶅奖鍝嶅畨鍏ㄨ瘎鍒?
**Supported LLM Providers (built-in) / 鏀寔鐨勫ぇ妯″瀷鎻愪緵鍟嗭紙鍐呯疆锛?**

| Provider / 鎻愪緵鍟?| API Domain | Auth / 璁よ瘉鏂瑰紡 | Env Vars / 鐜鍙橀噺 |
|----------|-----------|------|----------|
| OpenAI | `api.openai.com` | API Key | `OPENAI_API_KEY` |
| OpenAI OAuth | `api.openai.com`, `auth0.openai.com` | OAuth 2.0 | `OPENAI_CLIENT_ID`, `OPENAI_CLIENT_SECRET`, `OPENAI_ORG_ID` |
| Anthropic / Claude | `api.anthropic.com` | API Key | `ANTHROPIC_API_KEY` |
| DeepSeek (娣卞害姹傜储) | `api.deepseek.com` | API Key | `DEEPSEEK_API_KEY` |
| GLM5 (鏅鸿氨 BigModel) | `open.bigmodel.cn` | API Key | `GLM_API_KEY` |
| Kimi (鏈堜箣鏆楅潰 Moonshot) | `api.moonshot.cn` | API Key | `KIMI_API_KEY` |
| MiniMax | `api.minimax.io` | API Key | `MINIMAX_API_KEY`, `MINIMAX_GROUP_ID` |
| Custom / 鑷畾涔?| User-defined | User-defined | User-defined |

**Supported Channels (built-in) / 鏀寔鐨勬秷鎭€氶亾锛堝唴缃級:**

| Channel / 閫氶亾 | API Domain | Env Vars / 鐜鍙橀噺 |
|---------|-----------|----------|
| 浼佷笟寰俊 (WeCom) | `qyapi.weixin.qq.com` | `WECOM_CORP_ID`, `WECOM_AGENT_ID`, `WECOM_SECRET` |
| 椋炰功 (Feishu) | `open.feishu.cn` | `FEISHU_APP_ID`, `FEISHU_APP_SECRET` |
| Discord | `discord.com`, `cdn.discordapp.com` | `DISCORD_BOT_TOKEN`, `DISCORD_WEBHOOK_URL` |
| Custom / 鑷畾涔?| User-defined | User-defined |

---

## Interactive Installation / 浜や簰寮忓畨瑁?
The installer runs in 7 stages:

瀹夎绋嬪簭鍒?7 涓樁娈垫墽琛岋細

```
[1/7] Environment Pre-Flight     -- Checks OS, dependencies, disk space
                                    妫€鏌ユ搷浣滅郴缁熴€佷緷璧栥€佺鐩樼┖闂?[2/7] Secret Collection           -- Interactive: Telegram, Brave, OpenAI (Key/OAuth),
                                    Anthropic, DeepSeek, GLM5, Kimi, MiniMax, Qdrant
                                    浜や簰寮忥細鏀堕泦鍚勬彁渚涘晢 API 瀵嗛挜
[3/7] User Isolation & Migration  -- Creates openclaw-svc, migrates secrets, installs drop-in
                                    鍒涘缓闅旂鐢ㄦ埛銆佽縼绉诲瘑閽ャ€佸畨瑁?systemd drop-in
[4/7] Qdrant Security             -- API key auth, 127.0.0.1 binding, cap_drop ALL, read_only
                                    Qdrant 璁よ瘉銆佺鍙ｇ粦瀹氥€佹潈闄愬墛鍑忋€佸彧璇绘枃浠剁郴缁?[5/7] System Hardening            -- SSH, UFW, fail2ban, IPv6, Squid, iptables block+LOG,
                                    systemd sandbox, proxy-preload.mjs (EnvHttpProxyAgent)
                                    绯荤粺鍔犲浐锛歋SH/闃茬伀澧?Squid/iptables/systemd 娌欑/浠ｇ悊棰勫姞杞?[6/7] Injection Defense           -- SOUL.md canary, skills policy, scanner timer, cost monitor
                                    娉ㄥ叆闃插尽锛歋OUL.md 閲戜笣闆€銆佹妧鑳界瓥鐣ャ€佹壂鎻忓畾鏃跺櫒銆佹垚鏈洃鎺?[7/7] Secrets Encryption          -- systemd-creds encryption, tmpfs decryption, reseal timer,
                                    Jarvis Memory secret export
                                    瀵嗛挜鍔犲瘑锛歴ystemd-creds 鍔犲瘑銆乼mpfs 瑙ｅ瘑銆佸畾鏈熼噸灏併€?                                    Jarvis Memory 瀵嗛挜瀵煎嚭
[POST] Guardian Installation      -- systemd path unit for update detection
                                    Guardian 鏇存柊妫€娴嬭矾寰勫崟鍏?[FINAL] Security Audit            -- 56-item check with score
                                    56 椤瑰畨鍏ㄥ璁¤瘎鍒?```

### Command-line flags / 鍛戒护琛屽弬鏁?
| Flag / 鍙傛暟 | Description / 璇存槑 |
|---|---|
| `--dry-run` | Show what would be done without making changes / 棰勬紨妯″紡锛屼笉鍋氬疄闄呬慨鏀?|
| `--skip-preflight` | Skip environment pre-checks / 璺宠繃鐜棰勬 |
| `--update` | Non-interactive re-apply (used by Guardian after OpenClaw updates) / 闈炰氦浜掑紡閲嶆柊搴旂敤锛圙uardian 鏇存柊鍚庝娇鐢級 |
| `--resume` | Resume from last failed stage / 浠庝笂娆″け璐ョ殑闃舵鎭㈠ |

---

## OpenClaw Update Compatibility / OpenClaw 鏇存柊鍏煎鎬?
When OpenClaw is updated via:

褰撻€氳繃浠ヤ笅鍛戒护鏇存柊 OpenClaw 鏃讹細

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

The **codeshield-guardian.path** systemd unit detects changes to:

**codeshield-guardian.path** systemd 鍗曞厓妫€娴嬩互涓嬫枃浠跺彉鍖栵細

- `/home/openclaw/.npm-global/lib/node_modules/openclaw/package.json`
- `/home/openclaw/.openclaw/openclaw.json`

Upon detection, the Guardian service (`/usr/local/sbin/openclaw-guardian`) executes:

妫€娴嬪埌鍙樺寲鍚庯紝Guardian 鏈嶅姟锛坄/usr/local/sbin/openclaw-guardian`锛夋墽琛岋細

1. Migrates any new inline secrets from openclaw.json to secrets.env (and fully deletes them from JSON)
   杩佺Щ openclaw.json 涓殑鍐呰仈瀵嗛挜鍒?secrets.env锛堝苟浠?JSON 涓畬鍏ㄥ垹闄わ級
2. Re-encrypts secrets with `codeshield-secrets-reseal`
   浣跨敤 `codeshield-secrets-reseal` 閲嶆柊鍔犲瘑瀵嗛挜
3. Verifies/recreates the systemd drop-in (EnvironmentFile, User=openclaw-svc)
   楠岃瘉/閲嶅缓 systemd drop-in锛圗nvironmentFile銆乁ser=openclaw-svc锛?4. Syncs openclaw data to the isolated service home
   鍚屾 openclaw 鏁版嵁鍒伴殧绂荤殑鏈嶅姟涓荤洰褰?5. Restores SOUL.md canary token and injection resistance if overwritten
   鎭㈠ SOUL.md 閲戜笣闆€浠ょ墝鍜屾敞鍏ユ姷鎶楄鍒欙紙濡傝瑕嗙洊锛?6. Restores skills-policy.json if missing
   鎭㈠ skills-policy.json锛堝缂哄け锛?7. Regenerates skills baseline checksums
   閲嶆柊鐢熸垚鎶€鑳藉熀绾挎牎楠屽拰
8. Re-patches non-native provider JS files (DeepSeek, GLM5) if dist files were replaced
   閲嶆柊淇ˉ闈炲師鐢熸彁渚涘晢 JS 鏂囦欢锛圖eepSeek銆丟LM5锛屽 dist 鏂囦欢琚浛鎹級
9. Runs `systemctl daemon-reload && systemctl restart codeshield-secrets && systemctl restart openclaw`
   閲嶈浇 systemd 骞堕噸鍚浉鍏虫湇鍔?10. Sends Telegram notification confirming re-application
    鍙戦€?Telegram 閫氱煡纭閲嶆柊搴旂敤

This ensures zero-downtime protection continuity. No manual intervention required.

Guardian 纭繚 OpenClaw 姣忔鏇存柊鍚庤嚜鍔ㄩ噸鏂扮敓鏁堟墍鏈夊畨鍏ㄩ槻鎶わ紝鏃犻渶鎵嬪姩骞查銆?
**What OpenClaw updates do NOT touch / OpenClaw 鏇存柊涓嶄細褰卞搷鐨勫唴瀹癸細**

| Item / 椤圭洰 | Safe / 瀹夊叏 |
|---|---|
| CodeShield iptables rules | Not touched by OpenClaw installer / OpenClaw 瀹夎绋嬪簭涓嶈Е纰?|
| Squid proxy configuration | Not touched / 涓嶈Е纰?|
| systemd sandbox (drop-in) | Guardian re-applies if overwritten / Guardian 鑷姩鎭㈠ |
| Encrypted secrets (secrets.env.enc) | Not touched / 涓嶈Е纰?|
| Jarvis Memory data (Qdrant/Redis) | Not touched / 涓嶈Е纰?|
| `openclaw.json` memorySearch config | Preserved by `--no-onboard` / `--no-onboard` 淇濈暀 |
| CodeShield guardian/audit services | Not touched / 涓嶈Е纰?|

---

## Security Audit / 瀹夊叏瀹¤

Run the audit at any time / 闅忔椂杩愯瀹夊叏瀹¤锛?
```bash
security-audit.sh
```

### 58-Item Checklist / 58 椤规鏌ユ竻鍗?
**Network Security / 缃戠粶瀹夊叏 (12)**
- firewall active (UFW or netfilter-persistent) / 闃茬伀澧欏凡婵€娲?- ssh password disabled / SSH 瀵嗙爜鐧诲綍宸茬鐢?- ssh keyboard-interactive disabled / SSH 閿洏浜や簰宸茬鐢?- root key-only login / root 浠呴檺瀵嗛挜鐧诲綍
- fail2ban sshd active / fail2ban SSH 闃叉姢宸叉縺娲?- ipv6 disabled / IPv6 宸茬鐢?- zerotier online / ZeroTier 鍦ㄧ嚎
- zerotier private network / ZeroTier 绉佹湁缃戠粶
- docker-user drop rules / Docker 鐢ㄦ埛 DROP 瑙勫垯
- docker-user qdrant grpc blocked / Docker 鐢ㄦ埛 Qdrant gRPC 宸查樆鏂?*(V3.1.1)*
- docker-user rules persist service / Docker 鐢ㄦ埛瑙勫垯鎸佷箙鍖栨湇鍔″凡鍚敤 *(V3.1.1)*
- dns direct query blocked / DNS 鐩磋繛鏌ヨ宸查樆鏂?
**Access Control / 璁块棶鎺у埗 (11)**
- openclaw not in docker group / openclaw 涓嶅湪 docker 缁?- openclaw not in sudo group / openclaw 涓嶅湪 sudo 缁?- openclaw-svc exists / openclaw-svc 鐢ㄦ埛瀛樺湪
- openclaw service isolated user / openclaw 鏈嶅姟浣跨敤闅旂鐢ㄦ埛
- watcher isolated user / watcher 浣跨敤闅旂鐢ㄦ埛
- controlled sudoers present / 鍙楁帶 sudoers 宸查厤缃?- secrets file permissions / 瀵嗛挜鏂囦欢鏉冮檺姝ｇ‘
- secrets encrypted at rest / 瀵嗛挜宸查潤鎬佸姞瀵?- secrets decrypted to tmpfs / 瀵嗛挜瑙ｅ瘑鍒?tmpfs
- codeshield-secrets service active / codeshield-secrets 鏈嶅姟宸叉縺娲?- no inline secrets in openclaw.json / openclaw.json 鏃犲唴鑱斿瘑閽?
**Qdrant Security / Qdrant 瀹夊叏 (2)**
- qdrant unauth rejected / Qdrant 鏈巿鏉冭姹傝鎷掔粷
- qdrant auth accepted / Qdrant 鎺堟潈璇锋眰琚帴鍙?
**Outbound Proxy / 鍑虹珯浠ｇ悊 (4)**
- squid active / Squid 宸叉縺娲?- squid body size limit / Squid 璇锋眰浣撳ぇ灏忛檺鍒?- squid delay pools active / Squid 寤惰繜姹犲凡婵€娲?- squid injection guard exists / Squid 娉ㄥ叆闃叉姢宸插瓨鍦?
**AI Agent Security / AI Agent 瀹夊叏 (6)**
- skills freeze policy exists / 鎶€鑳藉喕缁撶瓥鐣ュ凡瀛樺湪
- skills integrity script exists / 鎶€鑳藉畬鏁存€ц剼鏈凡瀛樺湪
- soul canary exists / SOUL 閲戜笣闆€宸插瓨鍦?- soul injection rules present / SOUL 娉ㄥ叆瑙勫垯宸插瓨鍦?- injection scanner exists / 娉ㄥ叆鎵弿鍣ㄥ凡瀛樺湪
- cost monitor exists / 鎴愭湰鐩戞帶宸插瓨鍦?
**Database Protection / 鏁版嵁搴撲繚鎶?(2 -- optional / 鍙€?**
- redis not deployed / Redis 鏈儴缃诧紙鎴栧凡瀹夊叏閰嶇疆锛?- postgres not deployed / PostgreSQL 鏈儴缃诧紙鎴栧凡瀹夊叏閰嶇疆锛?
**Incident Response / 浜嬩欢鍝嶅簲 (4)**
- forensics key exists / 鍙栬瘉瀵嗛挜宸插瓨鍦?- emergency lockdown exists / 绱ф€ラ攣瀹氳剼鏈凡瀛樺湪
- docker daemon hardened / Docker 瀹堟姢杩涚▼宸插姞鍥?- baseline exists / 鍩虹嚎宸插瓨鍦?
**V3.0.1 Security Fixes / V3.0.1 瀹夊叏淇 (6)**
- qdrant cap_drop all / Qdrant 鏉冮檺鍏ㄩ儴鍓婂噺
- qdrant no-new-privileges / Qdrant 绂佹鏂版潈闄?- force proxy non-loopback block / 寮哄埗浠ｇ悊闈炲洖鐜樆鏂?- openclaw protect system / OpenClaw 绯荤粺淇濇姢
- openclaw capability bounding / OpenClaw 鑳藉姏杈圭晫
- no inline gateway token / 鏃犲唴鑱旂綉鍏充护鐗?
**V3.0.2 Security Fixes / V3.0.2 瀹夊叏淇 (9)**
- ssh forwarding disabled / SSH 杞彂宸茬鐢?- ssh agent forwarding disabled / SSH 浠ｇ悊杞彂宸茬鐢?- ssh max sessions limited / SSH 鏈€澶т細璇濆凡闄愬埗
- fs.suid_dumpable disabled / 鏍稿績杞偍宸茬鐢?- docker icc disabled / Docker 瀹瑰櫒闂撮€氫俊宸茬鐢?- iptables outbound logging / iptables 鍑虹珯鏃ュ織
- reseal timer active / 閲嶅皝瀹氭椂鍣ㄥ凡婵€娲?- systemd restrict address families / systemd 鍦板潃鏃忛檺鍒?- systemd syscall filter / systemd 绯荤粺璋冪敤杩囨护

**Continuous Monitoring / 鎸佺画鐩戞帶 (2)**
- audit timer active / 瀹¤瀹氭椂鍣ㄥ凡婵€娲?- guardian path active / Guardian 璺緞鍗曞厓宸叉縺娲?
**Service Health / 鏈嶅姟鍋ュ悍 (2)**
- openclaw active / openclaw 鏈嶅姟宸叉縺娲?- watcher active / watcher 鏈嶅姟宸叉縺娲?
### Sample Output / 绀轰緥杈撳嚭

```
 [PASS] firewall active
 [PASS] ssh password disabled
 ...
 [PASS] secrets encrypted at rest
 [PASS] secrets decrypted to tmpfs
 ...
 [PASS] ssh forwarding disabled
 [PASS] docker icc disabled
 [PASS] systemd syscall filter
 ...
 鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?  CODE SHIELD V3 -- Security Audit Report
 鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?  Pass: 56  Fail: 0  Optional: 2
  Security Score: 9.5 / 10
 鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?```

---

## Architecture / 鏋舵瀯鍥?
```
                          +-------------------+
                          |   Administrator   |
                          |   (SSH key-only)  |
                          +--------+----------+
                                   |
                          +--------v----------+
                          |   UFW Firewall    |
                          |  (deny incoming)  |
                          +--------+----------+
                                   |
                +------------------+------------------+
                |                                     |
    +-----------v-----------+           +-------------v-----------+
    |  fail2ban (SSH guard) |           |  ZeroTier VPN (private) |
    +-----------+-----------+           +-------------+-----------+
                |                                     |
                +------------------+------------------+
                                   |
          +------------------------v--------------------------+
          |                Ubuntu Server                      |
          |                                                   |
          |  +------------------------------------------+     |
          |  | codeshield-secrets.service (oneshot)      |     |
          |  | secrets.env.enc 鈫?tmpfs (systemd-creds)  |     |
          |  +-----+------------------------------------+     |
          |        |                                          |
          |        +--鈫?/run/openclaw-codeshield/secrets.env  |
          |        |    (root:root 600) 鈥?all secrets         |
          |        |                                          |
          |        +--鈫?/run/openclaw-memory/secrets.env      |
          |             (root:openclaw 640) 鈥?QDRANT_API_KEY  |
          |             only, for Jarvis Memory cron (V3.1.0) |
          |                                                   |
          |  +-----v------------------------------------+     |
          |  | openclaw.service (User=openclaw-svc)     |     |
          |  | EnvironmentFile=/run/.../secrets.env      |     |
          |  | ProtectSystem=strict / CapabilityBound=  |     |
          |  | RestrictAddressFamilies / SystemCallFilter|     |
          |  | ProtectHome=yes / NoNewPrivileges=yes     |     |
          |  | NODE_OPTIONS=--import proxy-preload.mjs   |     |
          |  +-----+------+------+-----+----------+----+     |
          |        |      |      |     |          |           |
          |   +----v--+ +-v----+ | +---v---+ +----v-------+  |
          |   |Telegr.| |Brave | | |OpenAI | | Qdrant DB  |  |
          |   | API   | |Search| | | API   | | 127.0.0.1  |  |
          |   +---+---+ +--+---+ | +---+---+ | cap_drop   |  |
          |       |         |    |     |      | read_only  |  |
          |       +----+----+----+-----+      +----+-------+  |
          |            |                           |          |
          |       +----v--------------------+      |          |
          |       | Squid Proxy             |      |          |
          |       | EnvHttpProxyAgent       |      |          |
          |       | (respects NO_PROXY)     |      |          |
          |       | injection guard (py)    |      |          |
          |       | delay_pools rate limit  |      |          |
          |       +-------------------------+      |          |
          |                                        |          |
          |  iptables: uid-owner openclaw-svc      |          |
          |  ! -d 127.0.0.0/8 -j LOG + DROP       |          |
          |  (all external blocked at kernel)      |          |
          |                                        |          |
          |  +-------------------------------------------+    |
          |  | codeshield-guardian.path                   |    |
          |  | Watches: openclaw/package.json             |    |
          |  | Triggers: secret migration, re-seal,      |    |
          |  |           drop-in, SOUL.md, skills policy, |    |
          |  |           JS patch (DeepSeek/GLM5)         |    |
          |  +-------------------------------------------+    |
          |                                                   |
          |  +-------------------------------------------+    |
          |  | auditd rules | DNS block (iptables uid)   |    |
          |  | injection scanner (15min) | cost monitor   |    |
          |  | emergency-lockdown (AES forensics)         |    |
          |  | codeshield-reseal.timer (monthly)          |    |
          |  +-------------------------------------------+    |
          +---------------------------------------------------+
```

---

## Scoring / 璇勫垎璇存槑

Score formula / 璇勫垎鍏紡:

```
base = 7.0
pass_bonus = (pass_count / total_checks) * 2.0
extra_bonus:
  +0.2  if zero failures / 闆跺け璐?  +0.1  if guardian path unit is active / Guardian 璺緞鍗曞厓婵€娲?  +0.1  if network hardening (UFW/netfilter + SSH) fully applied / 缃戠粶鍔犲浐瀹屽叏搴旂敤
  +0.1  if secrets encrypted at rest / 瀵嗛挜宸查潤鎬佸姞瀵?
final_score = min(base + pass_bonus + extra_bonus, 10.0)
```

| Version / 鐗堟湰 | Automated Checks / 鑷姩妫€鏌?| Score / 璇勫垎 |
|---------|-----------------|-------|
| V3.0.0  | 38/38           | 9.3/10 |
| V3.0.1  | 42/42           | 9.3/10 |
| V3.0.2  | 56/56           | 9.5/10 |
| V3.0.3  | 56/56           | 9.5/10 |
| V3.0.4  | 56/56           | 9.5/10 |
| V3.0.5  | 56/56           | 9.5/10 |
| V3.0.6  | 56/56           | 9.5/10 |
| V3.0.7  | 56/56           | 9.5/10 |
| V3.0.8  | 56/56           | 9.5/10 |
| V3.0.9  | 56/56           | 9.5/10 |
| V3.0.10 | 56/56           | 9.5/10 |
| V3.1.0  | 56/56           | 9.5/10 |
| **V3.1.1** | **58/58**    | **9.5/10** |

Professional audit score (manual review) / 涓撲笟瀹¤璇勫垎锛堜汉宸ヨ瘎瀹★級: **~9.0/10** (up from 7.3 in V3.0.0)

---

## File Structure / 鏂囦欢缁撴瀯

```
codeshield-v3/
|-- install.sh                    # One-line installer entry point / 涓€琛屽畨瑁呭叆鍙?|-- lib/
|   |-- 00-preflight.sh           # Environment pre-checks / 鐜棰勬
|   |-- 01-collect-secrets.sh     # Interactive secret collection / 浜や簰寮忓瘑閽ユ敹闆?|   |-- 02-isolation.sh           # User isolation & secret migration / 鐢ㄦ埛闅旂涓庡瘑閽ヨ縼绉?|   |-- 03-qdrant.sh              # Qdrant auth, network binding, cap_drop / Qdrant 瀹夊叏鍔犲浐
|   |-- 04-hardening.sh           # SSH/UFW/fail2ban/sysctl/Squid/iptables/systemd sandbox
|   |                             # 绯荤粺鍔犲浐锛堝惈 proxy-preload.mjs 閮ㄧ讲锛?|   |-- 05-injection-defense.sh   # Prompt injection defense / 鎻愮ず娉ㄥ叆闃插尽
|   `-- 06-guardian.sh            # Guardian watchdog service / Guardian 鐪嬮棬鐙楁湇鍔?|-- scripts/
|   |-- codeshield-config         # Configuration management CLI / 閰嶇疆绠＄悊鍛戒护琛屽伐鍏?|   |-- security-audit.sh         # 56-item security audit / 56 椤瑰畨鍏ㄥ璁?|   |-- proxy-preload.mjs         # Node.js EnvHttpProxyAgent preload (V3.1.0)
|   |                             # Node.js 浠ｇ悊棰勫姞杞借剼鏈紙灏婇噸 NO_PROXY锛?|   |-- openclaw-injection-scan   # Session injection scanner / 浼氳瘽娉ㄥ叆鎵弿鍣?|   |-- openclaw-cost-monitor     # API cost monitoring / API 鎴愭湰鐩戞帶
|   |-- openclaw-guardian         # Update re-application hook / 鏇存柊鍚庨噸鏂板簲鐢ㄩ挬瀛?|   |-- emergency-lockdown        # Emergency lockdown with AES forensics / 绱ф€ラ攣瀹氾紙AES 鍙栬瘉锛?|   |-- squid-injection-guard.py  # Squid URL rewrite injection filter / Squid URL 娉ㄥ叆杩囨护
|   |-- codeshield-secrets-seal   # Encrypt secrets.env 鈫?.enc / 鍔犲瘑瀵嗛挜鏂囦欢
|   |-- codeshield-secrets-unseal # Decrypt .enc 鈫?tmpfs + Jarvis Memory export (V3.1.0)
|   |                             # 瑙ｅ瘑鍒?tmpfs + Jarvis Memory 瀵嗛挜瀵煎嚭
|   |-- codeshield-secrets-reseal # Re-seal after Guardian migration / Guardian 杩佺Щ鍚庨噸灏?|   `-- codeshield-secrets-migrate # One-time plaintext 鈫?encrypted migration / 涓€娆℃€ф槑鏂囪浆鍔犲瘑
|-- templates/
|   |-- squid.conf                # Squid proxy configuration template / Squid 浠ｇ悊閰嶇疆妯℃澘
|   |-- soul-injection.md         # SOUL.md injection resistance chapter / SOUL.md 娉ㄥ叆鎶垫姉绔犺妭
|   |-- skills-policy.json        # Skills whitelist freeze policy / 鎶€鑳界櫧鍚嶅崟鍐荤粨绛栫暐
|   |-- codeshield-secrets.service # systemd unit for secret decryption / 瀵嗛挜瑙ｅ瘑 systemd 鍗曞厓
|   |-- codeshield-reseal.service  # Monthly re-seal oneshot / 鏈堝害閲嶅皝涓€娆℃€ф湇鍔?|   `-- codeshield-reseal.timer    # Monthly re-seal timer / 鏈堝害閲嶅皝瀹氭椂鍣?|-- CHANGELOG.md                  # Version history with technical details / 鐗堟湰鍘嗗彶涓庢妧鏈粏鑺?`-- README.md                     # This file (bilingual EN/ZH) / 鏈枃浠讹紙涓嫳鍙岃锛?```

### Installation Paths / 瀹夎璺緞

| Path / 璺緞 | Purpose / 鐢ㄩ€?|
|---|---|
| `/etc/openclaw-codeshield/` | Configuration directory (secrets.env.enc, forensics.key, channels.d/, models.d/) / 閰嶇疆鐩綍 |
| `/run/openclaw-codeshield/` | Tmpfs-backed secrets (RAM only, auto-cleaned) / tmpfs 瀵嗛挜锛堜粎鍐呭瓨锛?|
| `/run/openclaw-memory/` | Restricted secret export for Jarvis Memory (V3.1.0) / Jarvis Memory 鍙楅檺瀵嗛挜瀵煎嚭 |
| `/usr/local/sbin/` | Executable tools (security-audit.sh, codeshield-secrets-*, etc.) / 鍙墽琛屽伐鍏?|
| `/usr/local/lib/openclaw-codeshield/` | Library files, templates, proxy-preload.mjs / 搴撴枃浠躲€佹ā鏉裤€佷唬鐞嗛鍔犺浇 |
| `/var/log/openclaw-codeshield/` | Log files (guardian, audit, injection scan, reseal) / 鏃ュ織鏂囦欢 |
| `/var/lib/openclaw-codeshield/` | Data files (baselines, canary, metadata) / 鏁版嵁鏂囦欢 |
| `/var/lib/openclaw-svc/.openclaw/` | Isolated OpenClaw data directory / 闅旂鐨?OpenClaw 鏁版嵁鐩綍 |

---

## Changelog / 鐗堟湰鍘嗗彶

### V3.1.1 (2026-03-21) 鈥?DOCKER-USER Security Gap Fix / DOCKER-USER 瀹夊叏缂哄彛淇

**Fix 1: Qdrant gRPC port 6334 not blocked in DOCKER-USER / 淇 1锛歈drant gRPC 绔彛 6334 鏈湪 DOCKER-USER 涓樆鏂?*
- **Root cause / 鏍瑰洜:** `lib/03-qdrant.sh` only blocked port 6333 (HTTP API) in the DOCKER-USER chain and only bound 6333 to `127.0.0.1` in docker-compose. Port 6334 (gRPC) was left exposed on `0.0.0.0`, allowing external attackers to bypass UFW (Docker bypasses UFW) and access Qdrant directly via gRPC.
- **鏍瑰洜鎻忚堪锛?* `lib/03-qdrant.sh` 浠呭湪 DOCKER-USER 閾句腑闃绘柇浜嗙鍙?6333锛圚TTP API锛夛紝涓斿湪 docker-compose 涓粎灏?6333 缁戝畾鍒?`127.0.0.1`銆傜鍙?6334锛坓RPC锛夋毚闇插湪 `0.0.0.0`锛屽閮ㄦ敾鍑昏€呭彲缁曡繃 UFW锛圖ocker 缁曡繃 UFW锛夐€氳繃 gRPC 鐩存帴璁块棶 Qdrant銆?- **Fix / 淇:** Both ports 6333 and 6334 now bound to `127.0.0.1` in docker-compose. Both blocked in DOCKER-USER chain. Added ESTABLISHED,RELATED and loopback rules. Optional Redis (6379) and PostgreSQL (5432) rules added when containers detected.
- **淇鏂瑰紡锛?* docker-compose 涓?6333 鍜?6334 鍧囩粦瀹氬埌 `127.0.0.1`銆備袱鑰呭湪 DOCKER-USER 閾句腑鍧囪闃绘柇銆傛柊澧?ESTABLISHED,RELATED 鍜?loopback 瑙勫垯銆傛娴嬪埌瀹瑰櫒鏃惰嚜鍔ㄦ坊鍔?Redis (6379) 鍜?PostgreSQL (5432) 鍙€夎鍒欍€?
**Fix 2: DOCKER-USER rules lost after Docker restart / 淇 2锛欴ocker 閲嶅惎鍚?DOCKER-USER 瑙勫垯涓㈠け**
- **Root cause / 鏍瑰洜:** Docker flushes and recreates the DOCKER-USER chain every time it restarts. `netfilter-persistent save` saves the rules to disk, but Docker overwrites them on restart. The guardian service only handles OpenClaw updates, not Docker restarts.
- **鏍瑰洜鎻忚堪锛?* Docker 姣忔閲嶅惎鏃舵竻绌哄苟閲嶅缓 DOCKER-USER 閾俱€俙netfilter-persistent save` 灏嗚鍒欎繚瀛樺埌纾佺洏锛屼絾 Docker 閲嶅惎鏃朵細瑕嗙洊銆侴uardian 鏈嶅姟浠呭鐞?OpenClaw 鏇存柊锛屼笉澶勭悊 Docker 閲嶅惎銆?- **Fix / 淇:** New `codeshield-docker-user.service` (systemd oneshot, `After=docker.service`) automatically re-applies all DOCKER-USER rules whenever Docker restarts.
- **淇鏂瑰紡锛?* 鏂板 `codeshield-docker-user.service`锛坰ystemd oneshot锛宍After=docker.service`锛夛紝鍦?Docker 閲嶅惎鏃惰嚜鍔ㄩ噸鏂板簲鐢ㄦ墍鏈?DOCKER-USER 瑙勫垯銆?
**New audit checks / 鏂板瀹¤妫€鏌ワ紙58 total锛屽師 56锛夛細**
- `docker-user qdrant grpc blocked` 鈥?Verifies DOCKER-USER chain blocks port 6334
- `docker-user rules persist service` 鈥?Verifies `codeshield-docker-user.service` is enabled

**Files changed / 淇敼鏂囦欢锛?*

| File / 鏂囦欢 | Change / 鍙樻洿 |
|---|---|
| `lib/03-qdrant.sh` | Bind 6334 to 127.0.0.1; complete DOCKER-USER rules (ESTABLISHED/RELATED, loopback, 6333, 6334, optional 6379/5432); deploy `codeshield-docker-user.service` |
| `scripts/security-audit.sh` | 2 new checks (58 total); updated JSON version to 3.1.1 |
| `install.sh` | Version bump to 3.1.1 |
| `scripts/codeshield-config` | Header version bump |

### V3.1.0 (2026-03-21) 鈥?Proxy preload fix for local services & Jarvis Memory secret export / 浠ｇ悊棰勫姞杞戒慨澶嶄笌 Jarvis Memory 瀵嗛挜瀵煎嚭

**Fix 1: `ProxyAgent` blocks local services / 淇 1锛歚ProxyAgent` 闃绘柇鏈湴鏈嶅姟**
- **Root cause / 鏍瑰洜:** V3.0.10's `ProxyAgent` routes ALL `fetch()` traffic through Squid 鈥?including requests to local services (Ollama `127.0.0.1:11434`, Qdrant `127.0.0.1:6333`, Redis `127.0.0.1:6379`). Squid blocks `CONNECT` to localhost ports, causing OpenClaw's `memory_search` to fail with `TypeError: fetch failed` when using local Ollama embedding.
- **鏍瑰洜鎻忚堪锛?* V3.0.10 鐨?`ProxyAgent` 灏嗘墍鏈?`fetch()` 娴侀噺璺敱鍒?Squid鈥斺€斿寘鎷埌鏈湴鏈嶅姟鐨勮姹傘€係quid 闃绘柇鍒?localhost 绔彛鐨?`CONNECT`锛屽鑷翠娇鐢ㄦ湰鍦?Ollama 宓屽叆鏃?`memory_search` 鎶ラ敊銆?- **Fix / 淇:** Replaced `ProxyAgent` with `EnvHttpProxyAgent` in `proxy-preload.mjs`. `EnvHttpProxyAgent` reads `NO_PROXY` from environment and bypasses proxy for matching hosts.
- **淇鏂瑰紡锛?* 灏?`proxy-preload.mjs` 涓殑 `ProxyAgent` 鏇挎崲涓?`EnvHttpProxyAgent`锛岃嚜鍔ㄨ鍙?`NO_PROXY` 骞剁粫杩囧尮閰嶄富鏈恒€?
**Fix 2: Secure Jarvis Memory secret export / 淇 2锛欽arvis Memory 瀹夊叏瀵嗛挜瀵煎嚭**
- **Problem / 闂:** Jarvis Memory cron jobs (running as `openclaw` user) need `QDRANT_API_KEY` but it's only in root-owned `/run/openclaw-codeshield/secrets.env`. Storing in plaintext `~/.memory_env` is a security risk.
- **闂鎻忚堪锛?* Jarvis Memory 鐨?cron 浠诲姟锛堜互 `openclaw` 鐢ㄦ埛杩愯锛夐渶瑕?`QDRANT_API_KEY`锛屼絾璇ュ瘑閽ヤ粎瀛樺湪浜?root 鎷ユ湁鐨勮矾寰勪腑銆傛槑鏂囧瓨鍌ㄦ湁瀹夊叏椋庨櫓銆?- **Fix / 淇:** `codeshield-secrets-unseal` now exports a restricted subset (`QDRANT_API_KEY` only) to `/run/openclaw-memory/secrets.env` with `root:openclaw 640` permissions.
- **淇鏂瑰紡锛?* `codeshield-secrets-unseal` 鐜板湪灏嗗彈闄愬瓙闆嗭紙浠?`QDRANT_API_KEY`锛夊鍑哄埌 `/run/openclaw-memory/secrets.env`锛屾潈闄愪负 `root:openclaw 640`銆?
**Files changed / 淇敼鏂囦欢锛?*
| File / 鏂囦欢 | Change / 鍙樻洿 |
|---|---|
| `scripts/proxy-preload.mjs` | `ProxyAgent` 鈫?`EnvHttpProxyAgent` (respects `NO_PROXY`) |
| `scripts/codeshield-secrets-unseal` | Export `QDRANT_API_KEY` to `/run/openclaw-memory/` |
| `install.sh` | Version bumped to 3.1.0 |

### V3.0.10 (2026-03-17) 鈥?Undici ProxyAgent preload for web_fetch / 浠ｇ悊棰勫姞杞戒慨澶?web_fetch

- Added `proxy-preload.mjs` 鈥?Node.js ESM preload script that forces all `fetch()` through Squid via `setGlobalDispatcher(new ProxyAgent(...))`.
- 鏂板 `proxy-preload.mjs`鈥斺€擭ode.js ESM 棰勫姞杞借剼鏈紝寮哄埗鎵€鏈?`fetch()` 閫氳繃 Squid銆?- Deployed via `NODE_OPTIONS="--import /usr/local/lib/openclaw-codeshield/proxy-preload.mjs"`.

### V3.0.9 (2026-03-17) 鈥?Fix OpenClaw network access & add network-mode command / 淇缃戠粶璁块棶涓庢柊澧炵綉缁滄ā寮忓懡浠?
- **Fix:** Guardian missing `NODE_USE_ENV_PROXY` and `NO_PROXY` 鈥?replaced simple 4-variable loop with 7-variable associative array.
- **淇锛?* Guardian 閬楁紡 `NODE_USE_ENV_PROXY` 鍜?`NO_PROXY`鈥斺€斿皢 4 鍙橀噺寰幆鏇挎崲涓?7 鍙橀噺鍏宠仈鏁扮粍銆?- **New:** `codeshield-config network-mode` 鈥?toggle between open (all domains) and strict (whitelist only).
- **鏂板锛?* `codeshield-config network-mode`鈥斺€斿湪寮€鏀炬ā寮忓拰涓ユ牸妯″紡涔嬮棿鍒囨崲銆?
### V3.0.8 (2026-03-17) 鈥?Auto-patch openclaw JS for non-native providers / 鑷姩淇ˉ闈炲師鐢熸彁渚涘晢

- `codeshield-config add-model deepseek|glm5` auto-patches openclaw dist JS files.
- `codeshield-config patch-provider deepseek` re-applies after openclaw update.

### V3.0.7 (2026-03-17) 鈥?Bug Fix: add-model/add-channel crash / 淇娣诲姞瀵嗛挜宕╂簝

- `read_secret()` pipeline `grep` exit code 1 + `set -euo pipefail` killed script. Fixed with `|| true`.

### V3.0.6 (2026-03-17) 鈥?Interactive menu selection & new providers / 浜や簰寮忚彍鍗曚笌鏂板鎻愪緵鍟?
- `add-model`: 8-choice numbered menu with auto-filled domains.
- `add-channel`: 4-choice numbered menu with built-in presets (WeCom, Feishu, Discord).
- New providers: DeepSeek, MiniMax.

### V3.0.5 (2026-03-17) 鈥?DNS audit check & scoring fix / DNS 瀹¤妫€鏌ヤ笌璇勫垎淇

- Fixed `dns direct query blocked` regex for normalized `iptables -S` field order.
- Fixed scoring bonus for `netfilter-persistent` firewall.

### V3.0.4 (2026-03-17) 鈥?Update mode & audit reliability / 鏇存柊妯″紡涓庡璁″彲闈犳€?
- Fixed `--update` mode Stage 6 failure (broken `source` reference).
- Fixed three false audit failures (firewall check, dynamic UID detection).

### V3.0.3 (2026-03-16) 鈥?Configuration management & deployment reliability / 閰嶇疆绠＄悊涓庨儴缃插彲闈犳€?
- New: `codeshield-config` CLI (show/edit/set/add-model/add-channel/proxy-allow).
- Multi-LLM provider support (OpenAI Key+OAuth, Anthropic, GLM5, Kimi).
- UTF-8/locale fixes, `--resume` flag, install logging, error trap.

### V3.0.2 (2026-03-16) 鈥?Security hardening round 2 / 瀹夊叏鍔犲浐绗簩杞?
- 8 fixes from professional audit: SSH tunneling block, kernel hardening, Docker ICC, systemd sandbox, secrets encryption (systemd-creds), outbound logging, monthly reseal timer, auditd expansion.
- 9 new audit checks (56 total). Score: **9.5/10**.

### V3.0.1 (2026-03-16) 鈥?Security patch / 瀹夊叏琛ヤ竵

- 4 priority fixes: Qdrant privilege reduction, iptables outbound block, systemd sandbox, complete secret removal from openclaw.json.
- 6 new audit checks (42 total).

### V3.0.0 (2026-03-15) 鈥?Initial release / 鍒濆鐗堟湰

- Complete rewrite as modular installer with 6 stages.
- Guardian systemd path unit, 36-item security audit, Squid injection guard, SOUL.md canary, skills policy, emergency lockdown.
- One-line `curl | bash` installation.

See [CHANGELOG.md](CHANGELOG.md) for full technical details / 瀹屾暣鎶€鏈粏鑺傝鍙傞槄 CHANGELOG.md銆?
---

## Contact / 鑱旂郴鏂瑰紡

John
Email: iok@outlook.com

---

## License

MIT License

Copyright (c) 2026 CODE SHIELD V3 Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
