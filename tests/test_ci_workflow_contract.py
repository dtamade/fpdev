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
        self.assertIn('fpc-3.2.2.i386-win32.cross.x86_64-win64.exe', self.text)
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

    def test_ci_installs_win32_and_win64_cross_windows_fpc_toolchain(self):
        section = self._smoke_step_block('Install FPC toolchain on Windows')
        self.assertIn("if: runner.os == 'Windows'", section)
        self.assertIn('shell: pwsh', section)
        self.assertIn("$InstallationPath = 'C:\\tools\\freepascal'", section)
        self.assertIn("$InstallerSpecs = @(", section)
        self.assertIn('https://downloads.sourceforge.net/project/freepascal/Win32/3.2.2/fpc-3.2.2.i386-win32.exe', section)
        self.assertIn('https://downloads.sourceforge.net/project/freepascal/Win32/3.2.2/fpc-3.2.2.i386-win32.cross.x86_64-win64.exe', section)
        self.assertIn("Arguments = \"/verysilent /norestart /DIR=`\"$InstallationPath`\"\"", section)
        self.assertIn('foreach ($Installer in $InstallerSpecs)', section)
        self.assertIn('curl.exe -L --fail --retry 3 --output $InstallerPath $Installer.Url', section)
        self.assertIn('/verysilent /norestart /LoadInf=', section)

    def test_ci_installs_and_stages_windows_libgit2_runtime(self):
        install_section = self._smoke_step_block('Install libgit2 runtime on Windows')
        self.assertIn("if: runner.os == 'Windows'", install_section)
        self.assertIn('shell: pwsh', install_section)
        self.assertIn('choco install libgit2 --no-progress -y', install_section)

        stage_section = self._smoke_step_block('Stage Windows libgit2 runtime')
        self.assertIn("if: runner.os == 'Windows'", stage_section)
        self.assertIn('shell: pwsh', stage_section)
        self.assertIn('Get-ChildItem $env:ChocolateyInstall -Recurse -File -Filter libgit2.dll', stage_section)
        self.assertIn('Get-ChildItem $LibGit2Dll.DirectoryName -File -Filter *.dll', stage_section)
        self.assertIn("Copy-Item $LibGit2Dll.FullName (Join-Path $BinDir 'git2.dll') -Force", stage_section)
        self.assertIn('libgit2.dll not found under $env:ChocolateyInstall', stage_section)

    def test_ci_exports_windows_fpc_path_from_win32_cross_layout(self):
        section = self._smoke_step_block('Export Windows x64 FPC path')
        self.assertIn("if: runner.os == 'Windows'", section)
        self.assertIn('shell: pwsh', section)
        self.assertIn("$InstallationPath = 'C:\\tools\\freepascal'", section)
        self.assertIn('Get-ChildItem $InstallationPath -Recurse -Filter fpc.exe', section)
        self.assertIn('i386-win32', section)
        self.assertIn('ppcx64.exe,ppcrossx64.exe', section)
        self.assertIn('fpjson.ppu', section)
        self.assertIn('x86_64-win64', section)
        self.assertIn('Select-Object -First 1', section)
        self.assertIn('$env:GITHUB_ENV', section)
        self.assertIn('FPC_EXE=$($FpcExe.FullName)', section)
        self.assertIn("Join-Path $FpcExe.DirectoryName 'fpcmkcfg.exe'", section)
        self.assertIn("Join-Path $FpcExe.DirectoryName 'fpc.cfg'", section)
        self.assertIn('& $FpcMkCfg -d "basepath=$InstallationPath" -o $FpcCfg', section)
        self.assertIn('FPC_CFG_PATH=$FpcCfg', section)
        self.assertIn('$env:GITHUB_PATH', section)
        self.assertIn('win64 fpjson unit not found', section)
        self.assertIn('FPC_TARGET=win64', section)

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
        self.assertIn("$TargetFlags = @()", build_windows)
        self.assertIn("$ConfigFlags = @('-n', \"@$($env:FPC_CFG_PATH)\")", build_windows)
        self.assertIn("$env:FPC_TARGET -eq 'win64'", build_windows)
        self.assertIn("@('-Px86_64', '-Twin64')", build_windows)
        self.assertIn('& $env:FPC_EXE @ConfigFlags @TargetFlags ${{ matrix.build_flags }}', build_windows)

    def test_ci_assembles_release_ready_bundle(self):
        section = self._assemble_release_ready_bundle_section()
        self.assertIn('release-ready-bundle', section)
        self.assertIn('bash scripts/assemble_release_ready_bundle.sh', section)
        self.assertIn('release-acceptance-logs', section)
        self.assertIn('owner-proof-windows-x64', section)
        self.assertIn('owner-proof-macos-x64', section)
        self.assertIn('owner-proof-macos-arm64', section)
        self.assertNotIn('cp bundle/downloads/release-asset-linux-x64/fpdev-linux-x64.tar.gz', section)

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

    def test_release_ready_bundle_discovers_summary_paths_without_escaped_quotes(self):
        section = self._assemble_release_ready_bundle_section()
        self.assertIn('scripts/assemble_release_ready_bundle.sh', section)
        self.assertNotIn('\\"$path\\"', section)

    def test_release_ready_bundle_tolerates_missing_optional_install_summary(self):
        section = self._assemble_release_ready_bundle_section()
        self.assertIn('scripts/assemble_release_ready_bundle.sh', section)

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
