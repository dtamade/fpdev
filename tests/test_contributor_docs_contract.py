import unittest
from pathlib import Path
import re


REPO_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MD = REPO_ROOT / 'CLAUDE.md'
AGENTS_MD = REPO_ROOT / 'AGENTS.md'
CHANGELOG_MD = REPO_ROOT / 'CHANGELOG.md'
README_MD = REPO_ROOT / 'README.md'
FAQ_ROOT_MD = REPO_ROOT / 'FAQ.md'
QUICKSTART_ROOT_MD = REPO_ROOT / 'QUICKSTART.md'
DOCS_DIR = REPO_ROOT / 'docs'
HISTORY_DIR = DOCS_DIR / 'history'
INTERNAL_DIR = DOCS_DIR / 'internal'
TESTING_MD = DOCS_DIR / 'testing.md'
ARCHITECTURE_MD = DOCS_DIR / 'ARCHITECTURE.md'
ARCHITECTURE_EN_MD = DOCS_DIR / 'ARCHITECTURE.en.md'
BUILD_MANAGER_MD = DOCS_DIR / 'build-manager.md'
BUILD_MANAGER_EN_MD = DOCS_DIR / 'build-manager.en.md'
FAQ_DOCS_MD = DOCS_DIR / 'FAQ.md'
FAQ_DOCS_EN_MD = DOCS_DIR / 'FAQ.en.md'
QUICKSTART_DOCS_MD = DOCS_DIR / 'QUICKSTART.md'
QUICKSTART_DOCS_EN_MD = DOCS_DIR / 'QUICKSTART.en.md'
MANIFEST_USAGE_MD = DOCS_DIR / 'MANIFEST-USAGE.md'
HISTORY_README = HISTORY_DIR / 'README.md'
INTERNAL_README = INTERNAL_DIR / 'README.md'
LIBGIT2_DYNAMIC_MD = HISTORY_DIR / 'LIBGIT2_DYNAMIC.md'
TEST_PLAN_GIT2_LOCAL_MD = HISTORY_DIR / 'TEST_PLAN_GIT2_LOCAL.md'
AGENT_TEAM_KICKOFF_MD = INTERNAL_DIR / 'AGENT_TEAM_KICKOFF.md'
TODO_FPC_V1_MD = HISTORY_DIR / 'TODO-FPC-v1.md'
DEPRECATED_CODE_AUDIT_MD = HISTORY_DIR / 'DEPRECATED_CODE_AUDIT.md'
LARGE_FILES_REPORT = HISTORY_DIR / 'B171-large-files-report.md'
V11_TEST_REPORT = REPO_ROOT / 'TEST_REPORT_v1.1.md'
V11_RELEASE_NOTES = REPO_ROOT / 'RELEASE_NOTES_v1.1.md'
SLEEP_MODE_SUMMARY = REPO_ROOT / 'SLEEP_MODE_SUMMARY.md'
TODO_SLEEP = REPO_ROOT / 'TODO_SLEEP.md'
DEVELOPMENT_ROADMAP_DOCS = [
    HISTORY_DIR / 'DEVELOPMENT_ROADMAP.md',
    HISTORY_DIR / 'DEVELOPMENT_ROADMAP.en.md',
]
HISTORICAL_DOCS = [
    HISTORY_DIR / 'B165-i18n-retrospective.md',
    HISTORY_DIR / 'B166-deprecated-cleanup.md',
    HISTORY_DIR / 'B167-cross-split-analysis.md',
    HISTORY_DIR / 'B172-week11-retrospective.md',
    HISTORY_DIR / 'PHASE5-SUMMARY.md',
    HISTORY_DIR / 'PHASE6-SUMMARY.md',
    HISTORY_DIR / 'M1_GIT_HARDENING.md',
]


class ContributorDocsContractTests(unittest.TestCase):
    def _section(self, text: str, start: str, end: str) -> str:
        start_index = text.index(start)
        end_index = text.index(end, start_index)
        return text[start_index:end_index]

    def test_changelog_version_headings_are_unique(self):
        text = CHANGELOG_MD.read_text(encoding='utf-8')
        versions = re.findall(r'^## \[([^\]]+)\]', text, flags=re.MULTILINE)
        self.assertEqual(len(versions), len(set(versions)), 'CHANGELOG.md should not repeat version headings')

    def test_changelog_release_baseline_does_not_claim_stale_current_inventory(self):
        text = CHANGELOG_MD.read_text(encoding='utf-8')
        self.assertIn('Release-time discoverable test inventory', text)
        self.assertIn('README.md', text)
        self.assertIn('docs/ROADMAP.md', text)
        self.assertNotIn('Current discoverable test inventory', text)
        self.assertNotIn('Production-ready code quality maintained throughout', text)

    def test_testing_doc_ci_section_matches_tracked_workflows(self):
        text = TESTING_MD.read_text(encoding='utf-8')
        self.assertIn('Pushes to `main` / `develop`', text)
        self.assertIn('Pull requests targeting `main`', text)
        self.assertIn('Manual/local release verification before publishing', text)
        self.assertIn('Verification entrypoints include:', text)
        self.assertNotIn('Tests are automatically run on:', text)
        self.assertNotIn('Every commit (pre-commit hook)', text)
        self.assertNotIn('Nightly builds (full test suite)', text)

    def test_testing_doc_does_not_reference_missing_windows_all_tests_wrapper(self):
        text = TESTING_MD.read_text(encoding='utf-8')
        self.assertIn('scripts/run_all_tests.sh', text)
        self.assertIn('No dedicated `scripts\\run_all_tests.bat` wrapper is tracked', text)
        self.assertNotIn('\n# Windows\nscripts\\run_all_tests.bat', text)

    def test_testing_doc_uses_repo_local_prettier_wrapper_and_tmp_pascal_outputs(self):
        text = TESTING_MD.read_text(encoding='utf-8')
        self.assertIn('scripts/run_prettier.sh', text)
        self.assertIn('/tmp/fpdev-test-bin', text)
        self.assertIn('/tmp/fpdev-test-lib', text)
        self.assertIn('FPDEV_TEST_PROJECT_ROOT=', text)
        self.assertNotIn('yarn prettier --write', text)

    def test_testing_doc_scopes_make_not_found_to_real_build_flows(self):
        text = TESTING_MD.read_text(encoding='utf-8')
        self.assertIn('mock toolchain checkers', text)
        self.assertIn('integration/build-oriented flows', text)
        self.assertNotIn('BuildManager test requires `make` in PATH.', text)

    def test_testing_doc_scopes_libgit2_runtime_troubleshooting_by_platform(self):
        text = TESTING_MD.read_text(encoding='utf-8')
        self.assertIn('Test Fails to Load libgit2 at Runtime', text)
        self.assertIn('`git2.dll`', text)
        self.assertIn('`libgit2.so`', text)
        self.assertIn('`libgit2.1.dylib`', text)
        self.assertIn('src/libgit2.pas', text)
        self.assertNotIn('### Test Fails with "git2.dll not found"', text)
        self.assertNotIn('export LD_LIBRARY_PATH=3rd/libgit2:$LD_LIBRARY_PATH', text)
        self.assertNotIn('copy 3rd\\libgit2\\git2.dll bin\\', text)

    def test_libgit2_dynamic_doc_marks_missing_loader_plan_as_historical_snapshot(self):
        text = LIBGIT2_DYNAMIC_MD.read_text(encoding='utf-8')
        self.assertIn('2026-04-05 更新', text)
        self.assertIn('历史快照', text)
        self.assertIn('当前工作树', text)
        self.assertIn('src/libgit2.dynamic.pas', text)
        self.assertIn('src/libgit2.pas', text)
        self.assertIn('src/git2.modern.pas', text)
        self.assertIn('docs/GIT2_USAGE.md', text)
        self.assertIn('docs/FAQ.md', text)
        self.assertIn('## 2026-04-05 当前工作树补充', text)
        self.assertIn('## 历史快照正文', text)

    def test_git2_local_test_plan_uses_current_entrypoints_not_missing_batch_wrapper(self):
        text = TEST_PLAN_GIT2_LOCAL_MD.read_text(encoding='utf-8')
        self.assertIn('tests/test_git2_local_repo.lpr', text)
        self.assertIn('tests/test_git2_local_repo.lpi', text)
        self.assertIn('bash scripts/run_single_test.sh tests/test_git2_local_repo.lpr', text)
        self.assertNotIn('scripts/test_git2_local_repo.bat', text)

    def test_todo_fpc_v1_test_plan_marks_batch_wrappers_as_planned_not_tracked(self):
        text = TODO_FPC_V1_MD.read_text(encoding='utf-8')
        self.assertIn('planned coverage placeholders', text)
        self.assertIn('scripts/run_single_test.sh', text)
        self.assertIn('tests/test_fpc_verify.lpr', text)
        self.assertNotIn('- scripts/test_fpc_install_prefix.bat:', text)
        self.assertNotIn('- scripts/test_fpc_idempotent.bat:', text)
        self.assertNotIn('- scripts/test_fpc_verify.bat:', text)
        self.assertNotIn('- scripts/test_fpc_list_status.bat:', text)

    def test_agent_team_kickoff_marks_itself_as_historical_sprint_snapshot(self):
        text = AGENT_TEAM_KICKOFF_MD.read_text(encoding='utf-8')
        self.assertIn('2026-04-06 更新', text)
        self.assertIn('历史快照', text)
        self.assertIn('当前工作树', text)
        self.assertIn('README.md', text)
        self.assertIn('docs/ROADMAP.md', text)
        self.assertIn('## 2026-04-05 Sprint 1 快照正文', text)

    def test_todo_fpc_v1_marks_untracked_batch_scripts_as_plan_placeholders(self):
        text = TODO_FPC_V1_MD.read_text(encoding='utf-8')
        self.assertIn('2026-04-06 更新', text)
        self.assertIn('计划草案', text)
        self.assertIn('当前工作树', text)
        self.assertIn('未跟踪', text)
        self.assertIn('scripts/run_single_test.sh', text)

    def test_history_readme_routes_snapshot_docs_to_current_public_sources(self):
        text = HISTORY_README.read_text(encoding='utf-8')
        self.assertIn('历史快照', text)
        self.assertIn('docs/ROADMAP.md', text)
        self.assertIn('docs/archive/', text)
        self.assertIn('docs/plans/', text)
        self.assertIn('DEVELOPMENT_ROADMAP.md', text)
        self.assertIn('TODO-FPC-v1.md', text)

    def test_internal_readme_marks_agent_docs_as_internal_coordination_artifacts(self):
        text = INTERNAL_README.read_text(encoding='utf-8')
        self.assertIn('内部协作', text)
        self.assertIn('README.md', text)
        self.assertIn('docs/ROADMAP.md', text)
        self.assertIn('AGENT_TEAM_SETUP.md', text)
        self.assertIn('AGENT_TEAM_KICKOFF.md', text)

    def test_historical_development_roadmaps_remap_fpc_owner_to_current_docs_and_units(self):
        expectations = {
            HISTORY_DIR / 'DEVELOPMENT_ROADMAP.md': ('当前工作树', '兼容层'),
            HISTORY_DIR / 'DEVELOPMENT_ROADMAP.en.md': ('current worktree', 'compatibility shim'),
        }
        for path, (worktree_note, shim_note) in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn('docs/ROADMAP.md', text)
            self.assertIn('src/fpdev.cmd.fpc.pas', text)
            self.assertIn(worktree_note, text)
            self.assertIn(shim_note, text)

    def test_historical_development_roadmaps_mark_test_mvp_script_as_untracked_example(self):
        expectations = {
            HISTORY_DIR / 'DEVELOPMENT_ROADMAP.md': (
                'scripts/test_mvp.sh',
                '历史示例',
                '当前工作树未跟踪',
                'docs/MVP_ACCEPTANCE_CRITERIA.md',
            ),
            HISTORY_DIR / 'DEVELOPMENT_ROADMAP.en.md': (
                'scripts/test_mvp.sh',
                'Historical example',
                'not tracked in the current worktree',
                'docs/MVP_ACCEPTANCE_CRITERIA.en.md',
            ),
        }
        for path, required in expectations.items():
            text = path.read_text(encoding='utf-8')
            for needle in required:
                self.assertIn(needle, text, f'{path} should contain {needle!r}')

    def test_historical_docs_mark_themselves_as_snapshots(self):
        for path in HISTORICAL_DOCS:
            text = path.read_text(encoding='utf-8')
            self.assertIn('历史快照', text, f'{path} should mark itself as a historical snapshot')
            self.assertIn('当前工作树', text, f'{path} should warn that the current worktree may differ')

    def test_m1_git_hardening_marks_removed_dynamic_loader_smoke_artifacts_as_historical(self):
        path = HISTORY_DIR / 'M1_GIT_HARDENING.md'
        text = path.read_text(encoding='utf-8')
        self.assertIn('scripts/test_dynamic_loader.bat', text)
        self.assertIn('src/test_dyn_loader.lpr', text)
        self.assertIn('当前工作树', text)
        self.assertIn('docs/history/LIBGIT2_DYNAMIC.md', text)
        self.assertIn('src/libgit2.pas', text)
        self.assertIn('已不在当前工作树', text)

    def test_large_file_report_marks_project_and_lazarus_shells_as_historical_snapshot(self):
        text = LARGE_FILES_REPORT.read_text(encoding='utf-8')
        self.assertIn('2026-04-11 更新', text)
        self.assertIn('历史快照', text)
        self.assertIn('src/fpdev.cmd.project.pas', text)
        self.assertIn('src/fpdev.cmd.lazarus.pas', text)
        self.assertIn('兼容层', text)
        self.assertIn('src/fpdev.fpc.manager.pas', text)
        self.assertIn('src/fpdev.fpc.statusflow.pas', text)
        self.assertIn('src/fpdev.project.manager.pas', text)
        self.assertIn('src/fpdev.lazarus.manager.pas', text)
        self.assertIn('src/fpdev.lazarus.metadataflow.pas', text)
        self.assertIn('src/fpdev.lazarus.pathflow.pas', text)
        self.assertIn('src/fpdev.lazarus.installcallbacks.pas', text)
        self.assertIn('src/fpdev.lazarus.runtimeactions.pas', text)

    def test_large_file_report_separates_current_worktree_supplement_from_historical_body(self):
        text = LARGE_FILES_REPORT.read_text(encoding='utf-8')
        self.assertIn('## 2026-04-11 当前工作树补充', text)
        self.assertIn('## 2026-02-10 历史快照正文', text)
        self.assertNotIn('## 当前状态', text)
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.cmd\.project\.pas`\s*\|\s*23\s*\|\s*兼容层\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.cmd\.lazarus\.pas`\s*\|\s*24\s*\|\s*兼容层\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.project\.manager\.pas`\s*\|\s*824\s*\|\s*当前 Project 实现重心\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.manager\.pas`\s*\|\s*841\s*\|\s*当前 Lazarus facade/orchestration 中心（已切出 metadata/path/runtime）\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.metadataflow\.pas`\s*\|\s*162\s*\|\s*Lazarus metadata/version inventory helper\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.pathflow\.pas`\s*\|\s*75\s*\|\s*Lazarus install path/install-state helper\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.installcallbacks\.pas`\s*\|\s*222\s*\|\s*Lazarus install callback helper\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.runtimeactions\.pas`\s*\|\s*211\s*\|\s*Lazarus runtime/IDE action helper\s*\|'))
        self.assertIn('历史观察结论（2026-02-10）', text)
        self.assertIn('当前工作树补充结论（2026-04-11）', text)

    def test_large_file_report_separates_current_worktree_note_from_historical_body(self):
        text = LARGE_FILES_REPORT.read_text(encoding='utf-8')
        self.assertIn('## 2026-04-11 当前工作树补充', text)
        self.assertIn('## 2026-02-10 历史快照', text)
        self.assertIn('## 2026-02-10 结论', text)
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.cmd\.project\.pas`\s*\|\s*23\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.cmd\.lazarus\.pas`\s*\|\s*24\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.project\.manager\.pas`\s*\|\s*824\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.manager\.pas`\s*\|\s*841\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.metadataflow\.pas`\s*\|\s*162\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.pathflow\.pas`\s*\|\s*75\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.installcallbacks\.pas`\s*\|\s*222\s*\|'))
        self.assertRegex(text, re.compile(r'\|\s*`src/fpdev\.lazarus\.runtimeactions\.pas`\s*\|\s*211\s*\|'))
        self.assertNotIn('## 当前状态', text)
        self.assertNotIn('当前大文件状态健康', text)

    def test_versioned_root_reports_are_removed_from_active_tree(self):
        for path in [
            V11_TEST_REPORT,
            V11_RELEASE_NOTES,
            SLEEP_MODE_SUMMARY,
            TODO_SLEEP,
        ]:
            self.assertFalse(path.exists(), f'{path} should be removed from the active worktree')

    def test_claude_doc_points_to_bootstrap_and_import_aggregators(self):
        text = CLAUDE_MD.read_text(encoding='utf-8')
        self.assertIn('src/fpdev.cli.bootstrap.pas', text)
        self.assertIn('src/fpdev.command.imports.pas', text)
        self.assertNotIn('src/fpdev.lpr: imports command units so `initialization` registration runs', text)

    def test_claude_doc_uses_repo_local_prettier_wrapper_and_unittest_baseline(self):
        text = CLAUDE_MD.read_text(encoding='utf-8')
        self.assertIn("python3 -m unittest discover -s tests -p 'test_*.py'", text)
        self.assertIn('scripts/run_prettier.sh', text)

    def test_architecture_docs_capture_current_facade_helper_split(self):
        expectations = {
            ARCHITECTURE_MD: (
                '## 2026-04 当前工作树 facade/helper split',
                'src/fpdev.build.managerflow.pas',
                'src/fpdev.build.runtimeflow.pas',
                'src/fpdev.fpc.builderflow.pas',
                'src/fpdev.fpc.binaryflow.pas',
                'src/fpdev.fpc.installcommandflow.pas',
                'src/fpdev.fpc.usecommandflow.pas',
                'src/fpdev.fpc.verifycommandflow.pas',
            ),
            ARCHITECTURE_EN_MD: (
                '## 2026-04 Current worktree facade/helper split',
                'src/fpdev.build.managerflow.pas',
                'src/fpdev.build.runtimeflow.pas',
                'src/fpdev.fpc.builderflow.pas',
                'src/fpdev.fpc.binaryflow.pas',
                'src/fpdev.fpc.installcommandflow.pas',
                'src/fpdev.fpc.usecommandflow.pas',
                'src/fpdev.fpc.verifycommandflow.pas',
            ),
        }
        for path, required in expectations.items():
            text = path.read_text(encoding='utf-8')
            for needle in required:
                self.assertIn(needle, text, f'{path} should contain {needle!r}')

    def test_build_manager_docs_capture_current_runbook_and_cross_config_contract(self):
        expectations = {
            BUILD_MANAGER_MD: (
                '## 全工具链真实演练 Runbook（快速上手）',
                'scripts\\check_toolchain.bat',
                'bash scripts/check_toolchain.sh',
                'scripts\\run_examples.bat',
                'bash scripts/run_examples.sh',
                'scripts\\run_examples_real.bat',
                'bash scripts/run_examples_real.sh',
                'REAL=1',
                'plays/.sandbox',
                'SetMakeCmd',
                'SetTarget',
                'SetPrefix',
            ),
            BUILD_MANAGER_EN_MD: (
                '## Full Toolchain Real-Rehearsal Runbook',
                'scripts\\check_toolchain.bat',
                'bash scripts/check_toolchain.sh',
                'scripts\\run_examples.bat',
                'bash scripts/run_examples.sh',
                'scripts\\run_examples_real.bat',
                'bash scripts/run_examples_real.sh',
                'REAL=1',
                'plays/.sandbox',
                'SetMakeCmd',
                'SetTarget',
                'SetPrefix',
            ),
        }
        for path, required in expectations.items():
            text = path.read_text(encoding='utf-8')
            for needle in required:
                self.assertIn(needle, text, f'{path} should contain {needle!r}')

    def test_quickstarts_use_binary_first_fpc_install_examples(self):
        expectations = {
            QUICKSTART_ROOT_MD: ('## 🚀 第一步：安装 FPC 编译器', '## 🎯 第二步：创建第一个项目'),
            QUICKSTART_DOCS_MD: ('### 安装 FPC (FreePascal 编译器)', '### 安装 Lazarus IDE (可选)'),
            QUICKSTART_DOCS_EN_MD: ('### Install FPC (FreePascal Compiler)', '### Install Lazarus IDE (Optional)'),
        }
        for path, (start, end) in expectations.items():
            text = path.read_text(encoding='utf-8')
            section = self._section(text, start, end)
            self.assertIn('fpdev fpc install 3.2.2', section)
            self.assertNotIn('fpdev fpc install 3.2.2 --from-source', section)

    def test_faqs_explain_offline_no_cache_and_cache_list_recovery(self):
        for path in [FAQ_ROOT_MD, FAQ_DOCS_MD, FAQ_DOCS_EN_MD]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('--offline', text, f'{path} should explain offline install behavior')
            self.assertIn('--no-cache', text, f'{path} should explain no-cache behavior')
            self.assertIn('fpdev fpc cache list', text, f'{path} should explain cache inspection recovery')

    def test_readme_install_section_mentions_current_fpc_and_lazarus_contract(self):
        text = README_MD.read_text(encoding='utf-8')
        self.assertIn('fpdev fpc install 3.2.2', text)
        self.assertIn('fpdev fpc install 3.2.2 --offline', text)
        self.assertIn('fpdev fpc install 3.2.2 --no-cache', text)
        self.assertIn('fpdev lazarus install 3.0', text)
        self.assertIn('回退到源码构建', text)

    def test_manifest_usage_mentions_binary_acquisition_fallback_and_cache_modes(self):
        text = MANIFEST_USAGE_MD.read_text(encoding='utf-8')
        self.assertIn('fpdev-repo', text)
        self.assertIn('SourceForge', text)
        self.assertIn('fpdev fpc install 3.2.2 --offline', text)
        self.assertIn('fpdev fpc install 3.2.2 --no-cache', text)
        self.assertIn('fpdev fpc install 3.2.2 --from-source', text)

    def test_command_registration_guidance_no_longer_points_to_lpr_imports(self):
        for path in [CLAUDE_MD, AGENTS_MD]:
            text = path.read_text(encoding='utf-8')
            self.assertNotIn('在 `src/fpdev.lpr` 的 uses 中引入该单元', text)
            self.assertNotIn('Import the unit from `src/fpdev.lpr`', text)


if __name__ == '__main__':
    unittest.main()
