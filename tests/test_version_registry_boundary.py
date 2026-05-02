import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VERSION_REGISTRY = REPO_ROOT / 'src' / 'fpdev.version.registry.pas'


class VersionRegistryBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = VERSION_REGISTRY.read_text(encoding='utf-8')
        interface_text, implementation_text = cls.text.split('implementation', 1)
        cls.interface_text = interface_text
        cls.implementation_text = implementation_text
        reload_start = cls.text.index('function TVersionRegistry.Reload: Boolean;')
        fpc_releases_start = cls.text.index('function TVersionRegistry.GetFPCReleases: TFPCReleaseArray;')
        cls.reload_body = cls.text[reload_start:fpc_releases_start]

    def test_registry_implementation_imports_loadflow_unit(self):
        self.assertIn('fpdev.version.registry.loadflow', self.implementation_text)
        self.assertNotIn('fpdev.version.registry.loadflow', self.interface_text)

    def test_reload_delegates_to_shared_loadflow(self):
        self.assertIn('TryLoadVersionRegistryDataCore(', self.reload_body)
        self.assertNotIn('SearchPaths[0] := FDataPath;', self.reload_body)
        self.assertNotIn('LoadFromJSON(SearchPaths[i]);', self.reload_body)
        self.assertNotIn('LoadDefaults;', self.reload_body)

    def test_registry_no_longer_declares_inline_parse_helpers(self):
        self.assertNotIn('procedure LoadFromJSON(const APath: string);', self.text)
        self.assertNotIn('procedure LoadDefaults;', self.text)
        self.assertNotIn('procedure ParseFPCReleases(AArray: TJSONArray);', self.text)
        self.assertNotIn('procedure ParseLazarusReleases(AArray: TJSONArray);', self.text)
        self.assertNotIn('procedure ParseBootstrapMap(AObj: TJSONObject);', self.text)


if __name__ == '__main__':
    unittest.main()
