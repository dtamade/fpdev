import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_BUILDER = REPO_ROOT / 'src' / 'fpdev.fpc.builder.pas'


class FPCBuilderBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_BUILDER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str | None) -> str:
        tail = cls.text.split(start, 1)[1]
        if end is None:
            return tail
        return tail.split(end, 1)[0]

    def test_builder_imports_builderflow_unit(self):
        self.assertIn('fpdev.fpc.builderflow', self.text)

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


if __name__ == '__main__':
    unittest.main()
