// CODE SHIELD V3.0.10 -- Node.js proxy preload script
// Loaded via NODE_OPTIONS="--import /usr/local/lib/openclaw-codeshield/proxy-preload.mjs"
//
// Problem: NODE_USE_ENV_PROXY=1 only makes the undici *global dispatcher* respect
// HTTP_PROXY/HTTPS_PROXY.  If OpenClaw's web_fetch (or any library) creates its
// own undici Client/Pool or uses Node.js http/https modules directly, the proxy
// is bypassed entirely.  Since iptables DROPs all non-loopback traffic from
// openclaw-svc, those requests silently fail with ETIMEDOUT.
//
// Solution: This preload script runs before any application code and explicitly
// sets the undici global dispatcher to a ProxyAgent.  This covers:
//   - globalThis.fetch() (native Node.js 22+ fetch, backed by undici)
//   - Any library that uses undici's global dispatcher
//
// For http/https module users (axios, node-fetch, got, etc.), the http_proxy
// and https_proxy env vars are already set, and most libraries respect them.
// This preload is specifically for the undici/fetch path.

import { setGlobalDispatcher, ProxyAgent } from 'undici';

const proxyUri = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;

if (proxyUri) {
  try {
    setGlobalDispatcher(new ProxyAgent(proxyUri));
  } catch (_) {
    // Silently ignore — proxy env var may be malformed or undici unavailable
  }
}
