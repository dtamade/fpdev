import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CI_WORKFLOW = REPO_ROOT / '.github' / 'workflows' / 'ci.yml'


class CIWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CI_WORKFLOW.read_text(encoding='utf-8')

    def test_ci_runs_linux_release_acceptance_lane(self):
        self.assertIn(
            'bash scripts/release_acceptance_linux.sh',
            self.text,
        )

    def test_ci_runs_repository_quality_analyzer(self):
        self.assertIn(
            'python3 scripts/analyze_code_quality.py .',
            self.text,
        )

    def test_ci_uploads_release_acceptance_logs(self):
        self.assertIn(
            'logs/release_acceptance/',
            self.text,
        )

    def test_ci_has_windows_cli_smoke_job(self):
        self.assertIn('windows-latest', self.text)
        self.assertIn('Cross-platform CLI smoke', self.text)
        self.assertIn('cli_smoke.ps1', self.text)
        self.assertIn('ExecutablePath', self.text)

    def test_ci_has_macos_cli_smoke_job(self):
        self.assertIn('macos-', self.text)
        self.assertIn('brew install --cask fpc-laz', self.text)
        self.assertIn('choco install freepascal', self.text)

    def test_ci_uses_shared_cli_smoke_scripts(self):
        self.assertIn('scripts/cli_smoke.sh', self.text)
        self.assertIn('scripts/cli_smoke.ps1', self.text)


if __name__ == '__main__':
    unittest.main()
