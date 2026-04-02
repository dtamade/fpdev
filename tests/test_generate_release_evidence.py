import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'generate_release_evidence.py'


class GenerateReleaseEvidenceTests(unittest.TestCase):
    def write_summary(self, path: Path, with_install: int, extra_lines: list[str]) -> None:
        lines = [
            'FPDev Linux Release Acceptance',
            f'timestamp: {path.parent.name}',
            f'run_dir: {path.parent}',
            f'with_install: {with_install}',
            'status: pass',
            *extra_lines,
        ]
        path.write_text('\n'.join(lines) + '\n', encoding='utf-8')

    def test_script_generates_markdown_evidence_summary(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-release-evidence-') as tmp:
            root = Path(tmp)
            logs_root = root / 'logs' / 'release_acceptance'
            baseline_dir = logs_root / '20260325_204342'
            install_dir = logs_root / '20260325_205542'
            baseline_dir.mkdir(parents=True)
            install_dir.mkdir(parents=True)
            self.write_summary(baseline_dir / 'summary.txt', 0, ['toolchain_check: pass'])
            self.write_summary(install_dir / 'summary.txt', 1, ['fpc_install_322: pass'])

            asset_dir = root / 'dist'
            asset_dir.mkdir()
            (asset_dir / 'SHA256SUMS.txt').write_text(
                'abc  fpdev-linux-x64.tar.gz\n'
                'def  fpdev-windows-x64.zip\n',
                encoding='utf-8',
            )
            owner_proof_dir = root / 'owner-proof'
            owner_proof_dir.mkdir()
            (owner_proof_dir / 'windows-x64-owner-smoke.txt').write_text(
                '[SMOKE] windows transcript\n',
                encoding='utf-8',
            )
            (owner_proof_dir / 'macos-x64-owner-smoke.txt').write_text(
                '[SMOKE] macOS x64 transcript\n',
                encoding='utf-8',
            )

            output = root / 'RELEASE_EVIDENCE.md'
            completed = subprocess.run(
                [
                    'python3',
                    str(SCRIPT),
                    '--baseline-summary',
                    str(baseline_dir / 'summary.txt'),
                    '--install-summary',
                    str(install_dir / 'summary.txt'),
                    '--asset-dir',
                    str(asset_dir),
                    '--owner-proof-dir',
                    str(owner_proof_dir),
                    '--output',
                    str(output),
                ],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                capture_output=True,
            )

            text = output.read_text(encoding='utf-8')
            self.assertIn('## Automated Evidence', text)
            self.assertIn('Linux automated acceptance', text)
            self.assertIn('20260325_204342/summary.txt', text)
            self.assertIn('Linux isolated install lane', text)
            self.assertIn('20260325_205542/summary.txt', text)
            self.assertIn('## Release Assets', text)
            self.assertIn('fpdev-linux-x64.tar.gz', text)
            self.assertIn('fpdev-windows-x64.zip', text)
            self.assertIn('## Owner Ledger', text)
            self.assertIn('Windows x64 asset smoke | pending', text)
            self.assertIn('## Owner Evidence Files', text)
            self.assertIn('windows-x64-owner-smoke.txt', text)
            self.assertIn('macos-x64-owner-smoke.txt', text)
            self.assertIn('macos-arm64-owner-smoke.txt', text)
            self.assertIn('found', text)
            self.assertIn('missing', text)
            self.assertIn('SHA256SUMS.txt', completed.stdout)

    def test_script_requires_existing_summary_inputs(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-release-evidence-missing-') as tmp:
            root = Path(tmp)
            completed = subprocess.run(
                [
                    'python3',
                    str(SCRIPT),
                    '--baseline-summary',
                    str(root / 'missing-baseline.txt'),
                    '--install-summary',
                    str(root / 'missing-install.txt'),
                    '--asset-dir',
                    str(root),
                ],
                cwd=REPO_ROOT,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertNotEqual(0, completed.returncode)
            self.assertIn('Summary file does not exist', completed.stderr)


if __name__ == '__main__':
    unittest.main()
