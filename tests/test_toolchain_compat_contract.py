import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = REPO_ROOT / 'src'
TOOLCHAIN_SOURCE = REPO_ROOT / 'src' / 'fpdev.toolchain.pas'


class ToolchainCompatContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = TOOLCHAIN_SOURCE.read_text(encoding='utf-8')

    def test_pascal_sources_do_not_use_fpc_3_3_only_plus_equals_syntax(self):
        for source_path in sorted(SRC_ROOT.rglob('*.pas')):
            text = source_path.read_text(encoding='utf-8')
            self.assertNotIn(
                '+=',
                text,
                msg=f'{source_path.relative_to(REPO_ROOT)} still uses += syntax',
            )

    def test_normalize_version_uses_fpc_3_2_2_compatible_string_append(self):
        self.assertIn('Result := Result + ch', self.text)
        self.assertNotIn('Result += ch', self.text)


if __name__ == '__main__':
    unittest.main()
