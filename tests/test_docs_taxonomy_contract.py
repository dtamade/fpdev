import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = REPO_ROOT / 'docs'
HISTORY_DIR = DOCS_DIR / 'history'
INTERNAL_DIR = DOCS_DIR / 'internal'

PUBLIC_ROOT_DOCS = [
    'API.md',
    'API.en.md',
    'ARCHITECTURE.md',
    'ARCHITECTURE.en.md',
    'ERROR_HANDLING_GUIDE.md',
    'FAQ.md',
    'FAQ.en.md',
    'FPC_MANAGEMENT.md',
    'FPC_MANAGEMENT.en.md',
    'FPDEVRC_SPEC.md',
    'FPDEVRC_SPEC.en.md',
    'FPDEV_TOML_SPEC.md',
    'FPDEV_TOML_SPEC.en.md',
    'GIT2_USAGE.md',
    'GIT2_USAGE.en.md',
    'INSTALLATION.md',
    'INSTALLATION.en.md',
    'KNOWN_LIMITATIONS.md',
    'LIBGIT2_INTEGRATION.md',
    'LIBGIT2_INTEGRATION.en.md',
    'MANIFEST-USAGE.md',
    'MVP_ACCEPTANCE_CRITERIA.md',
    'MVP_ACCEPTANCE_CRITERIA.en.md',
    'QUICKSTART.md',
    'QUICKSTART.en.md',
    'REPO_ARCHITECTURE.md',
    'REPO_ARCHITECTURE.en.md',
    'REPO_SPECIFICATION.md',
    'REPO_SPECIFICATION.en.md',
    'ROADMAP.md',
    'build-manager.md',
    'build-manager.en.md',
    'config-architecture.md',
    'config-architecture.en.md',
    'manifest-spec.md',
    'testing.md',
    'toolchain.md',
    'toolchain.en.md',
    '测试基建规范.md',
]

HISTORY_DOCS = [
    'ARCHITECTURE_REVIEW.md',
    'B165-i18n-retrospective.md',
    'B166-deprecated-cleanup.md',
    'B167-cross-split-analysis.md',
    'B171-large-files-report.md',
    'B172-week11-retrospective.md',
    'DEPRECATED_CODE_AUDIT.md',
    'DEVELOPMENT_ROADMAP.md',
    'DEVELOPMENT_ROADMAP.en.md',
    'LIBGIT2_DYNAMIC.md',
    'M1_GIT_HARDENING.md',
    'MANIFEST-MIGRATION.md',
    'PACKAGE_CREATION_DESIGN.md',
    'PACKAGE_CREATION_DESIGN.en.md',
    'PACKAGE_DEPENDENCY_SPEC.md',
    'PACKAGE_DEPENDENCY_SPEC.en.md',
    'PHASE2-MIGRATION-GUIDE.md',
    'PHASE2-MIGRATION-GUIDE.en.md',
    'PHASE5-SUMMARY.md',
    'PHASE6-SUMMARY.md',
    'RESOURCE_PACKAGING_PLAN.md',
    'TEST_PLAN_GIT2_LOCAL.md',
    'TODO-FPC-v1.md',
    'git2-status-and-tests.md',
]

INTERNAL_DOCS = [
    'AGENT_TEAM_KICKOFF.md',
    'AGENT_TEAM_SETUP.md',
]

PUBLIC_BILINGUAL_PAIRS = [
    ('API.md', 'API.en.md'),
    ('ARCHITECTURE.md', 'ARCHITECTURE.en.md'),
    ('FAQ.md', 'FAQ.en.md'),
    ('FPC_MANAGEMENT.md', 'FPC_MANAGEMENT.en.md'),
    ('FPDEVRC_SPEC.md', 'FPDEVRC_SPEC.en.md'),
    ('FPDEV_TOML_SPEC.md', 'FPDEV_TOML_SPEC.en.md'),
    ('GIT2_USAGE.md', 'GIT2_USAGE.en.md'),
    ('INSTALLATION.md', 'INSTALLATION.en.md'),
    ('LIBGIT2_INTEGRATION.md', 'LIBGIT2_INTEGRATION.en.md'),
    ('MVP_ACCEPTANCE_CRITERIA.md', 'MVP_ACCEPTANCE_CRITERIA.en.md'),
    ('QUICKSTART.md', 'QUICKSTART.en.md'),
    ('REPO_ARCHITECTURE.md', 'REPO_ARCHITECTURE.en.md'),
    ('REPO_SPECIFICATION.md', 'REPO_SPECIFICATION.en.md'),
    ('build-manager.md', 'build-manager.en.md'),
    ('config-architecture.md', 'config-architecture.en.md'),
    ('toolchain.md', 'toolchain.en.md'),
]

HISTORY_BILINGUAL_PAIRS = [
    ('DEVELOPMENT_ROADMAP.md', 'DEVELOPMENT_ROADMAP.en.md'),
    ('PACKAGE_CREATION_DESIGN.md', 'PACKAGE_CREATION_DESIGN.en.md'),
    ('PACKAGE_DEPENDENCY_SPEC.md', 'PACKAGE_DEPENDENCY_SPEC.en.md'),
    ('PHASE2-MIGRATION-GUIDE.md', 'PHASE2-MIGRATION-GUIDE.en.md'),
]


class DocsTaxonomyContractTests(unittest.TestCase):
    def test_public_root_docs_keep_stable_anchor_paths(self):
        for name in PUBLIC_ROOT_DOCS:
            self.assertTrue((DOCS_DIR / name).exists(), f'{name} should remain in docs/ root')

    def test_history_docs_live_under_docs_history_and_leave_docs_root(self):
        for name in HISTORY_DOCS:
            self.assertTrue((HISTORY_DIR / name).exists(), f'{name} should exist in docs/history/')
            self.assertFalse((DOCS_DIR / name).exists(), f'{name} should no longer remain in docs/ root')

    def test_internal_docs_live_under_docs_internal_and_leave_docs_root(self):
        for name in INTERNAL_DOCS:
            self.assertTrue((INTERNAL_DIR / name).exists(), f'{name} should exist in docs/internal/')
            self.assertFalse((DOCS_DIR / name).exists(), f'{name} should no longer remain in docs/ root')

    def test_history_and_internal_readmes_exist(self):
        self.assertTrue((HISTORY_DIR / 'README.md').exists(), 'docs/history/README.md should exist')
        self.assertTrue((INTERNAL_DIR / 'README.md').exists(), 'docs/internal/README.md should exist')

    def test_public_bilingual_pairs_remain_in_docs_root(self):
        for zh_name, en_name in PUBLIC_BILINGUAL_PAIRS:
            self.assertTrue((DOCS_DIR / zh_name).exists(), f'{zh_name} should exist in docs/ root')
            self.assertTrue((DOCS_DIR / en_name).exists(), f'{en_name} should exist in docs/ root')

    def test_history_bilingual_pairs_remain_grouped_in_history(self):
        for zh_name, en_name in HISTORY_BILINGUAL_PAIRS:
            self.assertTrue((HISTORY_DIR / zh_name).exists(), f'{zh_name} should exist in docs/history/')
            self.assertTrue((HISTORY_DIR / en_name).exists(), f'{en_name} should exist in docs/history/')


if __name__ == '__main__':
    unittest.main()
