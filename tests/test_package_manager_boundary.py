import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_MANAGER = REPO_ROOT / 'src' / 'fpdev.package.manager.pas'


class PackageManagerBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = PACKAGE_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_managerflow_unit(self):
        self.assertIn('fpdev.package.managerflow', self.text)

    def test_install_from_source_delegates_to_managerflow(self):
        section = self._section(
            'function TPackageManager.InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;',
            'function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;',
        )
        self.assertIn('ExecutePackageInstallFromSourceCore(', section)
        self.assertNotIn('PreparePackageInstallSourceTreeCore(', section)
        self.assertNotIn('InstallPreparedPackageSourceCore(', section)

    def test_dependency_methods_delegate_to_managerflow(self):
        resolve_section = self._section(
            'function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;',
            'function TPackageManager.InstallPackage(',
        )
        show_section = self._section(
            'function TPackageManager.ShowPackageDependencies(const APackageName: string): Boolean;',
            'function TPackageManager.VerifyPackage(',
        )

        self.assertIn('ResolvePackageDependenciesCore(', resolve_section)
        self.assertNotIn('PackageArrayToDepDescriptorsCore(', resolve_section)

        self.assertIn('WritePackageDependencyLinesCore(', show_section)
        self.assertNotIn('if Length(Dependencies) = 0 then', show_section)


if __name__ == '__main__':
    unittest.main()
