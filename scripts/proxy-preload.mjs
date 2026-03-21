// CODE SHIELD V3.0.11 -- Node.js proxy preload script
// Loaded via NODE_OPTIONS="--import /usr/local/lib/openclaw-codeshield/proxy-preload.mjs"
//
// V3.0.11 CHANGE: Switched from ProxyAgent to EnvHttpProxyAgent.
//
// Problem (V3.0.10): ProxyAgent routes ALL traffic through Squid — including
// requests to local services (Ollama 127.0.0.1:11434, Qdrant 127.0.0.1:6333,
// Redis 127.0.0.1:6379). Squid blocks CONNECT to localhost ports, causing
// OpenClaw's memory_search embeddings to fail with "TypeError: fetch failed"
// when using a local Ollama provider.
//
// Fix: EnvHttpProxyAgent reads HTTP_PROXY/HTTPS_PROXY AND NO_PROXY from the
// environment. Local services listed in NO_PROXY bypass the proxy automatically.
// External API calls (api.openai.com, api.telegram.org, etc.) still route
// through Squid as intended.
//
// Required env vars (set in secrets.env):
//   HTTPS_PROXY=http://127.0.0.1:3128
//   NO_PROXY=127.0.0.1,localhost

import { setGlobalDispatcher, EnvHttpProxyAgent } from 'undici';

const proxyUri = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;

if (proxyUri) {
  try {
    setGlobalDispatcher(new EnvHttpProxyAgent());
  } catch (_) {
    // Silently ignore — proxy env var may be malformed or undici unavailable
  }
}
