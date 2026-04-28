import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_MANAGER = REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas'


class FPCManagerMaintenanceBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_maintenanceflow_unit(self):
        self.assertIn('fpdev.fpc.maintenanceflow', self.text)

    def test_uninstall_delegates_to_maintenanceflow(self):
        section = self._section(
            'function TFPCManager.UninstallVersion(const AVersion: string): Boolean;',
            'function TFPCManager.ListVersions(const AShowAll: Boolean): Boolean;',
        )
        self.assertIn('ExecuteManagedFPCUninstallCore(', section)
        self.assertNotIn('DeleteDirRecursive(InstallPath);', section)
        self.assertNotIn("FConfigManager.GetToolchainManager.RemoveToolchain('fpc-' + AVersion);", section)

    def test_update_sources_delegates_to_maintenanceflow(self):
        section = self._section(
            'function TFPCManager.UpdateSources(const AVersion: string): Boolean;',
            'function TFPCManager.CleanSources(const AVersion: string): Boolean;',
        )
        self.assertIn('ExecuteManagedFPCUpdateSourcesCore(', section)
        self.assertNotIn('CreateFPCSourcePlanCore(FInstallRoot, Version);', section)
        self.assertNotIn('ExecuteFPCUpdatePlanCore(', section)

    def test_clean_sources_delegates_to_maintenanceflow(self):
        section = self._section(
            'function TFPCManager.CleanSources(const AVersion: string): Boolean;',
            'function TFPCManager.ShowVersionInfo(const AVersion: string): Boolean;',
        )
        self.assertIn('ExecuteManagedFPCCleanSourcesCore(', section)
        self.assertNotIn('CreateFPCSourcePlanCore(FInstallRoot, Version);', section)
        self.assertNotIn('ExecuteFPCCleanPlanCore(', section)


if __name__ == '__main__':
    unittest.main()
