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
        self.assertIn('macos-15-intel', self.text)
        self.assertIn('macos-15', self.text)
        self.assertIn('brew install fpc libgit2', self.text)
        self.assertIn('choco install freepascal', self.text)

    def test_ci_uses_shared_cli_smoke_scripts(self):
        self.assertIn('scripts/cli_smoke.sh', self.text)
        self.assertIn('scripts/cli_smoke.ps1', self.text)

    def test_ci_packages_linux_release_asset(self):
        self.assertIn('Package Linux release asset', self.text)
        self.assertIn('release-asset-linux-x64', self.text)
        self.assertIn('release-assets/fpdev-linux-x64.tar.gz', self.text)
        self.assertIn('scripts/package_release_assets.py', self.text)
        self.assertIn('--data-dir src/data', self.text)

    def test_ci_uploads_cross_platform_release_assets(self):
        self.assertIn('release-asset-windows-x64', self.text)
        self.assertIn('release-asset-macos-x64', self.text)
        self.assertIn('release-asset-macos-arm64', self.text)
        self.assertIn('fpdev-windows-x64.zip', self.text)
        self.assertIn('fpdev-macos-x64.tar.gz', self.text)
        self.assertIn('fpdev-macos-arm64.tar.gz', self.text)

    def test_ci_uses_release_grade_cross_platform_build_flags(self):
        self.assertIn('fpc ${{ matrix.build_flags }}', self.text)
        self.assertIn('-B -O3 -CX -XX', self.text)
        self.assertIn('-Twin64 -Px86_64', self.text)

    def test_ci_runs_public_doc_contract_suites(self):
        self.assertIn('tests.test_contributor_docs_contract', self.text)
        self.assertIn('tests.test_official_docs_cli_contract', self.text)

    def test_ci_does_not_require_private_fusion_contract_suites(self):
        self.assertNotIn('tests.test_fusion_status_artifacts_contract', self.text)
        self.assertNotIn('tests.test_fusion_task_analysis_contract', self.text)
        self.assertNotIn('tests.test_fusion_code_review_report_contract', self.text)
        self.assertNotIn('tests.test_fusion_audit_report_contract', self.text)

    def test_ci_bootstraps_windows_fpc_path(self):
        self.assertIn('Add FPC to PATH on Windows', self.text)
        self.assertIn('ppcx64.exe', self.text)
        self.assertIn('$env:GITHUB_PATH', self.text)
        self.assertIn('Unable to locate fpc.exe after Chocolatey installation.', self.text)
        self.assertIn('Unable to locate ppcx64.exe after Chocolatey installation.', self.text)
        self.assertIn('where.exe ppcx64', self.text)

    def test_ci_installs_libgit2_for_linked_builds(self):
        self.assertIn('sudo apt-get install -y fpc lazarus libgit2-dev', self.text)
        self.assertIn('brew install fpc libgit2', self.text)

    def test_ci_compile_check_uses_pipefail(self):
        self.assertIn('set -o pipefail', self.text)

    def test_ci_resolves_macos_libgit2_linker_flags(self):
        self.assertIn('Resolve libgit2 linker path on macOS', self.text)
        self.assertIn('brew --prefix libgit2', self.text)
        self.assertIn('LIBGIT2_LIB_DIR', self.text)
        self.assertIn('-k-lgit2', self.text)

    def test_ci_runs_release_packaging_contract_suites(self):
        self.assertIn('tests.test_package_release_assets', self.text)
        self.assertIn('tests.test_generate_release_checksums', self.text)
        self.assertIn('tests.test_ci_workflow_contract', self.text)


if __name__ == '__main__':
    unittest.main()
