import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'


class LazarusManagerVersionBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_MANAGER.read_text(encoding='utf-8')
        list_start = cls.text.index('function TLazarusManager.ListVersions(const Outp: IOutput;')
        set_start = cls.text.index('function TLazarusManager.SetDefaultVersion(const AVersion: string): Boolean;')
        current_start = cls.text.index('function TLazarusManager.GetCurrentVersion: string;')
        update_start = cls.text.index('function TLazarusManager.UpdateSources', current_start)
        show_start = cls.text.index('function TLazarusManager.ShowVersionInfo(const Outp: IOutput;')
        test_start = cls.text.index('function TLazarusManager.TestInstallation', show_start)
        cls.list_body = cls.text[list_start:set_start]
        cls.setdefault_body = cls.text[set_start:current_start]
        cls.current_body = cls.text[current_start:update_start]
        cls.show_body = cls.text[show_start:test_start]

    def test_manager_imports_versionflow_unit(self):
        self.assertIn('fpdev.lazarus.versionflow', self.text)

    def test_manager_listversions_delegates_to_shared_helper(self):
        self.assertIn('WriteManagedLazarusVersionListCore(', self.list_body)
        self.assertNotIn('for i := 0 to High(Versions) do', self.list_body)
        self.assertNotIn("Line := Format('%-8s  '", self.list_body)
        self.assertNotIn("StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll])", self.list_body)

    def test_manager_setdefault_delegates_to_shared_helper(self):
        self.assertIn('SetManagedLazarusDefaultVersionCore(', self.setdefault_body)
        self.assertNotIn("SetDefaultLazarusVersion('lazarus-' + AVersion)", self.setdefault_body)
        self.assertNotIn('if not IsVersionInstalled(AVersion) then', self.setdefault_body)

    def test_manager_getcurrentversion_delegates_to_shared_helper(self):
        self.assertIn('NormalizeDefaultLazarusVersionCore(', self.current_body)
        self.assertNotIn("StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll])", self.current_body)

    def test_manager_showversioninfo_delegates_to_shared_helper(self):
        self.assertIn('ShowManagedLazarusVersionInfoCore(', self.show_body)
        self.assertNotIn("Format('Version:      %s'", self.show_body)
        self.assertNotIn('TryFindLazarusVersionInfoCore(AllVersions, AVersion, VersionInfo)', self.show_body)


if __name__ == '__main__':
    unittest.main()
