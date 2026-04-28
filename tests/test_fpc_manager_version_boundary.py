import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_MANAGER = REPO_ROOT / 'src' / 'fpdev.fpc.manager.pas'


class FPCManagerVersionBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_MANAGER.read_text(encoding='utf-8')
        list_start = cls.text.index('function TFPCManager.ListVersions(const Outp: IOutput;')
        set_start = cls.text.index('function TFPCManager.SetDefaultVersion(const AVersion: string): Boolean;')
        activate_start = cls.text.index('function TFPCManager.ActivateVersion(const AVersion: string): TActivationResult;')
        update_start = cls.text.index('function TFPCManager.UpdateSources', activate_start)
        cls.list_body = cls.text[list_start:set_start]
        cls.setdefault_body = cls.text[set_start:activate_start]
        cls.activate_body = cls.text[activate_start:update_start]

    def test_manager_imports_shared_versionflow_unit(self):
        self.assertIn('fpdev.fpc.versionflow', self.text)

    def test_manager_listversions_delegates_to_shared_flow(self):
        self.assertIn('WriteManagedFPCVersionListCore(', self.list_body)
        self.assertNotIn('for i := 0 to High(Versions) do', self.list_body)
        self.assertNotIn("Line := Format('%-8s  '", self.list_body)

    def test_manager_setdefault_delegates_to_shared_flow(self):
        self.assertIn('SetManagedFPCDefaultVersionCore(', self.setdefault_body)
        self.assertNotIn("SetDefaultToolchain('fpc-' + AVersion)", self.setdefault_body)

    def test_manager_activateversion_delegates_to_shared_flow(self):
        self.assertIn('ActivateManagedFPCVersionCore(', self.activate_body)
        self.assertNotIn("BinPath := InstallPath + PathDelim + 'bin';", self.activate_body)
        self.assertNotIn('Result := FActivationMgr.ActivateVersion(AVersion, BinPath);', self.activate_body)


if __name__ == '__main__':
    unittest.main()
