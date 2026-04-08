import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CODE_REVIEW_REPORT = REPO_ROOT / '.fusion' / 'code_review_report.md'


class FusionCodeReviewReportContractTests(unittest.TestCase):
    def test_code_review_report_is_removed_from_active_tree(self):
        self.assertFalse(CODE_REVIEW_REPORT.exists(), f'{CODE_REVIEW_REPORT} should be removed from the active worktree')


if __name__ == '__main__':
    unittest.main()
