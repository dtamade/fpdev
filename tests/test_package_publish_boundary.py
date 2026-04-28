import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_PUBLISH_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.publish.pas'


class PackagePublishBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_PUBLISH_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_publish_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackagePublishCmd.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.publishcommandflow', self.command)
        self.assertIn('PreparePackagePublishCommandPlanCore(', section)
        self.assertIn('ExecutePackagePublishCommandPlanCore(', section)

    def test_cli_publish_no_longer_inlines_parse_or_runtime_checks(self):
        section = self._section(
            'function TPackagePublishCmd.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('InstalledPkgs :=', section)
        self.assertNotIn('MetadataPath :=', section)
        self.assertNotIn('CMD_PKG_META_NOT_FOUND', section)
        self.assertNotIn('Result := LMgr.GetLastPublishExitCode;', section)


if __name__ == '__main__':
    unittest.main()
