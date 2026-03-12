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


if __name__ == '__main__':
    unittest.main()
