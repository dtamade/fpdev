import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CONSOLE_SOURCE = REPO_ROOT / 'src' / 'fpdev.output.console.pas'


class WindowsConsoleOutputContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CONSOLE_SOURCE.read_text(encoding='utf-8')

    def test_console_output_uses_fpdev_utils_env_helper(self):
        self.assertIn('fpdev.utils,', self.text)
        self.assertIn("get_env('WT_SESSION')", self.text)
        self.assertIn("get_env('TERM_PROGRAM')", self.text)
        self.assertIn("get_env('TERM')", self.text)
        self.assertIn("get_env('ConEmuANSI')", self.text)
        self.assertIn("get_env('NO_COLOR')", self.text)

    def test_console_output_does_not_call_windows_environment_api_overloads(self):
        self.assertNotIn("GetEnvironmentVariable('WT_SESSION')", self.text)
        self.assertNotIn("GetEnvironmentVariable('TERM_PROGRAM')", self.text)
        self.assertNotIn("GetEnvironmentVariable('TERM')", self.text)
        self.assertNotIn("GetEnvironmentVariable('ConEmuANSI')", self.text)
        self.assertNotIn("GetEnvironmentVariable('NO_COLOR')", self.text)


if __name__ == '__main__':
    unittest.main()
