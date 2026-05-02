import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CROSS_DOWNLOADER = REPO_ROOT / 'src' / 'fpdev.cross.downloader.pas'


class CrossDownloaderBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CROSS_DOWNLOADER.read_text(encoding='utf-8')
        interface_text, implementation_text = cls.text.split('implementation', 1)
        cls.interface_text = interface_text
        cls.implementation_text = implementation_text
        verify_start = cls.text.index('function TCrossToolchainDownloader.VerifyInstallation(const ATarget: string): TCrossVerificationResult;')
        cls.verify_section = cls.text[verify_start:]

    def test_downloader_implementation_imports_verifyflow_unit(self):
        self.assertIn('fpdev.cross.verifyflow', self.implementation_text)
        self.assertNotIn('fpdev.cross.verifyflow', self.interface_text)

    def test_verifyinstallation_delegates_to_verifyflow(self):
        self.assertIn('VerifyCrossBinutilsInstallationCore(', self.verify_section)
        self.assertNotIn("RequiredBins[0] := 'ld';", self.verify_section)
        self.assertNotIn('ExecuteVersionCheck(LdPath)', self.verify_section)
        self.assertNotIn('UpdateVerificationMetadata(ATarget, Entry.Version, Entry.SHA256, True);', self.verify_section)

    def test_downloader_no_longer_declares_inline_verification_helpers(self):
        self.assertNotIn('function ExecuteVersionCheck(const ABinaryPath: string): string;', self.text)
        self.assertNotIn('procedure UpdateVerificationMetadata(const ATarget, AVersion, ASHA256: string; AVerified: Boolean);', self.text)
        self.assertNotIn('function LoadJSONFromFile(const APath: string): TJSONObject;', self.text)


if __name__ == '__main__':
    unittest.main()
