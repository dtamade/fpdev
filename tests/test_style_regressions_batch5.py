import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch5Tests(unittest.TestCase):
    def test_cmd_package_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.package.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_config_interfaces_has_no_trailing_whitespace(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.config.interfaces.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if line.rstrip(' \t') != line
        ]
        self.assertEqual([], offenders, f'Trailing whitespace found: {offenders}')

    def test_toml_parser_has_no_trailing_whitespace(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.toml.parser.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if line.rstrip(' \t') != line
        ]
        self.assertEqual([], offenders, f'Trailing whitespace found: {offenders}')


if __name__ == '__main__':
    unittest.main()
