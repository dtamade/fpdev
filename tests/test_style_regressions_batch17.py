import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch17Tests(unittest.TestCase):
    def test_fpc_builder_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.fpc.builder.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_config_test_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.config.test.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_toolchain_manifest_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.toolchain.manifest.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')


if __name__ == '__main__':
    unittest.main()
