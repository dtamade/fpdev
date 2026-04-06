import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN_SOURCE = REPO_ROOT / 'src' / 'fpdev.toolchain.pas'


class ToolchainWindowsParserContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = TOOLCHAIN_SOURCE.read_text(encoding='utf-8')

    def test_normalize_version_uses_explicit_char_checks_for_legacy_fpc(self):
        self.assertIn(
            "if ((ch >= '0') and (ch <= '9')) or (ch = '.') then",
            self.text,
        )
        self.assertNotIn(
            "if (ch in ['0'..'9','.']) then",
            self.text,
        )


if __name__ == '__main__':
    unittest.main()
