import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = REPO_ROOT / 'docs'
BUILD_MANAGER_MD = DOCS_DIR / 'build-manager.md'
BUILD_MANAGER_EN_MD = DOCS_DIR / 'build-manager.en.md'
BUILD_MANAGER_REPORT_MD = REPO_ROOT / 'report' / 'fpdev.build.manager.md'
TODO_BUILD_MANAGER_MD = REPO_ROOT / 'todos' / 'fpdev.build.manager.md'
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
        self.assertIn('- [x] BuildManager 强化', text)
        self.assertIn('  - [x] TestResults 校验沙箱输出结构（允许安装时）', text)
        self.assertIn('  - [x] 日志分文件（per-run 独立日志文件）', text)
        self.assertIn('  - [x] verbosity 开关', text)
        self.assertIn('  - [x] 日志轮转', text)

    def test_build_manager_todo_marks_runbook_and_api_examples_complete(self):
        text = TODO_BUILD_MANAGER_MD.read_text(encoding='utf-8')
        self.assertIn('- [x] 文档：docs/build-manager.md 增补“全工具链真实演练 Runbook、脚本清单与参数说明”', text)
        self.assertIn('- [x] 日志优化：Windows 时间戳零填充（避免空格）', text)
        self.assertIn('- [x] 示例增强：示例中演示 SetTarget/SetPrefix/SetMakeCmd 的用法（注释或参数）', text)

    def test_build_manager_docs_and_todo_capture_zero_padded_log_timestamp_truth(self):
        doc_text = BUILD_MANAGER_MD.read_text(encoding='utf-8')
        todo_text = TODO_BUILD_MANAGER_MD.read_text(encoding='utf-8')
        self.assertIn('logs/build_yyyymmdd_hhnnss_zzz.log', doc_text)
        self.assertIn('Windows 日志文件名当前已使用零填充时间戳', doc_text)
        self.assertNotIn('Windows 日志时间戳可能含空格', doc_text)
        self.assertIn('- [x] 日志优化：Windows 时间戳零填充（避免空格）', todo_text)

    def test_build_manager_backlog_is_drained_into_verified_artifacts(self):
        build_todo = TODO_BUILD_MANAGER_MD.read_text(encoding='utf-8')
        git2_todo = TODO_GIT2_MD.read_text(encoding='utf-8')
        doc_text = BUILD_MANAGER_MD.read_text(encoding='utf-8')
        self.assertNotIn('- [ ]', build_todo)
        self.assertNotIn('- [ ]', git2_todo)
        self.assertIn('artifact-manifest.txt', doc_text)
        self.assertIn('日志轮转', doc_text)
        self.assertIn('scripts/build_manager_self_hosted_ci.sh', doc_text)
        self.assertIn('FullBuild 会先执行 Preflight', doc_text)
        self.assertTrue((REPO_ROOT / 'scripts' / 'build_manager_self_hosted_ci.sh').exists())


if __name__ == '__main__':
    unittest.main()
