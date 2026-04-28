import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'


class LazarusManagerRuntimeBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_MANAGER.read_text(encoding='utf-8')
        uninstall_start = cls.text.index('function TLazarusManager.UninstallVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;')
        list_start = cls.text.index('function TLazarusManager.ListVersions(const AShowAll: Boolean): Boolean;')
        update_start = cls.text.index('function TLazarusManager.UpdateSources(')
        create_git_start = cls.text.index('function TLazarusManager.CreateGitClient(')
        clean_start = cls.text.index('function TLazarusManager.CleanSources(const AVersion: string): Boolean;')
        show_start = cls.text.index('function TLazarusManager.ShowVersionInfo(const AVersion: string): Boolean;')
        cls.uninstall_body = cls.text[uninstall_start:list_start]
        cls.update_body = cls.text[update_start:create_git_start]
        cls.clean_body = cls.text[clean_start:show_start]

    def test_manager_imports_runtimeactions_and_maintenanceflow_units(self):
        self.assertIn('fpdev.lazarus.runtimeactions', self.text)
        self.assertIn('fpdev.lazarus.maintenanceflow', self.text)

    def test_manager_delegates_runtime_and_ide_actions(self):
        self.assertIn('TestLazarusInstallationCore(', self.text)
        self.assertIn('LaunchLazarusIDECore(', self.text)
        self.assertIn('ConfigureLazarusIDECore(', self.text)
        self.assertNotIn("TProcessExecutor.Execute(LazarusExe, ['--version'], '');", self.text)
        self.assertNotIn('CreateLazarusLaunchPlanCore(', self.text)
        self.assertNotIn('CreateLazarusConfigurePlanCore(', self.text)
        self.assertNotIn('ApplyLazarusConfigurePlanCore(', self.text)

    def test_manager_delegates_uninstall_surface_to_maintenanceflow(self):
        self.assertIn('ExecuteManagedLazarusUninstallCore(', self.uninstall_body)
        self.assertNotIn('DeleteDirRecursive(InstallPath);', self.uninstall_body)
        self.assertNotIn("RemoveLazarusVersion('lazarus-' + AVersion)", self.uninstall_body)

    def test_manager_delegates_update_sources_surface_to_maintenanceflow(self):
        self.assertIn('ExecuteManagedLazarusUpdateSourcesCore(', self.update_body)
        self.assertNotIn('CreateLazarusSourcePlanCore(', self.update_body)
        self.assertNotIn('IsValidSourceDirectory(SourcePlan.SourceDir)', self.update_body)
        self.assertNotIn('ExecuteLazarusUpdatePlanCore(SourcePlan, Outp, Errp, Git)', self.update_body)

    def test_manager_delegates_clean_sources_surface_to_maintenanceflow(self):
        self.assertIn('ExecuteManagedLazarusCleanSourcesCore(', self.clean_body)
        self.assertNotIn('CreateLazarusSourcePlanCore(', self.clean_body)
        self.assertNotIn('IsValidSourceDirectory(SourcePlan.SourceDir)', self.clean_body)
        self.assertNotIn('ExecuteLazarusCleanPlanCore(SourcePlan, LOut, @CleanSourceArtifacts)', self.clean_body)


if __name__ == '__main__':
    unittest.main()
