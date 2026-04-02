import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
README_ZH = REPO_ROOT / 'README.md'
README_EN = REPO_ROOT / 'README.en.md'
ROADMAP = REPO_ROOT / 'docs' / 'ROADMAP.md'


class ReleaseStatusWordingTests(unittest.TestCase):
    def test_readme_uses_evidence_driven_release_status_in_chinese(self):
        text = README_ZH.read_text(encoding='utf-8')
        self.assertIn('[INFO] Feature checklist: closed for v2.1.0 scope', text)
        self.assertIn('[INFO] Linux release evidence: recorded', text)
        self.assertIn('[INFO] Release sign-off: pending Windows/macOS owner evidence', text)
        self.assertNotIn('121/121 complete', text)
        self.assertNotIn('Documentation: Complete', text)
        self.assertNotIn('Production-ready', text)

    def test_readme_uses_evidence_driven_release_status_in_english(self):
        text = README_EN.read_text(encoding='utf-8')
        self.assertIn('[INFO] Feature checklist: closed for v2.1.0 scope', text)
        self.assertIn('[INFO] Linux release evidence: recorded', text)
        self.assertIn('[INFO] Release sign-off: pending Windows/macOS owner evidence', text)
        self.assertNotIn('121/121 complete', text)
        self.assertNotIn('Documentation: Complete', text)
        self.assertNotIn('Production Ready', text)

    def test_roadmap_uses_evidence_driven_status_language(self):
        text = ROADMAP.read_text(encoding='utf-8')
        self.assertIn('**Status**: Feature Checklist Closed, Linux Release Evidence Recorded, Owner Sign-Off Pending', text)
        self.assertIn('- Release baseline: Linux automated lane passed; owner evidence still required for Windows/macOS', text)
        self.assertIn('- Status source of truth: release evidence artifacts + owner checkpoint ledger', text)
        self.assertNotIn('**Status**: Roadmap Complete, Linux Release Gates Passed, Owner Checkpoints Pending', text)
        self.assertNotIn('Production-ready baseline', text)
        self.assertNotIn('Roadmap checklist: 121/121 complete', text)


if __name__ == '__main__':
    unittest.main()
