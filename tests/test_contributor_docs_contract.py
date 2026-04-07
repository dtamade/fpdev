import unittest
from pathlib import Path
import re


REPO_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MD = REPO_ROOT / 'CLAUDE.md'
AGENTS_MD = REPO_ROOT / 'AGENTS.md'
CHANGELOG_MD = REPO_ROOT / 'CHANGELOG.md'
TESTING_MD = REPO_ROOT / 'docs' / 'testing.md'
LIBGIT2_DYNAMIC_MD = REPO_ROOT / 'docs' / 'LIBGIT2_DYNAMIC.md'
TEST_PLAN_GIT2_LOCAL_MD = REPO_ROOT / 'docs' / 'TEST_PLAN_GIT2_LOCAL.md'
AGENT_TEAM_KICKOFF_MD = REPO_ROOT / 'docs' / 'AGENT_TEAM_KICKOFF.md'
TODO_FPC_V1_MD = REPO_ROOT / 'docs' / 'TODO-FPC-v1.md'
DEPRECATED_CODE_AUDIT_MD = REPO_ROOT / 'docs' / 'DEPRECATED_CODE_AUDIT.md'
LARGE_FILES_REPORT = REPO_ROOT / 'docs' / 'B171-large-files-report.md'
V11_TEST_REPORT = REPO_ROOT / 'TEST_REPORT_v1.1.md'
V11_RELEASE_NOTES = REPO_ROOT / 'RELEASE_NOTES_v1.1.md'
SLEEP_MODE_SUMMARY = REPO_ROOT / 'SLEEP_MODE_SUMMARY.md'
TODO_SLEEP = REPO_ROOT / 'TODO_SLEEP.md'
DEVELOPMENT_ROADMAP_DOCS = [
    REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.md',
    REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.en.md',
]
HISTORICAL_ROOT_DOCS = [
    REPO_ROOT / 'docs' / 'B165-i18n-retrospective.md',
    REPO_ROOT / 'docs' / 'B166-deprecated-cleanup.md',
    REPO_ROOT / 'docs' / 'B167-cross-split-analysis.md',
    REPO_ROOT / 'docs' / 'B172-week11-retrospective.md',
    REPO_ROOT / 'docs' / 'PHASE5-SUMMARY.md',
    REPO_ROOT / 'docs' / 'PHASE6-SUMMARY.md',
    REPO_ROOT / 'docs' / 'M1_GIT_HARDENING.md',
]


class ContributorDocsContractTests(unittest.TestCase):
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

    def test_historical_development_roadmaps_remap_fpc_owner_to_current_docs_and_units(self):
        expectations = {
            REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.md': ('当前工作树', '兼容层'),
            REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.en.md': ('current worktree', 'compatibility shim'),
        }
        for path, (worktree_note, shim_note) in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn('docs/ROADMAP.md', text)
            self.assertIn('src/fpdev.cmd.fpc.pas', text)
            self.assertIn(worktree_note, text)
            self.assertIn(shim_note, text)

    def test_historical_development_roadmaps_mark_test_mvp_script_as_untracked_example(self):
        expectations = {
            REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.md': (
                'scripts/test_mvp.sh',
                '历史示例',
                '当前工作树未跟踪',
                'docs/MVP_ACCEPTANCE_CRITERIA.md',
            ),
            REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.en.md': (
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

    def test_historical_root_docs_mark_themselves_as_snapshots(self):
        for path in HISTORICAL_ROOT_DOCS:
            text = path.read_text(encoding='utf-8')
            self.assertIn('历史快照', text, f'{path} should mark itself as a historical snapshot')
            self.assertIn('当前工作树', text, f'{path} should warn that the current worktree may differ')

    def test_m1_git_hardening_marks_removed_dynamic_loader_smoke_artifacts_as_historical(self):
        path = REPO_ROOT / 'docs' / 'M1_GIT_HARDENING.md'
        text = path.read_text(encoding='utf-8')
        self.assertIn('scripts/test_dynamic_loader.bat', text)
        self.assertIn('src/test_dyn_loader.lpr', text)
        self.assertIn('当前工作树', text)
        self.assertIn('docs/LIBGIT2_DYNAMIC.md', text)
        self.assertIn('src/libgit2.pas', text)
        self.assertIn('已不在当前工作树', text)

    def test_large_file_report_marks_project_and_lazarus_shells_as_historical_snapshot(self):
        text = LARGE_FILES_REPORT.read_text(encoding='utf-8')
        self.assertIn('2026-04-05 更新', text)
        self.assertIn('历史快照', text)
        self.assertIn('src/fpdev.cmd.project.pas', text)
        self.assertIn('src/fpdev.cmd.lazarus.pas', text)
        self.assertIn('兼容层', text)
        self.assertIn('src/fpdev.project.manager.pas', text)
        self.assertIn('src/fpdev.lazarus.manager.pas', text)

    def test_large_file_report_separates_current_worktree_supplement_from_historical_body(self):
        text = LARGE_FILES_REPORT.read_text(encoding='utf-8')
        self.assertIn('## 2026-04-05 当前工作树补充', text)
        self.assertIn('## 2026-02-10 历史快照正文', text)
        self.assertNotIn('## 当前状态', text)
        self.assertIn('| `src/fpdev.cmd.project.pas` | 23 | 兼容层 |', text)
        self.assertIn('| `src/fpdev.cmd.lazarus.pas` | 24 | 兼容层 |', text)
        self.assertIn('| `src/fpdev.project.manager.pas` | 824 | 当前 Project 实现重心 |', text)
        self.assertIn('| `src/fpdev.lazarus.manager.pas` | 1166 | 当前 Lazarus 实现重心 |', text)
        self.assertIn('历史观察结论（2026-02-10）', text)
        self.assertIn('当前工作树补充结论（2026-04-05）', text)

    def test_large_file_report_separates_current_worktree_note_from_historical_body(self):
        text = LARGE_FILES_REPORT.read_text(encoding='utf-8')
        self.assertIn('## 2026-04-05 当前工作树补充', text)
        self.assertIn('## 2026-02-10 历史快照', text)
        self.assertIn('## 2026-02-10 结论', text)
        self.assertIn('| `src/fpdev.cmd.project.pas` | 23 |', text)
        self.assertIn('| `src/fpdev.cmd.lazarus.pas` | 24 |', text)
        self.assertIn('| `src/fpdev.project.manager.pas` | 824 |', text)
        self.assertIn('| `src/fpdev.lazarus.manager.pas` | 1166 |', text)
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

    def test_command_registration_guidance_no_longer_points_to_lpr_imports(self):
        for path in [CLAUDE_MD, AGENTS_MD]:
            text = path.read_text(encoding='utf-8')
            self.assertNotIn('在 `src/fpdev.lpr` 的 uses 中引入该单元', text)
            self.assertNotIn('Import the unit from `src/fpdev.lpr`', text)


if __name__ == '__main__':
    unittest.main()
