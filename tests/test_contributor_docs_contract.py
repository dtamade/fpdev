import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MD = REPO_ROOT / 'CLAUDE.md'
AGENTS_MD = REPO_ROOT / 'AGENTS.md'
WARP_MD = REPO_ROOT / 'WARP.md'
FPDEV_MD = REPO_ROOT / 'fpdev.md'


class ContributorDocsContractTests(unittest.TestCase):
    def test_claude_doc_points_to_bootstrap_and_import_aggregators(self):
        text = CLAUDE_MD.read_text(encoding='utf-8')
        self.assertIn('src/fpdev.cli.bootstrap.pas', text)
        self.assertIn('src/fpdev.command.imports.pas', text)
        self.assertNotIn('src/fpdev.lpr: imports command units so `initialization` registration runs', text)

    def test_command_registration_guidance_no_longer_points_to_lpr_imports(self):
        for path in [CLAUDE_MD, AGENTS_MD, WARP_MD]:
            text = path.read_text(encoding='utf-8')
            self.assertNotIn('在 `src/fpdev.lpr` 的 uses 中引入该单元', text)
            self.assertNotIn('Import the unit from `src/fpdev.lpr`', text)
            self.assertNotIn('// fpdev.lpr 中必须导入所有命令模块', text)

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

    def test_warp_doc_uses_repository_standard_test_commands(self):
        for path in [AGENTS_MD, WARP_MD]:
            text = path.read_text(encoding='utf-8')

            self.assertIn('scripts/run_all_tests.sh', text)
            self.assertNotIn(r'tests\fpdev.build.manager\run_tests.bat', text)
            self.assertNotIn('bash tests/fpdev.build.manager/run_tests.sh', text)
            self.assertNotIn('cd tests/fpdev.build.manager && ./run_tests.sh', text)

        warp_text = WARP_MD.read_text(encoding='utf-8')
        self.assertIn('bash scripts/run_single_test.sh tests/test_config_management.lpr', warp_text)
        self.assertNotIn('| **集成测试** | `tests/` | `run_tests.bat` | > 70% |', warp_text)

    def test_warp_doc_matches_current_cli_surface(self):
        text = WARP_MD.read_text(encoding='utf-8')

        self.assertIn('fpdev system help', text)
        self.assertIn('fpdev system version', text)
        self.assertNotIn('Usage: fpdev help', text)

        banned_tokens = [
            '├── help       (显示帮助)',
            '├── version    (显示版本信息)',
            '│   ├── default',
            '│   ├── add',
            '│   └── remove',
            r'.\bin\fpdev.exe source clone main',
            r'.\bin\fpdev.exe source status main',
            r'.\bin\fpdev.exe source checkout fixes_3_2',
        ]
        for token in banned_tokens:
            self.assertNotIn(token, text)

    def test_warp_doc_uses_current_build_entrypoints(self):
        text = WARP_MD.read_text(encoding='utf-8')

        self.assertIn('lazbuild -B fpdev.lpi', text)
        self.assertIn('fpc -Fusrc -Fisrc -FEbin -FUlib src/fpdev.lpr', text)
        self.assertNotIn('fpc fpdev.lpr', text)
        self.assertNotIn('fpc -Mobjfpc -Scghi -O3 -Xs -XX fpdev.lpr', text)
        self.assertNotIn('run_tests.bat', text)

    def test_warp_doc_uses_clean_build_examples_consistently(self):
        text = WARP_MD.read_text(encoding='utf-8')

        self.assertIn('lazbuild -B tests/test_config_management.lpi', text)
        self.assertIn('lazbuild -B --os=linux --cpu=x86_64 fpdev.lpi', text)
        self.assertNotIn('lazbuild fpdev.lpi', text)
        self.assertNotIn('lazbuild <test>.lpi', text)
        self.assertNotIn('lazbuild --os=linux --cpu=x86_64 fpdev.lpi', text)

    def test_fpdev_md_does_not_advertise_removed_root_commands(self):
        text = FPDEV_MD.read_text(encoding='utf-8')

        lines = text.splitlines()
        self.assertNotIn('## version', lines)
        self.assertNotIn('## help', lines)
        self.assertNotIn('## update', lines)

    def test_fpdev_md_does_not_advertise_removed_or_renamed_subcommands(self):
        text = FPDEV_MD.read_text(encoding='utf-8')

        banned_tokens = [
            '### upgrade <version>',
            '### upgrade <targetOS>-<targetCPU>-[version]',
            '### upgrade <package>',
            '### add <package>',
            '### remove <package>',
            '### upgrade',
        ]
        for token in banned_tokens:
            self.assertNotIn(token, text)

    def test_fpdev_md_points_to_current_namespaced_replacements(self):
        text = FPDEV_MD.read_text(encoding='utf-8')

        self.assertIn('fpdev system help', text)
        self.assertIn('fpdev system version', text)
        self.assertIn('fpdev fpc update', text)
        self.assertIn('fpdev lazarus update', text)
        self.assertIn('fpdev cross update', text)
        self.assertIn('fpdev package update', text)
        self.assertIn('fpdev system index update', text)


if __name__ == '__main__':
    unittest.main()
