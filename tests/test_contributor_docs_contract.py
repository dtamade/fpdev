import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MD = REPO_ROOT / 'CLAUDE.md'
AGENTS_MD = REPO_ROOT / 'AGENTS.md'


class ContributorDocsContractTests(unittest.TestCase):
    def test_claude_doc_points_to_bootstrap_and_import_aggregators(self):
        text = CLAUDE_MD.read_text(encoding='utf-8')
        self.assertIn('src/fpdev.cli.bootstrap.pas', text)
        self.assertIn('src/fpdev.command.imports.pas', text)
        self.assertNotIn('src/fpdev.lpr: imports command units so `initialization` registration runs', text)

    def test_command_registration_guidance_no_longer_points_to_lpr_imports(self):
        for path in [CLAUDE_MD, AGENTS_MD]:
            text = path.read_text(encoding='utf-8')
            self.assertNotIn('在 `src/fpdev.lpr` 的 uses 中引入该单元', text)
            self.assertNotIn('Import the unit from `src/fpdev.lpr`', text)


if __name__ == '__main__':
    unittest.main()
