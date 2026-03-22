from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ISOLATION = REPO_ROOT / 'lib' / '02-isolation.sh'
GUARDIAN = REPO_ROOT / 'scripts' / 'openclaw-guardian'
INSTALL = REPO_ROOT / 'install.sh'


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
        self.assertIn('readonly CS_VERSION="3.1.2"', read_text(INSTALL))


if __name__ == '__main__':
    unittest.main()
