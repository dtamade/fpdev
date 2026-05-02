import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_SOURCE = REPO_ROOT / 'src' / 'fpdev.fpc.source.pas'


class FPCSourceBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_SOURCE.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_source_imports_flow_units(self):
        self.assertIn('fpdev.fpc.sourceflow', self.text)
        self.assertIn('fpdev.fpc.sourceinstallflow', self.text)
        self.assertIn('fpdev.fpc.sourcebootstrapflow', self.text)
        self.assertIn('fpdev.fpc.sourcebuildflow', self.text)
        self.assertIn('fpdev.fpc.sourcemanagerflow', self.text)

    def test_lifecycle_and_query_surface_delegate_to_sourceflow(self):
        clone_section = self._section(
            'function TFPCSourceManager.CloneFPCSource(const AVersion: string): Boolean;',
            'function TFPCSourceManager.UpdateFPCSource(const AVersion: string): Boolean;',
        )
        update_section = self._section(
            'function TFPCSourceManager.UpdateFPCSource(const AVersion: string): Boolean;',
            'function TFPCSourceManager.SwitchFPCVersion(const AVersion: string): Boolean;',
        )
        switch_section = self._section(
            'function TFPCSourceManager.SwitchFPCVersion(const AVersion: string): Boolean;',
            'function TFPCSourceManager.ListAvailableVersions: TStringArray;',
        )
        available_section = self._section(
            'function TFPCSourceManager.ListAvailableVersions: TStringArray;',
            'function TFPCSourceManager.ListLocalVersions: TStringArray;',
        )
        local_section = self._section(
            'function TFPCSourceManager.ListLocalVersions: TStringArray;',
            'function TFPCSourceManager.GetCurrentVersion: string;',
        )
        prereq_section = self._section(
            'function TFPCSourceManager.CheckBuildPrerequisites(const {%H-} AVersion: string): Boolean;',
            'function TFPCSourceManager.IsValidSourceDirectory(const APath: string): Boolean;',
        )

        self.assertIn('ExecuteFPCSourceCloneCore(', clone_section)
        self.assertNotIn('Repo.CloneFPCSource(AVersion)', clone_section)
        self.assertNotIn("IfThen(AVersion<>'', AVersion, 'main')", clone_section)

        self.assertIn('ExecuteFPCSourceUpdateCore(', update_section)
        self.assertNotIn("if LVersion = '' then LVersion := FCurrentVersion;", update_section)
        self.assertNotIn("WriteLn('[OK] FPC source updated successfully')", update_section)

        self.assertIn('ExecuteFPCSourceSwitchCore(', switch_section)
        self.assertNotIn('if not IsVersionInstalled(AVersion) then', switch_section)
        self.assertNotIn('Repo.SwitchFPCVersion(AVersion)', switch_section)

        self.assertIn('BuildAvailableFPCSourceVersionsCore(', available_section)
        self.assertNotIn('TVersionRegistry.Instance.GetFPCReleases', available_section)
        self.assertNotIn('Values := TStringList.Create;', available_section)

        self.assertIn('ListLocalFPCSourceVersionsCore(', local_section)
        self.assertNotIn("FindFirst(FSourceRoot + PathDelim + 'fpc-*'", local_section)
        self.assertNotIn("if Pos('fpc-', DirName) = 1 then", local_section)

        self.assertIn('CheckFPCSourceBuildPrerequisitesCore(', prereq_section)
        self.assertNotIn("ExecuteCommand('make', ['--version'], '')", prereq_section)
        self.assertNotIn("if FBootstrapCompiler = '' then", prereq_section)

    def test_install_surface_delegates_to_installflow(self):
        section = self._section(
            'function TFPCSourceManager.InstallFPCVersion(const AVersion: string): Boolean;',
            '// Bootstrap compiler management - delegate to FBootstrap helper',
        )

        self.assertIn('ExecuteFPCSourceInstallFlowCore(', section)
        self.assertNotIn('if not InitializeInstall(Version) then', section)
        self.assertNotIn('if not EnsureBootstrapCompiler(Version) then', section)
        self.assertNotIn('if not BuildFPCCompiler(Version) then', section)

    def test_bootstrap_surface_delegates_to_bootstrapflow(self):
        download_section = self._section(
            'function TFPCSourceManager.DownloadBootstrapCompilerInternal(const AVersion: string): Boolean;',
            'function TFPCSourceManager.DownloadBootstrapCompiler(const AVersion: string): Boolean;',
        )
        ensure_section = self._section(
            'function TFPCSourceManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;',
            '// Step-by-step build process (FPCUpDeluxe-inspired)',
        )

        self.assertIn('ExecuteFPCSourceBootstrapDownloadCore(', download_section)
        self.assertNotIn('TFPHTTPClient.Create(nil)', download_section)
        self.assertNotIn('TUnZipper.Create', download_section)

        self.assertIn('ExecuteFPCSourceEnsureBootstrapCore(', ensure_section)
        self.assertNotIn('SystemFPC := FBootstrap.FindSystemFPC', ensure_section)
        self.assertNotIn('DownloadBootstrapCompilerInternal(RequiredVersion)', ensure_section)

    def test_build_and_cache_surface_delegate_to_buildflow(self):
        build_source = self._section(
            'function TFPCSourceManager.BuildFPCSource(const AVersion: string): Boolean;',
            'function TFPCSourceManager.InstallFPCVersion(const AVersion: string): Boolean;',
        )
        build_compiler = self._section(
            'function TFPCSourceManager.BuildFPCCompiler(const AVersion: string): Boolean;',
            'function TFPCSourceManager.BuildFPCRTL(const AVersion: string): Boolean;',
        )
        build_rtl = self._section(
            'function TFPCSourceManager.BuildFPCRTL(const AVersion: string): Boolean;',
            'function TFPCSourceManager.BuildFPCPackages(const AVersion: string): Boolean;',
        )
        build_packages = self._section(
            'function TFPCSourceManager.BuildFPCPackages(const AVersion: string): Boolean;',
            'function TFPCSourceManager.InstallFPCBinaries(const AVersion: string): Boolean;',
        )
        install_bins = self._section(
            'function TFPCSourceManager.InstallFPCBinaries(const AVersion: string): Boolean;',
            'function TFPCSourceManager.ConfigureFPCEnvironment(const AVersion: string): Boolean;',
        )
        config_env = self._section(
            'function TFPCSourceManager.ConfigureFPCEnvironment(const AVersion: string): Boolean;',
            'function TFPCSourceManager.TestBuildResults(const AVersion: string): Boolean;',
        )
        test_results = self._section(
            'function TFPCSourceManager.TestBuildResults(const AVersion: string): Boolean;',
            'function TFPCSourceManager.ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;',
        )
        cache_available = self._section(
            'function TFPCSourceManager.IsCacheAvailable(const AVersion: string): Boolean;',
            'function TFPCSourceManager.UseCachedBuild(const AVersion: string): Boolean;',
        )
        use_cache = self._section(
            'function TFPCSourceManager.UseCachedBuild(const AVersion: string): Boolean;',
            'function TFPCSourceManager.ProtectedIsCacheAvailable(const AVersion: string): Boolean;',
        )

        self.assertIn('ExecuteFPCSourceBuildCore(', build_source)
        self.assertNotIn("Result := ExecuteCommand('make', ['clean', 'all'], SourcePath);", build_source)

        for section in (build_compiler, build_rtl, build_packages, install_bins, config_env, test_results):
            self.assertIn('ExecuteFPCSourceManagedBuildStepCore(', section)
            self.assertNotIn('CreateBuildManager(', section)

        self.assertIn('ExecuteFPCSourceCacheAvailableCore(', cache_available)
        self.assertNotIn("CachePath := FSourceRoot + PathDelim + 'cache' + PathDelim + 'fpc-' + AVersion + '.cache';", cache_available)

        self.assertIn('ExecuteFPCSourceUseCachedBuildCore(', use_cache)
        self.assertNotIn('CacheMeta.LoadFromFile(CachePath);', use_cache)
        self.assertNotIn("CompilerDir := SourcePath + PathDelim + 'compiler';", use_cache)

    def test_private_manager_bridge_and_cache_marker_delegate_to_sourcemanagerflow(self):
        build_compiler = self._section(
            'function TFPCSourceManager.BuildCompilerWithManager(const AVersion: string): Boolean;',
            'function TFPCSourceManager.BuildRTLWithManager(const AVersion: string): Boolean;',
        )
        build_rtl = self._section(
            'function TFPCSourceManager.BuildRTLWithManager(const AVersion: string): Boolean;',
            'function TFPCSourceManager.BuildPackagesWithManager(const AVersion: string): Boolean;',
        )
        build_packages = self._section(
            'function TFPCSourceManager.BuildPackagesWithManager(const AVersion: string): Boolean;',
            'function TFPCSourceManager.InstallBinariesWithManager(const AVersion: string): Boolean;',
        )
        install_bins = self._section(
            'function TFPCSourceManager.InstallBinariesWithManager(const AVersion: string): Boolean;',
            'function TFPCSourceManager.ConfigureEnvironmentWithManager(const AVersion: string): Boolean;',
        )
        config_env = self._section(
            'function TFPCSourceManager.ConfigureEnvironmentWithManager(const AVersion: string): Boolean;',
            'function TFPCSourceManager.TestBuildResultsWithManager(const AVersion: string): Boolean;',
        )
        test_results = self._section(
            'function TFPCSourceManager.TestBuildResultsWithManager(const AVersion: string): Boolean;',
            'function TFPCSourceManager.WriteCacheMarker(const AVersion: string): Boolean;',
        )
        cache_marker = self._section(
            'function TFPCSourceManager.WriteCacheMarker(const AVersion: string): Boolean;',
            'function TFPCSourceManager.CloneFPCSource(const AVersion: string): Boolean;',
        )

        for section in (
            build_compiler,
            build_rtl,
            build_packages,
            install_bins,
            config_env,
            test_results,
        ):
            self.assertIn('ExecuteFPCSourceBuildManagerBridgeCore(', section)
            self.assertNotIn('LBM := CreateBuildManager(', section)
            self.assertNotIn('LBM.Free;', section)

        self.assertIn('WriteFPCSourceCacheMarkerCore(', cache_marker)
        self.assertNotIn('CacheMeta.SaveToFile(CachePath);', cache_marker)
        self.assertNotIn("CacheDir := FSourceRoot + PathDelim + 'cache';", cache_marker)


if __name__ == '__main__':
    unittest.main()
