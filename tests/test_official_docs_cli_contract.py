import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

OFFICIAL_DOCS = [
    REPO_ROOT / 'README.md',
    REPO_ROOT / 'README.en.md',
    REPO_ROOT / 'FAQ.md',
    REPO_ROOT / 'docs' / 'API.md',
    REPO_ROOT / 'docs' / 'API.en.md',
    REPO_ROOT / 'docs' / 'FAQ.md',
    REPO_ROOT / 'docs' / 'FAQ.en.md',
    REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.md',
    REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.en.md',
    REPO_ROOT / 'docs' / 'INSTALLATION.md',
    REPO_ROOT / 'docs' / 'INSTALLATION.en.md',
    REPO_ROOT / 'docs' / 'QUICKSTART.md',
    REPO_ROOT / 'docs' / 'QUICKSTART.en.md',
    REPO_ROOT / 'docs' / 'ARCHITECTURE.md',
    REPO_ROOT / 'docs' / 'ARCHITECTURE.en.md',
]

LIBGIT2_DOCS = [
    REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.md',
    REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.en.md',
]

CROSS_TARGET_SPEC_DOCS = [
    REPO_ROOT / 'docs' / 'FPDEV_TOML_SPEC.md',
    REPO_ROOT / 'docs' / 'FPDEV_TOML_SPEC.en.md',
    REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.md',
    REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.en.md',
]

BANNED_COMMAND_PREFIXES = [
    'fpdev help',
    'fpdev version --check',
    'fpdev version',
    'fpdev fpc default',
    'fpdev lazarus default',
    'fpdev fpc remove',
    'fpdev lazarus remove',
    'fpdev cross add',
    'fpdev package remove',
    'fpdev fpc upgrade',
    'fpdev lazarus upgrade',
    'fpdev lazarus launch',
    'fpdev fpc info',
]


class OfficialDocsCliContractTests(unittest.TestCase):
    def test_roadmap_current_features_do_not_point_to_project_or_lazarus_compat_shells(self):
        path = REPO_ROOT / 'docs' / 'ROADMAP.md'
        text = path.read_text(encoding='utf-8')

        banned_snippets = [
            'Source update functionality** ✅ COMPLETE (`fpdev.cmd.lazarus.pas:',
            'Source cleanup functionality** ✅ COMPLETE (`fpdev.cmd.lazarus.pas:',
            'IDE configuration functionality** ✅ COMPLETE (`fpdev.cmd.lazarus.pas:',
            'Already implemented in fpdev.cmd.lazarus.pas and fpdev.lazarus.config.pas',
            'Project cleanup functionality** ✅ COMPLETE (`fpdev.cmd.project.pas:',
            'Project test functionality** ✅ COMPLETE (`fpdev.cmd.project.pas:',
            'Project run functionality** ✅ COMPLETE (`fpdev.cmd.project.pas:',
            '// Step 2: Green Phase (src/fpdev.cmd.project.pas)',
            '**Status**: ✅ ALL PHASES COMPLETE - Phase 7 quality improvements in progress',
            '**Last Updated**: 2026-02-11 (Phase 7 in progress: All ROADMAP features verified complete, code quality improvements ongoing)',
        ]
        for snippet in banned_snippets:
            self.assertNotIn(snippet, text, f'docs/ROADMAP.md should no longer attribute current features to compat shell units: {snippet}')

        expected_snippets = [
            'Source update functionality** ✅ COMPLETE (`fpdev.cmd.lazarus.update.pas`, `fpdev.lazarus.manager.pas`)',
            'Source cleanup functionality** ✅ COMPLETE (`fpdev.lazarus.manager.pas`)',
            'IDE configuration functionality** ✅ COMPLETE (`fpdev.cmd.lazarus.configure.pas`, `fpdev.lazarus.manager.pas`, `fpdev.lazarus.config.pas`)',
            'Project cleanup functionality** ✅ COMPLETE (`fpdev.cmd.project.clean.pas`, `fpdev.project.manager.pas`)',
            'Project test functionality** ✅ COMPLETE (`fpdev.cmd.project.test.pas`, `fpdev.project.manager.pas`)',
            'Project run functionality** ✅ COMPLETE (`fpdev.cmd.project.run.pas`, `fpdev.project.manager.pas`)',
            '// Step 2: Green Phase (src/fpdev.project.manager.pas)',
            '> Historical note: the milestone progress tables below are retained as phase snapshots.',
            '**Status**: Feature checklist closed; public CI release proof remains the active finish line.',
            '**Last Updated**: 2026-03-25 (current public roadmap/status document)',
        ]
        for snippet in expected_snippets:
            self.assertIn(snippet, text, f'docs/ROADMAP.md should point to the current owning units: {snippet}')

    def test_libgit2_integration_docs_mark_test_fpc_source_as_migrated_sample(self):
        expectations = {
            REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.md': '历史遗留手动样例',
            REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.en.md': 'historical manual sample',
        }
        for path, expected_note in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn(
                'tests/migrated/root-lpr/test_fpc_source.lpr',
                text,
                f'{path} should point to the migrated sample path',
            )
            self.assertIn(expected_note, text, f'{path} should explain that test_fpc_source is no longer an active root test')
            self.assertNotIn('│   └── test_fpc_source.lpr', text)
            self.assertNotIn('fpc -Fusrc test_fpc_source.lpr', text)

    def test_libgit2_integration_docs_use_current_manual_paths_and_no_removed_helper_scripts(self):
        expectations = {
            REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.md': (
                '当前工作树未跟踪专用的 libgit2 构建辅助脚本',
                '默认 discoverable 测试清单之外',
            ),
            REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.en.md': (
                'No dedicated libgit2 helper build scripts are tracked in the current worktree',
                'excluded from the default discoverable test inventory',
            ),
        }
        for path, (build_note, inventory_note) in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn('tests/fpdev.libgit2.base/test_libgit2_complete.lpr', text)
            self.assertIn('tests/fpdev.git2.adapter/test_git_real.lpr', text)
            self.assertIn(build_note, text)
            self.assertIn(inventory_note, text)
            self.assertNotIn('scripts/build_libgit2_simple.bat', text)
            self.assertNotIn('scripts/build_libgit2_linux.sh', text)
            self.assertNotIn('scripts/get_git2_dll.bat', text)
            self.assertNotIn('tests/test_libgit2_complete.lpr', text)
            self.assertNotIn('tests/test_git_real.lpr', text)

    def test_libgit2_integration_docs_troubleshooting_scopes_runtime_loader_by_platform(self):
        expectations = {
            REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.md': 'libgit2 共享库装载失败',
            REPO_ROOT / 'docs' / 'LIBGIT2_INTEGRATION.en.md': 'Failed to load the libgit2 shared library',
        }
        for path, expected_heading in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn(expected_heading, text)
            self.assertIn('git2.dll', text)
            self.assertIn('libgit2.so', text)
            self.assertIn('libgit2.1.dylib', text)
            self.assertIn('src/libgit2.pas', text)
            self.assertNotIn('libgit2.dll not found', text)
            self.assertNotIn('libgit2.dll未找到', text)

    def test_official_docs_do_not_advertise_removed_top_level_commands(self):
        offenders = []
        for path in OFFICIAL_DOCS:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                stripped = line.strip()
                for prefix in BANNED_COMMAND_PREFIXES:
                    if stripped.startswith(prefix):
                        offenders.append((path.relative_to(REPO_ROOT), lineno, stripped))
        self.assertEqual([], offenders, f'Found removed CLI commands in official docs: {offenders}')

    def test_official_docs_do_not_describe_legacy_tfpcmd_model(self):
        offenders = []
        for path in [
            REPO_ROOT / 'docs' / 'API.md',
            REPO_ROOT / 'docs' / 'API.en.md',
            REPO_ROOT / 'docs' / 'ARCHITECTURE.md',
            REPO_ROOT / 'docs' / 'ARCHITECTURE.en.md',
        ]:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                if 'TFPCMD' in line:
                    offenders.append((path.relative_to(REPO_ROOT), lineno, line.strip()))
        self.assertEqual([], offenders, f'Found legacy TFPCMD docs in official architecture/API docs: {offenders}')

    def test_cross_target_specs_do_not_advertise_legacy_target_names(self):
        legacy_patterns = [
            re.compile(r'(^|[^A-Za-z0-9_-])win32([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])win64([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])linux-x86_64([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])linux-arm([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])linux-aarch64([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])darwin-x86_64([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])darwin-aarch64([^A-Za-z0-9_-]|$)'),
            re.compile(r'(^|[^A-Za-z0-9_-])x86_64-windows([^A-Za-z0-9_-]|$)'),
        ]
        offenders = []
        for path in CROSS_TARGET_SPEC_DOCS:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                for pattern in legacy_patterns:
                    if pattern.search(line):
                        offenders.append((path.relative_to(REPO_ROOT), lineno, line.strip()))
                        break
        self.assertEqual([], offenders, f'Found legacy cross target names in spec docs: {offenders}')

    def test_fpc_docs_do_not_recommend_source_install_as_default(self):
        offenders = []
        for path in [
            REPO_ROOT / 'FAQ.md',
            REPO_ROOT / 'docs' / 'FAQ.md',
            REPO_ROOT / 'docs' / 'FAQ.en.md',
        ]:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                if '推荐使用源码安装' in line or 'Source installation is recommended' in line:
                    offenders.append((path.relative_to(REPO_ROOT), lineno, line.strip()))
        self.assertEqual([], offenders, f'Found stale source-first install guidance in FAQ docs: {offenders}')

    def test_fpc_management_docs_do_not_call_binary_install_planned(self):
        offenders = []
        for path in [
            REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.md',
            REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.en.md',
        ]:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                if '预编译二进制包安装（规划中）' in line or 'planned' in line.lower():
                    offenders.append((path.relative_to(REPO_ROOT), lineno, line.strip()))
        self.assertEqual([], offenders, f'Found stale binary-install roadmap language in FPC management docs: {offenders}')

    def test_official_docs_use_documented_baselines_not_current_recommended_version_claims(self):
        expectations = {
            REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.md': (
                '文档示例基线',
                '当前推荐版本',
            ),
            REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.en.md': (
                'Documented baseline for examples',
                'Current recommended version',
            ),
            REPO_ROOT / 'docs' / 'QUICKSTART.md': (
                '安装文档示例基线 FPC 3.2.2',
                '安装推荐版本 FPC 3.2.2',
            ),
            REPO_ROOT / 'docs' / 'QUICKSTART.en.md': (
                'Install the documented example baseline FPC 3.2.2',
                'Install recommended version FPC 3.2.2',
            ),
            REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.md': (
                '本规范中的示例基线',
                '最新稳定版（当前 3.2.2）',
            ),
            REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.en.md': (
                'Example baseline in this spec',
                'Latest stable release (currently 3.2.2)',
            ),
        }
        for path, (required, banned) in expectations.items():
            text = path.read_text(encoding='utf-8')
            self.assertIn(required, text, f'{path} should contain {required!r}')
            self.assertNotIn(banned, text, f'{path} should not contain stale current-version wording {banned!r}')

    def test_current_public_source_build_docs_use_shared_release_build_entrypoint(self):
        for path in [
            REPO_ROOT / 'README.md',
            REPO_ROOT / 'README.en.md',
            REPO_ROOT / 'docs' / 'FAQ.md',
            REPO_ROOT / 'docs' / 'FAQ.en.md',
            REPO_ROOT / 'docs' / 'INSTALLATION.md',
            REPO_ROOT / 'docs' / 'INSTALLATION.en.md',
        ]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('bash scripts/build_release.sh', text, f'{path} should use the shared release build entrypoint')


if __name__ == '__main__':
    unittest.main()
