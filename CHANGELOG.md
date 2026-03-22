# Changelog

All notable changes to CODE SHIELD are documented here.

---

## [3.1.2] - 2026-03-22

### Fix: mirror `.claude.json` into the Codeshield runtime home / ???? `.claude.json` ??? Codeshield ??????

- Problem / ??: QMD and other external MCP registrations were often written only to `/home/openclaw/.claude.json`, but the live `openclaw.service` process runs as `openclaw-svc` with home `/var/lib/openclaw-svc`. Result: the Telegram-bound OpenClaw runtime could miss MCP registrations that were visible only to the interactive `openclaw` user.
- Fix / ??: both `lib/02-isolation.sh` and `scripts/openclaw-guardian` now copy `/home/openclaw/.claude.json` into `/var/lib/openclaw-svc/.claude.json`, set `openclaw-svc` ownership, and preserve restrictive permissions. This keeps Codeshield's isolated runtime aligned with user-managed MCP registrations without falling back to unsafe secret handling.
- Files changed / ????: `lib/02-isolation.sh`, `scripts/openclaw-guardian`, `install.sh`, `README.md`

---

## [3.1.1] — 2026-03-21

### Security Fix: DOCKER-USER chain incomplete — Qdrant gRPC port 6334 exposed + rules lost on Docker restart / 安全修复：DOCKER-USER 链不完整——Qdrant gRPC 端口 6334 暴露 + Docker 重启后规则丢失

#### Fix 1 — Port 6334 (gRPC) not blocked in DOCKER-USER / 端口 6334（gRPC）未在 DOCKER-USER 中阻断

- **Problem / 问题:** `lib/03-qdrant.sh` only added a DOCKER-USER DROP rule for port 6333 (Qdrant HTTP API) and only bound 6333 to `127.0.0.1` in docker-compose. Port 6334 (Qdrant gRPC interface) was left at `0.0.0.0`, and no DOCKER-USER rule existed for it. Since Docker bypasses UFW/netfilter-persistent firewall rules, external attackers could access Qdrant's gRPC endpoint directly from the internet. Although Qdrant API key authentication applies to gRPC as well, exposing the port unnecessarily increases attack surface.
- **问题描述：** `lib/03-qdrant.sh` 仅为端口 6333（Qdrant HTTP API）添加了 DOCKER-USER DROP 规则，且在 docker-compose 中仅将 6333 绑定到 `127.0.0.1`。端口 6334（Qdrant gRPC 接口）保留在 `0.0.0.0`，且无 DOCKER-USER 规则。由于 Docker 绕过 UFW/netfilter-persistent 防火墙规则，外部攻击者可从互联网直接访问 Qdrant 的 gRPC 端点。虽然 Qdrant API 密钥认证也适用于 gRPC，但不必要地暴露端口增加了攻击面。
- **Fix / 修复:**
  - docker-compose: Both 6333 and 6334 bound to `127.0.0.1`
  - DOCKER-USER chain: Complete rule set:
    1. `ESTABLISHED,RELATED` → ACCEPT (return traffic)
    2. loopback (`-i lo`) → ACCEPT (localhost access)
    3. Port 6333 `! -s 127.0.0.1` → DROP (Qdrant HTTP)
    4. Port 6334 `! -s 127.0.0.1` → DROP (Qdrant gRPC)
    5. Port 6379 `! -s 127.0.0.1` → DROP (Redis, if container detected)
    6. Port 5432 `! -s 127.0.0.1` → DROP (PostgreSQL, if container detected)
- **File changed / 修改文件:** `lib/03-qdrant.sh`

#### Fix 2 — DOCKER-USER rules lost after Docker restart / Docker 重启后 DOCKER-USER 规则丢失

- **Problem / 问题:** Docker flushes and recreates the DOCKER-USER chain every time the Docker daemon restarts (`systemctl restart docker`). `netfilter-persistent save` saves the rules to `/etc/iptables/rules.v4`, but Docker ignores this file and rebuilds its own chains from scratch. The Guardian service (`openclaw-guardian`) only monitors OpenClaw package updates, not Docker restarts. Result: after any Docker restart (e.g., kernel update reboot, `apt upgrade docker-ce`), all DOCKER-USER rules are gone.
- **问题描述：** Docker 守护进程每次重启时（`systemctl restart docker`）清空并重建 DOCKER-USER 链。`netfilter-persistent save` 将规则保存到 `/etc/iptables/rules.v4`，但 Docker 忽略此文件并从头重建自己的链。Guardian 服务（`openclaw-guardian`）仅监控 OpenClaw 包更新，不监控 Docker 重启。结果：每次 Docker 重启（如内核更新重启、`apt upgrade docker-ce`）后，所有 DOCKER-USER 规则消失。
- **Fix / 修复:** New `codeshield-docker-user.service`:
  - systemd oneshot service with `RemainAfterExit=yes`
  - `After=docker.service`, `Requires=docker.service`
  - Runs `/usr/local/sbin/codeshield-docker-user` script which re-applies all DOCKER-USER rules
  - Waits up to 10 seconds for DOCKER-USER chain to be ready
  - Calls `netfilter-persistent save` after applying rules
  - Enabled at install time, runs automatically on every boot and Docker restart
- **修复方式：** 新增 `codeshield-docker-user.service`：
  - systemd oneshot 服务，`RemainAfterExit=yes`
  - `After=docker.service`，`Requires=docker.service`
  - 运行 `/usr/local/sbin/codeshield-docker-user` 脚本重新应用所有 DOCKER-USER 规则
  - 等待最多 10 秒直到 DOCKER-USER 链就绪
  - 应用规则后调用 `netfilter-persistent save`
  - 安装时启用，每次启动和 Docker 重启时自动运行
- **Files changed / 修改文件:** `lib/03-qdrant.sh` (service deployment)

#### New Audit Checks / 新增审计检查 (58 total, up from 56)

- `docker-user qdrant grpc blocked` — Verifies DOCKER-USER chain contains DROP rule for port 6334
- `docker-user rules persist service` — Verifies `codeshield-docker-user.service` is enabled

#### Version Bump

- `install.sh`: `CS_VERSION` → `3.1.1`
- `scripts/codeshield-config`: Header → `V3.1.1`
- `scripts/security-audit.sh`: JSON version → `3.1.1`, check count → 58

---

## [3.1.0] — 2026-03-21

### Fix: proxy-preload breaks local services + Jarvis Memory secret export / 修复：代理预加载阻断本地服务 + Jarvis Memory 密钥导出

**Problem 1 / 问题1:** V3.0.10's `ProxyAgent` routes **all** `fetch()` traffic through Squid — including requests to local services (Ollama at `127.0.0.1:11434`, Qdrant at `127.0.0.1:6333`). Squid blocks `CONNECT` to localhost ports, causing OpenClaw's `memory_search` to fail with `TypeError: fetch failed` when using a local Ollama embedding provider (e.g., `qwen3-embedding:4b`).

**V3.0.10 的 `ProxyAgent` 将所有 `fetch()` 流量路由到 Squid——包括到本地服务（Ollama `127.0.0.1:11434`、Qdrant `127.0.0.1:6333`）的请求。Squid 阻断到 localhost 端口的 `CONNECT`，导致 OpenClaw 使用本地 Ollama 嵌入模型（如 `qwen3-embedding:4b`）时 `memory_search` 报错 `TypeError: fetch failed`。**

**Fix 1 / 修复1:** Replaced `ProxyAgent` with `EnvHttpProxyAgent` in `proxy-preload.mjs`. `EnvHttpProxyAgent` reads `NO_PROXY` from the environment and bypasses the proxy for matching hosts. External API calls still route through Squid.

**将 `proxy-preload.mjs` 中的 `ProxyAgent` 替换为 `EnvHttpProxyAgent`。`EnvHttpProxyAgent` 读取环境变量 `NO_PROXY`，对匹配的主机绕过代理。外部 API 调用仍通过 Squid 路由。**

**Problem 2 / 问题2:** Jarvis Memory cron jobs (running as `openclaw` user) need `QDRANT_API_KEY` but the key is only available in root-owned `/run/openclaw-codeshield/secrets.env`. Storing the key in plaintext `~/.memory_env` is a security risk.

**Jarvis Memory 的 cron 任务（以 `openclaw` 用户运行）需要 `QDRANT_API_KEY`，但该密钥仅存在于 root 拥有的 `/run/openclaw-codeshield/secrets.env` 中。将密钥明文存储在 `~/.memory_env` 有安全风险。**

**Fix 2 / 修复2:** `codeshield-secrets-unseal` now exports a restricted subset (`QDRANT_API_KEY` only) to `/run/openclaw-memory/secrets.env` with `root:openclaw 640` permissions. Jarvis Memory's `.memory_env` sources this file instead of storing the key directly.

**`codeshield-secrets-unseal` 现在将受限子集（仅 `QDRANT_API_KEY`）导出到 `/run/openclaw-memory/secrets.env`，权限为 `root:openclaw 640`。Jarvis Memory 的 `.memory_env` 从该文件加载密钥，而非直接存储。**

**Changes / 变更:**

| File / 文件 | Change / 变更 |
|---|---|
| `scripts/proxy-preload.mjs` | `ProxyAgent` → `EnvHttpProxyAgent` (respects `NO_PROXY`) / 使用 `EnvHttpProxyAgent`（尊重 `NO_PROXY`） |
| `scripts/codeshield-secrets-unseal` | Export `QDRANT_API_KEY` to `/run/openclaw-memory/secrets.env` for Jarvis Memory cron / 导出 `QDRANT_API_KEY` 供 Jarvis Memory cron 使用 |

---

## [3.0.10] — 2026-03-17

### Fix: web_fetch bypasses proxy despite NODE_USE_ENV_PROXY — undici ProxyAgent preload / 修复：web_fetch 绕过代理——undici ProxyAgent 预加载

**Problem / 问题:** Even with `NODE_USE_ENV_PROXY=1` and all proxy environment variables correctly set (V3.0.9 fix), OpenClaw's `web_fetch` tool still failed to access external URLs. The Squid access log showed **zero entries** for web_fetch requests, while `curl` through the same proxy worked perfectly. This confirmed that web_fetch's HTTP client was bypassing the Squid proxy entirely and hitting the iptables DROP rule.

**即使设置了 `NODE_USE_ENV_PROXY=1` 及所有代理环境变量（V3.0.9 修复），OpenClaw 的 `web_fetch` 工具仍然无法访问外部 URL。Squid 访问日志中 web_fetch 请求记录为零，而通过相同代理的 `curl` 完全正常。这证实 web_fetch 的 HTTP 客户端完全绕过了 Squid 代理，直接触发 iptables DROP 规则。**

**Root cause / 根因:** `NODE_USE_ENV_PROXY=1` only configures the **global undici dispatcher** to respect `HTTP_PROXY`/`HTTPS_PROXY`. However, OpenClaw's web_fetch tool creates its own undici `Client` or `Pool` instance (or uses Node.js `http`/`https` modules directly), which bypasses the global dispatcher. Since iptables blocks all non-loopback traffic from `openclaw-svc`, these requests silently fail with `ETIMEDOUT`.

**`NODE_USE_ENV_PROXY=1` 仅让 undici 的全局 dispatcher 尊重 `HTTP_PROXY`/`HTTPS_PROXY`。但 OpenClaw 的 web_fetch 工具创建了自己的 undici `Client`/`Pool` 实例（或直接使用 Node.js 的 `http`/`https` 模块），绕过了全局 dispatcher。由于 iptables 阻断了 `openclaw-svc` 的所有非回环流量，这些请求以 `ETIMEDOUT` 静默失败。**

**Fix / 修复:** Added a Node.js ESM preload script (`proxy-preload.mjs`) that runs before any application code via `NODE_OPTIONS="--import /usr/local/lib/openclaw-codeshield/proxy-preload.mjs"`. The preload explicitly calls `setGlobalDispatcher(new ProxyAgent(...))` from the bundled `undici` module, forcing **all** `fetch()` calls through the Squid proxy — regardless of whether the caller uses the global dispatcher or not.

**新增 Node.js ESM 预加载脚本 (`proxy-preload.mjs`)，通过 `NODE_OPTIONS="--import ..."` 在任何应用代码之前运行。该脚本显式调用 `setGlobalDispatcher(new ProxyAgent(...))` 强制所有 `fetch()` 调用通过 Squid 代理——无论调用方是否使用全局 dispatcher。**

**Changes / 变更:**

| File / 文件 | Change / 变更 |
|---|---|
| `scripts/proxy-preload.mjs` | **New:** Undici ProxyAgent preload script (ESM) / 新增：undici ProxyAgent 预加载脚本 |
| `lib/04-hardening.sh` | Deploy preload to `/usr/local/lib/openclaw-codeshield/` and add `NODE_OPTIONS` to secrets.env / 部署预加载脚本并添加 NODE_OPTIONS |
| `scripts/openclaw-guardian` | Add `NODE_OPTIONS` to proxy variables associative array / 在代理变量关联数组中添加 NODE_OPTIONS |
| `lib/01-collect-secrets.sh` | Include `NODE_OPTIONS` in fresh-install secret generation / 在新安装密钥生成中包含 NODE_OPTIONS |
| `install.sh` | Bump version to 3.0.10 / 版本号升至 3.0.10 |

**Verification / 验证:** After applying the fix, web_fetch requests appear in the Squid access log (`/var/log/squid/access.log`) as `TCP_TUNNEL/200 CONNECT` entries, confirming they now route through the proxy. Both `httpbin.org/get` and `wttr.in` are accessible via web_fetch.

**修复后，web_fetch 请求以 `TCP_TUNNEL/200 CONNECT` 形式出现在 Squid 访问日志中，确认已通过代理路由。`httpbin.org/get` 和 `wttr.in` 均可通过 web_fetch 访问。**

**Security impact / 安全影响:** Positive. Previously, web_fetch silently failed (no network access at all). Now web_fetch correctly routes through Squid, gaining rate limiting (1MB/s), body size cap (10MB), injection guard URL scanning, and full traffic logging. All 56 audit checks remain passing.

**安全影响：** 正面。此前 web_fetch 静默失败（完全无网络访问）。现在 web_fetch 正确通过 Squid 路由，获得速率限制（1MB/s）、请求体上限（10MB）、注入防护 URL 扫描和全流量日志记录。所有 56 项审计检查继续通过。

---

## [3.0.9] — 2026-03-17

### Fix: Guardian proxy variable injection incomplete — OpenClaw cannot access network / 修复：Guardian 代理变量注入不完整——OpenClaw 无法访问网络

**Problem / 问题:** After OpenClaw updates, the guardian script (`openclaw-guardian`) only injected 4 proxy variables (`HTTPS_PROXY`, `HTTP_PROXY`, `https_proxy`, `http_proxy`) into `secrets.env`. Two critical variables were missing:

1. `NODE_USE_ENV_PROXY=1` — Required for Node.js 22+ built-in fetch (undici) to respect `HTTP_PROXY`/`HTTPS_PROXY` environment variables. Without this, all outbound HTTP requests from OpenClaw bypass the proxy and hit the iptables DROP rule, resulting in `TypeError: fetch failed` / `ETIMEDOUT`.
2. `NO_PROXY=127.0.0.1,localhost` — Without this, requests to local services (Qdrant on 127.0.0.1:6333) are routed through Squid unnecessarily, causing potential routing loops or connection failures.

**问题描述：** OpenClaw 更新后，Guardian 脚本（`openclaw-guardian`）仅向 `secrets.env` 注入 4 个代理变量（`HTTPS_PROXY`、`HTTP_PROXY`、`https_proxy`、`http_proxy`），遗漏了两个关键变量：

1. `NODE_USE_ENV_PROXY=1` — Node.js 22+ 内置 fetch (undici) 需要此变量才会尊重 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量。缺少此变量时，OpenClaw 的所有出站 HTTP 请求绕过代理直接命中 iptables DROP 规则，导致 `TypeError: fetch failed` / `ETIMEDOUT`。
2. `NO_PROXY=127.0.0.1,localhost` — 缺少此变量时，访问本地服务（如 Qdrant 的 127.0.0.1:6333）也会经过 Squid，可能导致路由回环或连接失败。

**Fix / 修复:** Replaced the simple 4-variable `for` loop with an associative array covering all 7 required variables and their correct values:

```bash
declare -A PROXY_VARS=(
    [HTTPS_PROXY]="http://127.0.0.1:3128"
    [HTTP_PROXY]="http://127.0.0.1:3128"
    [https_proxy]="http://127.0.0.1:3128"
    [http_proxy]="http://127.0.0.1:3128"
    [NO_PROXY]="127.0.0.1,localhost"
    [no_proxy]="127.0.0.1,localhost"
    [NODE_USE_ENV_PROXY]="1"
)
```

Also added `NO_PROXY` and `no_proxy` to the fresh-install secret generation in `01-collect-secrets.sh` (which already had `NODE_USE_ENV_PROXY=1` but was missing `NO_PROXY`).

同时在新安装密钥生成脚本 `01-collect-secrets.sh` 中添加了 `NO_PROXY` 和 `no_proxy`（该文件已有 `NODE_USE_ENV_PROXY=1` 但缺少 `NO_PROXY`）。

**Files changed / 修改文件:** `scripts/openclaw-guardian` (lines 112-131), `lib/01-collect-secrets.sh` (lines 199-200)

**Security impact / 安全影响:** None. All 56 audit checks remain passing (9.5/10). The iptables kernel-level block, Squid rate limiting, body size cap, injection guard, and full traffic logging are unchanged. This fix only ensures OpenClaw correctly routes through the existing Squid proxy instead of failing to connect.

**安全影响：** 无。所有 56 项审计检查继续通过（9.5/10）。iptables 内核级阻断、Squid 速率限制、请求体上限、注入防护和全流量日志均不变。此修复仅确保 OpenClaw 正确通过现有 Squid 代理路由，而非连接失败。

---

### New Feature: `codeshield-config network-mode` command / 新功能：`codeshield-config network-mode` 命令

Added `network-mode` command to `codeshield-config` for toggling Squid proxy between **open** and **strict** domain enforcement modes.

新增 `network-mode` 命令到 `codeshield-config`，用于在 Squid 代理的**开放**和**严格**域名模式之间切换。

**Usage / 用法:**

```bash
# Show current network mode / 查看当前网络模式
codeshield-config network-mode
# → Current network mode: open (all domains allowed through proxy)

# Switch to open mode (default, required for web_fetch)
# 切换为开放模式（默认，web_fetch 必需）
codeshield-config network-mode open

# Switch to strict mode (known API domains only, disables web_fetch for arbitrary URLs)
# 切换为严格模式（仅已知 API 域名，禁用对任意 URL 的 web_fetch）
codeshield-config network-mode strict

# In strict mode, add additional domains as needed
# 严格模式下，按需添加额外域名
codeshield-config proxy-allow api.example.com
```

**How it works / 工作原理:** The command toggles the `http_access` line in `/etc/squid/squid.conf` between:
- **open:** `http_access allow localnet` (all domains through proxy)
- **strict:** `http_access allow localnet known_api_domains` (whitelist enforcement)

Squid is automatically reloaded after the change. Both modes maintain full security (iptables block, rate limiting, logging, injection guard).

该命令切换 `/etc/squid/squid.conf` 中的 `http_access` 行：
- **开放：** `http_access allow localnet`（所有域名通过代理）
- **严格：** `http_access allow localnet known_api_domains`（白名单模式）

切换后 Squid 自动重载。两种模式均保持完整安全性（iptables 阻断、速率限制、日志记录、注入防护）。

**Files changed / 修改文件:** `scripts/codeshield-config` (new `cmd_network_mode()` function, help text, dispatch entry)

---

## [3.0.8] — 2026-03-17

### Fix: openclaw web_fetch and tool calls fail — Squid whitelist too restrictive / 修复：web_fetch 和工具调用失败——Squid 白名单过于严格

**Problem / 问题:** OpenClaw's `web_fetch` tool (and any AI agent tool that fetches arbitrary URLs) failed with `TypeError: fetch failed` because Squid was configured to only allow a fixed list of known API domains. Any URL outside that list — including `github.com`, weather APIs (`wttr.in`, `api.open-meteo.com`), or any page the user asked the agent to fetch — was silently denied with HTTP 403.

**问题描述：** OpenClaw 的 `web_fetch` 工具（以及任何获取任意 URL 的 AI Agent 工具）因 Squid 仅允许已知 API 域名的固定列表而失败，报错 `TypeError: fetch failed`。任何不在该列表中的 URL——包括 `github.com`、天气 API（`wttr.in`、`api.open-meteo.com`）或用户要求 Agent 获取的任何页面——都被静默拒绝（HTTP 403）。

**Additional problems / 附加问题:**
- `request_body_max_size 65536 bytes` (64KB): LLM API calls with conversation history routinely exceed 64KB, causing silent failures. Increased to 10MB.
- `request_body_max_size 65536 bytes` (64KB): 包含对话历史的大模型 API 调用通常超过 64KB，导致静默失败。已提高至 10MB。
- `read_timeout 60s` / `request_timeout 60s`: Reasoning models (DeepSeek-R1, o1) can take 3-5 minutes to respond. Increased to 300s.
- `read_timeout 60s` / `request_timeout 60s`: 推理模型（DeepSeek-R1、o1）可能需要 3-5 分钟响应。已提高至 300s。

**Root cause / 根因:** CODE SHIELD's security model was designed as "block all + allow only known API domains." This is correct for preventing the agent from autonomously connecting to unknown servers, but conflicts with user-directed tool calls where the *user* is requesting the agent to fetch arbitrary web content.

**根因：** CODE SHIELD 的安全模型设计为"全部阻断 + 仅允许已知 API 域名"。这对于防止 Agent 自主连接未知服务器是正确的，但与用户主动要求 Agent 获取任意网页内容的工具调用相冲突。

**Fix / 修复:** Removed the domain restriction from Squid's `http_access` rule. All outbound traffic is now allowed **through the proxy** (only — direct external connections remain blocked by iptables at the kernel level). Security is maintained via:
- iptables uid-owner rule: all external traffic from `openclaw-svc` **must** pass through Squid (direct access still returns timeout/ECONNREFUSED)
- Rate limiting: increased to 1MB/s to allow LLM streaming, still throttles bulk exfiltration
- Request body size limit: 10MB cap
- Full access logging: all requests logged to `/var/log/squid/access.log`
- Injection guard: URL rewrite scanner still active

**修复方式：** 从 Squid 的 `http_access` 规则中移除域名限制。所有出站流量现在允许**通过代理**（iptables 在内核层面仍阻止直接外部连接）。安全性通过以下机制维持：
- iptables uid-owner 规则：来自 `openclaw-svc` 的所有外部流量**必须**经过 Squid（直接访问仍返回超时/ECONNREFUSED）
- 速率限制：提高至 1MB/s 以支持大模型流式响应，同时仍限制批量数据渗漏
- 请求体大小限制：10MB 上限
- 完整访问日志：所有请求记录到 `/var/log/squid/access.log`
- 注入防护：URL 重写扫描器仍处于活跃状态

**Files changed / 修改文件:** `templates/squid.conf`, `/etc/squid/squid.conf` (live)

---

### New Feature: Automatic openclaw JS patching for non-native providers / 新功能：非原生提供商自动修补 openclaw JS

**Problem / 问题:** OpenClaw's bundled JS dist files do not natively include DeepSeek or GLM5 as LLM providers. Three edits per dist file are required for each non-native provider: (1) add the API key env var to the `resolveEnvApiKey()` lookup map, (2) add a `buildProvider()` function with model definitions, (3) register the provider in `resolveImplicitProviders()`. There are 5 separate JS bundles, each containing their own copy of these functions. Previously this required manual editing after every openclaw update, and was completely undocumented for end-users.

**问题描述：** OpenClaw 的打包 JS dist 文件不原生支持 DeepSeek 或 GLM5 大模型提供商。每个 dist 文件需要三处修改：(1) 在 `resolveEnvApiKey()` 查找映射中添加 API 密钥环境变量，(2) 添加包含模型定义的 `buildProvider()` 函数，(3) 在 `resolveImplicitProviders()` 中注册提供商。共有 5 个独立的 JS 包，每个都包含这些函数的独立副本。此前每次 openclaw 更新后都需要手动编辑，且对用户完全没有文档说明。

**Fix / 修复:** `codeshield-config add-model deepseek` (and `glm5`) now automatically calls a Python-based JS patching routine that modifies all openclaw dist files in `$OPENCLAW_MODULE_DIR/dist/`. Additionally, a new `patch-provider` command allows re-applying the patch after openclaw updates.

**修复方式：** `codeshield-config add-model deepseek`（及 `glm5`）现在自动调用基于 Python 的 JS 修补程序，修改 `$OPENCLAW_MODULE_DIR/dist/` 中的所有 openclaw dist 文件。新增 `patch-provider` 命令允许 openclaw 更新后重新应用修补。

**Root cause discovered / 发现的根因:** When OpenClaw processes API calls via its lane task gateway (`run-main-D5as9z3E.js` → `auth-profiles-Do5usXx5.js`), it uses `resolveImplicitProviders()` to build the provider list. If `deepseek` is not in the env var map and not registered in `resolveImplicitProviders()`, the gateway falls back to the rate-limited built-in OpenAI-codex profile, producing "API rate limit reached" errors even when `DEEPSEEK_API_KEY` is correctly set in `secrets.env`.

**发现的根因：** OpenClaw 通过 lane task 网关（`run-main-D5as9z3E.js` → `auth-profiles-Do5usXx5.js`）处理 API 调用时，使用 `resolveImplicitProviders()` 构建提供商列表。如果 `deepseek` 不在环境变量映射中且未在 `resolveImplicitProviders()` 中注册，网关会回退到受速率限制的内置 OpenAI-codex 配置文件，即使 `DEEPSEEK_API_KEY` 在 `secrets.env` 中正确设置，也会产生 "API rate limit reached" 错误。

**New commands / 新命令:**
- `codeshield-config patch-provider <provider>` — manually trigger JS patching for a specific non-native provider. Use after `npm install -g openclaw` or `openclaw update` wipes the dist files.
- `codeshield-config patch-provider <provider>` — 手动触发特定非原生提供商的 JS 修补。在 `npm install -g openclaw` 或 `openclaw update` 覆盖 dist 文件后使用。

**Files changed / 修改文件:**
- `scripts/codeshield-config`: Added `patch_openclaw_provider()`, `update_openclaw_model_whitelist()`, `clear_openclaw_caches()` functions; added `patch-provider` command; `cmd_add_model()` now auto-calls patching for non-native providers.

### Version Bump
- `scripts/codeshield-config`: Header comment → `V3.0.8`
- `README.md`: Version → V3.0.8, added `patch-provider` command docs
- `CHANGELOG.md`: Added V3.0.8 entry

---

## [3.0.7] — 2026-03-17

### Bug Fix: `codeshield-config add-model`/`add-channel` crashes when adding new keys / 修复：添加新密钥时崩溃

- **Problem / 问题:** Running `codeshield-config add-model deepseek` (or any new provider whose API key doesn't yet exist in `secrets.env`) would print the model info but silently exit before prompting for the API key. The script terminated immediately after displaying "Auth: apikey" — the `DEEPSEEK_API_KEY:` prompt never appeared. Same issue affected `add-channel` for new channels.
- **问题描述：** 运行 `codeshield-config add-model deepseek`（或任何 API 密钥尚不存在于 `secrets.env` 中的新提供商）会打印模型信息但在提示输入 API 密钥前静默退出。脚本在显示 "Auth: apikey" 后立即终止——`DEEPSEEK_API_KEY:` 提示永远不会出现。`add-channel` 添加新通道时也有同样问题。
- **Root cause / 根因:** `read_secret()` (line 98-103) uses a `grep | head | cut` pipeline. When the key doesn't exist, `grep` returns exit code 1. With `set -euo pipefail` (line 15), `pipefail` propagates `grep`'s non-zero exit to the pipeline result, and `set -e` kills the script. The caller `existing=$(read_secret "$var")` at line 590 (`add-model`) and line 422 (`add-channel`) captures the non-zero exit code, triggering immediate termination.
- **根因详述：** `read_secret()`（第 98-103 行）使用 `grep | head | cut` 管道。当密钥不存在时，`grep` 返回退出码 1。由于 `set -euo pipefail`（第 15 行），`pipefail` 将 `grep` 的非零退出码传播到管道结果，`set -e` 终止脚本。调用方 `existing=$(read_secret "$var")`（`add-model` 第 590 行、`add-channel` 第 422 行）捕获到非零退出码，触发立即终止。
- **Fix / 修复:** Added `|| true` to the grep pipeline in `read_secret()` so it returns an empty string (not an error) when a key is missing:
  ```bash
  grep -E "^${key}=" "$SECRETS_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- || true
  ```
- **修复方式：** 在 `read_secret()` 的 grep 管道末尾添加 `|| true`，使密钥不存在时返回空字符串而非错误。
- **File changed / 修改文件:** `scripts/codeshield-config` (line 101)
- **Impact / 影响:** Both `add-model` and `add-channel` now correctly prompt for new API keys. Existing keys continue to show the masked current value with option to keep.

### Version Bump

- `install.sh`: `CS_VERSION` → `3.0.7`
- `scripts/codeshield-config`: Header comment → `V3.0.7`

---

## [3.0.6] — 2026-03-17

### New Feature: Interactive Menu-Based Selection / 新功能：交互式菜单选择

#### LLM Provider Menu (`codeshield-config add-model`) / 大模型提供商菜单

- **Problem / 问题:** Users had to manually type API domains and environment variable names when adding LLM providers, which was error-prone and inconvenient.
- **问题描述：** 用户添加大模型提供商时需要手动输入 API 域名和环境变量名，容易出错且不便。
- **Fix / 修复:** All built-in providers now use a numbered menu (8 choices). Selecting a provider automatically fills in the API domain(s) and environment variable name(s). Users only need to enter the API key value.
- **修复方式：** 所有内置提供商现在使用编号菜单（8 个选项）。选择提供商后自动填充 API 域名和环境变量名。用户只需输入 API 密钥值。
- **New providers added / 新增提供商：**
  - **DeepSeek (深度求索)** — `api.deepseek.com`, env var `DEEPSEEK_API_KEY`
  - **MiniMax** — `api.minimax.io`, env vars `MINIMAX_API_KEY`, `MINIMAX_GROUP_ID`
- **Updated providers / 更新提供商：**
  - Anthropic → "Anthropic / Claude"
  - Kimi 2.5 → "Kimi (月之暗面 Moonshot)"

**Menu / 菜单：**
```
1) OpenAI (API Key)       2) OpenAI (OAuth)
3) Anthropic / Claude     4) DeepSeek (深度求索)
5) GLM5 (智谱 BigModel)   6) Kimi (月之暗面 Moonshot)
7) MiniMax                8) Custom (自定义)
```

#### Channel Presets (`codeshield-config add-channel`) / 通道预设

- **Problem / 问题:** Users had to manually type API domains and environment variable names when adding messaging channels, which was error-prone.
- **问题描述：** 用户添加消息通道时需要手动输入 API 域名和环境变量名，容易出错。
- **Fix / 修复:** Added built-in presets for the three most common channels. Selecting a preset automatically fills in the API domain(s), environment variable names, and channel name. Users only need to enter the secret values. Custom channel option is still available.
- **修复方式：** 新增三个最常用通道的内置预设。选择预设后自动填充 API 域名、环境变量名和通道名称。用户只需输入密钥值。自定义通道选项仍然可用。
- **Built-in channel presets / 内置通道预设：**
  - **企业微信 (WeCom)** — `qyapi.weixin.qq.com`, env vars `WECOM_CORP_ID`, `WECOM_AGENT_ID`, `WECOM_SECRET`
  - **飞书 (Feishu)** — `open.feishu.cn`, env vars `FEISHU_APP_ID`, `FEISHU_APP_SECRET`
  - **Discord** — `discord.com`, `cdn.discordapp.com`, env vars `DISCORD_BOT_TOKEN`, `DISCORD_WEBHOOK_URL`

**Menu / 菜单：**
```
1) 企业微信 (WeCom)    2) 飞书 (Feishu)
3) Discord             4) Custom (自定义)
```

#### Skills Policy Update / 技能策略更新

- Added `deepseek-chat` (`api.deepseek.com`) and `minimax-chat` (`api.minimax.io`) to approved skills list in `templates/skills-policy.json`.
- 在 `templates/skills-policy.json` 中新增 `deepseek-chat` 和 `minimax-chat` 到已批准技能列表。

### Files Changed / 修改文件

| File / 文件 | Change / 变更 |
|---|---|
| `scripts/codeshield-config` | Added DeepSeek/MiniMax providers; added WeCom/Feishu/Discord channel presets; updated menus and help text |
| `templates/skills-policy.json` | Added `deepseek-chat`, `minimax-chat` skills |
| `README.md` | Updated version, provider/channel tables, menu examples, changelog |
| `CHANGELOG.md` | Added V3.0.6 entry |

---

## [3.0.5] — 2026-03-17

### Bug Fixes / 缺陷修复

#### Fix 1 — `dns direct query blocked` audit check always fails due to `iptables -S` field normalization / `dns direct query blocked` 审计检查因 `iptables -S` 字段归一化而始终失败

- **Problem / 问题:** The `dns direct query blocked` audit check regex expected `uid-owner` to appear before `! -d 127.0.0.0/8` in `iptables -S OUTPUT` results. However, `iptables -S` normalizes rule output and places the destination filter (`! -d 127.0.0.0/8`) **before** the match extension (`-m owner --uid-owner $UID`). The actual output is `-A OUTPUT ! -d 127.0.0.0/8 -m owner --uid-owner 996 -j DROP`, but the regex pattern `uid-owner.*$SVC_UID.*(dport 53.*DROP|! -d 127.0.0.0/8.*DROP)` required `uid-owner` first — so it never matched. This is why `force proxy non-loopback block` (which uses the correct order `! -d 127.0.0.0/8.*uid-owner`) passed while `dns direct query blocked` failed.
- **问题描述：** `dns direct query blocked` 审计检查的正则表达式要求 `uid-owner` 出现在 `! -d 127.0.0.0/8` 之前。但 `iptables -S` 对规则输出进行归一化，将目标过滤器 (`! -d 127.0.0.0/8`) 排在匹配扩展 (`-m owner --uid-owner $UID`) **之前**。实际输出为 `-A OUTPUT ! -d 127.0.0.0/8 -m owner --uid-owner 996 -j DROP`，但正则 `uid-owner.*$SVC_UID.*(dport 53.*DROP|! -d 127.0.0.0/8.*DROP)` 要求 `uid-owner` 在前——因此永远无法匹配。这解释了为什么 `force proxy non-loopback block`（使用正确顺序 `! -d 127.0.0.0/8.*uid-owner`）通过而 `dns direct query blocked` 失败。
- **Fix / 修复:** Updated regex to `(uid-owner.*$SVC_UID.*dport 53.*DROP|! -d 127.0.0.0/8.*uid-owner.*$SVC_UID.*DROP)`. The first alternative matches a dedicated DNS port DROP rule; the second matches the comprehensive non-loopback block in the normalized field order.
- **修复方式：** 将正则表达式更新为 `(uid-owner.*$SVC_UID.*dport 53.*DROP|! -d 127.0.0.0/8.*uid-owner.*$SVC_UID.*DROP)`。第一项匹配专用 DNS 端口 DROP 规则；第二项按归一化后的字段顺序匹配综合阻断规则。
- **File changed / 修改文件:** `scripts/security-audit.sh` (line 120)

#### Fix 2 — Scoring bonus not awarded when `netfilter-persistent` replaces UFW / 评分加分在 `netfilter-persistent` 替换 UFW 后未生效

- **Problem / 问题:** The score calculation awards a +0.1 bonus for network hardening (firewall + SSH). The firewall check in the scoring section (line 340) only tested `ufw status | grep 'Status: active'`. On systems where `iptables-persistent` replaced UFW (the standard case after V3.0.3 install), this bonus was never awarded. V3.0.4 had fixed the audit _check_ to accept either firewall but missed updating the _scoring_ section.
- **问题描述：** 评分计算为网络加固（防火墙 + SSH）提供 +0.1 加分。评分部分（第 340 行）的防火墙检查仅测试 `ufw status | grep 'Status: active'`。在 `iptables-persistent` 替换了 UFW 的系统上（V3.0.3 安装后的标准情况），此加分永远无法获得。V3.0.4 修复了审计_检查_以接受两种防火墙，但遗漏了_评分_部分的更新。
- **Fix / 修复:** Updated scoring bonus to accept either `ufw status | grep active` or `systemctl is-active netfilter-persistent`.
- **修复方式：** 评分加分逻辑改为同时接受 `ufw status | grep active` 或 `systemctl is-active netfilter-persistent`。
- **File changed / 修改文件:** `scripts/security-audit.sh` (lines 340-342)

#### Minor: Updated JSON output version string / 次要：更新 JSON 输出版本号

- JSON output mode (`--json`) version string updated from `3.0.3` to `3.0.5`.

---

## [3.0.4] — 2026-03-17

### Bug Fixes / 缺陷修复

#### Fix 1 — `--update` mode Stage 6 "Secrets encryption" fails with "No such file or directory" / `--update` 模式第 6 阶段「密钥加密」报错找不到文件

- **Problem / 问题:** When running `install.sh --update`, Stage 6 ("Secrets encryption") attempted to `source` a non-existent file `INLINE_SECRETS_ENCRYPT` from `$CS_LIB_DIR`. This was a placeholder name that was never replaced with the actual script path. The real secrets encryption logic (`setup_secrets_encryption()`) is an inline function defined later in `install.sh` (line 289+) and already runs unconditionally after the update/install if-else block — meaning it was never missing, just incorrectly also referenced as a lib script.
- **问题描述：** 使用 `install.sh --update` 更新时，第 6 阶段（「密钥加密」）试图 `source` 一个不存在的文件 `INLINE_SECRETS_ENCRYPT`。这是一个从未被替换为实际脚本路径的占位符名称。真正的密钥加密逻辑 `setup_secrets_encryption()` 是 `install.sh` 中的内联函数（第 289 行），在 update/install 的 if-else 块之后已经会无条件执行——功能本身并未缺失，只是被错误地作为外部 lib 脚本重复引用。
- **Error / 报错:** `main: line 257: /usr/local/lib/openclaw-codeshield/INLINE_SECRETS_ENCRYPT: No such file or directory`
- **Fix / 修复:** Removed the `run_stage 6 ... "INLINE_SECRETS_ENCRYPT"` line from the `--update` mode block. Secrets encryption continues to run via the inline `setup_secrets_encryption()` function that executes for both install and update modes.
- **修复方式：** 从 `--update` 模式的代码块中移除 `run_stage 6 ... "INLINE_SECRETS_ENCRYPT"` 调用。密钥加密继续通过内联函数 `setup_secrets_encryption()` 在两种模式下执行。
- **File changed / 修改文件:** `install.sh` (line 267)
- **Impact / 影响:** `--update` mode now completes all 7 stages without error. Previously, execution would fail at Stage 6 and skip Stage 7 (Guardian service) and the inline secrets encryption entirely.
- **影响范围：** `--update` 模式现在可以无错完成所有 7 个阶段。此前执行会在第 6 阶段失败，导致第 7 阶段（Guardian 服务）和内联密钥加密逻辑被完全跳过。

#### Fix 2 — Security audit false failures: hardcoded UID and removed UFW / 安全审计误报：硬编码 UID 和已卸载的 UFW

Three audit checks consistently reported `[FAIL]` on correctly-configured systems due to two root causes:

三项审计检查在配置正确的系统上持续报告 `[FAIL]`，根因有两个：

**Root Cause A: UFW removed by iptables-persistent / 根因 A：UFW 被 iptables-persistent 卸载**

- **Problem / 问题:** The hardening script (`04-hardening.sh`) configures UFW firewall rules, then later installs `iptables-persistent`/`netfilter-persistent` for iptables rule persistence. On Debian/Ubuntu, `iptables-persistent` conflicts with `ufw` and automatically removes it during `apt-get install`. The audit check `"ufw active"` then fails because `ufw` no longer exists on the system.
- **问题描述：** 加固脚本 (`04-hardening.sh`) 先配置 UFW 防火墙规则，之后安装 `iptables-persistent`/`netfilter-persistent` 以持久化 iptables 规则。在 Debian/Ubuntu 上，`iptables-persistent` 与 `ufw` 包冲突，`apt-get install` 时会自动卸载 UFW。审计检查 `"ufw active"` 因此失败——因为系统上已不存在 `ufw`。
- **Fix / 修复:** Renamed check to `"firewall active"` and updated the test to accept either UFW (`ufw status | grep 'Status: active'`) or netfilter-persistent (`systemctl is-active netfilter-persistent`).
- **修复方式：** 将检查项重命名为 `"firewall active"`，测试逻辑改为同时接受 UFW 或 netfilter-persistent 任一防火墙处于活跃状态。

**Root Cause B: Hardcoded UID 997 / 根因 B：硬编码 UID 997**

- **Problem / 问题:** The audit checks for `"dns direct query blocked"` and `"force proxy non-loopback block"` used hardcoded UID `997` in their iptables grep patterns (e.g., `uid-owner.*(997|openclaw-svc)`). However, the `openclaw-svc` user's UID varies by system — on the affected system it was `996`. Since `iptables -S` outputs numeric UIDs (not usernames), the pattern `997` never matched.
- **问题描述：** `"dns direct query blocked"` 和 `"force proxy non-loopback block"` 两项审计检查在 iptables grep 模式中硬编码了 UID `997`（如 `uid-owner.*(997|openclaw-svc)`）。然而 `openclaw-svc` 用户的 UID 因系统而异——在受影响的系统上为 `996`。由于 `iptables -S` 输出数值 UID（而非用户名），模式 `997` 永远无法匹配。
- **Fix / 修复:** Both checks now dynamically resolve the UID at runtime via `id -u openclaw-svc` instead of using hardcoded values.
- **修复方式：** 两项检查现在通过 `id -u openclaw-svc` 在运行时动态获取 UID，不再使用硬编码值。
- **File changed / 修改文件:** `scripts/security-audit.sh` (lines 92, 119, 257)
- **Impact / 影响:** All three checks now pass on correctly-configured systems regardless of the assigned UID or firewall backend. Security score on the affected system: **9.1/10 → 10.0/10** (all 54 checks pass).
- **影响范围：** 三项检查现在在所有配置正确的系统上均通过，不受分配的 UID 或防火墙后端影响。受影响系统的安全评分：**9.1/10 → 10.0/10**（全部 54 项检查通过）。

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
