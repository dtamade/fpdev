import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

MANAGEMENT_TESTS = [
    REPO_ROOT / 'tests' / 'test_config_management.lpr',
    REPO_ROOT / 'tests' / 'test_cross_management.lpr',
    REPO_ROOT / 'tests' / 'test_lazarus_management.lpr',
]


class PascalTestExitContractTests(unittest.TestCase):
    def test_management_test_programs_fail_process_when_test_counter_is_nonzero(self):
        offenders = []
        pattern = re.compile(
            r'Test\.RunAllTests(?:\(\))?;'
            r'[\s\S]*?if\s+Test\.TestsFailed\s*>\s*0\s+then'
            r'[\s\S]*?(?:ExitCode\s*:=\s*1|Halt\s*\(\s*1\s*\))',
            re.MULTILINE,
        )

        for path in MANAGEMENT_TESTS:
            text = path.read_text(encoding='utf-8')
            if not pattern.search(text):
                offenders.append(path.relative_to(REPO_ROOT).as_posix())

        self.assertEqual(
            [],
            offenders,
            f'Management Pascal tests must return a failing process exit code: {offenders}',
        )


if __name__ == '__main__':
    unittest.main()
