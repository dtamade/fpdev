import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_MANAGER = REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas'


class FPCManagerStatusBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_MANAGER.read_text(encoding='utf-8')
        start = cls.text.index('function TFPCManager.GetStatus')
        end = cls.text.index('function TFPCManager.ActivateVersion', start)
        cls.body = cls.text[start:end]

    def test_manager_imports_shared_statusflow_unit(self):
        self.assertIn('fpdev.fpc.statusflow', self.text)

    def test_manager_getstatus_delegates_to_shared_flow(self):
        self.assertIn('BuildManagedFPCStatusCore(', self.body)
        self.assertIn('@LookupToolchainInfo', self.body)
        self.assertIn('@TryReadStatusMetadata', self.body)
        self.assertIn('@InferStatusScope', self.body)

    def test_manager_getstatus_no_longer_inlines_status_orchestration(self):
        self.assertNotIn('BuildFPCInstalledExecutablePathCore(', self.body)
        self.assertNotIn('Configured default FPC ', self.body)
        self.assertNotIn('ReadFPCMetadata(', self.body)


if __name__ == '__main__':
    unittest.main()
