import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_LIST_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.list.pas'


class PackageListBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_LIST_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_list_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackageListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.listcommandflow', self.command)
        self.assertIn('PreparePackageListCommandPlanCore(', section)
        self.assertIn('ExecutePackageListCommandPlanCore(', section)

    def test_cli_list_no_longer_inlines_parse_or_json_serialization(self):
        section = self._section(
            'function TPackageListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn("HasFlag(AParams, 'all')", section)
        self.assertNotIn("HasFlag(AParams, 'json')", section)
        self.assertNotIn('TJSONObject.Create', section)
        self.assertNotIn('TJSONArray.Create', section)
        self.assertNotIn('PackageInfoToJson(', section)


if __name__ == '__main__':
    unittest.main()
