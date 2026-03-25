from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ISOLATION = REPO_ROOT / 'lib' / '02-isolation.sh'
GUARDIAN = REPO_ROOT / 'scripts' / 'openclaw-guardian'
INSTALL = REPO_ROOT / 'install.sh'
HARDENING = REPO_ROOT / 'lib' / '04-hardening.sh'
CONFIG_CLI = REPO_ROOT / 'scripts' / 'codeshield-config'
SOUL_TEMPLATE = REPO_ROOT / 'templates' / 'soul-injection.md'


def read_text(path: Path) -> str:
    return path.read_text(encoding='utf-8', errors='replace')


class RuntimeSyncTests(unittest.TestCase):
    def test_runtime_sync_copies_claude_registry(self) -> None:
        for path in (ISOLATION, GUARDIAN):
            text = read_text(path)
            self.assertIn('"$OPENCLAW_HOME/.claude.json"', text)
            self.assertIn('"$OPENCLAW_SVC_HOME/.claude.json"', text)
            self.assertIn('install -m 0600 -o openclaw-svc -g openclaw-svc', text)

    def test_install_version_bumped(self) -> None:
        self.assertIn('readonly CS_VERSION="3.1.12"', read_text(INSTALL))

    def test_codeshield_config_can_manage_qmd_backend(self) -> None:
        text = read_text(CONFIG_CLI)
        self.assertIn('cmd_qmd_backend()', text)
        self.assertIn('qmd-backend [enable|show|disable]', text)
        self.assertIn('/home/openclaw/scripts/qmd-openclaw-wrapper.sh', text)
        self.assertIn("memory['backend'] = 'qmd'", text)
        self.assertIn("qmd['searchMode'] = qmd.get('searchMode') or 'search'", text)
        self.assertIn("qmd['limits'] = {'maxResults': 6, 'timeoutMs': 15000}", text)
        self.assertIn("defaults.setdefault('memorySearch', {})['enabled'] = True", text)
        self.assertIn("print(f\"  timeoutMs: {limits.get('timeoutMs', '(default)')}\")", text)

    def test_codeshield_config_writes_non_native_provider_models_config(self) -> None:
        text = read_text(CONFIG_CLI)
        self.assertIn('update_openclaw_model_provider_config()', text)
        self.assertIn("cfg.setdefault('models', {}).setdefault('providers', {})", text)
        self.assertIn("'apiKey': f'${{{env_var}}}'", text)
        self.assertIn('update_openclaw_model_provider_config "$safename"', text)
        self.assertIn('update_openclaw_model_provider_config "$provider"', text)
        self.assertNotIn("cfg.setdefault('auth', {}).setdefault('providers', {})", text)

    def test_service_runtime_uses_writable_workspace_path(self) -> None:
        self.assertIn(
            '$OPENCLAW_SVC_HOME/.openclaw/workspace',
            read_text(ISOLATION),
        )
        self.assertIn(
            '$OPENCLAW_SVC_HOME/.openclaw/workspace',
            read_text(GUARDIAN),
        )
        self.assertIn(
            '/var/lib/openclaw-svc/.openclaw/workspace',
            read_text(CONFIG_CLI),
        )

    def test_scripts_do_not_source_systemd_env_files_directly(self) -> None:
        for path in (ISOLATION, GUARDIAN):
            text = read_text(path)
            self.assertNotIn('source "$SECRETS_RUNTIME"', text)
            self.assertNotIn('source "$SECRETS_FILE"', text)
            self.assertNotIn('source "$_secrets_src"', text)
            self.assertIn('read_env_file_value()', text)

    def test_isolation_migrates_deepseek_secrets(self) -> None:
        text = read_text(ISOLATION)
        self.assertIn('("auth.deepseek.apiKey",              "DEEPSEEK_API_KEY")', text)
        self.assertIn('("deepseekApiKey",                    "DEEPSEEK_API_KEY")', text)

    def test_collect_secrets_exports_deepseek_key(self) -> None:
        text = read_text(REPO_ROOT / 'lib' / '01-collect-secrets.sh')
        self.assertIn("printf 'DEEPSEEK_API_KEY=%s\\n' \"${DEEPSEEK_API_KEY:-}\"", text)
        self.assertIn('export ANTHROPIC_API_KEY DEEPSEEK_API_KEY GLM_API_KEY KIMI_API_KEY', text)

    def test_guardian_repairs_runtime_dropin_env_lines(self) -> None:
        text = read_text(GUARDIAN)
        self.assertIn('ensure_dropin_line()', text)
        self.assertIn("ensure_dropin_line 'Environment=HOME=/var/lib/openclaw-svc'", text)
        self.assertIn("ensure_dropin_line 'Environment=XDG_CONFIG_HOME=/var/lib/openclaw-svc/.config'", text)
        self.assertIn("ensure_dropin_line 'WorkingDirectory=/var/lib/openclaw-svc'", text)

    def test_soul_template_requires_live_qmd_verification(self) -> None:
        text = read_text(SOUL_TEMPLATE)
        self.assertIn('CODESHIELD-SOUL-BEGIN', text)
        self.assertIn('CODESHIELD-SOUL-END', text)
        self.assertIn('Live Retrieval Verification', text)
        self.assertIn('QMD, memory search, or the knowledge base', text)
        self.assertIn('current session context already contains live retrieval results', text)
        self.assertIn('first perform one approved retrieval check', text)
        self.assertIn('treat those as valid evidence and use them directly', text)
        self.assertIn('Do not confuse "no explicit tool button" with "no retrieval evidence in the current turn."', text)
        self.assertIn('Do not claim that you lack Jarvis Memory, True Recall, QMD, or knowledge-base access', text)

    def test_guardian_can_refresh_existing_soul_protection_block(self) -> None:
        text = read_text(GUARDIAN)
        self.assertIn('sync_soul_file()', text)
        self.assertIn('legacy_heading = \'## Prompt Injection Resistance (CODE SHIELD V3)\'', text)
        self.assertIn('SOUL.md protection refreshed', text)
        self.assertTrue(text.rstrip().endswith('exit 0'))

    def test_openai_oauth_uses_openclaw_native_flow(self) -> None:
        text = read_text(CONFIG_CLI)
        self.assertIn('print_openai_oauth_next_steps()', text)
        self.assertIn('onboard --auth-choice openai-codex', text)
        self.assertIn('MODEL_SETUP_FLOW=$setupflow', text)
        self.assertIn('MODEL_OPENCLAW_PROVIDER=$openclaw_provider', text)

    def test_openai_oauth_no_longer_collects_client_secret_values(self) -> None:
        text = read_text(CONFIG_CLI)
        self.assertIn('[openai-oauth]=""', text)
        self.assertNotIn('[openai-oauth]="OPENAI_CLIENT_ID,OPENAI_CLIENT_SECRET,OPENAI_ORG_ID"', text)

    def test_cache_clear_helper_does_not_abort_followup_steps(self) -> None:
        text = read_text(CONFIG_CLI)
        self.assertIn('clear_openclaw_caches()', text)
        self.assertIn(
            '[ "$found" -eq 0 ] && info "No openclaw runtime caches found (already clean)."\n    return 0',
            text,
        )

    def test_runtime_sync_preserves_service_auth_state(self) -> None:
        for path in (ISOLATION, GUARDIAN):
            text = read_text(path)
            self.assertIn('sync_openclaw_runtime_tree()', text)
            self.assertIn('--exclude=agents/*/agent/auth.json', text)
            self.assertIn('--exclude=agents/*/agent/auth-profiles.json', text)
            self.assertIn('--exclude=identity/device-auth.json', text)
            self.assertIn('seed_service_auth_state_once', text)

    def test_install_fetches_proxy_preload_asset(self) -> None:
        text = read_text(INSTALL)
        self.assertIn('scripts/proxy-preload.mjs', text)

    def test_hardening_does_not_reference_undefined_cs_dir(self) -> None:
        text = read_text(HARDENING)
        self.assertNotIn('$CS_DIR/scripts/proxy-preload.mjs', text)
        self.assertIn('PRELOAD_SRC="$CS_LIB_DIR/proxy-preload.mjs"', text)


if __name__ == '__main__':
    unittest.main()
