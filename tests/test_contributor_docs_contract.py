import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MD = REPO_ROOT / 'CLAUDE.md'
AGENTS_MD = REPO_ROOT / 'AGENTS.md'
WARP_MD = REPO_ROOT / 'WARP.md'


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

    def test_contributor_docs_describe_active_data_root_paths(self):
        agents_text = AGENTS_MD.read_text(encoding='utf-8')
        warp_text = WARP_MD.read_text(encoding='utf-8')

        self.assertIn('FPDEV_DATA_ROOT', agents_text)
        self.assertIn('$XDG_DATA_HOME/fpdev', agents_text)
        self.assertIn(r'%APPDATA%\\fpdev\\', agents_text)
        self.assertNotIn('%APPDATA%\\\\.fpdev\\\\', agents_text)

        self.assertIn('FPDEV_DATA_ROOT', warp_text)
        self.assertIn('data/config.json', warp_text)
        self.assertIn('$XDG_DATA_HOME/fpdev/config.json', warp_text)
        self.assertIn(r'%APPDATA%\\fpdev\\config.json', warp_text)
        self.assertNotIn('%APPDATA%\\.fpdev\\config.json', warp_text)


if __name__ == '__main__':
    unittest.main()
