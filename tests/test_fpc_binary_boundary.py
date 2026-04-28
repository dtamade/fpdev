import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC_BINARY = REPO_ROOT / 'src' / 'fpdev.fpc.binary.pas'


class FPCBinaryBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FPC_BINARY.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_binary_installer_imports_binaryflow_unit(self):
        self.assertIn('fpdev.fpc.binaryflow', self.text)

    def test_load_manifest_delegates_to_binaryflow(self):
        section = self._section(
            'function TBinaryInstaller.LoadManifest(const AManifestURL: string): Boolean;',
            'function TBinaryInstaller.DownloadBinary(const AVersion, ADestFile: string): Boolean;',
        )

        self.assertIn('LoadBinaryManifestCore(', section)
        self.assertNotIn('FManifestParser.LoadFromURL(', section)
        self.assertNotIn("WriteLn('Loading manifest from: ", section)
        self.assertNotIn("WriteLn('Manifest loaded successfully')", section)

    def test_download_binary_delegates_to_binaryflow(self):
        section = self._section(
            'function TBinaryInstaller.DownloadBinary(const AVersion, ADestFile: string): Boolean;',
            'function TBinaryInstaller.Install(const AVersion, AInstallDir: string): Boolean;',
        )

        self.assertIn('DownloadBinaryArchiveCore(', section)
        self.assertNotIn('FManifestParser.GetTarget(', section)
        self.assertNotIn('FMirrorManager.GetDownloadURL(', section)
        self.assertNotIn('ParseHashAlgorithm(', section)
        self.assertNotIn('EnsureDownloadedCached(', section)

    def test_install_delegates_orchestration_to_binaryflow(self):
        section = self._section(
            'function TBinaryInstaller.Install(const AVersion, AInstallDir: string): Boolean;',
            'function TBinaryInstaller.IsCached(const AVersion: string): Boolean;',
        )

        self.assertIn('ExecuteBinaryInstallCore(', section)
        self.assertNotIn('FCacheManager.HasArtifacts(', section)
        self.assertNotIn('FCacheManager.RestoreBinaryArtifact(', section)
        self.assertNotIn('FExtractor.Extract(', section)
        self.assertNotIn('RunInstalledFPCVerificationCore(', section)
        self.assertNotIn('WriteBinaryInstallVerificationMetadataCore(', section)


if __name__ == '__main__':
    unittest.main()
