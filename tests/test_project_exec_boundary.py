import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROJECT_MANAGER = REPO_ROOT / 'src' / 'fpdev.project.manager.pas'


class ProjectExecBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = PROJECT_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_execflow_and_cleanflow_units(self):
        self.assertIn('fpdev.project.execflow', self.text)
        self.assertIn('fpdev.project.cleanflow', self.text)

    def test_build_test_and_run_delegate_to_execflow(self):
        build_section = self._section(
            'function TProjectManager.BuildProject(const AProjectDir: string; const ATarget: string): Boolean;',
            'function TProjectManager.CleanProject(const AProjectDir: string): Boolean;',
        )
        test_section = self._section(
            'function TProjectManager.TestProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean;',
            'function TProjectManager.RunProject(const AProjectDir: string; const AArgs: string): Boolean;',
        )
        run_section = self._section(
            'function TProjectManager.RunProject(const Outp, Errp: IOutput; const AProjectDir: string; const AArgs: string): Boolean;',
            'function TProjectManager.InstallTemplate(const ATemplatePath: string): Boolean;',
        )

        self.assertIn('ExecuteProjectBuildCore(', build_section)
        self.assertIn('ExecuteProjectTestCore(', test_section)
        self.assertIn('ExecuteProjectRunCore(', run_section)

    def test_clean_delegates_to_cleanflow(self):
        clean_section = self._section(
            'function TProjectManager.CleanProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean;',
            'function TProjectManager.TestProject(const AProjectDir: string): Boolean;',
        )

        self.assertIn('ExecuteProjectCleanCore(', clean_section)
        self.assertNotIn('CleanBuildArtifacts(', clean_section)


if __name__ == '__main__':
    unittest.main()
