import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_MANAGER = REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas'


class FPCManagerResidualBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_residualflow_unit(self):
        self.assertIn('fpdev.fpc.residualflow', self.text)

    def test_setup_environment_delegates_to_residualflow(self):
        section = self._section(
            'function TFPCManager.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;',
            'function TFPCManager.AddToolchainToConfig(const AName: string; const AInfo: TToolchainInfo): Boolean;',
        )
        self.assertIn('ExecuteManagedFPCSetupEnvironmentCore(', section)
        self.assertNotIn('EnsureManagedFPCInstallLayout(', section)
        self.assertNotIn('ExecuteFPCEnvironmentRegistrationFlow(', section)

    def test_install_metadata_delegates_to_residualflow(self):
        section = self._section(
            'function TFPCManager.WriteInstallMetadata(const AVersion, AInstallPath: string;',
            'function TFPCManager.UpdateVerificationMetadata(const AVersion, AInstallPath: string;',
        )
        self.assertIn('ExecuteManagedFPCWriteInstallMetadataCore(', section)
        self.assertNotIn('BuildFPCInstallMetadataCore(', section)
        self.assertNotIn('WriteFPCMetadata(', section)

    def test_verification_metadata_delegates_to_residualflow(self):
        update_section = self._section(
            'function TFPCManager.UpdateVerificationMetadata(const AVersion, AInstallPath: string;',
            'function TFPCManager.RefreshInstallVerificationMetadata(const AVersion,',
        )
        refresh_section = self._section(
            'function TFPCManager.RefreshInstallVerificationMetadata(const AVersion,',
            'procedure TFPCManager.ConfigureInstaller(ANoCache, AOfflineMode: Boolean);',
        )

        self.assertIn('ExecuteManagedFPCUpdateVerificationMetadataCore(', update_section)
        self.assertNotIn('ApplyFPCVerificationMetadataCore(', update_section)
        self.assertIn('ExecuteManagedFPCRefreshVerificationMetadataCore(', refresh_section)
        self.assertNotIn('RefreshInstalledFPCVerificationCore(', refresh_section)


if __name__ == '__main__':
    unittest.main()
