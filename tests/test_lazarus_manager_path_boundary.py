import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'


class LazarusManagerPathBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_MANAGER.read_text(encoding='utf-8')

    def test_manager_imports_pathflow_unit(self):
        self.assertIn('fpdev.lazarus.pathflow', self.text)

    def test_manager_delegates_install_path_and_executable_path_helpers(self):
        self.assertIn('BuildLazarusVersionInstallPathCore(', self.text)
        self.assertIn('BuildLazarusExecutablePathFromInstallPathCore(', self.text)
        self.assertNotIn("Result := FInstallRoot + PathDelim + 'lazarus' + PathDelim + AVersion;", self.text)
        self.assertNotIn("Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'lazarus-ide';", self.text)
        self.assertNotIn("Result := AInstallPath + PathDelim + 'lazarus.exe';", self.text)

    def test_manager_delegates_resolved_path_and_install_state(self):
        self.assertIn('ResolveLazarusInstallPathCore(', self.text)
        self.assertIn('IsLazarusVersionInstalledCore(', self.text)
        self.assertNotRegex(
            self.text,
            re.compile(r'if FileExists\(GetExecutablePathFromInstallPath\(ConfiguredPath\)\) then', re.S),
        )
        self.assertNotIn(
            'Result := FileExists(GetExecutablePathFromInstallPath(GetResolvedInstallPath(AVersion)));',
            self.text,
        )


if __name__ == '__main__':
    unittest.main()
