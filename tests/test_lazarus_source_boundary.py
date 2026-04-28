import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_SOURCE = REPO_ROOT / 'src' / 'fpdev.lazarus.source.pas'


class LazarusSourceBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_SOURCE.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_source_imports_sourceflow_unit(self):
        self.assertIn('fpdev.lazarus.sourceflow', self.text)

    def test_source_imports_sourceversionflow_unit(self):
        self.assertIn('fpdev.lazarus.sourceversionflow', self.text)

    def test_source_imports_sourcelifecycleflow_unit(self):
        self.assertIn('fpdev.lazarus.sourcelifecycleflow', self.text)

    def test_source_imports_sourceruntimeflow_unit(self):
        self.assertIn('fpdev.lazarus.sourceruntimeflow', self.text)

    def test_source_delegates_path_and_tree_validation_helpers(self):
        get_source_path = self._section(
            'function TLazarusSourceManager.GetSourcePath',
            'function TLazarusSourceManager.GetVersionFromBranch',
        )
        validate_tree = self._section(
            'function TLazarusSourceManager.IsValidSourceDirectory',
            'function TLazarusSourceManager.ConfigureCustomFPCIDE',
        )

        self.assertIn('BuildLazarusLegacySourcePathCore(', get_source_path)
        self.assertNotIn("Result := FSourceRoot + PathDelim + 'lazarus-' + Version;", get_source_path)

        self.assertIn('IsValidLazarusLegacySourceTreeCore(', validate_tree)
        self.assertNotIn("DirectoryExists(APath + PathDelim + 'ide')", validate_tree)
        self.assertNotIn("DirectoryExists(APath + PathDelim + 'lcl')", validate_tree)
        self.assertNotIn("DirectoryExists(APath + PathDelim + 'packager')", validate_tree)

    def test_source_delegates_clone_and_update_plan_helpers(self):
        clone_section = self._section(
            'function TLazarusSourceManager.CloneLazarusSource',
            'function TLazarusSourceManager.UpdateLazarusSource',
        )
        update_section = self._section(
            'function TLazarusSourceManager.UpdateLazarusSource',
            'function TLazarusSourceManager.SwitchLazarusVersion',
        )

        self.assertIn('CreateLazarusLegacyClonePlanCore(', clone_section)
        self.assertNotIn('SourcePath := GetSourcePath(Version);', clone_section)
        self.assertIn('ExecuteLazarusLegacyCloneCore(', clone_section)
        self.assertNotIn('Git.Clone(ClonePlan.RepositoryURL, ClonePlan.SourcePath, ClonePlan.RefName)', clone_section)

        self.assertIn('CreateLazarusLegacyUpdatePlanCore(', update_section)
        self.assertNotIn('SourcePath := GetSourcePath(Version);', update_section)
        self.assertIn('ExecuteLazarusLegacyUpdateCore(', update_section)
        self.assertNotIn('Result := Git.Pull(UpdatePlan.SourcePath);', update_section)

    def test_source_delegates_switch_and_install_lifecycle_helpers(self):
        switch_section = self._section(
            'function TLazarusSourceManager.SwitchLazarusVersion',
            'function TLazarusSourceManager.ListAvailableVersions',
        )
        install_section = self._section(
            'function TLazarusSourceManager.InstallLazarusVersion',
            'end.',
        )

        self.assertIn('ExecuteLazarusLegacySwitchCore(', switch_section)
        self.assertNotIn('Git.Checkout(SourcePath, RefName, True)', switch_section)
        self.assertNotIn("WriteLn('Switching to Lazarus version: ', AVersion);", switch_section)

        self.assertIn('ExecuteLazarusLegacyInstallCore(', install_section)
        self.assertNotIn('if not CloneLazarusSource(Version) then', install_section)
        self.assertNotIn('if not BuildLazarus(Version) then', install_section)
        self.assertNotIn('if SwitchLazarusVersion(Version) then', install_section)

    def test_source_delegates_runtime_and_config_helpers(self):
        configure_section = self._section(
            'function TLazarusSourceManager.ConfigureCustomFPCIDE',
            'function TLazarusSourceManager.ExecuteCommand',
        )
        local_versions_section = self._section(
            'function TLazarusSourceManager.ListLocalVersions',
            'function TLazarusSourceManager.GetCurrentVersion',
        )
        build_section = self._section(
            'function TLazarusSourceManager.BuildLazarus',
            'function TLazarusSourceManager.LaunchLazarus',
        )
        launch_section = self._section(
            'function TLazarusSourceManager.LaunchLazarus',
            'function TLazarusSourceManager.GetLazarusVersion',
        )

        self.assertIn('ConfigureLegacyLazarusCustomFPCIDECore(', configure_section)
        self.assertNotIn('TLazarusIDEConfig.Create(ConfigDir)', configure_section)
        self.assertNotIn("Result := IDEConfig.SetCompilerPath(FFPCPath);", configure_section)

        self.assertIn('ListLegacyLazarusLocalVersionsCore(', local_versions_section)
        self.assertNotIn("if FindFirst(FSourceRoot + PathDelim + 'lazarus-*'", local_versions_section)

        self.assertIn('ExecuteLegacyLazarusBuildCore(', build_section)
        self.assertNotIn('BuildLazarusLegacyMakeParamsCore(', build_section)
        self.assertNotIn("Result := ExecuteCommand('make', MakeParams, SourcePath);", build_section)

        self.assertIn('ExecuteLegacyLazarusLaunchCore(', launch_section)
        self.assertNotIn("Result := ExecuteCommand('cmd', ['/c', 'start', '', ExecutablePath], '');", launch_section)
        self.assertNotIn("Result := TProcessExecutor.Launch(ExecutablePath, [], '');", launch_section)

    def test_source_delegates_version_inventory_helpers(self):
        branch_section = self._section(
            'function TLazarusSourceManager.GetVersionFromBranch',
            'function TLazarusSourceManager.IsValidSourceDirectory',
        )
        list_section = self._section(
            'function TLazarusSourceManager.ListAvailableVersions',
            'function TLazarusSourceManager.ListLocalVersions',
        )
        version_section = self._section(
            'function TLazarusSourceManager.GetLazarusVersion',
            'function TLazarusSourceManager.InstallLazarusVersion',
        )

        self.assertIn('ResolveLegacyLazarusVersionFromBranchCore(', branch_section)
        self.assertNotIn('FindStaticLazarusBranchIndex', branch_section)

        self.assertIn('BuildLegacyLazarusAvailableVersionsCore(', list_section)
        self.assertNotIn('UseStaticFallback :=', list_section)

        self.assertIn('ResolveLegacyLazarusDescriptionCore(', version_section)
        self.assertNotIn('ResolveLazarusDescriptionFromRegistryOrStatic', version_section)

    def test_source_no_longer_owns_static_version_index_helpers(self):
        self.assertNotIn('function FindStaticLazarusVersionIndex', self.text)
        self.assertNotIn('function FindStaticLazarusBranchIndex', self.text)


if __name__ == '__main__':
    unittest.main()
