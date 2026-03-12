import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch11Tests(unittest.TestCase):
    def test_fpc_mocks_has_no_trailing_whitespace(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.fpc.mocks.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if (line.strip() != '') and (line.rstrip(' \t') != line)
        ]
        self.assertEqual([], offenders, f'Trailing whitespace found: {offenders}')

    def test_cmd_fpc_autoinstall_has_no_trailing_whitespace(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.fpc.autoinstall.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if (line.strip() != '') and (line.rstrip(' \t') != line)
        ]
        self.assertEqual([], offenders, f'Trailing whitespace found: {offenders}')

    def test_fpc_logger_has_no_trailing_whitespace(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.fpc.logger.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if (line.strip() != '') and (line.rstrip(' \t') != line)
        ]
        self.assertEqual([], offenders, f'Trailing whitespace found: {offenders}')


if __name__ == '__main__':
    unittest.main()
