import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
GIT2_IMPL = REPO_ROOT / 'src' / 'git2.impl.pas'
GIT2_CORE = REPO_ROOT / 'src' / 'git2.core.pas'
LEGACY_WRAPPER = REPO_ROOT / 'src' / 'fpdev.git2.pas'
USAGE_DOCS = [
    REPO_ROOT / 'docs' / 'GIT2_USAGE.md',
    REPO_ROOT / 'docs' / 'GIT2_USAGE.en.md',
]
STATUS_DOC = REPO_ROOT / 'docs' / 'history' / 'git2-status-and-tests.md'
STATUS_REPORT = REPO_ROOT / 'report' / 'fpdev.git2.md'


class Git2ImplBoundaryTests(unittest.TestCase):
    def test_modern_impl_moves_to_shared_core_and_stops_importing_legacy_wrapper(self):
        text = GIT2_IMPL.read_text(encoding='utf-8')
        self.assertIn('git2.core', text, 'git2.impl should depend on the shared backend core')
        self.assertNotIn('fpdev.git2', text, 'git2.impl should not import or mention the deprecated legacy wrapper')

    def test_shared_core_unit_exists(self):
        self.assertTrue(GIT2_CORE.exists(), f'Missing {GIT2_CORE}')

    def test_legacy_wrapper_reexports_shared_core_and_stays_marked_legacy(self):
        text = LEGACY_WRAPPER.read_text(encoding='utf-8')
        self.assertIn('git2.core', text, 'fpdev.git2 should become a compatibility wrapper over the shared backend core')
        self.assertIn('backward compatibility only', text)
        self.assertIn('legacy compatibility wrapper', text)

    def test_usage_docs_keep_modern_preferred_and_legacy_on_compatibility_side(self):
        for path in USAGE_DOCS:
            text = path.read_text(encoding='utf-8')
            self.assertIn('New code should prefer `git2.api` + `git2.impl`', text)
            self.assertIn('Use `fpdev.git2` only when you need its legacy concrete classes or compatibility shim names.', text)
            self.assertIn(
                'legacy `fpdev.git2` surface is now a compatibility re-export over the shared `git2.core` backend.',
                text,
                f'{path} should explain the current legacy/backend layering',
            )

    def test_status_docs_keep_split_between_legacy_and_modern_lanes(self):
        for path in [STATUS_DOC, STATUS_REPORT]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('`tests/fpdev.git2/`（legacy concrete-wrapper lane）', text)
            self.assertIn('`tests/fpdev.git2.modern/`（modern interface lane）', text)


if __name__ == '__main__':
    unittest.main()
