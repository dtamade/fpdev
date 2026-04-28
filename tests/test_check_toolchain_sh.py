import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'check_toolchain.sh'
BASH = shutil.which('bash') or '/bin/bash'


class CheckToolchainShTests(unittest.TestCase):
    def _create_repo_fixture(self, root: Path) -> tuple[Path, Path]:
        repo_root = root / 'repo'
        repo_root.mkdir()
        (repo_root / 'fpdev.lpi').write_text('<CONFIG/>', encoding='utf-8')
        (repo_root / 'bin').mkdir()
        (repo_root / 'lib').mkdir()

        lazarus_root = root / 'lazarus'
        (lazarus_root / 'lcl').mkdir(parents=True)
        return repo_root, lazarus_root

    def _run_script(self, repo_root: Path, lazarus_root: Path) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env['FPDEV_TOOLCHAIN_REPO_ROOT'] = str(repo_root)
        env['FPDEV_LAZARUSDIR'] = str(lazarus_root)
        return subprocess.run(
            [BASH, str(SCRIPT)],
            cwd=REPO_ROOT,
            check=False,
            text=True,
            capture_output=True,
            env=env,
        )

    def test_script_passes_when_repo_build_outputs_are_writable(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-check-toolchain-sh-') as tmp:
            repo_root, lazarus_root = self._create_repo_fixture(Path(tmp))

            completed = self._run_script(repo_root, lazarus_root)
            output = completed.stdout + completed.stderr

            self.assertEqual(0, completed.returncode, output)
            self.assertIn('[ OK ] repo_bin_writable', output)
            self.assertIn('[ OK ] repo_lib_writable', output)
            self.assertIn('Build outputs:', output)

    @unittest.skipUnless(os.name == 'posix', 'read-only directory probe requires POSIX permissions')
    def test_script_fails_when_repo_lib_is_not_writable(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-check-toolchain-sh-') as tmp:
            repo_root, lazarus_root = self._create_repo_fixture(Path(tmp))
            repo_lib = repo_root / 'lib'
            repo_lib.chmod(0o555)
            try:
                completed = self._run_script(repo_root, lazarus_root)
            finally:
                repo_lib.chmod(0o755)

            output = completed.stdout + completed.stderr

            self.assertNotEqual(0, completed.returncode, output)
            self.assertIn('[MISS] repo_lib_writable', output)
            self.assertIn('missing_required:', output)


if __name__ == '__main__':
    unittest.main()
