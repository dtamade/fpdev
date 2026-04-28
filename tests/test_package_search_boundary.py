import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_SEARCH_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.search.pas'


class PackageSearchBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_SEARCH_COMMAND.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_cli_search_delegates_parse_and_runtime_to_commandflow(self):
        section = self._section(
            'function TPackageSearchCmd.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertIn('fpdev.package.searchcommandflow', self.command)
        self.assertIn('PreparePackageSearchCommandPlanCore(', section)
        self.assertIn('ExecutePackageSearchCommandPlanCore(', section)

    def test_cli_search_no_longer_inlines_parse_or_json_serialization(self):
        section = self._section(
            'function TPackageSearchCmd.Execute(const AParams: array of string; const Ctx: IContext): Integer;',
            'initialization',
        )
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('CountPositionalArgs(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('TJSONObject.Create', section)
        self.assertNotIn('TJSONArray.Create', section)
        self.assertNotIn('LJson.Add(', section)


if __name__ == '__main__':
    unittest.main()
