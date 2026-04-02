import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'record_owner_smoke.ps1'


class RecordOwnerSmokePs1Tests(unittest.TestCase):
    def _build_fake_executable(self, root: Path) -> Path:
        if os.name == 'nt':
            fake_exe = root / 'fpdev.cmd'
            fake_exe.write_text(
                '@echo off\r\n'
                'echo fake fpdev %*\r\n',
                encoding='utf-8',
            )
            return fake_exe

        fake_exe = root / 'fpdev'
        fake_exe.write_text(
            '#!/usr/bin/env bash\n'
            'echo "fake fpdev $*"\n',
            encoding='utf-8',
        )
        fake_exe.chmod(0o755)
        return fake_exe

    def test_script_records_standardized_transcript_file(self):
        if shutil.which('pwsh') is None:
            self.skipTest('pwsh is not available in this environment')

        with tempfile.TemporaryDirectory(prefix='fpdev-owner-smoke-ps1-') as tmp:
            root = Path(tmp)
            output_dir = root / 'proof'
            lane = 'windows-x64' if os.name == 'nt' else 'macos-x64'
            fake_exe = self._build_fake_executable(root)

            completed = subprocess.run(
                [
                    'pwsh',
                    '-NoProfile',
                    '-File',
                    str(SCRIPT),
                    '-Lane',
                    lane,
                    '-ExecutablePath',
                    str(fake_exe),
                    '-OutputDir',
                    str(output_dir),
                ],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                capture_output=True,
            )

            transcript = output_dir / f'{lane}-owner-smoke.txt'
            self.assertTrue(transcript.exists())
            text = transcript.read_text(encoding='utf-8')
            self.assertIn('[SMOKE] system version', text)
            self.assertIn('[ OK ] CLI smoke passed', text)
            self.assertIn('Recorded owner smoke transcript', completed.stdout)


if __name__ == '__main__':
    unittest.main()
