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


if __name__ == '__main__':
    unittest.main()
