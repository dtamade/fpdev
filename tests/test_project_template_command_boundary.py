import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / 'src'

PROJECT_TEMPLATE_LIST_COMMAND = SRC / 'fpdev.cmd.project.template.list.pas'
PROJECT_TEMPLATE_INSTALL_COMMAND = SRC / 'fpdev.cmd.project.template.install.pas'
PROJECT_TEMPLATE_REMOVE_COMMAND = SRC / 'fpdev.cmd.project.template.remove.pas'
PROJECT_TEMPLATE_UPDATE_COMMAND = SRC / 'fpdev.cmd.project.template.update.pas'


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


class ProjectTemplateListBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_TEMPLATE_LIST_COMMAND
    execute_signature = (
        'function TProjectTemplateListCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_template_list_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.templatecommandflow', self.command)
        self.assertIn('PrepareProjectTemplateListCommandPlanCore(', section)
        self.assertIn('ExecuteProjectTemplateListCommandPlanCore(', section)

    def test_cli_template_list_no_longer_inlines_parse_or_usage_dispatch(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('CountPositionalArgs(', section)
        self.assertNotIn('Usage: fpdev project template list', section)


class ProjectTemplateInstallBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_TEMPLATE_INSTALL_COMMAND
    execute_signature = (
        'function TProjectTemplateInstallCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_template_install_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.templatecommandflow', self.command)
        self.assertIn('PrepareProjectTemplateInstallCommandPlanCore(', section)
        self.assertIn('ExecuteProjectTemplateInstallCommandPlanCore(', section)

    def test_cli_template_install_no_longer_inlines_parse_or_usage_dispatch(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('MissingArgError(', section)
        self.assertNotIn('GetPositionalArg(', section)
        self.assertNotIn('Usage: fpdev project template install <path>', section)


class ProjectTemplateRemoveBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_TEMPLATE_REMOVE_COMMAND
    execute_signature = (
        'function TProjectTemplateRemoveCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_template_remove_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.templatecommandflow', self.command)
        self.assertIn('PrepareProjectTemplateRemoveCommandPlanCore(', section)
        self.assertIn('ExecuteProjectTemplateRemoveCommandPlanCore(', section)

    def test_cli_template_remove_no_longer_inlines_parse_or_usage_dispatch(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('MissingArgError(', section)
        self.assertNotIn('GetPositionalArg(', section)
        self.assertNotIn('Usage: fpdev project template remove <name>', section)


class ProjectTemplateUpdateBoundaryTests(_BaseBoundaryTest):
    command_path = PROJECT_TEMPLATE_UPDATE_COMMAND
    execute_signature = (
        'function TProjectTemplateUpdateCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_template_update_delegates_parse_and_runtime_to_commandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.project.templatecommandflow', self.command)
        self.assertIn('PrepareProjectTemplateUpdateCommandPlanCore(', section)
        self.assertIn('ExecuteProjectTemplateUpdateCommandPlanCore(', section)

    def test_cli_template_update_no_longer_inlines_parse_or_usage_dispatch(self):
        section = self.execute_section()
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('CountPositionalArgs(', section)
        self.assertNotIn('Usage: fpdev project template update', section)


if __name__ == '__main__':
    unittest.main()
