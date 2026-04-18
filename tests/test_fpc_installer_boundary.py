import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class FPCInstallerBoundaryTests(unittest.TestCase):
    def test_binary_installer_does_not_own_cli_fallback_or_exit_code_logic(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.installer.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteFPCBinaryPostInstall', source)
        self.assertNotIn('Attempting binary installation first...', source)
        self.assertNotIn('Binary installation failed, falling back to source installation...', source)
        self.assertNotIn('Both binary and source installation failed', source)
        self.assertNotIn('EXIT_', source)
        self.assertNotIn('TryStringToInstallMode', source)

    def test_installer_imports_lifecycleflow_unit(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.installer.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.installer.lifecycleflow', source)

    def test_install_version_delegates_to_lifecycleflow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.installer.pas').read_text(encoding='utf-8')
        section = source.split('function TFPCInstaller.InstallVersion(', 1)[1]
        section = section.split('function TFPCInstaller.UninstallVersion(', 1)[0]

        self.assertIn('ExecuteFPCInstallerInstallCore(', section)
        self.assertNotIn('FVersionManager.ValidateVersion(AVersion)', section)
        self.assertNotIn('FFileSystem.DirectoryExists(InstallDir)', section)
        self.assertNotIn('FBuilder.DownloadSource(AVersion, SourceDir)', section)
        self.assertNotIn('FBuilder.BuildFromSource(SourceDir, InstallDir)', section)

    def test_uninstall_version_delegates_to_lifecycleflow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.installer.pas').read_text(encoding='utf-8')
        section = source.split('function TFPCInstaller.UninstallVersion(', 1)[1]
        section = section.split('function TFPCInstaller.GetBinaryDownloadURL(', 1)[0]

        self.assertIn('ExecuteFPCInstallerUninstallCore(', section)
        self.assertNotIn("FProcessRunner.Execute('rm', ['-rf', InstallDir], '')", section)
        self.assertNotIn("Result := OperationError(ecUninstallationFailed, 'Failed to remove directory: ' + InstallDir);", section)


if __name__ == '__main__':
    unittest.main()
