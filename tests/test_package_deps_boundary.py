import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_DEPS_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.deps.pas'


class PackageDepsBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_DEPS_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_deps_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackageDepsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.depscommandflow', self.command)
        self.assertIn('PreparePackageDepsCommandPlanCore(', section)
        self.assertIn('ExecutePackageDepsCommandPlanCore(', section)

    def test_cli_deps_no_longer_inlines_parse_or_tree_rendering(self):
        section = self._section(
            'function TPackageDepsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn("HasFlag(AParams, 'flat')", section)
        self.assertNotIn('GetFlagValue(AParams, ''depth''', section)
        self.assertNotIn('PrintDepTree(', section)
        self.assertNotIn('CMD_PKG_DEPS_TOTAL', section)


if __name__ == '__main__':
    unittest.main()
