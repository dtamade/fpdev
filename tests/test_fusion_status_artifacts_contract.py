import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FUSION_PROGRESS = REPO_ROOT / '.fusion' / 'progress.md'
FUSION_FINDINGS = REPO_ROOT / '.fusion' / 'findings.md'
FUSION_AUDIT = REPO_ROOT / '.fusion' / 'test_audit_report.md'
FUSION_TASK_PLAN = REPO_ROOT / '.fusion' / 'task_plan.md'
FUSION_TASK_PLAN_V2 = REPO_ROOT / '.fusion' / 'task_plan_v2.md'


class FusionStatusArtifactsContractTests(unittest.TestCase):
    def test_fusion_status_artifacts_are_removed_from_active_tree(self):
        for path in [
            FUSION_PROGRESS,
            FUSION_FINDINGS,
            FUSION_AUDIT,
            FUSION_TASK_PLAN,
            FUSION_TASK_PLAN_V2,
        ]:
            self.assertFalse(path.exists(), f'{path} should be removed from the active worktree')


if __name__ == '__main__':
    unittest.main()
