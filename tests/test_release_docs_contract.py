import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
OWNER_CHECKPOINTS = REPO_ROOT / 'docs' / 'plans' / '2026-03-25-v2.1.0-release-owner-checkpoints.md'
FINAL_DELIVERY_ROUTE = REPO_ROOT / 'docs' / 'plans' / '2026-04-08-final-delivery-route.md'
MVP_ACCEPTANCE_ZH = REPO_ROOT / 'docs' / 'MVP_ACCEPTANCE_CRITERIA.md'
MVP_ACCEPTANCE_EN = REPO_ROOT / 'docs' / 'MVP_ACCEPTANCE_CRITERIA.en.md'
RELEASE_NOTES = REPO_ROOT / 'RELEASE_NOTES.md'
ROADMAP = REPO_ROOT / 'docs' / 'ROADMAP.md'


class ReleaseDocsContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = OWNER_CHECKPOINTS.read_text(encoding='utf-8')

    def test_owner_checkpoint_doc_uses_shared_smoke_scripts(self):
        self.assertIn('scripts/cli_smoke.ps1', self.text)
        self.assertIn('scripts/cli_smoke.sh', self.text)
        self.assertIn('scripts/record_owner_smoke.ps1', self.text)
        self.assertIn('scripts/record_owner_smoke.sh', self.text)

    def test_owner_checkpoint_doc_uses_release_checksum_script(self):
        self.assertIn('scripts/generate_release_checksums.py', self.text)
        self.assertIn('SHA256SUMS.txt', self.text)

    def test_owner_checkpoint_doc_uses_release_packaging_script(self):
        self.assertIn('scripts/package_release_assets.py', self.text)
        self.assertIn('--data-dir src/data', self.text)
        self.assertNotIn('--data-dir bin/data', self.text)

    def test_owner_checkpoint_doc_uses_release_evidence_script(self):
        self.assertIn('scripts/generate_release_evidence.py', self.text)
        self.assertIn('windows-x64-owner-smoke.txt', self.text)
        self.assertIn('macos-x64-owner-smoke.txt', self.text)
        self.assertIn('macos-arm64-owner-smoke.txt', self.text)

    def test_owner_checkpoint_doc_promotes_public_ci_release_proof_bundle(self):
        self.assertIn('GitHub Actions', self.text)
        self.assertIn('release-ready-bundle', self.text)
        self.assertIn('owner-proof-windows-x64', self.text)
        self.assertIn('owner-proof-macos-x64', self.text)
        self.assertIn('owner-proof-macos-arm64', self.text)

    def test_owner_checkpoint_doc_stops_inlining_smoke_commands(self):
        self.assertNotIn('.\\fpdev.exe system version', self.text)
        self.assertNotIn('./fpdev system version', self.text)
        self.assertNotIn('.\\fpdev.exe fpc --help', self.text)
        self.assertNotIn('./fpdev fpc --help', self.text)

    def test_owner_checkpoint_doc_keeps_local_recorders_as_manual_fallback(self):
        self.assertIn('fallback', self.text.lower())
        self.assertIn('scripts/record_owner_smoke.ps1', self.text)
        self.assertIn('scripts/record_owner_smoke.sh', self.text)

    def test_release_acceptance_docs_use_shared_release_build_entrypoint(self):
        for path in [MVP_ACCEPTANCE_ZH, MVP_ACCEPTANCE_EN]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('bash scripts/build_release.sh', text)
            self.assertNotIn('`lazbuild -B --build-mode=Release fpdev.lpi` succeeds', text)

    def test_release_notes_use_shared_release_build_entrypoint(self):
        text = RELEASE_NOTES.read_text(encoding='utf-8')
        self.assertIn('bash scripts/build_release.sh', text)
        self.assertNotIn('lazbuild -B --build-mode=Release fpdev.lpi', text)

    def test_roadmap_points_to_final_delivery_route_and_owner_checkpoint_docs(self):
        text = ROADMAP.read_text(encoding='utf-8')
        self.assertIn('docs/plans/2026-04-08-final-delivery-route.md', text)
        self.assertIn('release-ready-bundle', text)
        self.assertIn('docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md', text)

    def test_final_delivery_route_references_green_ci_handoff_and_publish_artifacts(self):
        text = FINAL_DELIVERY_ROUTE.read_text(encoding='utf-8')
        self.assertIn('24113915296', text)
        self.assertIn('release-ready-bundle', text)
        self.assertIn('SHA256SUMS.txt', text)
        self.assertIn('RELEASE_EVIDENCE.md', text)
        self.assertIn('docs/MVP_ACCEPTANCE_CRITERIA.md', text)
        self.assertIn('docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md', text)


if __name__ == '__main__':
    unittest.main()
