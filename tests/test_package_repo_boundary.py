import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_REPO_ADD_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.repo.add.pas'
PACKAGE_REPO_LIST_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.repo.list.pas'
PACKAGE_REPO_REMOVE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.repo.remove.pas'
PACKAGE_REPO_UPDATE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.repo.update.pas'


class _BaseBoundaryTest(unittest.TestCase):
    command_path: Path
    execute_signature: str

    @classmethod
    def setUpClass(cls):
        cls.command = cls.command_path.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.command.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def execute_section(self) -> str:
        return self._section(self.execute_signature, 'initialization')


class PackageRepoAddBoundaryTests(_BaseBoundaryTest):
    command_path = PACKAGE_REPO_ADD_COMMAND
    execute_signature = (
        'function TPackageRepoAddCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_repo_add_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.package.repocommandflow', self.command)
        self.assertIn('PreparePackageRepoAddCommandPlanCore(', section)
        self.assertIn('ExecutePackageRepoAddCommandPlanCore(', section)

    def test_cli_repo_add_no_longer_inlines_parse_or_duplicate_precheck_messages(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('MSG_ALREADY_EXISTS', section)
        self.assertNotIn('HELP_PACKAGE_REPO_ADD_USAGE', section)


class PackageRepoListBoundaryTests(_BaseBoundaryTest):
    command_path = PACKAGE_REPO_LIST_COMMAND
    execute_signature = (
        'function TPackageRepoListCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_repo_list_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.package.repocommandflow', self.command)
        self.assertIn('PreparePackageRepoListCommandPlanCore(', section)
        self.assertIn('ExecutePackageRepoListCommandPlanCore(', section)

    def test_cli_repo_list_no_longer_inlines_parse_or_usage_dispatch(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('HELP_PACKAGE_REPO_LIST_USAGE', section)
        self.assertNotIn('HELP_PACKAGE_REPO_LIST_DESC', section)


class PackageRepoRemoveBoundaryTests(_BaseBoundaryTest):
    command_path = PACKAGE_REPO_REMOVE_COMMAND
    execute_signature = (
        'function TPackageRepoRemoveCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_repo_remove_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.package.repocommandflow', self.command)
        self.assertIn('PreparePackageRepoRemoveCommandPlanCore(', section)
        self.assertIn('ExecutePackageRepoRemoveCommandPlanCore(', section)

    def test_cli_repo_remove_no_longer_inlines_parse_or_not_found_precheck_messages(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('CMD_REPO_NOT_FOUND', section)
        self.assertNotIn('HELP_PACKAGE_REPO_REMOVE_USAGE', section)


class PackageRepoUpdateBoundaryTests(_BaseBoundaryTest):
    command_path = PACKAGE_REPO_UPDATE_COMMAND
    execute_signature = (
        'function TPackageRepoUpdateCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_repo_update_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.package.repocommandflow', self.command)
        self.assertIn('PreparePackageRepoUpdateCommandPlanCore(', section)
        self.assertIn('ExecutePackageRepoUpdateCommandPlanCore(', section)

    def test_cli_repo_update_no_longer_inlines_parse_or_usage_dispatch(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('HELP_PACKAGE_REPO_UPDATE_USAGE', section)
        self.assertNotIn('HELP_PACKAGE_REPO_UPDATE_DESC', section)


if __name__ == '__main__':
    unittest.main()
