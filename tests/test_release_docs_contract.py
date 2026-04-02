import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
OWNER_CHECKPOINTS = REPO_ROOT / 'docs' / 'plans' / '2026-03-25-v2.1.0-release-owner-checkpoints.md'
MVP_ACCEPTANCE = REPO_ROOT / 'docs' / 'MVP_ACCEPTANCE_CRITERIA.md'
MVP_ACCEPTANCE_EN = REPO_ROOT / 'docs' / 'MVP_ACCEPTANCE_CRITERIA.en.md'
RELEASE_NOTES = REPO_ROOT / 'RELEASE_NOTES.md'
CHANGELOG = REPO_ROOT / 'CHANGELOG.md'
LATEST_BASELINE_SUMMARY = 'logs/release_acceptance/20260402_104133/summary.txt'
LATEST_INSTALL_SUMMARY = 'logs/release_acceptance/20260402_111602/summary.txt'
STALE_BASELINE_SUMMARY = 'logs/release_acceptance/20260325_204342/summary.txt'
STALE_INSTALL_SUMMARY = 'logs/release_acceptance/20260325_205542/summary.txt'


class ReleaseDocsContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = OWNER_CHECKPOINTS.read_text(encoding='utf-8')
        cls.mvp_text = MVP_ACCEPTANCE.read_text(encoding='utf-8')
        cls.mvp_en_text = MVP_ACCEPTANCE_EN.read_text(encoding='utf-8')
        cls.release_notes_text = RELEASE_NOTES.read_text(encoding='utf-8')
        cls.changelog_text = CHANGELOG.read_text(encoding='utf-8')

    def test_owner_checkpoint_doc_uses_shared_smoke_scripts(self):
        self.assertIn('scripts/cli_smoke.ps1', self.text)
        self.assertIn('scripts/cli_smoke.sh', self.text)
        self.assertIn('scripts/record_owner_smoke.ps1', self.text)
        self.assertIn('scripts/record_owner_smoke.sh', self.text)

    def test_owner_checkpoint_doc_uses_release_checksum_script(self):
        self.assertIn('scripts/generate_release_checksums.py', self.text)
        self.assertIn('SHA256SUMS.txt', self.text)

    def test_owner_checkpoint_doc_lists_release_evidence_as_planned_artifact(self):
        self.assertIn('| `RELEASE_EVIDENCE.md` | Release evidence handoff |', self.text)

    def test_owner_checkpoint_doc_uses_release_packaging_script(self):
        self.assertIn('scripts/package_release_assets.py', self.text)

    def test_owner_checkpoint_doc_uses_release_evidence_script(self):
        self.assertIn('scripts/generate_release_evidence.py', self.text)
        self.assertIn('windows-x64-owner-smoke.txt', self.text)
        self.assertIn('macos-x64-owner-smoke.txt', self.text)
        self.assertIn('macos-arm64-owner-smoke.txt', self.text)

    def test_owner_checkpoint_doc_marks_install_summary_as_optional_evidence_input(self):
        self.assertIn('--baseline-summary logs/release_acceptance/<baseline-run>/summary.txt', self.text)
        self.assertIn('If the network-gated install lane was executed', self.text)
        self.assertIn('--install-summary logs/release_acceptance/<install-run>/summary.txt', self.text)

    def test_release_closeout_docs_include_release_evidence_handoff(self):
        self.assertIn('RELEASE_EVIDENCE.md', self.text)
        self.assertIn('RELEASE_EVIDENCE.md', self.mvp_text)
        self.assertIn('RELEASE_EVIDENCE.md', self.mvp_en_text)
        self.assertIn('RELEASE_EVIDENCE.md', self.release_notes_text)
        self.assertIn(
            'Remaining publish-time proof: Windows/macOS owner checkpoints + SHA256SUMS + RELEASE_EVIDENCE.md',
            self.release_notes_text,
        )

    def test_release_notes_use_standard_owner_smoke_recorders(self):
        self.assertIn('record_owner_smoke.ps1', self.release_notes_text)
        self.assertIn('record_owner_smoke.sh', self.release_notes_text)
        self.assertIn('generate_release_evidence.py', self.release_notes_text)
        self.assertNotIn('system version/help', self.release_notes_text)
        self.assertNotIn('fpc --help', self.release_notes_text)
        self.assertNotIn('fpc list --all', self.release_notes_text)

    def test_owner_checkpoint_exit_criteria_include_release_evidence(self):
        self.assertIn('RELEASE_EVIDENCE.md', self.text)
        self.assertIn('`RELEASE_EVIDENCE.md` is published with the release.', self.text)

    def test_owner_checkpoint_doc_stops_inlining_smoke_commands(self):
        self.assertNotIn('.\\fpdev.exe system version', self.text)
        self.assertNotIn('./fpdev system version', self.text)
        self.assertNotIn('.\\fpdev.exe fpc --help', self.text)
        self.assertNotIn('./fpdev fpc --help', self.text)

    def test_release_closeout_docs_reference_latest_april_2_evidence(self):
        for text in (self.text, self.mvp_text, self.mvp_en_text):
            self.assertIn(LATEST_BASELINE_SUMMARY, text)
            self.assertIn(LATEST_INSTALL_SUMMARY, text)

    def test_release_closeout_docs_drop_stale_march_25_evidence_paths(self):
        for text in (self.text, self.mvp_text, self.mvp_en_text):
            self.assertNotIn(STALE_BASELINE_SUMMARY, text)
            self.assertNotIn(STALE_INSTALL_SUMMARY, text)

    def test_changelog_release_baseline_tracks_release_publish_artifacts(self):
        self.assertIn('SHA256SUMS.txt', self.changelog_text)
        self.assertIn('RELEASE_EVIDENCE.md', self.changelog_text)


if __name__ == '__main__':
    unittest.main()
