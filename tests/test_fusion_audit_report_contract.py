import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
AUDIT_REPORT = REPO_ROOT / '.fusion' / 'test_audit_report.md'


class FusionAuditReportContractTests(unittest.TestCase):
    def test_audit_report_is_removed_from_active_tree(self):
        self.assertFalse(AUDIT_REPORT.exists(), f'{AUDIT_REPORT} should be removed from the active worktree')


if __name__ == '__main__':
    unittest.main()
