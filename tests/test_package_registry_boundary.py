import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_REGISTRY = REPO_ROOT / 'src' / 'fpdev.package.registry.pas'


class PackageRegistryBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = PACKAGE_REGISTRY.read_text(encoding='utf-8')
        interface_text, implementation_text = cls.text.split('implementation', 1)
        cls.interface_text = interface_text
        cls.implementation_text = implementation_text

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_registry_implementation_imports_queryflow_unit(self):
        self.assertIn('fpdev.package.registry.queryflow', self.implementation_text)
        self.assertNotIn('fpdev.package.registry.queryflow', self.interface_text)

    def test_getpackagemetadata_delegates_to_queryflow(self):
        section = self._section(
            'function TPackageRegistry.GetPackageMetadata(const AName: string): TJSONObject;',
            'function TPackageRegistry.GetPackageVersions(const AName: string): TStringList;',
        )
        self.assertIn('GetPackageMetadataCore(', section)
        self.assertNotIn("Packages := FIndex.Objects['packages'];", section)
        self.assertNotIn('TJSONObject(Packages.Objects[AName].Clone)', section)

    def test_query_methods_delegate_to_queryflow(self):
        versions_section = self._section(
            'function TPackageRegistry.GetPackageVersions(const AName: string): TStringList;',
            'function TPackageRegistry.HasPackage(const AName: string): Boolean;',
        )
        has_section = self._section(
            'function TPackageRegistry.HasPackage(const AName: string): Boolean;',
            'function TPackageRegistry.HasPackageVersion(const AName, AVersion: string): Boolean;',
        )
        has_version_section = self._section(
            'function TPackageRegistry.HasPackageVersion(const AName, AVersion: string): Boolean;',
            'function TPackageRegistry.GetPackageArchive(const AName, AVersion: string): string;',
        )
        archive_section = self._section(
            'function TPackageRegistry.GetPackageArchive(const AName, AVersion: string): string;',
            'function TPackageRegistry.ListPackages: TStringList;',
        )
        list_section = self._section(
            'function TPackageRegistry.ListPackages: TStringList;',
            'function TPackageRegistry.SearchPackages(const AQuery: string): TStringList;',
        )
        search_section = self._section(
            'function TPackageRegistry.SearchPackages(const AQuery: string): TStringList;',
            'function TPackageRegistry.GetLastError: string;',
        )

        self.assertIn('GetPackageVersionsCore(', versions_section)
        self.assertNotIn('for I := 0 to Versions.Count - 1 do', versions_section)

        self.assertIn('HasPackageCore(', has_section)
        self.assertNotIn("Packages := FIndex.Objects['packages'];", has_section)

        self.assertIn('HasPackageVersionCore(', has_version_section)
        self.assertNotIn('Versions.IndexOf(AVersion) >= 0', has_version_section)

        self.assertIn('GetPackageArchiveCore(', archive_section)
        self.assertNotIn("Result := PackagePath + PathDelim + AName + '-' + AVersion + '.tar.gz';", archive_section)

        self.assertIn('ListPackagesCore(', list_section)
        self.assertNotIn('for I := 0 to Packages.Count - 1 do', list_section)

        self.assertIn('SearchPackagesCore(', search_section)
        self.assertNotIn('LowerQuery := LowerCase(AQuery);', search_section)
        self.assertNotIn('Pos(LowerQuery, LowerCase(Description)) > 0', search_section)


if __name__ == '__main__':
    unittest.main()
