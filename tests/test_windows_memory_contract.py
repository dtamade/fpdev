import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
UTILS_SOURCE = REPO_ROOT / 'src' / 'fpdev.utils.pas'


class WindowsMemoryContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = UTILS_SOURCE.read_text(encoding='utf-8')

    def test_windows_memory_declares_local_ex_compat_types(self):
        self.assertIn('TFPDevMemoryStatusEx = record', self.text)
        self.assertIn('PFPDevMemoryStatusEx = ^TFPDevMemoryStatusEx;', self.text)
        self.assertIn(
            "external 'kernel32.dll' name 'GlobalMemoryStatusEx';",
            self.text,
        )
        self.assertIn('MemStatus: TFPDevMemoryStatusEx;', self.text)
        self.assertIn('FpdevGlobalMemoryStatusEx(@MemStatus)', self.text)
        self.assertIn('UInt64(MemStatus.ullAvailPhys)', self.text)
        self.assertIn('UInt64(MemStatus.ullTotalPhys)', self.text)

    def test_windows_memory_does_not_depend_on_windows_unit_ex_symbols(self):
        self.assertNotIn('MemStatus: MEMORYSTATUS;', self.text)
        self.assertNotIn('MemStatus: TMemoryStatusEx;', self.text)
        self.assertNotIn('if GlobalMemoryStatusEx(MemStatus)', self.text)


if __name__ == '__main__':
    unittest.main()
