import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'record_owner_smoke.sh'


class RecordOwnerSmokeShTests(unittest.TestCase):
    def test_script_records_standardized_transcript_file(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-owner-smoke-') as tmp:
            root = Path(tmp)
            output_dir = root / 'proof'
            fake_exe = root / 'fpdev'
            fake_exe.write_text(
                '#!/usr/bin/env bash\n'
                'echo "fake fpdev $*"\n',
                encoding='utf-8',
            )
            fake_exe.chmod(0o755)

            completed = subprocess.run(
                [
                    'bash',
                    str(SCRIPT),
                    'macos-x64',
                    str(fake_exe),
                    str(output_dir),
                ],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                capture_output=True,
            )

            transcript = output_dir / 'macos-x64-owner-smoke.txt'
            self.assertTrue(transcript.exists())
            text = transcript.read_text(encoding='utf-8')
            self.assertIn('[SMOKE] system version', text)
            self.assertIn('[ OK ] CLI smoke passed', text)
            self.assertIn('Recorded owner smoke transcript', completed.stdout)


if __name__ == '__main__':
    unittest.main()
