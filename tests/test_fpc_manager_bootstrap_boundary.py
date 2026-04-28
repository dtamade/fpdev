import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_MANAGER = REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas'


class FPCManagerBootstrapBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_shared_bootstrapflow_unit(self):
        self.assertIn('fpdev.fpc.bootstrapflow', self.text)

    def test_manager_bootstrap_delegates_to_shared_flow(self):
        body = self._section(
            'function TFPCManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;',
            'function TFPCManager.EnsureBootstrapWithBuilder(const ATargetVersion: string): Boolean;',
        )
        self.assertIn('ExecuteManagedFPCBootstrapEnsureCore(', body)
        self.assertIn('@EnsureBootstrapWithBuilder', body)
        self.assertIn('@InstallBinaryBootstrapFallback', body)

    def test_manager_bootstrap_no_longer_inlines_fallback_glue(self):
        body = self._section(
            'function TFPCManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;',
            'function TFPCManager.EnsureBootstrapWithBuilder(const ATargetVersion: string): Boolean;',
        )
        self.assertNotIn('FBuilderMgr.EnsureBootstrapCompiler(ATargetVersion)', body)
        self.assertNotIn('Attempting binary bootstrap fallback for FPC', body)
        self.assertNotIn('Binary bootstrap fallback installed FPC', body)


if __name__ == '__main__':
    unittest.main()
