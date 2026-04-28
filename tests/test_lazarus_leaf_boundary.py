import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_CURRENT_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.current.pas'
LAZARUS_USE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.use.pas'
LAZARUS_SHOW_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.show.pas'
LAZARUS_CONFIGURE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.configure.pas'
LAZARUS_UNINSTALL_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.uninstall.pas'
LAZARUS_UPDATE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.update.pas'
LAZARUS_TEST_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.test.pas'


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


class LazarusCurrentBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_CURRENT_COMMAND
    execute_signature = (
        'function TLazCurrentCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_current_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusCurrentCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusCurrentCommandPlanCore(', section)

    def test_cli_current_no_longer_inlines_parse_or_json_rendering(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('HELP_LAZARUS_CURRENT_USAGE', section)
        self.assertNotIn('TJSONObject.Create', section)
        self.assertNotIn('LJson.Add(', section)


class LazarusUseBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_USE_COMMAND
    execute_signature = (
        'function TLazUseCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_use_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusUseCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusUseCommandPlanCore(', section)

    def test_cli_use_no_longer_inlines_parse_or_usage_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('HELP_LAZARUS_USE_USAGE', section)


class LazarusShowBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_SHOW_COMMAND
    execute_signature = (
        'function TLazShowCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_show_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusShowCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusShowCommandPlanCore(', section)

    def test_cli_show_no_longer_inlines_parse_or_unsupported_version_message(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('HELP_LAZARUS_SHOW_USAGE', section)
        self.assertNotIn('CMD_LAZARUS_UNSUPPORTED_VERSION', section)


class LazarusConfigureBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_CONFIGURE_COMMAND
    execute_signature = (
        'function TLazConfigureCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_configure_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusConfigureCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusConfigureCommandPlanCore(', section)

    def test_cli_configure_no_longer_inlines_parse_or_start_banner(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('HELP_LAZARUS_CONFIGURE_USAGE', section)
        self.assertNotIn('CMD_LAZARUS_CONFIG_START', section)


class LazarusUninstallBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_UNINSTALL_COMMAND
    execute_signature = (
        'function TLazUninstallCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_uninstall_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusUninstallCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusUninstallCommandPlanCore(', section)

    def test_cli_uninstall_no_longer_inlines_parse_or_generic_failed_message(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('HELP_LAZARUS_UNINSTALL_USAGE', section)
        self.assertNotIn('MSG_FAILED', section)


class LazarusUpdateBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_UPDATE_COMMAND
    execute_signature = (
        'function TLazUpdateCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_update_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusUpdateCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusUpdateCommandPlanCore(', section)

    def test_cli_update_no_longer_inlines_parse_or_usage_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('HELP_LAZARUS_UPDATE_USAGE', section)
        self.assertNotIn('Length(AParams) > 1', section)


class LazarusTestBoundaryTests(_BaseBoundaryTest):
    command_path = LAZARUS_TEST_COMMAND
    execute_signature = (
        'function TLazTestCommand.Execute(const AParams: array of string; '
        'const Ctx: IContext): Integer;'
    )

    def test_cli_test_delegates_parse_and_runtime_to_leafcommandflow(self):
        section = self.execute_section()
        self.assertIn('fpdev.lazarus.leafcommandflow', self.command)
        self.assertIn('PrepareLazarusTestCommandPlanCore(', section)
        self.assertIn('ExecuteLazarusTestCommandPlanCore(', section)

    def test_cli_test_no_longer_inlines_parse_or_usage_messages(self):
        section = self.execute_section()
        self.assertNotIn('HasFlag(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('HELP_LAZARUS_TEST_USAGE', section)


if __name__ == '__main__':
    unittest.main()
