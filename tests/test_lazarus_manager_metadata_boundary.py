import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'


class LazarusManagerMetadataBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_MANAGER.read_text(encoding='utf-8')
        compat_start = cls.text.index('function TLazarusManager.GetCompatibleFPCVersion')
        available_start = cls.text.index('function TLazarusManager.GetAvailableVersions')
        installed_start = cls.text.index('function TLazarusManager.GetInstalledVersions')
        download_start = cls.text.index('function TLazarusManager.DownloadSource')
        cls.compat_body = cls.text[compat_start:available_start]
        cls.available_body = cls.text[available_start:installed_start]
        cls.installed_body = cls.text[installed_start:download_start]

    def test_manager_imports_metadataflow_types_and_catalogflow_units(self):
        self.assertIn('fpdev.lazarus.metadataflow', self.text)
        self.assertIn('fpdev.lazarus.types', self.text)
        self.assertIn('fpdev.lazarus.catalogflow', self.text)

    def test_manager_delegates_configured_version_info_building(self):
        self.assertIn('BuildConfiguredLazarusVersionInfoCore(', self.text)
        self.assertNotIn('Delete(NormalizedFPCVersion, 1, 4);', self.text)

    def test_manager_delegates_compatible_fpc_resolution_to_catalogflow(self):
        self.assertIn('ResolveManagedLazarusCompatibleFPCVersionCore(', self.compat_body)
        self.assertNotIn('TVersionRegistry.Instance.GetLazarusRecommendedFPC(ALazarusVersion)', self.compat_body)
        self.assertNotIn('Trim(ConfiguredInfo.FPCVersion)', self.compat_body)

    def test_manager_delegates_available_versions_surface_to_catalogflow(self):
        self.assertIn('BuildManagedLazarusAvailableVersionsCore(', self.available_body)
        self.assertNotIn('for i := 0 to High(Releases) do', self.available_body)
        self.assertNotIn("ConfiguredVersions := FConfigManager.GetLazarusManager.ListLazarusVersions;", self.available_body)
        self.assertNotIn("SameText(Copy(ConfiguredVersion, 1, PrefixLength), 'lazarus-')", self.available_body)

    def test_manager_delegates_installed_versions_surface_to_catalogflow(self):
        self.assertIn('FilterManagedInstalledLazarusVersionsCore(', self.installed_body)
        self.assertNotIn('FilterInstalledLazarusVersionsCore(GetAvailableVersions)', self.installed_body)


if __name__ == '__main__':
    unittest.main()
