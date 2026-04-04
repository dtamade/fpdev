import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BASH_COMPLETION = REPO_ROOT / 'scripts' / 'completions' / 'fpdev.bash'
ZSH_COMPLETION = REPO_ROOT / 'scripts' / 'completions' / '_fpdev'
DUMP_SOURCE = REPO_ROOT / 'tests' / 'cli_surface_dump.lpr'
PROJECT_MANAGER = REPO_ROOT / 'src' / 'fpdev.project.manager.pas'


def resolve_python_test_temp_root() -> str:
    candidate = os.environ.get('FPDEV_TEST_TMPDIR', '').strip()
    if candidate == '':
        candidate = os.environ.get('TMPDIR', '').strip()
    if candidate == '':
        candidate = os.environ.get('TMP', '').strip()
    if candidate == '':
        candidate = os.environ.get('TEMP', '').strip()

    if candidate != '':
        root = Path(candidate).expanduser()
    else:
        fallback_root = REPO_ROOT / '.tmp-pytest'
        root = fallback_root

    root.mkdir(parents=True, exist_ok=True)
    return str(root)


class CliSurfaceConsistencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._temp_dir = tempfile.TemporaryDirectory(
            prefix='fpdev-cli-surface-',
            dir=resolve_python_test_temp_root(),
        )
        temp_root = Path(cls._temp_dir.name)
        dump_bin_dir = temp_root / 'bin'
        dump_lib_dir = temp_root / 'lib'
        dump_bin_dir.mkdir(parents=True, exist_ok=True)
        dump_lib_dir.mkdir(parents=True, exist_ok=True)
        dump_binary = dump_bin_dir / 'cli_surface_dump'

        subprocess.run(
            [
                'fpc',
                '-Fusrc',
                '-Fisrc',
                f'-FE{dump_bin_dir}',
                f'-FU{dump_lib_dir}',
                str(DUMP_SOURCE),
            ],
            cwd=REPO_ROOT,
            check=True,
            text=True,
            capture_output=True,
        )

        completed = subprocess.run(
            [str(dump_binary)],
            cwd=REPO_ROOT,
            check=True,
            text=True,
            capture_output=True,
        )
        cls.registry_paths = [
            line.strip() for line in completed.stdout.splitlines() if line.strip()
        ]
        cls.registry_tree = cls.build_tree(cls.registry_paths)
        cls.bash_text = BASH_COMPLETION.read_text(encoding='utf-8')
        cls.zsh_text = ZSH_COMPLETION.read_text(encoding='utf-8')
        cls.project_manager_text = PROJECT_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def tearDownClass(cls):
        cls._temp_dir.cleanup()

    @staticmethod
    def build_tree(paths: list[str]) -> dict[tuple[str, ...], set[str]]:
        tree: dict[tuple[str, ...], set[str]] = {}
        for path in paths:
            parts = tuple(path.split('/'))
            for depth in range(len(parts)):
                parent = parts[:depth]
                child = parts[depth]
                tree.setdefault(parent, set()).add(child)
        return tree

    def registry_children(self, *path: str) -> list[str]:
        return sorted(self.registry_tree.get(tuple(path), set()))

    def parse_bash_words(self, variable_name: str) -> list[str]:
        pattern = rf'local {re.escape(variable_name)}="([^"]+)"'
        match = re.search(pattern, self.bash_text)
        self.assertIsNotNone(match, f'bash variable not found: {variable_name}')
        return match.group(1).split()

    def parse_zsh_array(self, array_name: str) -> list[str]:
        pattern = rf'{re.escape(array_name)}=\(\n(.*?)\n    \)'
        match = re.search(pattern, self.zsh_text, re.S)
        self.assertIsNotNone(match, f'zsh array not found: {array_name}')
        return re.findall(r"'([^':]+):", match.group(1))

    def parse_zsh_inline_describe(self, label: str) -> list[str]:
        pattern = rf"_describe '{re.escape(label)}' '\(([^)]*)\)'"
        match = re.search(pattern, self.zsh_text)
        self.assertIsNotNone(match, f'zsh inline describe not found: {label}')
        return match.group(1).split()

    def parse_zsh_simple_array(self, array_name: str) -> list[str]:
        pattern = rf'{re.escape(array_name)}=\((.*?)\)'
        match = re.search(pattern, self.zsh_text, re.S)
        self.assertIsNotNone(match, f'zsh simple array not found: {array_name}')
        return re.findall(r"'([^']+)'", match.group(1))

    def parse_bash_project_new_templates(self) -> list[str]:
        return self.parse_bash_project_template_completion('new')

    def parse_bash_project_template_completion(self, subcommand: str) -> list[str]:
        pattern = r'([a-z|]+)\)\s*\n\s*# Template completion\s*\n\s*COMPREPLY=\(\$\(compgen -W "([^"]+)" -- "\$\{cur\}"\)\)'
        for labels, values in re.findall(pattern, self.bash_text, re.S):
            if subcommand in labels.split('|'):
                return values.split()
        self.fail(f'bash project {subcommand} template completion not found')

    def parse_zsh_template_completion_case_labels(self) -> set[str]:
        labels = set()
        pattern = r"([a-z|]+)\)\s*\n\s*_describe 'template' project_templates"
        for raw_labels in re.findall(pattern, self.zsh_text):
            labels.update(raw_labels.split('|'))
        return labels

    def parse_available_project_templates_from_manager(self) -> list[str]:
        entries = re.findall(
            r"\(Name: '([^']+)';.*?Available: (True|False)\)",
            self.project_manager_text,
            re.S,
        )
        self.assertTrue(entries, 'no built-in project templates found in project manager')
        return [name for name, available in entries if available == 'True']

    def assertCommandSetEqual(self, actual: list[str], expected: list[str], label: str):
        self.assertEqual(sorted(expected), sorted(actual), label)

    def test_root_command_completion_matches_registry(self):
        expected = self.registry_children()
        bash_commands = [
            item for item in self.parse_bash_words('commands') if not item.startswith('--')
        ]
        zsh_commands = [
            item for item in self.parse_zsh_array('commands') if not item.startswith('--')
        ]

        self.assertCommandSetEqual(bash_commands, expected, 'bash root commands drift')
        self.assertCommandSetEqual(zsh_commands, expected, 'zsh root commands drift')

    def test_bash_completion_matches_registry_subtrees(self):
        self.assertCommandSetEqual(
            self.parse_bash_words('fpc_commands'),
            self.registry_children('fpc'),
            'bash fpc commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('fpc_cache_commands'),
            self.registry_children('fpc', 'cache'),
            'bash fpc cache commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('fpc_policy_commands'),
            self.registry_children('fpc', 'policy'),
            'bash fpc policy commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('lazarus_commands'),
            self.registry_children('lazarus'),
            'bash lazarus commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('cross_commands'),
            self.registry_children('cross'),
            'bash cross commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('package_commands'),
            self.registry_children('package'),
            'bash package commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('package_repo_commands'),
            self.registry_children('package', 'repo'),
            'bash package repo commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('project_commands'),
            self.registry_children('project'),
            'bash project commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('project_template_commands'),
            self.registry_children('project', 'template'),
            'bash project template commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_commands'),
            self.registry_children('system'),
            'bash system commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_env_commands'),
            self.registry_children('system', 'env'),
            'bash system env commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_repo_commands'),
            self.registry_children('system', 'repo'),
            'bash system repo commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_config_commands'),
            self.registry_children('system', 'config'),
            'bash system config commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_index_commands'),
            self.registry_children('system', 'index'),
            'bash system index commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_cache_commands'),
            self.registry_children('system', 'cache'),
            'bash system cache commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_perf_commands'),
            self.registry_children('system', 'perf'),
            'bash system perf commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_words('system_toolchain_commands'),
            self.registry_children('system', 'toolchain'),
            'bash system toolchain commands drift',
        )

    def test_zsh_completion_matches_registry_subtrees(self):
        self.assertCommandSetEqual(
            self.parse_zsh_array('fpc_commands'),
            self.registry_children('fpc'),
            'zsh fpc commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_inline_describe('cache command'),
            self.registry_children('fpc', 'cache'),
            'zsh fpc cache commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_inline_describe('policy command'),
            self.registry_children('fpc', 'policy'),
            'zsh fpc policy commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('lazarus_commands'),
            self.registry_children('lazarus'),
            'zsh lazarus commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('cross_commands'),
            self.registry_children('cross'),
            'zsh cross commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('package_commands'),
            self.registry_children('package'),
            'zsh package commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('package_repo_commands'),
            self.registry_children('package', 'repo'),
            'zsh package repo commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('project_commands'),
            self.registry_children('project'),
            'zsh project commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_inline_describe('template command'),
            self.registry_children('project', 'template'),
            'zsh project template commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_commands'),
            self.registry_children('system'),
            'zsh system commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_env_commands'),
            self.registry_children('system', 'env'),
            'zsh system env commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_repo_commands'),
            self.registry_children('system', 'repo'),
            'zsh system repo commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_config_commands'),
            self.registry_children('system', 'config'),
            'zsh system config commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_index_commands'),
            self.registry_children('system', 'index'),
            'zsh system index commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_cache_commands'),
            self.registry_children('system', 'cache'),
            'zsh system cache commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_perf_commands'),
            self.registry_children('system', 'perf'),
            'zsh system perf commands drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_array('system_toolchain_commands'),
            self.registry_children('system', 'toolchain'),
            'zsh system toolchain commands drift',
        )

    def test_project_template_name_completion_matches_available_templates(self):
        expected = self.parse_available_project_templates_from_manager()
        self.assertCommandSetEqual(
            self.parse_bash_project_new_templates(),
            expected,
            'bash project new template suggestions drift',
        )
        self.assertCommandSetEqual(
            self.parse_zsh_simple_array('project_templates'),
            expected,
            'zsh project new template suggestions drift',
        )
        self.assertCommandSetEqual(
            self.parse_bash_project_template_completion('info'),
            expected,
            'bash project info template suggestions drift',
        )
        self.assertIn(
            'info',
            self.parse_zsh_template_completion_case_labels(),
            'zsh project info should use project template suggestions',
        )


if __name__ == '__main__':
    unittest.main()
