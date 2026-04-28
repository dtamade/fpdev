import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class FPCInstallCLIBoundaryTests(unittest.TestCase):
    def test_cli_install_no_longer_owns_cache_restore_orchestration(self):
        source = (REPO_ROOT / 'src' / 'fpdev.cmd.fpc.install.pas').read_text(encoding='utf-8')
        self.assertNotIn('TBuildCache.Create', source)
        self.assertNotIn('RestoreArtifacts(', source)
        self.assertNotIn('SetupEnvironment(', source)
        self.assertNotIn('VerifyInstallation(', source)

    def test_cli_install_delegates_parse_and_runtime_to_commandflow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.cmd.fpc.install.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.installcommandflow', source)
        self.assertIn('PrepareFPCInstallCommandPlanCore(', source)
        self.assertIn('ExecuteFPCInstallCommandPlanCore(', source)

    def test_cli_install_no_longer_inlines_parse_or_auto_fallback_strings(self):
        source = (REPO_ROOT / 'src' / 'fpdev.cmd.fpc.install.pas').read_text(encoding='utf-8')
        self.assertNotIn('TryStringToInstallMode(', source)
        self.assertNotIn('FindUnknownOption(', source)
        self.assertNotIn('Attempting binary installation first...', source)
        self.assertNotIn('Binary installation failed, falling back to source installation...', source)
        self.assertNotIn('Both binary and source installation failed', source)


if __name__ == '__main__':
    unittest.main()
