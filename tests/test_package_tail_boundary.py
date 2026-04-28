import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_MANAGER = REPO_ROOT / 'src' / 'fpdev.package.manager.pas'


class PackageTailBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = PACKAGE_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_facade_and_tail_helper_units(self):
        self.assertIn('fpdev.package.facadeflow', self.text)
        self.assertIn('fpdev.package.creation', self.text)
        self.assertIn('fpdev.package.publishflow', self.text)

    def test_manager_no_longer_declares_pure_tail_wrappers(self):
        self.assertNotIn('function EnsurePackageMetadataFile(', self.text)
        self.assertNotIn('function ResolvePublishMetadata(', self.text)
        self.assertNotIn('function HandlePublishMetadataFailure(', self.text)
        self.assertNotIn('function CreatePublishArchive(', self.text)

    def test_create_and_publish_delegate_using_core_helpers(self):
        create_section = self._section(
            'function TPackageManager.CreatePackage(',
            'function TPackageManager.PublishPackage(',
        )
        publish_section = self._section(
            'function TPackageManager.PublishPackage(',
            'function TPackageManager.GetLastPublishExitCode: Integer;',
        )

        self.assertIn('ExecutePackageCreateCore(', create_section)
        self.assertIn('@EnsurePackageMetadataFileCore', create_section)

        self.assertIn('ExecutePackagePublishCore(', publish_section)
        self.assertIn('@TryResolvePublishMetadataCore', publish_section)
        self.assertIn('@HandlePublishMetadataFailureCore', publish_section)
        self.assertIn('@CreatePublishArchiveCore', publish_section)


if __name__ == '__main__':
    unittest.main()
