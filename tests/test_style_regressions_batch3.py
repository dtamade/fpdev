import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch3Tests(unittest.TestCase):
    def test_build_interfaces_has_no_trailing_whitespace(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.build.interfaces.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, line)
            for lineno, line in enumerate(lines, start=1)
            if line.rstrip(' \t') != line
        ]
        self.assertEqual([], offenders, f'Trailing whitespace found: {offenders}')

    def test_collections_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.collections.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_project_template_remove_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.project.template.remove.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')


if __name__ == '__main__':
    unittest.main()
