import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_CACHE = REPO_ROOT / 'src' / 'fpdev.build.cache.pas'


class BuildCacheSourceArtifactBoundaryTests(unittest.TestCase):
    signatures = [
        'function TBuildCache.SaveArtifacts(const AVersion, AInstallPath: string): Boolean;',
        'function TBuildCache.RestoreArtifacts(const AVersion, ADestPath: string): Boolean;',
        'function TBuildCache.GetArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;',
        'function TBuildCache.DeleteArtifacts(const AVersion: string): Boolean;',
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

    def test_build_cache_imports_sourceartifactflow(self):
        self.assertIn('fpdev.build.cache.sourceartifactflow', self.text)

    def test_save_restore_info_delete_delegate_to_sourceartifactflow(self):
        save_section = self.section(self.signatures[0])
        restore_section = self.section(self.signatures[1])
        info_section = self.section(self.signatures[2])
        delete_section = self.section(self.signatures[3])

        self.assertIn('BuildCacheSaveSourceArtifactsCore(', save_section)
        self.assertNotIn("RunCommand('tar'", save_section)
        self.assertNotIn('BuildCacheSaveOldMeta(', save_section)

        self.assertIn('BuildCacheRestoreSourceArtifactsCore(', restore_section)
        self.assertNotIn("RunCommand('tar'", restore_section)
        self.assertNotIn("'Cache integrity verification failed'", restore_section)

        self.assertIn('BuildCacheGetSourceArtifactInfoCore(', info_section)
        self.assertNotIn('BuildCacheLoadOldMeta(', info_section)
        self.assertNotIn('BuildCacheCreateSourceArtifactInfo(', info_section)

        self.assertIn('BuildCacheDeleteSourceArtifactsCore(', delete_section)
        self.assertNotIn('BuildCacheDeleteArtifactFiles(', delete_section)

    def test_hasartifacts_stays_in_build_cache(self):
        section = self.section('function TBuildCache.HasArtifacts(const AVersion: string): Boolean;')
        self.assertIn('BuildCacheHasArtifactFiles(', section)
        self.assertNotIn('BuildCacheHasSourceArtifactsCore(', section)


if __name__ == '__main__':
    unittest.main()
