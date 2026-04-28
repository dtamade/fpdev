import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_MANAGER = REPO_ROOT / 'src' / 'fpdev.build.manager.pas'


class BuildManagerBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = BUILD_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str | None) -> str:
        tail = cls.text.split(start, 1)[1]
        if end is None:
            return tail
        return tail.split(end, 1)[0]

    def test_manager_imports_managerflow_unit(self):
        self.assertIn('fpdev.build.managerflow', self.text)

    def test_manager_imports_runtimeflow_unit(self):
        self.assertIn('fpdev.build.runtimeflow', self.text)

    def test_make_surface_methods_delegate_to_managerflow(self):
        compiler_section = self._section(
            'function TBuildManager.BuildCompiler(const AVersion: string): Boolean;',
            'function TBuildManager.BuildRTL(const AVersion: string): Boolean;',
        )
        rtl_section = self._section(
            'function TBuildManager.BuildRTL(const AVersion: string): Boolean;',
            'function TBuildManager.BuildPackages(const AVersion: string): Boolean;',
        )
        packages_section = self._section(
            'function TBuildManager.BuildPackages(const AVersion: string): Boolean;',
            'function TBuildManager.InstallPackages(const AVersion: string): Boolean;',
        )
        install_packages_section = self._section(
            'function TBuildManager.InstallPackages(const AVersion: string): Boolean;',
            'function TBuildManager.Install(const AVersion: string): Boolean;',
        )
        install_section = self._section(
            'function TBuildManager.Install(const AVersion: string): Boolean;',
            'function TBuildManager.Configure(const AVersion: string): Boolean;',
        )

        for section in (
            compiler_section,
            rtl_section,
            packages_section,
            install_packages_section,
            install_section,
        ):
            self.assertIn('ExecuteBuildManagerMakeOperationCore(', section)

        self.assertNotIn('CreateBuildCompilerStepPlanCore(', compiler_section)
        self.assertNotIn('CreateBuildRTLStepPlanCore(', rtl_section)
        self.assertNotIn('CreateBuildPackagesStepPlanCore(', packages_section)
        self.assertNotIn('CreateBuildInstallPackagesStepPlanCore(', install_packages_section)
        self.assertNotIn('CreateBuildInstallStepPlanCore(', install_section)

    def test_testresults_and_preflight_delegate_to_managerflow(self):
        testresults_section = self._section(
            'function TBuildManager.TestResults(const AVersion: string): Boolean;',
            'function TBuildManager.Preflight(const AVersion: string): Boolean;',
        )
        preflight_section = self._section(
            'function TBuildManager.Preflight(const AVersion: string): Boolean;',
            'function TBuildManager.FullBuild(const AVersion: string): Boolean;',
        )

        self.assertIn('ExecuteBuildManagerTestResultsCore(', testresults_section)
        self.assertNotIn('ExecuteBuildTestResultsCore(', testresults_section)

        self.assertIn('ExecuteBuildManagerPreflightCore(', preflight_section)
        self.assertNotIn('BuildBuildPreflightInputsCore(', preflight_section)
        self.assertNotIn('CollectBuildPreflightIssuesCore(', preflight_section)

    def test_runtime_surface_methods_delegate_to_runtimeflow(self):
        toolchain_section = self._section(
            'function TBuildManager.CheckToolchain: Boolean;',
            'function TBuildManager.HasTool(',
        )
        apply_config_section = self._section(
            'procedure TBuildManager.ApplyConfig(const AConfig: TBuildConfig);',
            'function TBuildManager.GetBuildStep: Integer;',
        )
        runmake_section = self._section(
            'function TBuildManager.RunMake(const ASourcePath: string; const ATargets: array of string): Boolean;',
            'function TBuildManager.RunMakeTargets(',
        )
        build_stamp_section = self._section(
            'procedure TBuildManager.CreateBuildStamp(const AVersion: string);',
            '{ Package Selection Methods (Phase 4.3) }',
        )

        self.assertIn('ExecuteBuildManagerToolchainCheckCore(', toolchain_section)
        self.assertNotIn('LIssues := TStringList.Create;', toolchain_section)
        self.assertNotIn('for i:=0 to LIssues.Count-1 do', toolchain_section)
        self.assertNotIn("Check('fpc','-iV'", toolchain_section)

        self.assertIn('ApplyBuildManagerConfigCore(', apply_config_section)
        self.assertNotIn('SetLength(FSelectedPackages', apply_config_section)
        self.assertNotIn('SetLength(FSkippedPackages', apply_config_section)
        self.assertNotIn('for I := 0 to High(AConfig.SelectedPackages) do', apply_config_section)
        self.assertNotIn('for I := 0 to High(AConfig.SkippedPackages) do', apply_config_section)

        self.assertIn('ExecuteBuildManagerRunMakeCore(', runmake_section)
        self.assertNotIn('TProcessExecutor.FindExecutable(', runmake_section)
        self.assertNotIn('TProcessExecutor.RunDirect(', runmake_section)
        self.assertNotIn('LArgs[0] := \'-C\'', runmake_section)
        self.assertNotIn('OPT="-O2"', runmake_section)

        self.assertIn('CreateBuildManagerStampCore(', build_stamp_section)
        self.assertNotIn('AssignFile(F, StampFile);', build_stamp_section)
        self.assertNotIn("WriteLn(F, 'cpu=', LCpu);", build_stamp_section)
        self.assertNotIn('{$IFDEF CPUX86_64}', build_stamp_section)


if __name__ == '__main__':
    unittest.main()
