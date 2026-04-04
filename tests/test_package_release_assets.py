import json
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'package_release_assets.py'
REPO_SHARED_CONFIG = REPO_ROOT / 'src' / 'data' / 'config.json'
TEST_SHARED_CONFIG = REPO_ROOT / 'tests' / 'data' / 'config.json'


class PackageReleaseAssetsTests(unittest.TestCase):
    def test_repo_shared_data_configs_do_not_embed_machine_specific_paths(self):
        for path in [REPO_SHARED_CONFIG, TEST_SHARED_CONFIG]:
            config = json.loads(path.read_text(encoding='utf-8'))

            self.assertEqual(
                '',
                config.get('settings', {}).get('install_root', ''),
                f'{path.relative_to(REPO_ROOT)} should not hardcode install_root',
            )

            for repo_name, repo_url in config.get('repositories', {}).items():
                self.assertFalse(
                    repo_url.startswith('file://'),
                    f'{path.relative_to(REPO_ROOT)} embeds local file repository {repo_name}: {repo_url}',
                )

    def test_script_packages_available_assets_with_shared_data_dir(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-release-package-') as tmp:
            root = Path(tmp)
            out_dir = root / 'out'
            data_dir = root / 'data'
            data_dir.mkdir()
            (data_dir / 'catalog.json').write_text('{"ok":true}', encoding='utf-8')

            linux_bin = root / 'fpdev-linux'
            linux_bin.write_text('linux-binary', encoding='utf-8')
            linux_bin.chmod(0o755)

            windows_bin = root / 'fpdev.exe'
            windows_bin.write_text('windows-binary', encoding='utf-8')

            completed = subprocess.run(
                [
                    'python3',
                    str(SCRIPT),
                    '--output-dir',
                    str(out_dir),
                    '--data-dir',
                    str(data_dir),
                    '--linux-bin',
                    str(linux_bin),
                    '--windows-bin',
                    str(windows_bin),
                ],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                capture_output=True,
            )

            linux_asset = out_dir / 'fpdev-linux-x64.tar.gz'
            windows_asset = out_dir / 'fpdev-windows-x64.zip'
            self.assertTrue(linux_asset.exists())
            self.assertTrue(windows_asset.exists())

            with tarfile.open(linux_asset, 'r:gz') as archive:
                names = archive.getnames()
                self.assertIn('fpdev', names)
                self.assertIn('data/catalog.json', names)

            with zipfile.ZipFile(windows_asset) as archive:
                names = archive.namelist()
                self.assertIn('fpdev.exe', names)
                self.assertIn('data/catalog.json', names)

            self.assertIn('fpdev-linux-x64.tar.gz', completed.stdout)
            self.assertIn('fpdev-windows-x64.zip', completed.stdout)

    def test_script_fails_when_required_assets_missing(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-release-package-missing-') as tmp:
            root = Path(tmp)
            out_dir = root / 'out'
            data_dir = root / 'data'
            data_dir.mkdir()
            (data_dir / 'catalog.json').write_text('{"ok":true}', encoding='utf-8')
            linux_bin = root / 'fpdev-linux'
            linux_bin.write_text('linux-binary', encoding='utf-8')
            linux_bin.chmod(0o755)

            completed = subprocess.run(
                [
                    'python3',
                    str(SCRIPT),
                    '--output-dir',
                    str(out_dir),
                    '--data-dir',
                    str(data_dir),
                    '--linux-bin',
                    str(linux_bin),
                    '--require-planned-assets',
                ],
                cwd=REPO_ROOT,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertNotEqual(0, completed.returncode)
            self.assertIn('Missing binaries for planned release assets', completed.stderr)


if __name__ == '__main__':
    unittest.main()
