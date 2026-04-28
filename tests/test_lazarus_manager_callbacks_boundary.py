import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_MANAGER = REPO_ROOT / 'src' / 'fpdev.lazarus.manager.pas'


class LazarusManagerCallbacksBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_MANAGER.read_text(encoding='utf-8')

    def test_manager_imports_installcallbacks_unit(self):
        self.assertIn('fpdev.lazarus.installcallbacks', self.text)

    def test_manager_delegates_download_build_and_setup_helpers(self):
        self.assertIn('DownloadLazarusSourceCore(', self.text)
        self.assertIn('BuildLazarusFromSourceCore(', self.text)
        self.assertIn('SetupLazarusEnvironmentCore(', self.text)
        self.assertNotIn('GitTag := TVersionRegistry.Instance.GetLazarusGitTag(AVersion);', self.text)
        self.assertNotIn('RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;', self.text)
        self.assertNotIn('ToolchainChecker := TBuildToolchainChecker.Create(False);', self.text)
        self.assertNotIn('CreateLazarusBuildPlanCore(', self.text)

    def test_manager_keeps_named_configure_adapter_for_install_plan(self):
        self.assertIn('function RunConfigureIDEWithOutputs(const Outp, Errp: IOutput;', self.text)
        self.assertIn('@RunConfigureIDEWithOutputs', self.text)


if __name__ == '__main__':
    unittest.main()
