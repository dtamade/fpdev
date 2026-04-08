import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TASK_ANALYSIS_PATHS = [
    REPO_ROOT / '.fusion' / 'task_1.2_analysis.md',
    REPO_ROOT / '.fusion' / 'task_2.1_analysis.md',
    REPO_ROOT / '.fusion' / 'task_2.2_analysis.md',
    REPO_ROOT / '.fusion' / 'task_2.3_analysis.md',
]


class FusionTaskAnalysisContractTests(unittest.TestCase):
    def test_task_analysis_reports_are_removed_from_active_tree(self):
        for path in TASK_ANALYSIS_PATHS:
            self.assertFalse(path.exists(), f'{path} should be removed from the active worktree')


if __name__ == '__main__':
    unittest.main()
