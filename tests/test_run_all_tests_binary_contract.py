import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RUN_ALL_TESTS = REPO_ROOT / 'scripts' / 'run_all_tests.sh'


class RunAllTestsBinaryContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = RUN_ALL_TESTS.read_text(encoding='utf-8')

    def test_binary_candidate_resolution_consumes_full_candidate_list(self):
        self.assertIn(
            'mapfile -t candidates < <(get_test_binary_candidates',
            self.text,
        )
        self.assertNotIn(
            'done < <(get_test_binary_candidates "$preferred_bin" "$test_dir" "$test_name" "$test_lpi")',
            self.text,
        )


if __name__ == '__main__':
    unittest.main()
