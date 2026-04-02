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

    def test_fpdevrc_docs_describe_active_global_config_paths(self):
        zh_text = (REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.md').read_text(encoding='utf-8')
        en_text = (REPO_ROOT / 'docs' / 'FPDEVRC_SPEC.en.md').read_text(encoding='utf-8')

        for text in (zh_text, en_text):
            self.assertIn('FPDEV_DATA_ROOT', text)
            self.assertIn('data/config.json', text)
            self.assertIn('XDG_DATA_HOME', text)
            self.assertIn('%APPDATA%\\fpdev\\config.json', text)

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
