import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CI_WORKFLOW = REPO_ROOT / '.github' / 'workflows' / 'ci.yml'


class CIReleaseContractsTests(unittest.TestCase):
    def test_ci_workflow_runs_release_contract_unit_tests(self):
        text = CI_WORKFLOW.read_text(encoding='utf-8')
        self.assertIn('tests.test_build_manager_callback_contract', text)
        self.assertIn('tests.test_lazarus_callback_contract', text)
        self.assertIn('tests.test_release_docs_contract', text)
        self.assertIn('tests.test_release_scripts_contract', text)
        self.assertIn('tests.test_package_release_assets', text)
        self.assertIn('tests.test_generate_release_checksums', text)
        self.assertIn('tests.test_generate_release_evidence', text)
        self.assertIn('tests.test_record_owner_smoke_sh', text)
        self.assertIn('tests.test_release_status_wording', text)
        self.assertIn('tests.test_ci_workflow_contract', text)
        self.assertIn('tests.test_ci_release_contracts', text)


if __name__ == '__main__':
    unittest.main()
