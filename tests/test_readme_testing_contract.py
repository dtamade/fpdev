import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
README_ZH = REPO_ROOT / 'README.md'
README_EN = REPO_ROOT / 'README.en.md'


class ReadmeTestingContractTests(unittest.TestCase):
    def test_chinese_readme_testing_section_uses_inventory_summary_and_canonical_links(self):
        text = README_ZH.read_text(encoding='utf-8')
        self.assertIn('## 🧪 测试覆盖', text)
        self.assertIn('<!-- TEST-INVENTORY-SUMMARY:BEGIN -->', text)
        self.assertIn('docs/testing.md', text)
        self.assertIn('docs/MVP_ACCEPTANCE_CRITERIA.md', text)
        self.assertNotIn('Phase 1: 核心工作流', text)
        self.assertNotIn('17/17', text)
        self.assertNotIn('20+ 测试通过', text)

    def test_english_readme_testing_section_uses_inventory_summary_and_canonical_links(self):
        text = README_EN.read_text(encoding='utf-8')
        self.assertIn('## 🧪 Testing', text)
        self.assertIn('<!-- TEST-INVENTORY-SUMMARY:BEGIN -->', text)
        self.assertIn('docs/testing.md', text)
        self.assertIn('docs/MVP_ACCEPTANCE_CRITERIA.en.md', text)
        self.assertNotIn('Zero compilation warnings', text)
        self.assertNotIn('GitHub Actions CI ready', text)


if __name__ == '__main__':
    unittest.main()
