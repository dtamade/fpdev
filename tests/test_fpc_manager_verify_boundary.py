import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class FPCManagerVerifyBoundaryTests(unittest.TestCase):
    def test_manager_uses_shared_verifyflow_unit(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.verifyflow', source)

    def test_manager_refresh_delegates_to_shared_flow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas').read_text(encoding='utf-8')
        self.assertIn('function TFPCManager.RefreshInstallVerificationMetadata', source)
        section = source.split('function TFPCManager.RefreshInstallVerificationMetadata', 1)[1]
        section = section.split('procedure TFPCManager.ConfigureInstaller', 1)[0]
        self.assertIn('ExecuteManagedFPCRefreshVerificationMetadataCore(', section)
        self.assertNotIn('Verifier := TFPCVerifier.Create', section)

    def test_manager_verifyinstallation_delegates_to_shared_surface_helper(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas').read_text(encoding='utf-8')
        self.assertIn('function TFPCManager.VerifyInstallation', source)
        section = source.split('function TFPCManager.VerifyInstallation', 1)[1]
        section = section.split('function TFPCManager.GetVersionInstallPath', 1)[0]
        self.assertIn('ExecuteManagedFPCVerificationSurfaceCore(', section)
        self.assertNotIn('PersistManagedFPCVerificationResultCore(', section)


if __name__ == '__main__':
    unittest.main()
