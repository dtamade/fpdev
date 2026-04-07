import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_README = REPO_ROOT / 'docs' / 'archive' / 'README.md'
ARCH_REFACTOR_DOC = REPO_ROOT / 'docs' / 'archive' / 'FPDEV_ARCH_REFACTOR.md'
FINAL_SUMMARY_DOC = REPO_ROOT / 'docs' / 'archive' / 'FINAL_SUMMARY.md'
INTEGRATION_COMPLETE_DOC = REPO_ROOT / 'docs' / 'archive' / 'FPDEV_INTEGRATION_COMPLETE.md'


class ArchiveDocsContractTests(unittest.TestCase):
    def test_archive_readme_explains_paths_are_historical_snapshots(self):
        text = ARCHIVE_README.read_text(encoding='utf-8')
        self.assertIn('历史记录', text)
        self.assertIn('文件路径、脚本名和测试名', text)
        self.assertIn('可能已经移动或删除', text)

    def test_archive_refactor_doc_is_removed_from_active_tree(self):
        self.assertFalse(ARCH_REFACTOR_DOC.exists(), f'{ARCH_REFACTOR_DOC} should be removed from the active worktree')

    def test_archive_final_summary_is_removed_from_active_tree(self):
        self.assertFalse(FINAL_SUMMARY_DOC.exists(), f'{FINAL_SUMMARY_DOC} should be removed from the active worktree')

    def test_archive_integration_complete_is_removed_from_active_tree(self):
        self.assertFalse(INTEGRATION_COMPLETE_DOC.exists(), f'{INTEGRATION_COMPLETE_DOC} should be removed from the active worktree')


if __name__ == '__main__':
    unittest.main()
