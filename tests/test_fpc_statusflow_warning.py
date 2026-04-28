import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FPC = shutil.which('fpc')
STATUSFLOW_TEST = REPO_ROOT / 'tests' / 'test_fpc_statusflow.lpr'


class FPCStatusflowWarningTests(unittest.TestCase):
    @unittest.skipUnless(FPC, 'fpc compiler is required')
    def test_statusflow_helper_compiles_without_unit_warning(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-fpc-statusflow-warning-') as tmp:
            bin_dir = Path(tmp) / 'bin'
            lib_dir = Path(tmp) / 'lib'
            bin_dir.mkdir()
            lib_dir.mkdir()

            completed = subprocess.run(
                [
                    FPC,
                    '-Fusrc',
                    '-Fisrc',
                    '-Fu./tests',
                    f'-FE{bin_dir}',
                    f'-FU{lib_dir}',
                    str(STATUSFLOW_TEST.relative_to(REPO_ROOT)),
                ],
                cwd=REPO_ROOT,
                check=False,
                text=True,
                capture_output=True,
            )

            output = completed.stdout + completed.stderr

            self.assertEqual(0, completed.returncode, output)
            self.assertNotRegex(
                output,
                r'fpdev\.fpc\.statusflow\.pas\(\d+,\d+\)\s+Warning:',
            )


if __name__ == '__main__':
    unittest.main()
