import unittest
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

    @classmethod
    def _cross_platform_cli_smoke_section(cls):
        return cls.text.split('cross-platform-cli-smoke:', 1)[1].split('assemble-release-ready-bundle:', 1)[0]

    @classmethod
    def _smoke_step_block(cls, name: str) -> str:
        marker = f'- name: {name}'
        after = cls._cross_platform_cli_smoke_section().split(marker, 1)[1]
        return marker + after.split('\n    - name:', 1)[0]

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
        self.assertIn("if: always() && runner.os != 'Windows' && hashFiles('bin/fpdev') != ''", self.text)
        self.assertIn("if: always() && runner.os == 'Windows' && hashFiles('bin/fpdev.exe') != ''", self.text)
        self.assertIn("if: always() && hashFiles('owner-proof/**') != ''", self.text)

    def test_ci_uses_release_grade_cross_platform_build_flags(self):
        self.assertIn('fpc ${{ matrix.build_flags }}', self.text)
        self.assertIn('-B -O3 -CX -XX', self.text)

    def test_ci_uses_manual_cross_platform_smoke_checkout(self):
        section = self._smoke_step_block('Checkout repository')
        self.assertIn('shell: bash', section)
        self.assertIn('git init .', section)
        self.assertIn('git remote add origin "https://github.com/${GITHUB_REPOSITORY}.git"', section)
        self.assertIn('git -c protocol.version=2 fetch --no-tags --depth=1 origin "$GITHUB_REF"', section)
        self.assertIn('git checkout --force FETCH_HEAD', section)

    def test_ci_exports_windows_fpc_path_after_chocolatey_install(self):
        section = self._smoke_step_block('Export Windows x64 FPC path')
        self.assertIn("if: runner.os == 'Windows'", section)
        self.assertIn('shell: pwsh', section)
        self.assertIn("Get-ChildItem 'C:\\tools\\freepascal\\bin' -Recurse -Filter fpc.exe", section)
        self.assertIn('x86_64-win64', section)
        self.assertIn('$env:GITHUB_ENV', section)
        self.assertIn('FPC_EXE=$($FpcExe.FullName)', section)
        self.assertIn('$env:GITHUB_PATH', section)

    def test_ci_uses_windows_specific_steps_for_fpc_probe_and_build(self):
        show_unix = self._smoke_step_block('Show FPC version')
        show_windows = self._smoke_step_block('Show FPC version on Windows')
        build_unix = self._smoke_step_block('Build CLI smoke binary')
        build_windows = self._smoke_step_block('Build CLI smoke binary on Windows')

        self.assertIn("if: runner.os != 'Windows'", show_unix)
        self.assertIn('shell: bash', show_unix)

        self.assertIn("if: runner.os == 'Windows'", show_windows)
        self.assertIn('shell: pwsh', show_windows)
        self.assertIn('$env:FPC_EXE -iV', show_windows)

        self.assertIn("if: runner.os != 'Windows'", build_unix)
        self.assertIn('shell: bash', build_unix)

        self.assertIn("if: runner.os == 'Windows'", build_windows)
        self.assertIn('shell: pwsh', build_windows)
        self.assertIn('$env:FPC_EXE ${{ matrix.build_flags }}', build_windows)

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
