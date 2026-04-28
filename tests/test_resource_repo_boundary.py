import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RESOURCE_REPO = REPO_ROOT / 'src' / 'fpdev.resource.repo.pas'


class ResourceRepoBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = RESOURCE_REPO.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_resource_repo_imports_mirrorflow_unit(self):
        self.assertIn('fpdev.resource.repo.mirrorflow', self.text)

    def test_resource_repo_imports_queryflow_unit(self):
        self.assertIn('fpdev.resource.repo.queryflow', self.text)

    def test_resource_repo_imports_lifecycleflow_unit(self):
        self.assertIn('fpdev.resource.repo.lifecycleflow', self.text)

    def test_resource_repo_imports_packageflow_unit(self):
        self.assertIn('fpdev.resource.repo.packageflow', self.text)

    def test_resource_repo_imports_bootstrapflow_unit(self):
        self.assertIn('fpdev.resource.repo.bootstrapflow', self.text)

    def test_select_best_mirror_delegates_to_mirrorflow(self):
        section = self._section(
            'function TResourceRepository.SelectBestMirror: string;',
            'function TResourceRepository.GetMirrors: TMirrorArray;',
        )
        self.assertIn('ExecuteResourceRepoSelectBestMirrorSurfaceCore(', section)
        self.assertNotIn('SelectResourceRepoBestMirrorCore(', section)
        self.assertNotIn('ResourceRepoBuildCandidateMirrors(', section)
        self.assertNotIn('ResourceRepoSelectBestMirrorFromCandidates(', section)
        self.assertNotIn('SetLength(FMirrorLatencies, Length(Selection.CandidateMirrors));', section)
        self.assertNotIn('for I := 0 to High(Selection.CandidateMirrors) do', section)
        self.assertNotIn('try', section)

    def test_get_mirrors_delegates_mapping_to_mirrorflow(self):
        section = self._section(
            'function TResourceRepository.GetMirrors: TMirrorArray;',
            'function TResourceRepository.GetBestMirrorURL: string;',
        )
        self.assertIn('ExecuteResourceRepoGetMirrorsSurfaceCore(', section)
        self.assertNotIn('ConvertResourceRepoMirrorsCore(', section)
        self.assertNotIn('ResourceRepoGetMirrorsFromManifest(', section)
        self.assertNotIn('Result[i].Name := ParsedMirrors[i].Name;', section)
        self.assertNotIn('try', section)

    def test_repo_io_lifecycle_surface_delegates_to_lifecycleflow(self):
        clone_section = self._section(
            'function TResourceRepository.GitClone(const AURL: string): Boolean;',
            'function TResourceRepository.GitPull: Boolean;',
        )
        pull_section = self._section(
            'function TResourceRepository.GitPull: Boolean;',
            'function TResourceRepository.QueryShortHead(const AWorkDir: string): TProcessResult;',
        )
        manifest_section = self._section(
            'function TResourceRepository.LoadManifest: Boolean;',
            'function TResourceRepository.EnsureManifestLoaded: Boolean;',
        )
        version_section = self._section(
            'function TResourceRepository.GetManifestVersion: string;',
            'function TResourceRepository.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;',
        )
        has_package_section = self._section(
            'function TResourceRepository.HasPackage(const AName, AVersion: string): Boolean;',
            'function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;',
        )

        self.assertIn('ExecuteResourceRepoGitCloneCore(', clone_section)
        self.assertNotIn('FGitOps.Clone(', clone_section)
        self.assertNotIn('ParentDir := ExtractFileDir(FLocalPath);', clone_section)

        self.assertIn('ExecuteResourceRepoGitPullCore(', pull_section)
        self.assertNotIn('FGitOps.PullFastForwardOnly(FLocalPath)', pull_section)
        self.assertNotIn('Warning: No Git backend available, skipping update', pull_section)

        self.assertIn('LoadResourceRepoManifestSurfaceCore(', manifest_section)
        self.assertNotIn("ManifestPath := FLocalPath + PathDelim + 'manifest.json';", manifest_section)
        self.assertNotIn('FreeAndNil(FManifestData);', manifest_section)

        self.assertIn('GetResourceRepoManifestVersionSurfaceCore(', version_section)
        self.assertNotIn("Result := FManifestData.Get('version', 'unknown');", version_section)
        self.assertNotIn('if not EnsureManifestLoaded then', version_section)

        self.assertIn('ExecuteResourceRepoHasPackageSurfaceCore(', has_package_section)
        self.assertNotIn('ResourceRepoHasPackageCore(FLocalPath, AName, AVersion)', has_package_section)
        self.assertNotIn('try', has_package_section)

    def test_bootstrap_queries_delegate_to_queryflow(self):
        has_section = self._section(
            'function TResourceRepository.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;',
            'function TResourceRepository.GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;',
        )
        info_section = self._section(
            'function TResourceRepository.GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;',
            'function TResourceRepository.GetBootstrapExecutable(const AVersion, APlatform: string): string;',
        )
        version_section = self._section(
            'function TResourceRepository.GetRequiredBootstrapVersion(const AFPCVersion: string): string;',
            'function TResourceRepository.GetBootstrapVersionFromMakefile(const ASourcePath: string): string;',
        )
        list_section = self._section(
            'function TResourceRepository.ListBootstrapVersions: SysUtils.TStringArray;',
            'function TResourceRepository.FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;',
        )

        self.assertIn('ExecuteResourceRepoBooleanQueryCore(', has_section)
        self.assertNotIn('if not EnsureManifestLoaded then', has_section)
        self.assertIn('ExecuteResourceRepoPlatformInfoQueryCore(', info_section)
        self.assertNotIn('System.Initialize(AInfo);', info_section)
        self.assertIn('ExecuteResourceRepoStringQueryCore(', version_section)
        self.assertNotIn('ResourceRepoGetRequiredBootstrapVersion(nil, AFPCVersion)', version_section)
        self.assertIn('ExecuteResourceRepoStringArrayQueryCore(', list_section)
        self.assertNotIn('SetLength(Result, 0);', list_section)

    def test_bootstrap_surface_delegates_to_bootstrapflow(self):
        best_section = self._section(
            'function TResourceRepository.FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;',
            'function TResourceRepository.VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;',
        )
        checksum_section = self._section(
            'function TResourceRepository.VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;',
            'function TResourceRepository.HasBinaryRelease(const AVersion, APlatform: string): Boolean;',
        )
        install_section = self._section(
            'function TResourceRepository.InstallBootstrap(const AVersion, APlatform, ADestDir: string): Boolean;',
            '{ Mirror Management }',
        )

        self.assertIn('ExecuteResourceRepoFindBestBootstrapVersionCore(', best_section)
        self.assertNotIn('SelectBestBootstrapVersionCore(', best_section)
        self.assertIn('ExecuteResourceRepoVerifyChecksumCore(', checksum_section)
        self.assertNotIn("LResult := TProcessExecutor.Execute('sha256sum', [AFile], '');", checksum_section)
        self.assertIn('ExecuteResourceRepoInstallBootstrapCore(', install_section)
        self.assertNotIn('RepoInstallBootstrapCompiler(BuildInstallContext(Self), Info, AVersion, APlatform, ADestDir)', install_section)

    def test_binary_and_cross_queries_delegate_to_queryflow(self):
        binary_has = self._section(
            'function TResourceRepository.HasBinaryRelease(const AVersion, APlatform: string): Boolean;',
            'function TResourceRepository.GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;',
        )
        binary_info = self._section(
            'function TResourceRepository.GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;',
            'function TResourceRepository.GetBinaryReleasePath(const AVersion, APlatform: string): string;',
        )
        cross_has = self._section(
            'function TResourceRepository.HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;',
            'function TResourceRepository.GetCrossToolchainInfo(',
        )
        cross_info = self._section(
            'function TResourceRepository.GetCrossToolchainInfo(',
            'function TResourceRepository.ListCrossTargets: SysUtils.TStringArray;',
        )
        cross_list = self._section(
            'function TResourceRepository.ListCrossTargets: SysUtils.TStringArray;',
            'function TResourceRepository.InstallCrossToolchain(const ATarget, AHostPlatform, ADestDir: string): Boolean;',
        )

        self.assertIn('ExecuteResourceRepoBooleanQueryCore(', binary_has)
        self.assertIn('ExecuteResourceRepoPlatformInfoQueryCore(', binary_info)
        self.assertIn('ExecuteResourceRepoBooleanQueryCore(', cross_has)
        self.assertIn('ExecuteResourceRepoCrossInfoQueryCore(', cross_info)
        self.assertIn('ExecuteResourceRepoStringArrayQueryCore(', cross_list)

    def test_package_surface_queries_delegate_to_packageflow(self):
        has_section = self._section(
            'function TResourceRepository.HasPackage(const AName, AVersion: string): Boolean;',
            'function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;',
        )
        info_section = self._section(
            'function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;',
            'function TResourceRepository.ListPackages(const ACategory: string): SysUtils.TStringArray;',
        )
        list_section = self._section(
            'function TResourceRepository.ListPackages(const ACategory: string): SysUtils.TStringArray;',
            'function TResourceRepository.SearchPackages(const AKeyword: string): SysUtils.TStringArray;',
        )
        search_section = self._section(
            'function TResourceRepository.SearchPackages(const AKeyword: string): SysUtils.TStringArray;',
            'function TResourceRepository.InstallPackage(const AName, AVersion, ADestDir: string): Boolean;',
        )

        self.assertIn('ExecuteResourceRepoHasPackageSurfaceCore(', has_section)
        self.assertIn('ExecuteResourceRepoPackageInfoSurfaceCore(', info_section)
        self.assertNotIn('System.Initialize(AInfo);', info_section)
        self.assertNotIn('try', info_section)
        self.assertIn('ExecuteResourceRepoPackageListSurfaceCore(', list_section)
        self.assertNotIn('ResourceRepoListPackagesCore(', list_section)
        self.assertIn('ExecuteResourceRepoPackageSearchSurfaceCore(', search_section)
        self.assertNotIn('AllPackages := ListPackages(\'\');', search_section)


if __name__ == '__main__':
    unittest.main()
