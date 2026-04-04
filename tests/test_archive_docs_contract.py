import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FINAL_REPORT = REPO_ROOT / 'docs' / 'archive' / 'FINAL_REPORT.md'
FINAL_INTEGRATION = REPO_ROOT / 'docs' / 'archive' / 'FPDEV_FINAL_INTEGRATION.md'
WEEK10_PLAN = REPO_ROOT / 'docs' / 'archive' / 'WEEK10-PLAN.md'
WEEK10_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'WEEK10-SUMMARY.md'
COMPLETION_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'COMPLETION_SUMMARY.md'
WEEK5_PLAN = REPO_ROOT / 'docs' / 'archive' / 'WEEK5-PLAN.md'
WEEK5_COMPLETION = REPO_ROOT / 'docs' / 'archive' / 'WEEK5-COMPLETION.md'
WEEK5_PROGRESS = REPO_ROOT / 'docs' / 'archive' / 'WEEK5-PROGRESS.md'
WEEK5_FINAL_REPORT = REPO_ROOT / 'docs' / 'archive' / 'WEEK5-FINAL-REPORT.md'
WEEK5_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'WEEK5-SUMMARY.md'
WEEK5_INTEGRATION_TEST_REPORT = REPO_ROOT / 'docs' / 'archive' / 'WEEK5-INTEGRATION-TEST-REPORT.md'
WEEK6_PLAN = REPO_ROOT / 'docs' / 'archive' / 'WEEK6-PLAN.md'
WEEK6_PROGRESS = REPO_ROOT / 'docs' / 'archive' / 'WEEK6-PROGRESS.md'
WEEK6_ISSUES = REPO_ROOT / 'docs' / 'archive' / 'WEEK6-ISSUES.md'
WEEK4_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'WEEK4-SUMMARY.md'
WEEK7_PLAN = REPO_ROOT / 'docs' / 'archive' / 'WEEK7-PLAN.md'
WEEK7_PROGRESS = REPO_ROOT / 'docs' / 'archive' / 'WEEK7-PROGRESS.md'
WEEK7_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'WEEK7-SUMMARY.md'
CODE_IMPROVEMENTS_SUMMARY = REPO_ROOT / 'docs' / 'archive' / 'CODE-IMPROVEMENTS-SUMMARY.md'
WEEK8_PLAN = REPO_ROOT / 'docs' / 'archive' / 'WEEK8-PLAN.md'


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

    def test_archive_docs_do_not_embed_developer_workspace_paths(self):
        week6 = WEEK6_PROGRESS.read_text(encoding='utf-8')
        self.assertIn('cd <workspace>/fpdev-fpc', week6)
        self.assertIn('cd <repo-root>', week6)
        self.assertIn('rm -rf <data-root>/toolchains/fpc/3.2.0', week6)
        self.assertNotIn('/home/dtamade/projects/', week6)

        week4 = WEEK4_SUMMARY.read_text(encoding='utf-8')
        self.assertIn('`<workspace>/fpdev-fpc/manifest.json`', week4)
        self.assertIn('`<workspace>/fpdev-lazarus/manifest.json`', week4)
        self.assertIn('`<workspace>/fpdev-bootstrap/manifest.json`', week4)
        self.assertIn('`<workspace>/fpdev-cross/manifest.json`', week4)
        self.assertIn('`<repo-root>/docs/MANIFEST-MIGRATION.md`', week4)
        self.assertNotIn('/home/dtamade/projects/', week4)

    def test_archive_manifest_cache_docs_use_active_data_root_paths(self):
        cache_docs = [
            WEEK5_PLAN,
            WEEK5_COMPLETION,
            WEEK5_PROGRESS,
            WEEK5_FINAL_REPORT,
            WEEK5_SUMMARY,
            WEEK5_INTEGRATION_TEST_REPORT,
            WEEK6_PLAN,
        ]
        for path in cache_docs:
            text = path.read_text(encoding='utf-8')
            self.assertIn('<data-root>/cache/manifests', text)
            self.assertNotIn('~/.fpdev/cache/manifests', text)
            self.assertNotIn('/home/dtamade/.fpdev/cache/manifests', text)

    def test_archive_cache_restore_docs_use_active_data_root_paths(self):
        toolchain_docs = [
            WEEK6_ISSUES,
            WEEK7_PLAN,
            WEEK7_PROGRESS,
            WEEK7_SUMMARY,
            CODE_IMPROVEMENTS_SUMMARY,
        ]
        for path in toolchain_docs:
            text = path.read_text(encoding='utf-8')
            self.assertIn('<data-root>/toolchains/fpc/3.2.0', text)
            self.assertNotIn('~/.fpdev/toolchains/fpc/3.2.0', text)
            self.assertNotIn('/home/dtamade/.fpdev/toolchains/fpc/3.2.0', text)

        week7_summary_text = WEEK7_SUMMARY.read_text(encoding='utf-8')
        self.assertIn('<data-root>/cache', week7_summary_text)
        self.assertNotIn('/home/dtamade/.config/fpdev/.fpdev/cache', week7_summary_text)

    def test_archive_docs_do_not_advertise_missing_fpc_clean_command(self):
        completion_text = COMPLETION_SUMMARY.read_text(encoding='utf-8')
        self.assertIn('manual cleanup under `<data-root>/sources/fpc/fpc-<version>`', completion_text)
        self.assertIn('`fpdev fpc update`', completion_text)
        self.assertNotIn('#### Feature: `fpdev fpc clean`', completion_text)
        self.assertNotIn('| FPC source cleanup | Manual cleanup | `fpdev fpc clean` |', completion_text)

        week8_text = WEEK8_PLAN.read_text(encoding='utf-8')
        self.assertIn('manual FPC source cleanup + fpc update', week8_text)
        self.assertNotIn('fpc clean/update', week8_text)


if __name__ == '__main__':
    unittest.main()
