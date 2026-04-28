import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROJECT_MANAGER = REPO_ROOT / 'src' / 'fpdev.project.manager.pas'


class ProjectManagerBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = PROJECT_MANAGER.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_manager_imports_templateflow_unit(self):
        self.assertIn('fpdev.project.templateflow', self.text)

    def test_manager_imports_createflow_unit(self):
        self.assertIn('fpdev.project.createflow', self.text)

    def test_create_surface_delegates_to_createflow(self):
        create_from_template_section = self._section(
            'function TProjectManager.CreateFromTemplate(const ATemplateName, AProjectName, ATargetDir: string): Boolean;',
            'function TProjectManager.SetupProjectEnvironment(const AProjectDir: string): Boolean;',
        )
        create_project_section = self._section(
            'function TProjectManager.CreateProject(const ATemplateName, AProjectName, ATargetDir: string): Boolean;',
            'function TProjectManager.ListTemplates: Boolean;',
        )

        self.assertIn('ExecuteProjectCreateFromTemplateCore(', create_from_template_section)
        self.assertNotIn('EnsureDir(ATargetDir)', create_from_template_section)
        self.assertNotIn('FGenerator.GenerateProjectFiles(', create_from_template_section)

        self.assertIn('ExecuteProjectCreateCore(', create_project_section)
        self.assertNotIn('if not ValidateProjectName(AProjectName) then', create_project_section)
        self.assertNotIn("LOut.WriteLn('Warning: Project environment setup incomplete for: ' + ATargetDir);", create_project_section)

    def test_list_and_info_delegate_to_templateflow(self):
        list_section = self._section(
            'function TProjectManager.ListTemplates(const Outp: IOutput): Boolean;',
            'function TProjectManager.ShowTemplateInfo(const ATemplateName: string): Boolean;',
        )
        info_section = self._section(
            'function TProjectManager.ShowTemplateInfo(const Outp, Errp: IOutput; const ATemplateName: string): Boolean;',
            'function TProjectManager.ExecuteProcess(const AExecutable: string;',
        )

        self.assertIn('ExecuteProjectTemplateListCore(', list_section)
        self.assertNotIn('case Templates[i].ProjectType of', list_section)

        self.assertIn('ExecuteProjectTemplateInfoCore(', info_section)
        self.assertNotIn("LO.WriteLn(Format('Name:        %s'", info_section)

    def test_install_remove_and_update_delegate_to_templateflow(self):
        install_section = self._section(
            'function TProjectManager.InstallTemplate(const Outp, Errp: IOutput; const ATemplatePath: string): Boolean;',
            'function TProjectManager.RemoveTemplate(const ATemplateName: string): Boolean;',
        )
        remove_section = self._section(
            'function TProjectManager.RemoveTemplate(const Outp, Errp: IOutput; const ATemplateName: string): Boolean;',
            'function TProjectManager.UpdateTemplates: Boolean;',
        )
        update_section = self._section(
            'function TProjectManager.UpdateTemplates(const Outp, Errp: IOutput): Boolean;',
            'end.',
        )

        self.assertIn('ExecuteProjectTemplateInstallCore(', install_section)
        self.assertNotIn('FindFirst(ATemplatePath + PathDelim + \'*\'', install_section)

        self.assertIn('ExecuteProjectTemplateRemoveCore(', remove_section)
        self.assertNotIn('IsBuiltin := False;', remove_section)

        self.assertIn('ExecuteProjectTemplateUpdateCore(', update_section)
        self.assertNotIn('if not Repo.Initialize then', update_section)
        self.assertNotIn('if not Repo.Update(True) then', update_section)
        self.assertNotIn("TemplatesDir := Repo.LocalPath + PathDelim + 'templates';", update_section)


if __name__ == '__main__':
    unittest.main()
