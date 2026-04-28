import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CROSS_MANAGER = REPO_ROOT / 'src' / 'fpdev.cross.manager.pas'


class CrossManagerBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CROSS_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str | None) -> str:
        tail = cls.text.split(start, 1)[1]
        if end is None:
            return tail
        return tail.split(end, 1)[0]

    def test_manager_imports_managerflow_unit(self):
        self.assertIn('fpdev.cross.managerflow', self.text)

    def test_manager_imports_installsupportflow_unit(self):
        self.assertIn('fpdev.cross.installsupportflow', self.text)

    def test_list_and_show_delegate_to_managerflow(self):
        list_section = self._section(
            'function TCrossCompilerManager.ListTargets(const AShowAll: Boolean; Outp: IOutput): Boolean;',
            'function TCrossCompilerManager.EnableTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
        )
        show_section = self._section(
            'function TCrossCompilerManager.ShowTargetInfo(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
            'function TCrossCompilerManager.TestTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
        )

        self.assertIn('ExecuteCrossListTargetsCore(', list_section)
        self.assertNotIn('MSG_CROSS_LIST_TABLE_HEADER', list_section)

        self.assertIn('ExecuteCrossShowTargetInfoCore(', show_section)
        self.assertNotIn('MSG_CROSS_SHOW_DISPLAY_NAME', show_section)

    def test_update_and_clean_delegate_to_managerflow(self):
        update_section = self._section(
            'function TCrossCompilerManager.UpdateTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
            'function TCrossCompilerManager.CleanTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
        )
        clean_section = self._section(
            'function TCrossCompilerManager.CleanTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
            None,
        )

        self.assertIn('ExecuteCrossUpdateTargetCore(', update_section)
        self.assertNotIn('MSG_CROSS_UPDATE_STEP1', update_section)

        self.assertIn('ExecuteCrossCleanTargetCore(', clean_section)
        self.assertNotIn('binutils.tar.xz', clean_section)
        self.assertNotIn('cross_test.exe', clean_section)

    def test_install_and_uninstall_delegate_to_managerflow(self):
        install_section = self._section(
            'function TCrossCompilerManager.InstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
            'function TCrossCompilerManager.UninstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
        )
        uninstall_section = self._section(
            'function TCrossCompilerManager.UninstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
            'function TCrossCompilerManager.ListTargets(const AShowAll: Boolean; Outp: IOutput): Boolean;',
        )

        self.assertIn('ExecuteCrossInstallTargetCore(', install_section)
        self.assertNotIn('DetectSystemCrossCompiler(ATarget', install_section)
        self.assertNotIn('GetPackageManagerInstructions(ATarget)', install_section)
        self.assertNotIn('MSG_CROSS_INSTALL_STEP1', install_section)

        self.assertIn('ExecuteCrossUninstallTargetCore(', uninstall_section)
        self.assertNotIn('DeleteDirRecursive(InstallPath)', uninstall_section)
        self.assertNotIn('RemoveCrossTarget(ATarget)', uninstall_section)

    def test_download_surfaces_delegate_to_installsupportflow(self):
        binutils_section = self._section(
            'function TCrossCompilerManager.DownloadBinutils(',
            'function TCrossCompilerManager.DownloadLibraries(',
        )
        libraries_section = self._section(
            'function TCrossCompilerManager.DownloadLibraries(',
            'function TCrossCompilerManager.SetupCrossEnvironment(',
        )

        self.assertIn('ExecuteCrossDownloadBinutilsSurfaceCore(', binutils_section)
        self.assertNotIn('MSG_CROSS_DOWNLOADING_BINUTILS', binutils_section)
        self.assertNotIn('FDownloader.LastError', binutils_section)
        self.assertNotIn('MSG_CROSS_MANIFEST_NOT_FOUND', binutils_section)

        self.assertIn('ExecuteCrossDownloadLibrariesSurfaceCore(', libraries_section)
        self.assertNotIn('MSG_CROSS_DOWNLOADING_LIBS', libraries_section)
        self.assertNotIn('MSG_CROSS_LIBS_MANUAL_INSTALL', libraries_section)
        self.assertNotIn('MSG_CROSS_LIBS_NOTE', libraries_section)

    def test_setup_environment_delegates_to_installsupportflow(self):
        setup_section = self._section(
            'function TCrossCompilerManager.SetupCrossEnvironment(',
            'function TCrossCompilerManager.InstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;',
        )

        self.assertIn('ExecuteCrossSetupEnvironmentSurfaceCore(', setup_section)
        self.assertNotIn('CrossTarget.BinutilsPath := InstallPath + PathDelim + \'bin\'', setup_section)
        self.assertNotIn('FConfigManager.GetCrossTargetManager.AddCrossTarget', setup_section)


if __name__ == '__main__':
    unittest.main()
