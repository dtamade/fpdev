import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
STATUS_DOC = REPO_ROOT / 'docs' / 'history' / 'git2-status-and-tests.md'
STATUS_REPORT = REPO_ROOT / 'report' / 'fpdev.git2.md'
STATUS_TODO = REPO_ROOT / 'todos' / 'fpdev.git2.md'
STATUS_BATCH = REPO_ROOT / 'tests' / 'fpdev.git2' / 'buildOrTest.bat'
FPCUNIT_BATCH = REPO_ROOT / 'tests' / 'fpdev.git2' / 'buildOrTest.fpcunit.bat'


class Git2StatusDocsContractTests(unittest.TestCase):
    def test_status_doc_lists_current_focused_runners_and_api_surface(self):
        text = STATUS_DOC.read_text(encoding='utf-8')
        for needle in [
            'TGitRepository.Status: TStringArray',
            'TGitRepository.StatusEntries(Filter: TGitStatusFilter): TGitStatusEntryArray',
            'TGitRepository.IsClean: Boolean',
            'TGitRepository.HasUncommittedChanges: Boolean',
            'fpdev.git2.status_test.lpr',
            'fpdev.git2.status_entries_test.lpr',
            'fpdev.git2.status_ignore_test.lpr',
            'fpdev.git2.status_index_test.lpr',
            'fpdev.git2.status_conflict_test.lpr',
            'buildOrTest.bat',
            'buildOrTest.fpcunit.bat',
            'merge-conflict 覆盖（真实本地冲突仓库）',
        ]:
            self.assertIn(needle, text)
        self.assertNotIn('merge-conflict 覆盖（暂缓）', text)

    def test_status_batch_runner_compiles_and_runs_all_current_status_programs(self):
        text = STATUS_BATCH.read_text(encoding='utf-8')
        for needle in [
            'fpdev.git2.test.lpr',
            'fpdev.git2.status_test.lpr',
            'fpdev.git2.status_entries_test.lpr',
            'fpdev.git2.status_ignore_test.lpr',
            'fpdev.git2.status_index_test.lpr',
            'fpdev.git2.status_conflict_test.lpr',
            'fpdev.git2.status_test.exe',
            'fpdev.git2.status_entries_test.exe',
            'fpdev.git2.status_ignore_test.exe',
            'fpdev.git2.status_index_test.exe',
            'fpdev.git2.status_conflict_test.exe',
        ]:
            self.assertIn(needle, text)

    def test_git2_report_no_longer_tracks_status_api_as_future_work(self):
        text = STATUS_REPORT.read_text(encoding='utf-8')
        self.assertIn('Status/StatusEntries/IsClean/HasUncommittedChanges', text)
        self.assertIn('fpdev.git2.status_test.lpr', text)
        self.assertIn('fpdev.git2.status_entries_test.lpr', text)
        self.assertIn('fpdev.git2.status_conflict_test.lpr', text)
        self.assertNotIn('实现状态 API（Status/IsClean/HasUncommittedChanges）', text)

    def test_git2_todo_marks_ignore_and_index_coverage_done(self):
        text = STATUS_TODO.read_text(encoding='utf-8')
        self.assertIn('- [x] .gitignore 场景（IncludeIgnored）', text)
        self.assertIn('- [x] 索引变更（git_index_add_bypath/write）', text)
        self.assertIn('- [x] 冲突标志（可模拟）', text)
        self.assertIn('- [x] 在 docs/history/git2-status-and-tests.md 中补充 fpcunit 工程使用与默认离线说明', text)

    def test_fpcunit_runner_docs_and_batch_capture_required_all_flag(self):
        doc_text = STATUS_DOC.read_text(encoding='utf-8')
        report_text = STATUS_REPORT.read_text(encoding='utf-8')
        batch_text = FPCUNIT_BATCH.read_text(encoding='utf-8')
        needle = 'fpdev.git2.fpcunit.exe --all --format=plain'
        self.assertIn(needle, doc_text)
        self.assertIn(needle, report_text)
        self.assertIn(needle, batch_text)


if __name__ == '__main__':
    unittest.main()
