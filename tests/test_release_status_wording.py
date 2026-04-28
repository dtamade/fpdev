import importlib.util
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
README_ZH = REPO_ROOT / 'README.md'
README_EN = REPO_ROOT / 'README.en.md'
ROADMAP = REPO_ROOT / 'docs' / 'ROADMAP.md'
RELEASE_NOTES = REPO_ROOT / 'RELEASE_NOTES.md'
UPDATE_TEST_STATS = REPO_ROOT / 'scripts' / 'update_test_stats.py'


def current_test_inventory_line() -> str:
    spec = importlib.util.spec_from_file_location('update_test_stats', UPDATE_TEST_STATS)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    count = len(module.discover_tests())
    return f'[INFO] Discoverable test programs: {count} (same inventory rules as CI)'


class ReleaseStatusWordingTests(unittest.TestCase):
    def test_readme_uses_evidence_driven_release_status_in_chinese(self):
        text = README_ZH.read_text(encoding='utf-8')
        self.assertIn('[INFO] Feature checklist: closed for v2.1.0 scope', text)
        self.assertIn('[INFO] Linux release evidence: recorded', text)
        self.assertIn(current_test_inventory_line(), text)
        self.assertIn('[INFO] Release sign-off: public CI release-proof bundle published with v2.1.0', text)
        self.assertNotIn('121/121 complete', text)
        self.assertNotIn('Documentation: Complete', text)
        self.assertNotIn('Production-ready', text)

    def test_readme_uses_evidence_driven_release_status_in_english(self):
        text = README_EN.read_text(encoding='utf-8')
        self.assertIn('[INFO] Feature checklist: closed for v2.1.0 scope', text)
        self.assertIn('[INFO] Linux release evidence: recorded', text)
        self.assertIn(current_test_inventory_line(), text)
        self.assertIn('[INFO] Release sign-off: public CI release-proof bundle published with v2.1.0', text)
        self.assertNotIn('121/121 complete', text)
        self.assertNotIn('Documentation: Complete', text)
        self.assertNotIn('Production Ready', text)

    def test_roadmap_uses_evidence_driven_status_language(self):
        text = ROADMAP.read_text(encoding='utf-8')
        self.assertIn('**Status**: Feature Checklist Closed, Release Proof Published, v2.1.0 Released', text)
        self.assertIn('- Release baseline: Linux automated lane passed; cross-platform proof is published through public CI release-proof artifacts', text)
        self.assertIn('- Status source of truth: published GitHub release assets + public CI release-proof bundle', text)
        self.assertNotIn('**Status**: Roadmap Complete, Linux Release Gates Passed, Owner Checkpoints Pending', text)
        self.assertNotIn('Production-ready baseline', text)
        self.assertNotIn('Roadmap checklist: 121/121 complete', text)

    def test_release_notes_use_evidence_driven_status_language(self):
        text = RELEASE_NOTES.read_text(encoding='utf-8')
        self.assertIn('[INFO] Feature checklist: closed for v2.1.0 scope', text)
        self.assertIn('[INFO] Linux release evidence: recorded', text)
        self.assertIn('[INFO] Discoverable test programs: 275 (same inventory rules as CI)', text)
        self.assertIn('[INFO] Release sign-off: public CI release-proof bundle and RELEASE_EVIDENCE.md published with v2.1.0', text)
        self.assertNotIn('Roadmap checklist: 121/121 complete', text)
        self.assertNotIn('Primary release gate: Linux automated acceptance passed', text)
        self.assertNotIn('Remaining publish-time proof: Windows/macOS owner checkpoints + SHA256SUMS', text)


if __name__ == '__main__':
    unittest.main()
