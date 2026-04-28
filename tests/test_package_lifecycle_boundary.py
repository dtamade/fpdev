import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_UPDATE_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.update.pas'
PACKAGE_UNINSTALL_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.uninstall.pas'
PACKAGE_INSTALL_LOCAL_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.package.install_local.pas'


class PackageLifecycleBoundaryTests(unittest.TestCase):
    @staticmethod
    def _section(source: str) -> str:
        tail = source.split(
            'function',
            1,
        )[1]
        return tail.split('initialization', 1)[0]

    def test_cli_update_delegates_parse_and_runtime_to_commandflow(self):
        source = PACKAGE_UPDATE_COMMAND.read_text(encoding='utf-8')
        section = self._section(source)
        self.assertIn('fpdev.package.lifecyclecommandflow', source)
        self.assertIn('PreparePackageUpdateCommandPlanCore(', section)
        self.assertIn('ExecutePackageUpdateCommandPlanCore(', section)

    def test_cli_update_no_longer_inlines_parse_or_package_prechecks(self):
        source = PACKAGE_UPDATE_COMMAND.read_text(encoding='utf-8')
        section = self._section(source)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('InstalledPkgs :=', section)
        self.assertNotIn('AvailablePkgs :=', section)
        self.assertNotIn('CMD_PKG_NOT_INSTALLED', section)
        self.assertNotIn('CMD_PKG_NOT_IN_INDEX', section)

    def test_cli_uninstall_delegates_parse_and_runtime_to_commandflow(self):
        source = PACKAGE_UNINSTALL_COMMAND.read_text(encoding='utf-8')
        section = self._section(source)
        self.assertIn('fpdev.package.lifecyclecommandflow', source)
        self.assertIn('PreparePackageUninstallCommandPlanCore(', section)
        self.assertIn('ExecutePackageUninstallCommandPlanCore(', section)

    def test_cli_uninstall_no_longer_inlines_parse_or_installed_precheck(self):
        source = PACKAGE_UNINSTALL_COMMAND.read_text(encoding='utf-8')
        section = self._section(source)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('InstalledPkgs :=', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('CMD_PKG_NOT_INSTALLED', section)

    def test_cli_install_local_delegates_parse_and_runtime_to_commandflow(self):
        source = PACKAGE_INSTALL_LOCAL_COMMAND.read_text(encoding='utf-8')
        section = self._section(source)
        self.assertIn('fpdev.package.lifecyclecommandflow', source)
        self.assertIn('PreparePackageInstallLocalCommandPlanCore(', section)
        self.assertIn('ExecutePackageInstallLocalCommandPlanCore(', section)

    def test_cli_install_local_no_longer_inlines_parse_or_path_precheck(self):
        source = PACKAGE_INSTALL_LOCAL_COMMAND.read_text(encoding='utf-8')
        section = self._section(source)
        self.assertNotIn('FindUnknownOption(', section)
        self.assertNotIn('DirectoryExists(', section)
        self.assertNotIn('_Fmt(ERR_MISSING_ARGUMENT', section)
        self.assertNotIn('CMD_PKG_PATH_NOT_FOUND', section)


if __name__ == '__main__':
    unittest.main()
