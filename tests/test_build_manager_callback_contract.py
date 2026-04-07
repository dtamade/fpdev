import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_MANAGER = REPO_ROOT / 'src' / 'fpdev.build.manager.pas'


class BuildManagerCallbackContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = BUILD_MANAGER.read_text(encoding='utf-8')

    def test_full_build_does_not_pass_overloaded_preflight_directly(self):
        self.assertNotRegex(
            self.text,
            re.compile(r'RunFullBuildCore\s*\(\s*AVersion\s*,\s*@Preflight\s*,', re.S),
        )

    def test_full_build_uses_named_phase_adapter_for_preflight(self):
        self.assertIn(
            'function RunVersionedPreflight(const AVersion: string): Boolean;',
            self.text,
        )
        self.assertRegex(
            self.text,
            re.compile(r'RunFullBuildCore\s*\(\s*AVersion\s*,\s*@RunVersionedPreflight\s*,', re.S),
        )
        self.assertRegex(
            self.text,
            re.compile(
                r'function TBuildManager\.RunVersionedPreflight\(const AVersion: string\): Boolean;\s*'
                r'begin\s*'
                r'(?:\/\/[^\n]*\s*)*'
                r'Result := Preflight\(AVersion\);\s*'
                r'end;',
                re.S,
            ),
        )


if __name__ == '__main__':
    unittest.main()
