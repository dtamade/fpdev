import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_MANAGER = REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas'


class FPCManagerIndexBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_MANAGER.read_text(encoding='utf-8')
        parts = cls.text.split('procedure FPC_UpdateIndex(const AConfigPath: string);')
        cls.update_section = parts[1].split('{ TFPCManager }', 1)[0]

    def test_manager_imports_shared_indexflow_unit(self):
        self.assertIn('fpdev.fpc.indexflow', self.text)

    def test_global_update_index_delegates_to_shared_helper(self):
        self.assertIn('ExecuteFPCUpdateIndexCore(', self.update_section)
        self.assertNotIn('Cfg := TFPDevConfigManager.Create(AConfigPath);', self.update_section)
        self.assertNotIn('S.Add(\'  "items": [\');', self.update_section)

    def test_manager_no_longer_owns_duplicate_semver_helpers(self):
        self.assertNotIn('function TryParseInt(const S: string; out N: Integer): Boolean;', self.text)
        self.assertNotIn('procedure ParseVersion(const Ver: string; out A, B, C: Integer);', self.text)
        self.assertNotIn('function CompareSemVer(const V1, V2: string): Integer;', self.text)
        self.assertNotIn('function SameMajorMinor(const V1, V2: string): Boolean;', self.text)


if __name__ == '__main__':
    unittest.main()
