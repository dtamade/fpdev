import importlib.util
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[1] / 'scripts' / 'update_test_stats.py'


def load_module():
    spec = importlib.util.spec_from_file_location('update_test_stats', SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class UpdateTestStatsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def test_replace_marker_block_replaces_inner_content_only(self):
        text = (
            'before\n'
            '<!-- TEST-INVENTORY-BADGE:BEGIN -->\n'
            'old\n'
            '<!-- TEST-INVENTORY-BADGE:END -->\n'
            'after\n'
        )
        updated = self.mod.replace_marker_block(
            text,
            'TEST-INVENTORY-BADGE',
            'new',
            Path('README.md'),
        )
        self.assertIn('before\n', updated)
        self.assertIn('after\n', updated)
        self.assertIn('<!-- TEST-INVENTORY-BADGE:BEGIN -->\nnew\n<!-- TEST-INVENTORY-BADGE:END -->', updated)
        self.assertNotIn('old', updated)

    def test_render_testing_md_is_stable_without_date_stamp(self):
        sample = (
            '## Test Coverage\n\n'
            '<!-- TEST-INVENTORY-COVERAGE:BEGIN -->\n'
            'stale\n'
            '<!-- TEST-INVENTORY-COVERAGE:END -->\n\n'
            '## Continuous Integration\n\n'
            '**Last Updated**: 2026-03-08  \n'
            '**Test Framework**: fpcunit  \n'
            '<!-- TEST-INVENTORY-FOOTER:BEGIN -->\n'
            'stale footer\n'
            '<!-- TEST-INVENTORY-FOOTER:END -->\n'
        )
        updated = self.mod.render_testing_md(sample, 216)
        self.assertIn('Current discoverable test-program inventory:', updated)
        self.assertIn('**Test Inventory**: 216 discoverable test programs (same rules as CI)', updated)
        self.assertNotIn('as of ', updated)
        self.assertIn('**Last Updated**: 2026-03-08', updated)

    def test_render_run_all_tests_supports_mapfile_loader(self):
        sample = (
            'load_test_inventory() {\n'
            '  mapfile -t TEST_FILES < <(python3 "${SCRIPT_DIR}/legacy.py" --list)\n'
            '}\n'
        )
        updated = self.mod.render_run_all_tests(sample)
        self.assertIn('mapfile -t TEST_FILES < <(python3 "${SCRIPT_DIR}/update_test_stats.py" --list)', updated)
        self.assertNotIn('legacy.py', updated)

    def test_render_readme_md_updates_badge_and_summary_markers(self):
        sample = (
            '<!-- TEST-INVENTORY-BADGE:BEGIN -->\n'
            'old badge\n'
            '<!-- TEST-INVENTORY-BADGE:END -->\n\n'
            '```\n'
            '[OK] Discoverable test programs: 111\n'
            '```\n\n'
            '<!-- TEST-INVENTORY-SUMMARY:BEGIN -->\n'
            'old summary\n'
            '<!-- TEST-INVENTORY-SUMMARY:END -->\n'
        )
        updated = self.mod.render_readme_md(sample, 216)
        self.assertIn('tests-216%20discoverable', updated)
        self.assertIn('[OK] Discoverable test programs: 216 (same inventory rules as CI)', updated)
        self.assertIn('总计: 216 个可发现的 test_*.lpr 测试程序（与 CI 使用同一发现规则）', updated)


if __name__ == '__main__':
    unittest.main()
