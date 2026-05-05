import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_BUILDER = REPO_ROOT / 'src' / 'fpdev.fpc.builder.pas'
DOWNLOADFLOW = REPO_ROOT / 'src' / 'fpdev.fpc.builder.downloadflow.pas'
BOOTSTRAPRESOLVEFLOW = REPO_ROOT / 'src' / 'fpdev.fpc.builder.bootstrapresolveflow.pas'
HOTPATCHFLOW = REPO_ROOT / 'src' / 'fpdev.fpc.builder.hotpatchflow.pas'


class FPCBuilderBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_BUILDER.read_text(encoding='utf-8')
        cls.downloadflow_text = DOWNLOADFLOW.read_text(encoding='utf-8')
        cls.bootstrapresolveflow_text = BOOTSTRAPRESOLVEFLOW.read_text(encoding='utf-8')
        cls.hotpatchflow_text = HOTPATCHFLOW.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str | None) -> str:
        tail = cls.text.split(start, 1)[1]
        if end is None:
            return tail
        return tail.split(end, 1)[0]

    def test_builder_imports_builderflow_unit(self):
        self.assertIn('fpdev.fpc.builderflow', self.text)

    def test_builder_imports_downloadflow_unit(self):
        self.assertIn('fpdev.fpc.builder.downloadflow', self.text)

    def test_builder_imports_bootstrapresolveflow_unit(self):
        self.assertIn('fpdev.fpc.builder.bootstrapresolveflow', self.text)

    def test_builder_imports_hotpatchflow_unit(self):
        self.assertIn('fpdev.fpc.builder.hotpatchflow', self.text)

    def test_ensure_bootstrap_delegates_to_builderflow(self):
        section = self._section(
            'function TFPCSourceBuilder.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;',
            'function TFPCSourceBuilder.DownloadSource(const AVersion, ATargetDir: string): Boolean;',
        )
        self.assertIn('ExecuteFPCBuilderEnsureBootstrapCore(', section)
        self.assertNotIn('Attempting to download from resource repository...', section)
        self.assertNotIn('Unable to automatically download bootstrap compiler.', section)

    def test_build_from_source_delegates_to_builderflow(self):
        section = self._section(
            'function TFPCSourceBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;',
            '{ TFPCBuilder has been moved to fpdev.fpc.builder.di unit }',
        )
        self.assertIn('ExecuteFPCBuilderBuildFromSourceCore(', section)
        self.assertNotIn('TProcessExecutor.RunDirect', section)
        self.assertNotIn('FPCBuilderInvalidateCompilerMessageIncludesCore(', section)
        self.assertNotIn('CreateFPCSourceBuildPlanCore(', section)

    def test_download_source_delegates_to_downloadflow(self):
        section = self._section(
            'function TFPCSourceBuilder.DownloadSource(const AVersion, ATargetDir: string): Boolean;',
            'function TFPCSourceBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;',
        )
        self.assertIn('DownloadFPCSourceWithGitRuntimeCore(', section)
        self.assertNotIn('NewGitRuntime', section)
        self.assertNotIn('Git.Clone(', section)
        self.assertNotIn('Git.Fetch(', section)

    def test_try_resolve_installed_bootstrap_delegates_to_bootstrapresolveflow(self):
        section = self._section(
            'function TFPCSourceBuilder.TryResolveInstalledBootstrapCompiler(',
            'function TFPCSourceBuilder.EnsureResourceRepository',
        )
        self.assertIn('TryResolveInstalledBootstrapCompilerCore(', section)
        self.assertNotIn('CandidateVersion := ATargetVersion', section)
        self.assertNotIn('BuildFPCInstalledExecutablePathCore(GetVersionInstallPath', section)

    def test_get_required_bootstrap_version_delegates_to_bootstrapresolveflow(self):
        section = self._section(
            'function TFPCSourceBuilder.GetRequiredBootstrapVersion(const ATargetVersion: string): string;',
            'function TFPCSourceBuilder.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;',
        )
        self.assertIn('GetRequiredBootstrapVersionCore(', section)
        self.assertNotIn('BuildFPCSourceInstallPathCore(FInstallRoot', section)
        self.assertNotIn('ResourceRepoGetBootstrapVersionFromMakefile', section)

    def test_prepare_source_tree_delegates_to_hotpatchflow(self):
        section = self._section(
            'procedure TFPCSourceBuilder.PrepareSourceTree(const ASourceDir: string);',
            'procedure TFPCSourceBuilder.EnsureInstallDirectoryExists',
        )
        self.assertIn('FPCBuilderInvalidateCompilerMessageIncludesCore(', section)
        self.assertIn('FPCBuilderApplyFCLWebJWTSourcePathHotpatchCore(', section)

    def test_downloadflow_contains_git_runtime_workflow(self):
        self.assertIn('DownloadFPCSourceWithGitRuntimeCore(', self.downloadflow_text)
        self.assertIn('NewGitRuntime', self.downloadflow_text)
        self.assertIn('Git.Clone(', self.downloadflow_text)
        self.assertIn('Git.Fetch(', self.downloadflow_text)

    def test_bootstrapresolveflow_contains_can_use_system_compiler(self):
        self.assertIn('FPCBuilderCanUseSystemCompilerAsBootstrapCore(', self.bootstrapresolveflow_text)
        self.assertIn('TryResolveInstalledBootstrapCompilerCore(', self.bootstrapresolveflow_text)
        self.assertIn('GetRequiredBootstrapVersionCore(', self.bootstrapresolveflow_text)

    def test_hotpatchflow_contains_invalidate_and_jwt_hotpatch(self):
        self.assertIn('FPCBuilderInvalidateCompilerMessageIncludesCore(', self.hotpatchflow_text)
        self.assertIn('FPCBuilderApplyFCLWebJWTSourcePathHotpatchCore(', self.hotpatchflow_text)


if __name__ == '__main__':
    unittest.main()
