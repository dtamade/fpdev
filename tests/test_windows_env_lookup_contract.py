import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = REPO_ROOT / 'src'


class WindowsEnvLookupContractTests(unittest.TestCase):
    def test_windows_aware_units_do_not_use_ambiguous_environment_lookups(self):
        for source_path in sorted(SRC_ROOT.rglob('*.pas')):
            text = source_path.read_text(encoding='utf-8')
            if 'GetEnvironmentVariable(' not in text or 'Windows' not in text:
                continue

            normalized = text.replace('SysUtils.GetEnvironmentVariable(', '')
            normalized = normalized.replace('Windows.GetEnvironmentVariable(', '')
            self.assertNotIn(
                'GetEnvironmentVariable(',
                normalized,
                msg=(
                    f'{source_path.relative_to(REPO_ROOT)} still uses unqualified '
                    'GetEnvironmentVariable in a Windows-aware unit'
                ),
            )


if __name__ == '__main__':
    unittest.main()
