import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'
LAZARUS_COMMANDFLOW = REPO_ROOT / 'src' / 'fpdev.lazarus.commandflow.pas'
LAZARUS_INSTALL_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.lazarus.install.pas'


class LazarusInstallBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manager = LAZARUS_MANAGER.read_text(encoding='utf-8')
        cls.commandflow = LAZARUS_COMMANDFLOW.read_text(encoding='utf-8')
        cls.command = LAZARUS_INSTALL_COMMAND.read_text(encoding='utf-8')

    def test_manager_install_delegates_to_install_plan_helpers(self):
        self.assertIn('CreateLazarusInstallPlanCore(', self.manager)
        self.assertIn('ExecuteLazarusInstallPlanCore(', self.manager)
        self.assertRegex(
            self.manager,
            re.compile(
                r'ExecuteLazarusInstallPlanCore\s*\(\s*InstallPlan\s*,.*?@DownloadSource\s*,\s*@BuildFromSource\s*,\s*@SetupEnvironment\s*,\s*@RunConfigureIDEWithOutputs\s*\)',
                re.S,
            ),
        )

    def test_manager_does_not_own_install_flow_user_messages(self):
        self.assertNotIn('fallback to source build', self.manager)
        self.assertNotIn('fpdev lazarus use ', self.manager)
        self.assertNotIn('fpdev lazarus configure ', self.manager)
        self.assertNotIn('Installation completed!', self.manager)
        self.assertNotIn('CMD_LAZARUS_SOURCE_DOWNLOAD_FAILED', self.manager)
        self.assertNotIn('CMD_LAZARUS_SOURCE_BUILD_FAILED', self.manager)
        self.assertNotIn('CMD_LAZARUS_ENV_SETUP_FAILED', self.manager)

    def test_commandflow_owns_install_followup_and_fallback_messages(self):
        self.assertIn('fallback to source build', self.commandflow)
        self.assertIn('fpdev lazarus configure ', self.commandflow)
        self.assertIn('fpdev lazarus use ', self.commandflow)
        self.assertIn('Installation completed!', self.commandflow)

    def test_cli_install_delegates_parse_and_runtime_to_commandflow(self):
        self.assertIn('fpdev.lazarus.installcommandflow', self.command)
        self.assertIn('PrepareLazarusInstallCommandPlanCore(', self.command)
        self.assertIn('ExecuteLazarusInstallCommandPlanCore(', self.command)

    def test_cli_install_no_longer_inlines_parse_and_help_logic(self):
        self.assertNotIn('GetFlagValue(AParams, \'from\'', self.command)
        self.assertNotIn('GetFlagValue(AParams, \'fpc\'', self.command)
        self.assertNotIn('GetFlagValue(AParams, \'jobs\'', self.command)
        self.assertNotIn('LPositionalCount := 0', self.command)
        self.assertNotIn('HELP_LAZARUS_INSTALL_OPTIONS', self.command)
        self.assertNotIn('CMD_LAZARUS_INSTALL_START', self.command)


if __name__ == '__main__':
    unittest.main()
