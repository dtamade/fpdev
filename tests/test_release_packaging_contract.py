import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CI_WORKFLOW = REPO_ROOT / '.github' / 'workflows' / 'ci.yml'
PACKAGE_ENTRYPOINT = REPO_ROOT / 'scripts' / 'package_release_asset.sh'


class ReleasePackagingContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CI_WORKFLOW.read_text(encoding='utf-8')

    def test_shared_packaging_entrypoint_exists(self):
        self.assertTrue(PACKAGE_ENTRYPOINT.exists(), f'Missing {PACKAGE_ENTRYPOINT}')

    def test_ci_uses_shared_packaging_entrypoint_for_linux_and_matrix_jobs(self):
        self.assertGreaterEqual(
            self.text.count('scripts/package_release_asset.sh'),
            2,
            'CI should route both Linux and matrix release packaging through the shared entrypoint',
        )

    def test_ci_no_longer_inlines_release_asset_packaging_block(self):
        inline_pattern = re.compile(
            r'rm -rf release-assets\s+.*package_release_assets\.py',
            flags=re.MULTILINE | re.DOTALL,
        )
        self.assertIsNone(
            inline_pattern.search(self.text),
            'CI should stop inlining rm -rf release-assets plus package_release_assets.py blocks',
        )


if __name__ == '__main__':
    unittest.main()
