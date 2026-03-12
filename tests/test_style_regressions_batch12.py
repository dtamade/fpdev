import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch12Tests(unittest.TestCase):
    def test_cmd_cross_build_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.cross.build.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_cmd_cross_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.cross.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_logger_structured_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.logger.structured.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')


if __name__ == '__main__':
    unittest.main()
