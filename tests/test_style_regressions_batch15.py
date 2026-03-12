import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch15Tests(unittest.TestCase):
    def test_fpc_activation_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.fpc.activation.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_cmd_project_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.project.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_fpc_utils_style(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.fpc.utils.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        overlong = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        trailing = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if (line.strip() != '') and (line.rstrip(' \t') != line)
        ]
        self.assertEqual([], overlong, f'Overlong lines found: {overlong}')
        self.assertEqual([], trailing, f'Trailing whitespace found: {trailing}')


if __name__ == '__main__':
    unittest.main()
