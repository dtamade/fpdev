import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_INFO_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.info.pas'


class PackageInfoBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_INFO_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_info_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackageInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.infocommandflow', self.command)
        self.assertIn('PreparePackageInfoCommandPlanCore(', section)
        self.assertIn('ExecutePackageInfoCommandPlanCore(', section)

    def test_cli_info_no_longer_inlines_parse_or_installed_precheck(self):
        section = self._section(
            'function TPackageInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('InstalledPkgs :=', section)
        self.assertNotIn('IsInstalled :=', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn("Result := EXIT_ERROR;", section)


if __name__ == '__main__':
    unittest.main()
