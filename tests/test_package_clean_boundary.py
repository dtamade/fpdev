import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_CLEAN_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.clean.pas'


class PackageCleanBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_CLEAN_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_clean_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackageCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.cleancommandflow', self.command)
        self.assertIn('PreparePackageCleanCommandPlanCore(', section)
        self.assertIn('ExecutePackageCleanCommandPlanCore(', section)

    def test_cli_clean_no_longer_inlines_parse_or_dry_run_dispatch(self):
        section = self._section(
            'function TPackageCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn("HasFlag(AParams, 'dry-run')", section)
        self.assertNotIn("HasFlag(AParams, 'yes')", section)
        self.assertNotIn('CMD_PKG_CLEAN_COMPLETE', section)
        self.assertNotIn('CMD_PKG_CLEAN_ERRORS', section)


if __name__ == '__main__':
    unittest.main()
