import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'check_toolchain.bat'


class CheckToolchainBatContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SCRIPT.read_text(encoding='utf-8')

    def test_script_exists(self):
        self.assertTrue(SCRIPT.exists(), f'Missing {SCRIPT}')

    def test_script_supports_repo_root_override(self):
        self.assertIn('FPDEV_TOOLCHAIN_REPO_ROOT', self.text)

    def test_script_checks_repo_bin_writable(self):
        self.assertIn('repo_bin_writable', self.text)

    def test_script_checks_repo_lib_writable(self):
        self.assertIn('repo_lib_writable', self.text)

    def test_script_logs_build_outputs_section(self):
        self.assertIn('Build outputs:', self.text)


if __name__ == '__main__':
    unittest.main()
