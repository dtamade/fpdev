import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class FPCBinaryVerifyBoundaryTests(unittest.TestCase):
    def test_binary_installer_uses_shared_verifyflow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.binary.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.verifyflow', source)

    def test_binary_installer_no_longer_embeds_direct_verifier_orchestration(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.binary.pas').read_text(encoding='utf-8')
        self.assertNotIn('FVerifier: TFPCVerifier', source)
        self.assertNotIn('FVerifier := TFPCVerifier.Create', source)
        self.assertNotIn('FVerifier.VerifyVersion(', source)
        self.assertNotIn('FVerifier.CompileHelloWorld(', source)
        self.assertNotIn('FVerifier.GenerateMetadata(', source)
        self.assertIn('RunInstalledFPCVerificationCore(', source)
        self.assertIn('WriteBinaryInstallVerificationMetadataCore(', source)

    def test_legacy_duplicate_verifier_unit_removed(self):
        self.assertFalse((REPO_ROOT / 'src' / 'fpdev.fpc.verifier.pas').exists())


if __name__ == '__main__':
    unittest.main()
