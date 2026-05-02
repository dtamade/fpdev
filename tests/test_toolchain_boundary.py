import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN = REPO_ROOT / 'src' / 'fpdev.toolchain.pas'


class ToolchainBoundaryTests(unittest.TestCase):
    check_signature = (
        'function CheckFPCVersionPolicy(const ASourceVersion: string;\n'
        '  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;'
    )

    @classmethod
    def setUpClass(cls):
        cls.text = TOOLCHAIN.read_text(encoding='utf-8')
        cls.interface_text, cls.implementation_text = cls.text.split('implementation', 1)

    @classmethod
    def extract_section(cls, signature: str) -> str:
        pattern = re.compile(
            rf"{re.escape(signature)}(.*?)(?=\n(?:function|procedure) |\nend\.)",
            re.S,
        )
        match = pattern.search(cls.implementation_text)
        if not match:
            raise AssertionError(f'Unable to find section for {signature}')
        return match.group(0)

    def test_toolchain_implementation_imports_policyflow(self):
        self.assertIn('fpdev.toolchain.policyflow', self.implementation_text)
        self.assertNotIn('fpdev.toolchain.policyflow', self.interface_text)

    def test_checkfpcversionpolicy_delegates_to_policyflow(self):
        section = self.extract_section(self.check_signature)
        self.assertIn('EvaluateToolchainFPCVersionPolicyCore(', section)
        self.assertNotIn('LoadPolicyAuto', section)
        self.assertNotIn('GetPolicyForSource(', section)
        self.assertNotIn('CmpVersion(', section)

    def test_inline_policy_helpers_leave_toolchain_unit(self):
        self.assertNotIn('function EnsurePolicyStore: TStringList;', self.text)
        self.assertNotIn('function LoadPolicyFromFile(const Path: string): boolean;', self.text)
        self.assertNotIn('function LoadPolicyAuto: boolean;', self.text)
        self.assertNotIn(
            'function GetExternalPolicy(const ASource: string; out AMin, ARec, AMatchedKey: string): boolean;',
            self.text,
        )
        self.assertNotIn('function NormalizeVersion(const S: string): string;', self.text)
        self.assertNotIn('function CmpVersion(const A, B: string): Integer;', self.text)
        self.assertNotIn('procedure GetPolicyForSource(const ASource: string; out AMin, ARec: string);', self.text)
        self.assertNotIn('GPolicyLoaded', self.text)
        self.assertNotIn('GPolicyFPC', self.text)


if __name__ == '__main__':
    unittest.main()
