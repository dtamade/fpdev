import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_USE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.fpc.use.pas'


class FPCUseBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = FPC_USE_COMMAND.read_text(encoding='utf-8')

    def test_cli_use_delegates_plan_and_runtime_to_commandflow(self):
        self.assertIn('fpdev.fpc.usecommandflow', self.command)
        self.assertIn('PrepareFPCUseCommandPlanCore(', self.command)
        self.assertIn('ExecuteFPCUseCommandPlanCore(', self.command)

    def test_cli_use_no_longer_inlines_config_or_activation_reporting(self):
        self.assertNotIn('TProjectConfigResolver.Create', self.command)
        self.assertNotIn('ResolveVersionAlias(', self.command)
        self.assertNotIn('ResolveConfig(', self.command)
        self.assertNotIn('FPC ' + "' + LVer + '" + ' is not installed. Installing...', self.command)
        self.assertNotIn('CMD_FPC_USE_ACTIVATED', self.command)
        self.assertNotIn('CMD_FPC_USE_SCRIPT_CREATED', self.command)


if __name__ == '__main__':
    unittest.main()
