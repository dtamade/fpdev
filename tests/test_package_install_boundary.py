import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_INSTALL_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.install.pas'


class PackageInstallBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = PACKAGE_INSTALL_COMMAND.read_text(encoding='utf-8')

    def test_cli_install_delegates_parse_and_runtime_to_commandflow(self):
        self.assertIn('fpdev.package.installcommandflow', self.command)
        self.assertIn('PreparePackageInstallCommandPlanCore(', self.command)
        self.assertIn('ExecutePackageInstallCommandPlanCore(', self.command)

    def test_cli_install_no_longer_inlines_parse_or_runtime_messages(self):
        self.assertNotIn('FindUnknownOption(', self.command)
        self.assertNotIn('CMD_PKG_INSTALL_DRYRUN_HEADER', self.command)
        self.assertNotIn('CMD_PKG_INSTALL_NODEPS_WARN1', self.command)
        self.assertNotIn('CMD_PKG_NOT_IN_INDEX', self.command)
        self.assertNotIn('AvailablePkgs :=', self.command)


if __name__ == '__main__':
    unittest.main()
