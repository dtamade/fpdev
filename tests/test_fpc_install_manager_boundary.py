import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class FPCInstallManagerBoundaryTests(unittest.TestCase):
    def test_manager_install_does_not_own_cli_fallback_or_exit_code_logic(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas').read_text(encoding='utf-8')
        self.assertIn('RefreshInstallVerificationMetadata', source)
        self.assertNotIn('Attempting binary installation first...', source)
        self.assertNotIn('Binary installation failed, falling back to source installation...', source)
        self.assertNotIn('Both binary and source installation failed', source)
        self.assertNotIn('EXIT_', source)
        self.assertNotIn('TryStringToInstallMode', source)

    def test_manager_install_delegates_to_installsurfaceflow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.installsurfaceflow', source)

        section = source.split('function TFPCManager.InstallVersion(', 1)[1]
        section = section.split('function TFPCManager.UninstallVersion(', 1)[0]

        self.assertIn('ExecuteManagedFPCInstallSurfaceCore(', section)
        self.assertNotIn('(not AOfflineMode) and (not ValidateVersion(AVersion))', section)
        self.assertNotIn('FInstallerMgr.SetNoCache(ANoCache);', section)
        self.assertNotIn('FInstallerMgr.SetOfflineMode(AOfflineMode);', section)
        self.assertNotIn('ExecuteFPCInstallVersionCore(', section)


if __name__ == '__main__':
    unittest.main()
