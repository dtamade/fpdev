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

    def test_faq_docs_describe_project_local_isolation_via_active_data_root(self):
        zh_text = (REPO_ROOT / 'docs' / 'FAQ.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'FAQ.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('<data-root>/toolchains/fpc/3.2.2', text)
            self.assertNotIn('.fpdev/toolchains/', text)

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

    def test_installation_docs_do_not_advertise_unpublished_package_manager_channels(self):
        offenders = []
        for path in [
            REPO_ROOT / 'docs' / 'INSTALLATION.md',
            REPO_ROOT / 'docs' / 'INSTALLATION.en.md',
        ]:
            for lineno, line in enumerate(
                path.read_text(encoding='utf-8').splitlines(),
                start=1,
            ):
                lowered = line.lower()
                if (
                    '包管理器安装 (计划中)' in line
                    or 'package manager installation (planned)' in lowered
                    or 'brew install fpdev' in lowered
                    or 'choco install fpdev' in lowered
                    or 'snap install fpdev' in lowered
                    or 'apt install fpdev' in lowered
                ):
                    offenders.append((path.relative_to(REPO_ROOT), lineno, line.strip()))
        self.assertEqual([], offenders, f'Found unpublished package-manager install guidance in installation docs: {offenders}')

    def test_installation_docs_preserve_release_asset_layout(self):
        zh_text = (REPO_ROOT / 'docs' / 'INSTALLATION.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'INSTALLATION.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('data/', text)
            self.assertNotIn('sudo mv fpdev /usr/local/bin/', text)
            self.assertNotIn('mv fpdev ~/.local/bin/', text)

        self.assertNotIn(r'C:\fpdev\bin', zh_text)
        self.assertNotIn(r'C:\fpdev\bin', en_text)

    def test_installation_docs_use_supported_data_root_env_and_paths(self):
        zh_text = (REPO_ROOT / 'docs' / 'INSTALLATION.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'INSTALLATION.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)
            self.assertIn('data/logs/', text)

        for stale in [
            'FPDEV_HOME',
            'FPDEV_CONFIG',
            'FPDEV_PARALLEL_JOBS',
            'FPDEV_DEBUG',
            'FPDEV_VERBOSE',
        ]:
            self.assertNotIn(stale, zh_text)
            self.assertNotIn(stale, en_text)

    def test_installation_docs_use_standard_test_runner_commands(self):
        zh_text = (REPO_ROOT / 'docs' / 'INSTALLATION.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'INSTALLATION.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('scripts/run_all_tests.sh', text)
            self.assertIn('lazbuild -B tests/test_config_management.lpi', text)
            self.assertIn('./bin/test_config_management', text)
            self.assertNotIn('cd fpdev/src', text)
            self.assertNotIn('fpc -Fu. ../tests/test_config_management.lpr', text)
            self.assertNotIn('../tests/test_config_management', text)

    def test_testing_doc_uses_supported_full_suite_runner(self):
        text = (REPO_ROOT / 'docs' / 'testing.md').read_text(encoding='utf-8')

        self.assertIn('bash scripts/run_all_tests.sh', text)
        self.assertNotIn(r'scripts\run_all_tests.bat', text)

    def test_quickstart_docs_use_supported_config_and_parallelism_guidance(self):
        zh_text = (REPO_ROOT / 'docs' / 'QUICKSTART.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'QUICKSTART.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)

        for stale in [
            '~/.fpdev/config.json',
            r'%USERPROFILE%\.fpdev\config.json',
            'FPDEV_PARALLEL_JOBS',
        ]:
            self.assertNotIn(stale, zh_text)
            self.assertNotIn(stale, en_text)

    def test_quickstart_docs_do_not_advertise_unsupported_install_verbose_flag(self):
        zh_text = (REPO_ROOT / 'docs' / 'QUICKSTART.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'QUICKSTART.en.md').read_text(encoding='utf-8')

        self.assertNotIn('fpdev fpc install 3.2.2 --from-source --verbose', zh_text)
        self.assertNotIn('fpdev fpc install 3.2.2 --from-source --verbose', en_text)

    def test_quickstart_docs_do_not_recommend_source_install_as_default(self):
        zh_text = (REPO_ROOT / 'docs' / 'QUICKSTART.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'QUICKSTART.en.md').read_text(encoding='utf-8')

        self.assertIn('fpdev fpc install 3.2.2', zh_text)
        self.assertIn('fpdev fpc install 3.2.2', en_text)
        self.assertIn('--from-source', zh_text)
        self.assertIn('--from-source', en_text)
        self.assertNotIn('# 安装推荐版本 FPC 3.2.2\nfpdev fpc install 3.2.2 --from-source', zh_text)
        self.assertNotIn('# Install recommended version FPC 3.2.2\nfpdev fpc install 3.2.2 --from-source', en_text)

    def test_quickstart_docs_do_not_mark_package_commands_as_in_development(self):
        zh_text = (REPO_ROOT / 'docs' / 'QUICKSTART.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'QUICKSTART.en.md').read_text(encoding='utf-8')

        self.assertIn('fpdev package search synapse', zh_text)
        self.assertIn('fpdev package install synapse', zh_text)
        self.assertIn('fpdev package search synapse', en_text)
        self.assertIn('fpdev package install synapse', en_text)
        self.assertNotIn('功能开发中', zh_text)
        self.assertNotIn('under development', en_text)

    def test_quickstart_docs_describe_backup_via_active_data_root(self):
        zh_text = (REPO_ROOT / 'docs' / 'QUICKSTART.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'QUICKSTART.en.md').read_text(encoding='utf-8')

        self.assertIn('FPDEV_DATA_ROOT', zh_text)
        self.assertIn('FPDEV_DATA_ROOT', en_text)
        self.assertNotIn('备份 `.fpdev` 目录', zh_text)
        self.assertNotIn('backup `.fpdev` directory', en_text)

    def test_fpdevrc_docs_describe_active_global_config_paths(self):
        zh_text = (REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)
            self.assertIn('XDG_DATA_HOME', text)
            self.assertIn('%APPDATA%\\fpdev\\config.json', text)

    def test_fpdev_toml_spec_docs_do_not_advertise_unimplemented_workflow_commands(self):
        zh_text = (REPO_ROOT / 'docs' / 'FPDEV_TOML_SPEC.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'FPDEV_TOML_SPEC.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('fpdev fpc auto-install', text)
            self.assertIn('fpdev fpc use 3.2.2', text)
            self.assertIn('fpdev fpc current', text)
            self.assertNotIn('fpdev init --fpc=3.2.2', text)
            self.assertNotIn('fpdev auto-switch', text)
            self.assertNotIn('fpdev init -', text)
            self.assertNotIn('fpdev system config validate', text)
            self.assertNotIn('# Output: FPC 3.2.2 (from .fpdev.toml)', text)

    def test_fpc_management_docs_use_data_root_toolchain_layout(self):
        zh_text = (REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'FPC_MANAGEMENT.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('toolchains/fpc/3.2.2', text)
            self.assertIn('sources/fpc/fpc-3.2.2', text)
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)

        for stale in [
            '/home/user/.fpdev/fpc/3.2.2',
            'Check the configuration file at `~/.fpdev/config.json`',
            '检查配置文件 `~/.fpdev/config.json`',
        ]:
            self.assertNotIn(stale, zh_text)
            self.assertNotIn(stale, en_text)

    def test_known_limitations_doc_uses_supported_lazarus_install_fpc_flag(self):
        text = (REPO_ROOT / 'docs' / 'KNOWN_LIMITATIONS.md').read_text(encoding='utf-8')

        self.assertIn('fpdev lazarus install 3.0 --from-source --fpc=3.2.2', text)
        self.assertNotIn('fpdev lazarus install 3.0 --from-source --fpc-version 3.2.2', text)

    def test_toolchain_docs_describe_active_data_root_paths(self):
        zh_text = (REPO_ROOT / 'docs' / 'toolchain.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'toolchain.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('<data-root>/cache/', text)
            self.assertIn('<data-root>/sandbox/', text)
            self.assertIn('<data-root>/logs/', text)
            self.assertIn('<data-root>/locks/', text)

        for stale in [
            '默认使用仓库根下的 `.fpdev/`',
            'Defaults to `.fpdev/` under the repository root',
            '.fpdev/cache/',
            '.fpdev/sandbox/',
            '.fpdev/logs/',
            '.fpdev/locks/',
        ]:
            self.assertNotIn(stale, zh_text)
            self.assertNotIn(stale, en_text)

    def test_repo_spec_docs_describe_active_config_path_for_mirror_settings(self):
        zh_text = (REPO_ROOT / 'docs' / 'REPO_SPECIFICATION.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'REPO_SPECIFICATION.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)
            self.assertIn('XDG_DATA_HOME', text)
            self.assertIn('%APPDATA%\\fpdev\\config.json', text)

    def test_manifest_usage_doc_describes_active_manifest_cache_and_install_paths(self):
        text = (REPO_ROOT / 'docs' / 'MANIFEST-USAGE.md').read_text(encoding='utf-8')

        self.assertIn('FPDEV_DATA_ROOT', text)
        self.assertIn('XDG_DATA_HOME', text)
        self.assertIn('%APPDATA%\\fpdev\\', text)
        self.assertIn('<data-root>/cache/manifests/fpc.json', text)
        self.assertIn('<data-root>/toolchains/fpc/<version>', text)
        self.assertNotIn('~/.fpdev/cache/manifests/fpc.json', text)
        self.assertNotIn('~/.fpdev/toolchains/fpc/<version>', text)

    def test_manifest_migration_doc_does_not_advertise_unsupported_install_dry_run_flags(self):
        text = (REPO_ROOT / 'docs' / 'MANIFEST-MIGRATION.md').read_text(encoding='utf-8')

        self.assertIn('./bin/test_manifest_parser', text)
        self.assertIn('./bin/fpdev fpc install --help', text)
        self.assertIn('./bin/fpdev lazarus install --help', text)
        self.assertIn('./bin/fpdev cross build aarch64-linux --dry-run', text)
        self.assertNotIn('./bin/fpdev fpc install 3.2.2 --dry-run', text)
        self.assertNotIn('./bin/fpdev lazarus install 3.8 --dry-run', text)
        self.assertNotIn('./bin/fpdev cross install aarch64-linux --dry-run', text)

    def test_development_roadmap_uses_active_data_root_install_model(self):
        zh_text = (REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'DEVELOPMENT_ROADMAP.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('<data-root>/toolchains/fpc/3.2.2', text)
            self.assertIn('toolchains/fpc/3.2.2/bin/fpc', text)
            self.assertNotIn('~/.fpdev/fpc/3.2.2', text)

    def test_roadmap_success_metrics_use_active_install_path_model(self):
        text = (REPO_ROOT / 'docs' / 'ROADMAP.md').read_text(encoding='utf-8')

        self.assertIn('FPDEV_DATA_ROOT', text)
        self.assertIn('<data-root>/toolchains/fpc/<version>', text)
        self.assertNotIn('Project-scoped installation (`.fpdev/toolchains/`)', text)
        self.assertNotIn('User-scoped installation (`~/.fpdev/fpc/`)', text)

    def test_roadmap_does_not_advertise_removed_install_activate_flag(self):
        text = (REPO_ROOT / 'docs' / 'ROADMAP.md').read_text(encoding='utf-8')

        self.assertIn('explicit `use`', text)
        self.assertNotIn('`--activate`', text)

    def test_roadmap_does_not_advertise_removed_install_scope_flag(self):
        text = (REPO_ROOT / 'docs' / 'ROADMAP.md').read_text(encoding='utf-8')

        self.assertIn('project-local isolation via `FPDEV_DATA_ROOT` or `--prefix`', text)
        self.assertIn('scope-aware activation artifacts', text)
        self.assertNotIn('2.1 Scoped Installation', text)
        self.assertNotIn('Implement `--scope` (project/user/system)', text)

    def test_todo_fpc_v1_uses_active_data_root_install_model(self):
        text = (REPO_ROOT / 'docs' / 'TODO-FPC-v1.md').read_text(encoding='utf-8')

        self.assertIn('FPDEV_DATA_ROOT', text)
        self.assertIn('%APPDATA%\\fpdev', text)
        self.assertIn('$XDG_DATA_HOME/fpdev', text)
        self.assertIn('~/.fpdev', text)
        self.assertIn('<data-root>/toolchains/fpc/<version>', text)
        self.assertNotIn('FPDEV_HOME', text)
        self.assertNotIn('%LOCALAPPDATA%/fpdev', text)
        self.assertNotIn('~/.local/share/fpdev', text)
        self.assertNotIn('Project mode: if `.fpdev/` present → use `.fpdev/` as data root', text)
        self.assertNotIn('`--scope user|project|system`', text)
        self.assertNotIn('project: `.fpdev/toolchains/fpc/<version>`', text)
        self.assertNotIn('user: `<DATA_ROOT>/toolchains/fpc/<version>`', text)

    def test_config_architecture_docs_describe_active_config_paths(self):
        zh_text = (REPO_ROOT / 'docs' / 'config-architecture.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'config-architecture.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)
            self.assertIn('XDG_DATA_HOME', text)
            self.assertIn('%APPDATA%\\fpdev\\config.json', text)
            self.assertNotIn("TConfigManager.Create('~/.fpdev/config.json')", text)
            self.assertNotIn("TFPDevConfigManager.Create('~/.fpdev/config.json')", text)
            self.assertNotIn(r'%APPDATA%\.fpdev\config.json', text)


if __name__ == '__main__':
    unittest.main()
