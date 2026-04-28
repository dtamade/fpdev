import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_WHY_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.why.pas'


class PackageWhyBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_WHY_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_why_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackageWhyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.whycommandflow', self.command)
        self.assertIn('PreparePackageWhyCommandPlanCore(', section)
        self.assertIn('ExecutePackageWhyCommandPlanCore(', section)

    def test_cli_why_no_longer_inlines_parse_or_output_rendering(self):
        section = self._section(
            'function TPackageWhyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn("HasFlag(AParams, 'help')", section)
        self.assertNotIn('CMD_PKG_WHY_HEADER', section)
        self.assertNotIn('CMD_PKG_WHY_REQUIRED_BY', section)
        self.assertNotIn('ERR_MISSING_ARGUMENT', section)


if __name__ == '__main__':
    unittest.main()
