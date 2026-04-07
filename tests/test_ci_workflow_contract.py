import unittest
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CI_WORKFLOW = REPO_ROOT / '.github' / 'workflows' / 'ci.yml'


class CIWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CI_WORKFLOW.read_text(encoding='utf-8')

    @classmethod
    def _assemble_release_ready_bundle_section(cls):
        return cls.text.split('assemble-release-ready-bundle:', 1)[1]

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
        self.assertIn('record_owner_smoke.ps1', self.text)
        self.assertIn('-Lane ${{ matrix.lane }}', self.text)
        self.assertIn('owner-proof-windows-x64', self.text)

    def test_ci_has_macos_cli_smoke_job(self):
        self.assertIn('macos-15-intel', self.text)
        self.assertIn('macos-15', self.text)
        self.assertIn('brew install fpc', self.text)
        self.assertIn('choco install freepascal', self.text)
        self.assertIn('record_owner_smoke.sh ${{ matrix.lane }} ./bin/fpdev owner-proof', self.text)
        self.assertIn('owner-proof-macos-x64', self.text)
        self.assertIn('owner-proof-macos-arm64', self.text)

    def test_ci_uses_shared_cli_smoke_scripts(self):
        self.assertIn('scripts/cli_smoke.sh', self.text)
        self.assertIn('scripts/cli_smoke.ps1', self.text)
        self.assertIn('scripts/record_owner_smoke.sh', self.text)
        self.assertIn('scripts/record_owner_smoke.ps1', self.text)

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

    def test_ci_uploads_cross_platform_owner_proof_artifacts(self):
        self.assertIn('owner-proof-${{ matrix.lane }}', self.text)
        self.assertIn('owner-proof/', self.text)
        self.assertIn('if: always()', self.text)

    def test_ci_uses_release_grade_cross_platform_build_flags(self):
        self.assertIn('fpc ${{ matrix.build_flags }}', self.text)
        self.assertIn('-B -O3 -CX -XX', self.text)

    def test_ci_exports_windows_fpc_path_after_chocolatey_install(self):
        self.assertRegex(
            self.text,
            re.compile(
                r"- name: Export Windows FPC path\s+"
                r"if: runner\.os == 'Windows'\s+"
                r"shell: pwsh\s+"
                r"run:\s+\|\s+"
                r".*Get-ChildItem 'C:\\tools\\freepascal\\bin' -Recurse -Filter fpc\.exe.*"
                r".*\$env:GITHUB_PATH.*",
                re.S,
            ),
        )

    def test_ci_uses_windows_specific_steps_for_fpc_probe_and_build(self):
        self.assertRegex(
            self.text,
            re.compile(
                r"- name: Show FPC version\s+"
                r"if: runner\.os != 'Windows'\s+"
                r"shell: bash",
                re.S,
            ),
        )
        self.assertRegex(
            self.text,
            re.compile(
                r"- name: Show FPC version on Windows\s+"
                r"if: runner\.os == 'Windows'\s+"
                r"shell: pwsh",
                re.S,
            ),
        )
        self.assertRegex(
            self.text,
            re.compile(
                r"- name: Build CLI smoke binary\s+"
                r"if: runner\.os != 'Windows'\s+"
                r"shell: bash",
                re.S,
            ),
        )
        self.assertRegex(
            self.text,
            re.compile(
                r"- name: Build CLI smoke binary on Windows\s+"
                r"if: runner\.os == 'Windows'\s+"
                r"shell: pwsh",
                re.S,
            ),
        )

    def test_ci_assembles_release_ready_bundle(self):
        section = self._assemble_release_ready_bundle_section()
        self.assertIn('release-ready-bundle', section)
        self.assertIn('scripts/generate_release_checksums.py', section)
        self.assertIn('scripts/generate_release_evidence.py', section)
        self.assertIn('release-acceptance-logs', section)
        self.assertIn('owner-proof-windows-x64', section)
        self.assertIn('owner-proof-macos-x64', section)
        self.assertIn('owner-proof-macos-arm64', section)

    def test_release_ready_bundle_depends_on_all_release_gates(self):
        section = self._assemble_release_ready_bundle_section()
        self.assertIn('- compile-check', section)
        self.assertIn('- release-acceptance-linux', section)
        self.assertIn('- cross-platform-cli-smoke', section)
        header = section.split('steps:', 1)[0]
        self.assertNotIn('if: always()', header)

    def test_release_ready_bundle_uploads_only_after_successful_assembly(self):
        section = self._assemble_release_ready_bundle_section()
        upload_step = section.split('- name: Upload release-ready bundle', 1)[1]
        upload_header = upload_step.split('with:', 1)[0]
        self.assertNotIn('if: always()', upload_header)

    def test_ci_runs_public_doc_contract_suites(self):
        self.assertIn('tests.test_archive_docs_contract', self.text)
        self.assertIn('tests.test_contributor_docs_contract', self.text)
        self.assertIn('tests.test_official_docs_cli_contract', self.text)
        self.assertIn('tests.test_build_manager_callback_contract', self.text)
        self.assertIn('tests.test_lazarus_callback_contract', self.text)
        self.assertIn('tests.test_fusion_status_artifacts_contract', self.text)
        self.assertIn('tests.test_fusion_task_analysis_contract', self.text)
        self.assertIn('tests.test_fusion_code_review_report_contract', self.text)
        self.assertIn('tests.test_fusion_audit_report_contract', self.text)

    def test_ci_runs_release_packaging_contract_suites(self):
        self.assertIn('tests.test_package_release_assets', self.text)
        self.assertIn('tests.test_generate_release_checksums', self.text)
        self.assertIn('tests.test_ci_workflow_contract', self.text)


if __name__ == '__main__':
    unittest.main()
