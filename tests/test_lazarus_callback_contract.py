import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'


class LazarusCallbackContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_MANAGER.read_text(encoding='utf-8')

    def test_install_version_does_not_pass_overloaded_configure_ide_directly(self):
        self.assertNotRegex(
            self.text,
            re.compile(r'ExecuteLazarusInstallPlanCore\s*\(\s*InstallPlan\s*,.*?@ConfigureIDE\s*\)', re.S),
        )

    def test_install_version_uses_named_configure_ide_adapter(self):
        self.assertIn(
            'function RunConfigureIDEWithOutputs(const Outp, Errp: IOutput;',
            self.text,
        )
        self.assertRegex(
            self.text,
            re.compile(
                r'ExecuteLazarusInstallPlanCore\s*\(\s*InstallPlan\s*,.*?@RunConfigureIDEWithOutputs\s*\)',
                re.S,
            ),
        )
        self.assertRegex(
            self.text,
            re.compile(
                r'function TLazarusManager\.RunConfigureIDEWithOutputs'
                r'\(\s*const Outp, Errp: IOutput;\s*const AVersion: string\s*\)\s*:\s*Boolean;\s*'
                r'begin\s*'
                r'(?:\/\/[^\n]*\s*)*'
                r'Result := ConfigureIDE\(Outp, Errp, AVersion\);\s*'
                r'end;',
                re.S,
            ),
        )


if __name__ == '__main__':
    unittest.main()
