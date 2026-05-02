import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_CACHE = REPO_ROOT / 'src' / 'fpdev.build.cache.pas'


class BuildCacheBinaryArtifactBoundaryTests(unittest.TestCase):
    signatures = [
        'function TBuildCache.SaveBinaryArtifact(const AVersion, ADownloadedFile: string; const ASHA256: string = \'\'): Boolean;',
        'function TBuildCache.RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;',
        'function TBuildCache.GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;',
    ]

    @classmethod
    def setUpClass(cls):
        cls.text = BUILD_CACHE.read_text(encoding='utf-8')

    @classmethod
    def section(cls, signature: str) -> str:
        pattern = re.compile(
            rf"{re.escape(signature)}(.*?)(?=\nfunction TBuildCache\.|\nprocedure TBuildCache\.|\n\{{ )",
            re.S,
        )
        match = pattern.search(cls.text)
        if not match:
            raise AssertionError(f'missing section for {signature}')
        return match.group(0)

    def test_build_cache_imports_binaryartifactflow(self):
        self.assertIn('fpdev.build.cache.binaryartifactflow', self.text)

    def test_binary_artifact_surface_delegates_to_helper(self):
        save_section = self.section(self.signatures[0])
        restore_section = self.section(self.signatures[1])
        info_section = self.section(self.signatures[2])

        self.assertIn('BuildCacheSaveBinaryArtifactCore(', save_section)
        self.assertNotIn('BuildCacheResolveBinaryFileExt(', save_section)
        self.assertNotIn('BuildCacheSaveBinaryMeta(', save_section)

        self.assertIn('BuildCacheRestoreBinaryArtifactCore(', restore_section)
        self.assertNotIn('BuildCacheBuildBinaryRestorePlan(', restore_section)
        self.assertNotIn("WriteLn('Error: Cache integrity verification failed", restore_section)
        self.assertNotIn("RunCommand('tar'", restore_section)

        self.assertIn('BuildCacheGetBinaryArtifactInfoCore(', info_section)
        self.assertNotIn('BuildCacheLoadBinaryMeta(', info_section)
        self.assertNotIn('BuildCacheCreateBinaryArtifactInfo(', info_section)

    def test_hasartifacts_and_verify_surface_stay_in_build_cache(self):
        has_artifacts = self.section(
            'function TBuildCache.HasArtifacts(const AVersion: string): Boolean;'
        )
        calc_hash = self.section(
            'function TBuildCache.CalculateSHA256(const AFilePath: string): string;'
        )
        verify = self.section(
            'function TBuildCache.VerifyArtifact(const AArchivePath, AExpectedHash: string): Boolean;'
        )

        self.assertIn('BuildCacheHasArtifactFiles(', has_artifacts)
        self.assertNotIn('BuildCacheHasBinaryArtifactsCore(', has_artifacts)

        self.assertIn('BuildCacheCalculateSHA256(', calc_hash)
        self.assertNotIn('BuildCacheCalculateBinaryArtifactSHA256Core(', calc_hash)

        self.assertIn('BuildCacheVerifyFileHash(', verify)
        self.assertNotIn('BuildCacheVerifyBinaryArtifactCore(', verify)


if __name__ == '__main__':
    unittest.main()
