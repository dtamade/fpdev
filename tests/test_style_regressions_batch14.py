import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


class StyleRegressionBatch14Tests(unittest.TestCase):
    def test_build_toolchain_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.build.toolchain.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_cmd_package_repo_remove_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cmd.package.repo.remove.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')

    def test_cross_manifest_lines_within_120_chars(self):
        source_path = REPO_ROOT / 'src' / 'fpdev.cross.manifest.pas'
        lines = source_path.read_text(encoding='utf-8').splitlines()
        offenders = [
            (lineno, len(line))
            for lineno, line in enumerate(lines, start=1)
            if len(line) > 120
        ]
        self.assertEqual([], offenders, f'Overlong lines found: {offenders}')


if __name__ == '__main__':
    unittest.main()
