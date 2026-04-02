import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_DOC = REPO_ROOT / 'CLAUDE.md'


class DeveloperDocsCliContractTests(unittest.TestCase):
    def test_claude_doc_does_not_advertise_removed_root_commands(self):
        banned_tokens = [
            '+-- help',
            '+-- version',
            '+-- doctor',
            '+-- show',
            '+-- default',
            '+-- env',
            '+-- cache',
            '+-- index',
            '+-- shell-hook',
            '+-- resolve-version',
            '+-- config',
            '+-- repo',
            '+-- cross (x)',
            '+-- package (pkg)',
            '+-- project (proj)',
        ]
        offenders = []
        for line in CLAUDE_DOC.read_text(encoding='utf-8').splitlines():
            for token in banned_tokens:
                if line.startswith(token):
                    offenders.append(token)
        self.assertEqual([], offenders, f'Found removed root command tree entries in CLAUDE.md: {offenders}')

    def test_claude_doc_uses_repository_standard_test_commands(self):
        text = CLAUDE_DOC.read_text(encoding='utf-8')

        self.assertIn("python3 -m unittest discover -s tests -p 'test_*.py'", text)
        self.assertIn('bash scripts/run_all_tests.sh', text)
        self.assertIn('bash scripts/run_single_test.sh tests/test_config_management.lpr', text)
        self.assertNotIn('python3 -m pytest tests -q', text)


if __name__ == '__main__':
    unittest.main()
