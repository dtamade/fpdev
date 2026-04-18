import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = REPO_ROOT / 'docs'
BUILD_MANAGER_MD = DOCS_DIR / 'build-manager.md'
BUILD_MANAGER_EN_MD = DOCS_DIR / 'build-manager.en.md'
BUILD_MANAGER_REPORT_MD = REPO_ROOT / 'report' / 'fpdev.build.manager.md'
TODO_GIT2_MD = REPO_ROOT / 'todos' / 'fpdev.git2.md'


class BuildManagerDocsTruthContractTests(unittest.TestCase):
    def test_build_manager_docs_do_not_describe_testresults_as_directory_only_placeholder(self):
        expectations = {
            BUILD_MANAGER_MD: (
                'TestResults 在允许安装时优先校验沙箱',
                '未允许安装时，回退校验源码目录的 compiler/ 与 rtl/ 是否存在',
                'TestResults 仅检查目录是否存在（占位）',
            ),
            BUILD_MANAGER_EN_MD: (
                'TestResults prioritizes sandbox validation when installation is allowed',
                'falls back to source-tree compiler/rtl validation otherwise',
                'TestResults only checks if directory exists (placeholder)',
            ),
        }
        for path, (current_primary, current_fallback, stale_placeholder) in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn(current_primary, text, f'{path} should document sandbox-first validation')
            self.assertIn(current_fallback, text, f'{path} should document source-tree fallback validation')
            self.assertNotIn(stale_placeholder, text, f'{path} should not keep stale placeholder wording')

    def test_build_manager_report_mentions_current_testresults_validation_slice(self):
        text = BUILD_MANAGER_REPORT_MD.read_text(encoding='utf-8')
        self.assertIn('TestResults', text)
        self.assertIn('沙箱', text)
        self.assertIn('src/fpdev.build.testresultsflow.pas', text)
        self.assertIn('tests/test_build_testresultsflow.lpr', text)

    def test_git2_todo_marks_testresults_sandbox_structure_validation_complete(self):
        text = TODO_GIT2_MD.read_text(encoding='utf-8')
        self.assertIn('- [ ] BuildManager 强化', text)
        self.assertIn('  - [x] TestResults 校验沙箱输出结构（允许安装时）', text)
        self.assertIn('  - [ ] 日志分文件/轮转、verbosity 开关', text)


if __name__ == '__main__':
    unittest.main()
