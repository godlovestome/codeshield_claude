#!/usr/bin/env python3
"""
CODE SHIELD V3 -- Squid URL Rewrite Program (Injection Guard)

This script is called by Squid for each request. It checks URLs and
request data for prompt injection patterns. Suspicious requests are
redirected to a block page.

Protocol: Squid url_rewrite_program (concurrency=0)
Input:  URL [extras...]
Output: OK rewrite-url=<url>  or  OK url=<url>  or  ERR
"""

import sys
import io
import re
import os
import datetime

# Force UTF-8 for stdin/stdout to handle non-ASCII URLs gracefully
if hasattr(sys.stdin, 'buffer'):
    sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8', errors='replace')
if hasattr(sys.stdout, 'buffer'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

LOG_FILE = "/var/log/openclaw-codeshield/squid-guard.log"

# Injection patterns to detect in URLs
INJECTION_PATTERNS = [
    re.compile(r'ignore[+%20_-]*previous[+%20_-]*instructions', re.IGNORECASE),
    re.compile(r'system[+%20_-]*prompt', re.IGNORECASE),
    re.compile(r'jailbreak', re.IGNORECASE),
    re.compile(r'DAN[+%20_-]*mode', re.IGNORECASE),
    re.compile(r'base64[+%20_-]*decode', re.IGNORECASE),
    re.compile(r'eval\s*\(', re.IGNORECASE),
    re.compile(r'exec\s*\(', re.IGNORECASE),
    re.compile(r'__import__', re.IGNORECASE),
    re.compile(r'subprocess', re.IGNORECASE),
    re.compile(r'os\.system', re.IGNORECASE),
    re.compile(r'<script', re.IGNORECASE),
    re.compile(r'javascript:', re.IGNORECASE),
    re.compile(r'data:text/html', re.IGNORECASE),
    re.compile(r'%00', re.IGNORECASE),  # null byte injection
    re.compile(r'\.\./\.\./\.\./', re.IGNORECASE),  # path traversal
    re.compile(r'CODESHIELD-CANARY', re.IGNORECASE),  # canary exfiltration
]

# Excessively long URLs may indicate data exfiltration
MAX_URL_LENGTH = 4096


def log_event(msg):
    """Append a log entry."""
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            ts = datetime.datetime.now().isoformat()
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass


def check_url(url):
    """Return True if URL is suspicious."""
    # Length check
    if len(url) > MAX_URL_LENGTH:
        log_event(f"BLOCKED (too long, {len(url)} chars): {url[:200]}...")
        return True

    # Pattern checks
    for pattern in INJECTION_PATTERNS:
        if pattern.search(url):
            log_event(f"BLOCKED (pattern: {pattern.pattern}): {url[:500]}")
            return True

    return False


def main():
    """Main loop: read URLs from stdin, respond to Squid."""
    # Unbuffered I/O for Squid compatibility
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break

            line = line.strip()
            if not line:
                continue

            # Parse: URL [client_ip/fqdn ident method [kv-pairs]]
            parts = line.split()
            url = parts[0] if parts else ""

            if check_url(url):
                # Block: redirect to a local error page
                sys.stdout.write("OK rewrite-url=http://127.0.0.1/codeshield-blocked\n")
            else:
                # Allow: pass through unchanged
                sys.stdout.write("OK\n")

            sys.stdout.flush()

        except Exception as e:
            log_event(f"ERROR: {e}")
            sys.stdout.write("OK\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
