import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CLI_SMOKE_SH = REPO_ROOT / 'scripts' / 'cli_smoke.sh'
CLI_SMOKE_PS1 = REPO_ROOT / 'scripts' / 'cli_smoke.ps1'
OWNER_SMOKE_SH = REPO_ROOT / 'scripts' / 'record_owner_smoke.sh'
OWNER_SMOKE_PS1 = REPO_ROOT / 'scripts' / 'record_owner_smoke.ps1'
CHECKSUM_SCRIPT = REPO_ROOT / 'scripts' / 'generate_release_checksums.py'
PACKAGE_SCRIPT = REPO_ROOT / 'scripts' / 'package_release_assets.py'
EVIDENCE_SCRIPT = REPO_ROOT / 'scripts' / 'generate_release_evidence.py'
ASSEMBLE_BUNDLE_SCRIPT = REPO_ROOT / 'scripts' / 'assemble_release_ready_bundle.sh'
RELEASE_ACCEPTANCE_SCRIPT = REPO_ROOT / 'scripts' / 'release_acceptance_linux.sh'
BUILD_RELEASE_SCRIPT = REPO_ROOT / 'scripts' / 'build_release.sh'
CHECK_TOOLCHAIN_SCRIPT = REPO_ROOT / 'scripts' / 'check_toolchain.sh'
CHECK_TOOLCHAIN_BAT = REPO_ROOT / 'scripts' / 'check_toolchain.bat'


class ReleaseScriptsContractTests(unittest.TestCase):
    def test_posix_cli_smoke_script_exists_and_runs_core_commands(self):
        self.assertTrue(CLI_SMOKE_SH.exists(), f'Missing {CLI_SMOKE_SH}')
        text = CLI_SMOKE_SH.read_text(encoding='utf-8')
        self.assertIn('system version', text)
        self.assertIn('system help', text)
        self.assertIn('fpc --help', text)
        self.assertIn('fpc list --all', text)

    def test_powershell_cli_smoke_script_exists_and_runs_core_commands(self):
        self.assertTrue(CLI_SMOKE_PS1.exists(), f'Missing {CLI_SMOKE_PS1}')
        text = CLI_SMOKE_PS1.read_text(encoding='utf-8')
        self.assertIn('system version', text)
        self.assertIn('system help', text)
        self.assertIn("'fpc', '--help'", text)
        self.assertIn("'fpc', 'list', '--all'", text)

    def test_posix_owner_smoke_recorder_exists_and_targets_standard_transcript_names(self):
        self.assertTrue(OWNER_SMOKE_SH.exists(), f'Missing {OWNER_SMOKE_SH}')
        text = OWNER_SMOKE_SH.read_text(encoding='utf-8')
        self.assertIn('cli_smoke.sh', text)
        self.assertIn('owner-smoke.txt', text)
        self.assertIn('macos-x64', text)
        self.assertIn('macos-arm64', text)

    def test_powershell_owner_smoke_recorder_exists_and_targets_standard_transcript_names(self):
        self.assertTrue(OWNER_SMOKE_PS1.exists(), f'Missing {OWNER_SMOKE_PS1}')
        text = OWNER_SMOKE_PS1.read_text(encoding='utf-8')
        self.assertIn('cli_smoke.ps1', text)
        self.assertIn('owner-smoke.txt', text)
        self.assertIn('windows-x64', text)
        self.assertIn('OutputDir', text)

    def test_release_checksum_script_exists_and_targets_sha256sums(self):
        self.assertTrue(CHECKSUM_SCRIPT.exists(), f'Missing {CHECKSUM_SCRIPT}')
        text = CHECKSUM_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('SHA256SUMS.txt', text)
        self.assertIn('fpdev-linux-x64.tar.gz', text)
        self.assertIn('fpdev-windows-x64.zip', text)

    def test_release_packaging_script_exists_and_targets_planned_assets(self):
        self.assertTrue(PACKAGE_SCRIPT.exists(), f'Missing {PACKAGE_SCRIPT}')
        text = PACKAGE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('fpdev-linux-x64.tar.gz', text)
        self.assertIn('fpdev-windows-x64.zip', text)
        self.assertIn('fpdev-macos-x64.tar.gz', text)
        self.assertIn('fpdev-macos-arm64.tar.gz', text)

    def test_release_evidence_script_exists_and_targets_ledger_content(self):
        self.assertTrue(EVIDENCE_SCRIPT.exists(), f'Missing {EVIDENCE_SCRIPT}')
        text = EVIDENCE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('Linux automated acceptance', text)
        self.assertIn('SHA256SUMS.txt', text)
        self.assertIn('Windows x64 asset smoke', text)
        self.assertIn('windows-x64-owner-smoke.txt', text)

    def test_release_bundle_assembly_script_exists_and_uses_shared_packaging_tools(self):
        self.assertTrue(ASSEMBLE_BUNDLE_SCRIPT.exists(), f'Missing {ASSEMBLE_BUNDLE_SCRIPT}')
        text = ASSEMBLE_BUNDLE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('release-ready-bundle', text)
        self.assertIn('release-asset-linux-x64', text)
        self.assertIn('release-asset-windows-x64', text)
        self.assertIn('release-asset-macos-x64', text)
        self.assertIn('release-asset-macos-arm64', text)
        self.assertIn('scripts/generate_release_checksums.py', text)
        self.assertIn('scripts/generate_release_evidence.py', text)
        self.assertIn("grep -q '^with_install: 0$' \"$path\"", text)

    def test_release_build_script_exists_and_supports_explicit_lazarus_dir_override(self):
        self.assertTrue(BUILD_RELEASE_SCRIPT.exists(), f'Missing {BUILD_RELEASE_SCRIPT}')
        text = BUILD_RELEASE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('FPDEV_LAZARUSDIR', text)
        self.assertIn('--lazarusdir=', text)
        self.assertIn('--build-mode=Release', text)
        self.assertIn('fpdev.lpi', text)

    def test_release_build_script_reports_actual_release_binary_path_when_requested(self):
        text = BUILD_RELEASE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('FPDEV_RELEASE_BIN_PATH_FILE', text)
        self.assertIn('FPDEV_RELEASE_BUILD_ROOT', text)

    def test_toolchain_check_script_validates_lazarus_root_for_release_builds(self):
        self.assertTrue(CHECK_TOOLCHAIN_SCRIPT.exists(), f'Missing {CHECK_TOOLCHAIN_SCRIPT}')
        text = CHECK_TOOLCHAIN_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('FPDEV_LAZARUSDIR', text)
        self.assertIn('lcl', text)
        self.assertIn('lazarus_root', text)

    def test_toolchain_check_batch_script_validates_lazarus_root_for_release_builds(self):
        self.assertTrue(CHECK_TOOLCHAIN_BAT.exists(), f'Missing {CHECK_TOOLCHAIN_BAT}')
        text = CHECK_TOOLCHAIN_BAT.read_text(encoding='utf-8')
        self.assertIn('FPDEV_LAZARUSDIR', text)
        self.assertIn('lcl', text)
        self.assertIn('lazarus_root', text)

    def test_linux_release_acceptance_script_includes_iobridge_stability_gate(self):
        self.assertTrue(RELEASE_ACCEPTANCE_SCRIPT.exists(), f'Missing {RELEASE_ACCEPTANCE_SCRIPT}')
        text = RELEASE_ACCEPTANCE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('iobridge_stability', text)
        self.assertIn('run_repeated_focused_test iobridge_stability 5 tests/test_fpc_installer_iobridge.lpr', text)
        self.assertIn('scripts/run_single_test.sh', text)
        self.assertIn('FPDEV_TEST_LOG_ROOT', text)
        self.assertIn('pascal_regression_logs', text)

    def test_linux_release_acceptance_uses_shared_release_build_entrypoint(self):
        text = RELEASE_ACCEPTANCE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('bash scripts/build_release.sh', text)
        self.assertNotIn('lazbuild -B --build-mode=Release fpdev.lpi', text)

    def test_linux_release_acceptance_consumes_reported_release_binary_path(self):
        text = RELEASE_ACCEPTANCE_SCRIPT.read_text(encoding='utf-8')
        self.assertIn('FPDEV_RELEASE_BIN_PATH_FILE', text)
        self.assertIn('RELEASE_BIN=', text)
        self.assertIn('"${RELEASE_BIN}" system help', text)
        self.assertNotIn('run_cli_smoke system_help 0 ./bin/fpdev system help', text)


if __name__ == '__main__':
    unittest.main()
