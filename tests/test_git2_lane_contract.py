import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LEGACY_TEST = REPO_ROOT / 'tests' / 'fpdev.git2' / 'fpdev.git2.test.lpr'
LEGACY_TESTCASE = REPO_ROOT / 'tests' / 'fpdev.git2' / 'fpdev.git2.testcase.pas'
LEGACY_FPCUNIT = REPO_ROOT / 'tests' / 'fpdev.git2' / 'fpdev.git2.fpcunit.tests.pas'
MODERN_RUNNER = REPO_ROOT / 'tests' / 'fpdev.git2.modern' / 'fpdev.git2.modern.basic.lpr'
MODERN_SCRIPT = REPO_ROOT / 'tests' / 'fpdev.git2.modern' / 'run_tests.sh'
STATUS_DOC = REPO_ROOT / 'docs' / 'history' / 'git2-status-and-tests.md'
STATUS_REPORT = REPO_ROOT / 'report' / 'fpdev.git2.md'


class Git2LaneContractTests(unittest.TestCase):
    def test_legacy_focused_runners_are_explicitly_marked(self):
        expectations = {
            LEGACY_TEST: 'Legacy Git2 lane',
            LEGACY_TESTCASE: 'Legacy Git2 lane',
            LEGACY_FPCUNIT: 'Legacy Git2 lane',
        }
        for path, marker in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn(marker, text, f'{path} should declare itself as legacy coverage')
            self.assertIn('fpdev.git2', text, f'{path} should remain on the legacy wrapper surface')

    def test_modern_focused_runner_exists_and_avoids_legacy_wrapper(self):
        self.assertTrue(MODERN_RUNNER.exists(), f'Missing {MODERN_RUNNER}')
        self.assertTrue(MODERN_SCRIPT.exists(), f'Missing {MODERN_SCRIPT}')
        text = MODERN_RUNNER.read_text(encoding='utf-8')
        self.assertIn('Modern Git2 lane', text)
        self.assertIn('git2.api', text)
        self.assertIn('git2.impl', text)
        self.assertIn('NewGitManager', text)
        self.assertNotIn('fpdev.git2', text)

    def test_docs_and_report_split_legacy_and_modern_lanes(self):
        doc_text = STATUS_DOC.read_text(encoding='utf-8')
        report_text = STATUS_REPORT.read_text(encoding='utf-8')
        for text in [doc_text, report_text]:
            self.assertIn('`tests/fpdev.git2/`（legacy concrete-wrapper lane）', text)
            self.assertIn('`tests/fpdev.git2.modern/`（modern interface lane）', text)
            self.assertIn('fpdev.git2.modern.basic.lpr', text)


if __name__ == '__main__':
    unittest.main()
