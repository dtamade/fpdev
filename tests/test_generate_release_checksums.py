import hashlib
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'generate_release_checksums.py'


class GenerateReleaseChecksumsTests(unittest.TestCase):
    def test_script_generates_sha256sums_for_planned_assets(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-release-checksums-') as tmp:
            root = Path(tmp)
            assets = {
                'fpdev-linux-x64.tar.gz': b'linux-asset',
                'fpdev-windows-x64.zip': b'windows-asset',
                'fpdev-macos-x64.tar.gz': b'macos-x64-asset',
                'fpdev-macos-arm64.tar.gz': b'macos-arm64-asset',
            }
            for name, data in assets.items():
                (root / name).write_bytes(data)

            completed = subprocess.run(
                [
                    'python3',
                    str(SCRIPT),
                    str(root),
                    '--require-planned-assets',
                ],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                capture_output=True,
            )

            output = root / 'SHA256SUMS.txt'
            self.assertTrue(output.exists(), 'SHA256SUMS.txt should be generated')
            lines = output.read_text(encoding='utf-8').splitlines()
            self.assertEqual(4, len(lines), 'expected one checksum line per planned asset')

            for name, data in assets.items():
                digest = hashlib.sha256(data).hexdigest()
                self.assertIn(f'{digest}  {name}', lines)

            self.assertIn('SHA256SUMS.txt', completed.stdout)

    def test_script_fails_when_required_assets_are_missing(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-release-checksums-missing-') as tmp:
            root = Path(tmp)
            (root / 'fpdev-linux-x64.tar.gz').write_bytes(b'linux-only')

            completed = subprocess.run(
                [
                    'python3',
                    str(SCRIPT),
                    str(root),
                    '--require-planned-assets',
                ],
                cwd=REPO_ROOT,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertNotEqual(0, completed.returncode)
            self.assertIn('Missing planned release assets', completed.stderr)


if __name__ == '__main__':
    unittest.main()
