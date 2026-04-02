import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FINAL_REPORT = REPO_ROOT / 'docs' / 'archive' / 'FINAL_REPORT.md'
FINAL_INTEGRATION = REPO_ROOT / 'docs' / 'archive' / 'FPDEV_FINAL_INTEGRATION.md'
WEEK10_PLAN = REPO_ROOT / 'docs' / 'archive' / 'WEEK10-PLAN.md'
WEEK10_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'WEEK10-SUMMARY.md'
COMPLETION_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'COMPLETION_SUMMARY.md'


class ArchiveDocsContractTests(unittest.TestCase):
    def test_archive_final_summaries_use_current_help_and_version_commands(self):
        for path in [FINAL_REPORT, FINAL_INTEGRATION]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('fpdev system help', text)
            self.assertIn('fpdev system version', text)
            self.assertNotIn('fpdev help', text)
            self.assertNotIn('fpdev version', text)

    def test_archive_final_report_uses_supported_full_suite_runner(self):
        text = FINAL_REPORT.read_text(encoding='utf-8')
        self.assertIn('scripts/run_all_tests.sh', text)
        self.assertNotIn('scripts/run_all_tests.bat', text)

    def test_archive_final_report_uses_current_toolchain_command_names(self):
        text = FINAL_REPORT.read_text(encoding='utf-8')
        self.assertIn('fpdev fpc use 3.2.2', text)
        self.assertIn('fpdev lazarus use 3.0', text)
        self.assertIn('fpdev lazarus run', text)
        self.assertNotIn('fpdev fpc default 3.2.2', text)
        self.assertNotIn('fpdev lazarus default 3.0', text)
        self.assertNotIn('fpdev lazarus launch', text)

    def test_archive_final_integration_describes_current_cli_bootstrap_architecture(self):
        text = FINAL_INTEGRATION.read_text(encoding='utf-8')
        self.assertIn('src/fpdev.lpr', text)
        self.assertIn('fpdev.cli.bootstrap', text)
        self.assertIn('fpdev.command.imports', text)
        self.assertNotIn('FPDev主程序 (fpdev.lpr)', text)
        self.assertNotIn('fpdev.cmd.help', text)
        self.assertNotIn('fpdev.cmd.version', text)

    def test_archive_final_integration_uses_current_update_commands(self):
        text = FINAL_INTEGRATION.read_text(encoding='utf-8')
        self.assertIn('fpdev fpc update <version>', text)
        self.assertIn('fpdev lazarus update <version>', text)
        self.assertIn('支持 install/list/use/update 子命令', text)
        self.assertIn('支持 install/list/use/update/run 子命令', text)
        self.assertNotIn('fpdev fpc upgrade <version>', text)
        self.assertNotIn('fpdev lazarus upgrade <version>', text)
        self.assertNotIn('install/list/use/upgrade 子命令', text)
        self.assertNotIn('install/list/use/upgrade/run 子命令', text)

    def test_archive_week10_registry_docs_use_active_data_root_paths(self):
        for path in [WEEK10_PLAN, WEEK10_SUMMARY]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('<data-root>/registry/', text)
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertNotIn('~/.fpdev/registry', text)

        plan_text = WEEK10_PLAN.read_text(encoding='utf-8')
        self.assertIn('<data-root>/registry/config.json', plan_text)
        self.assertIn('<data-root>/config.json', plan_text)
        self.assertNotIn('~/.fpdev/config.json', plan_text)

    def test_archive_completion_summary_describes_user_scope_via_active_data_root(self):
        text = COMPLETION_SUMMARY.read_text(encoding='utf-8')
        self.assertIn('<data-root>/toolchains/fpc/<version>/', text)
        self.assertIn('FPDEV_DATA_ROOT', text)
        self.assertNotIn('~/.fpdev/fpc/<version>/', text)


if __name__ == '__main__':
    unittest.main()
