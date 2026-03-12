import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

OFFICIAL_DOCS = [
    REPO_ROOT / 'README.md',
    REPO_ROOT / 'README.en.md',
    REPO_ROOT / 'docs' / 'API.md',
    REPO_ROOT / 'docs' / 'API.en.md',
    REPO_ROOT / 'docs' / 'INSTALLATION.md',
    REPO_ROOT / 'docs' / 'INSTALLATION.en.md',
    REPO_ROOT / 'docs' / 'QUICKSTART.md',
    REPO_ROOT / 'docs' / 'QUICKSTART.en.md',
    REPO_ROOT / 'docs' / 'ARCHITECTURE.md',
    REPO_ROOT / 'docs' / 'ARCHITECTURE.en.md',
]

BANNED_COMMAND_PREFIXES = [
    'fpdev help',
    'fpdev version --check',
    'fpdev version',
    'fpdev fpc default',
    'fpdev lazarus default',
    'fpdev fpc remove',
    'fpdev lazarus remove',
    'fpdev cross add',
    'fpdev package remove',
    'fpdev fpc upgrade',
    'fpdev lazarus upgrade',
    'fpdev lazarus launch',
]


class OfficialDocsCliContractTests(unittest.TestCase):
    def test_official_docs_do_not_advertise_removed_top_level_commands(self):
        offenders = []
        for path in OFFICIAL_DOCS:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                stripped = line.strip()
                for prefix in BANNED_COMMAND_PREFIXES:
                    if stripped.startswith(prefix):
                        offenders.append((path.relative_to(REPO_ROOT), lineno, stripped))
        self.assertEqual([], offenders, f'Found removed CLI commands in official docs: {offenders}')

    def test_official_docs_do_not_describe_legacy_tfpcmd_model(self):
        offenders = []
        for path in [
            REPO_ROOT / 'docs' / 'API.md',
            REPO_ROOT / 'docs' / 'API.en.md',
            REPO_ROOT / 'docs' / 'ARCHITECTURE.md',
            REPO_ROOT / 'docs' / 'ARCHITECTURE.en.md',
        ]:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                if 'TFPCMD' in line:
                    offenders.append((path.relative_to(REPO_ROOT), lineno, line.strip()))
        self.assertEqual([], offenders, f'Found legacy TFPCMD docs in official architecture/API docs: {offenders}')


if __name__ == '__main__':
    unittest.main()
