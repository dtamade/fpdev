import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'scripts' / 'run_prettier.sh'
BASH = shutil.which('bash') or '/usr/bin/bash'


class RunPrettierShTests(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.exists(), f'Missing {SCRIPT}')

    def test_script_formats_repo_relative_markdown_path(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-prettier-sh-') as tmp:
            tmp_path = Path(tmp)
            doc_path = tmp_path / 'sample.md'
            doc_path.write_text('# Title\n\n-   item\n', encoding='utf-8')
            relative_path = doc_path.relative_to(tmp_path)

            completed = subprocess.run(
                [BASH, str(SCRIPT), '--write', str(relative_path)],
                cwd=tmp_path,
                check=True,
                text=True,
                capture_output=True,
            )

            text = doc_path.read_text(encoding='utf-8')
            self.assertIn('- item', text)
            self.assertNotIn('-   item', text)
            self.assertIn('sample.md', completed.stdout + completed.stderr)

    def test_script_formats_absolute_markdown_path(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-prettier-sh-') as tmp:
            tmp_path = Path(tmp)
            doc_path = tmp_path / 'sample.md'
            doc_path.write_text('# Title\n\n-   item\n', encoding='utf-8')

            completed = subprocess.run(
                [BASH, str(SCRIPT), '--write', str(doc_path)],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                capture_output=True,
            )

            text = doc_path.read_text(encoding='utf-8')
            self.assertIn('- item', text)
            self.assertNotIn('-   item', text)
            self.assertIn('sample.md', completed.stdout + completed.stderr)

    def test_script_reports_missing_prettier_binary(self):
        with tempfile.TemporaryDirectory(prefix='fpdev-prettier-sh-') as tmp:
            tmp_path = Path(tmp)
            doc_path = tmp_path / 'sample.md'
            doc_path.write_text('# Title\n', encoding='utf-8')
            path_env = tmp_path / 'empty-bin'
            path_env.mkdir()

            completed = subprocess.run(
                [BASH, str(SCRIPT), '--check', str(doc_path)],
                cwd=REPO_ROOT,
                check=False,
                text=True,
                capture_output=True,
                env={
                    'HOME': str(tmp_path / 'missing-home'),
                    'PATH': str(path_env),
                },
            )

            self.assertNotEqual(0, completed.returncode)
            self.assertIn('prettier', (completed.stdout + completed.stderr).lower())


if __name__ == '__main__':
    unittest.main()
