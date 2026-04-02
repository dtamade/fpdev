import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / 'src'
RUNTIME_PATH = SRC / 'fpdev.git.runtime.pas'


class GitRuntimeBoundaryTests(unittest.TestCase):
    def test_git_runtime_adapter_exists(self):
        self.assertTrue(RUNTIME_PATH.exists(), f'Missing {RUNTIME_PATH}')
        text = RUNTIME_PATH.read_text(encoding='utf-8')
        self.assertIn('IGitRuntime', text)
        self.assertIn('TGitRuntime = class', text)
        self.assertIn('TGitOperations', text)

    def test_business_modules_stop_constructing_tgitoperations_directly(self):
        forbidden = [
            'fpdev.fpc.manager.pas',
            'fpdev.resource.repo.pas',
            'fpdev.lazarus.source.pas',
            'fpdev.source.repo.pas',
            'fpdev.fpc.builder.pas',
        ]
        for filename in forbidden:
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertNotIn('TGitOperations.Create', text, f'{filename} should use git runtime injection instead')


if __name__ == '__main__':
    unittest.main()
