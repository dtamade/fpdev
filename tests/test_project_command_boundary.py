import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / 'src'

PROJECT_LIST_COMMAND = SRC / 'fpdev.cmd.project.list.pas'
PROJECT_INFO_COMMAND = SRC / 'fpdev.cmd.project.info.pas'
PROJECT_BUILD_COMMAND = SRC / 'fpdev.cmd.project.build.pas'
PROJECT_TEST_COMMAND = SRC / 'fpdev.cmd.project.test.pas'
PROJECT_CLEAN_COMMAND = SRC / 'fpdev.cmd.project.clean.pas'
PROJECT_NEW_COMMAND = SRC / 'fpdev.cmd.project.new.pas'


class _BaseBoundaryTest(unittest.TestCase):
    command_path: Path
    execute_signature: str

    @classmethod
    def setUpClass(cls):
        cls.command = cls.command_path.read_text(encoding='utf-8')

    @classmethod
    def execute_section(cls) -> str:
        tail = cls.command.split(cls.execute_signature, 1)[1]
        return tail.split('initialization', 1)[0]


class ProjectListBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_LIST_COMMAND
    execute_signature = (
        'function TProjectListCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_list_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.commandflow', self.command)
        self.assertIn('PrepareProjectListCommandPlanCore(', section)
        self.assertIn('ExecuteProjectListCommandPlanCore(', section)

    def test_cli_list_no_longer_inlines_parse_or_json_serialization(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('TJSONObject.Create', section)
        self.assertNotIn('TJSONArray.Create', section)
        self.assertNotIn('TemplateToJson(', section)
        self.assertNotIn('HELP_PROJECT_LIST_USAGE', section)


class ProjectInfoBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_INFO_COMMAND
    execute_signature = (
        'function TProjectInfoCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_info_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.commandflow', self.command)
        self.assertIn('PrepareProjectInfoCommandPlanCore(', section)
        self.assertIn('ExecuteProjectInfoCommandPlanCore(', section)

    def test_cli_info_no_longer_inlines_parse_or_usage_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('HELP_PROJECT_INFO_USAGE', section)


class ProjectBuildBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_BUILD_COMMAND
    execute_signature = (
        'function TProjectBuildCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_build_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.commandflow', self.command)
        self.assertIn('PrepareProjectBuildCommandPlanCore(', section)
        self.assertIn('ExecuteProjectBuildCommandPlanCore(', section)

    def test_cli_build_no_longer_inlines_parse_or_status_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('GetPositionalArg(', section)
        self.assertNotIn('HELP_PROJECT_BUILD_USAGE', section)
        self.assertNotIn('CMD_PROJECT_BUILD_DONE', section)
        self.assertNotIn('CMD_PROJECT_BUILD_FAILED', section)


class ProjectTestBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_TEST_COMMAND
    execute_signature = (
        'function TProjectTestCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_test_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.commandflow', self.command)
        self.assertIn('PrepareProjectTestCommandPlanCore(', section)
        self.assertIn('ExecuteProjectTestCommandPlanCore(', section)

    def test_cli_test_no_longer_inlines_parse_or_usage_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('GetPositionalArg(', section)
        self.assertNotIn('HELP_PROJECT_TEST_USAGE', section)


class ProjectCleanBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_CLEAN_COMMAND
    execute_signature = (
        'function TProjectCleanCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_clean_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.commandflow', self.command)
        self.assertIn('PrepareProjectCleanCommandPlanCore(', section)
        self.assertIn('ExecuteProjectCleanCommandPlanCore(', section)

    def test_cli_clean_no_longer_inlines_parse_or_usage_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('GetPositionalArg(', section)
        self.assertNotIn('HELP_PROJECT_CLEAN_USAGE', section)


class ProjectNewBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_NEW_COMMAND
    execute_signature = (
        'function TProjectNewCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_new_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.commandflow', self.command)
        self.assertIn('PrepareProjectNewCommandPlanCore(', section)
        self.assertIn('ExecuteProjectNewCommandPlanCore(', section)

    def test_cli_new_no_longer_inlines_parse_or_status_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('GetPositionalArg(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('HELP_PROJECT_NEW_USAGE', section)
        self.assertNotIn('CMD_PROJECT_NEW_DONE', section)
        self.assertNotIn('CMD_PROJECT_NEW_FAILED', section)


if __name__ == '__main__':
    unittest.main()
