unit fpdev.project.generator;

{$mode objfpc}{$H+}

{
  TProjectTemplateGenerator - Project file generation service

  Extracted from fpdev.cmd.project to handle:
  - Template-specific project file generation
  - Console, GUI, Library project types
  - README.md, .gitignore generation
}

interface

uses
  SysUtils, Classes;

type
  { TProjectType }
  TProjectType = (
    ptConsole, ptGUI, ptLibrary, ptPackage, ptWebApp, ptService, ptGame, ptCustom
  );

  { TProjectTemplate }
  TProjectTemplate = record
    Name: string;
    DisplayName: string;
    Description: string;
    ProjectType: TProjectType;
    Available: Boolean;
  end;

  { TProjectTemplateGenerator }
  TProjectTemplateGenerator = class
  private
    procedure WriteReadmeFile(const ATargetDir, AProjectName, ADescription: string);
    procedure WriteGitIgnoreFile(const ATargetDir, AProjectName: string);
    procedure WriteConsoleProject(const ATargetDir, AProjectName: string);
    procedure WriteGUIProject(const ATargetDir, AProjectName: string);
    procedure WriteLibraryProject(const ATargetDir, AProjectName: string);
    procedure WriteDefaultProject(const ATargetDir, AProjectName: string);
  public
    { Generate project files from template }
    function GenerateProjectFiles(const ATemplate: TProjectTemplate;
      const AProjectName, ATargetDir: string): Boolean;
  end;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings;

{ TProjectTemplateGenerator }

procedure TProjectTemplateGenerator.WriteReadmeFile(const ATargetDir, AProjectName, ADescription: string);
var
  ReadmeFile: TextFile;
begin
  AssignFile(ReadmeFile, ATargetDir + PathDelim + 'README.md');
  Rewrite(ReadmeFile);
  WriteLn(ReadmeFile, '# ', AProjectName);
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, ADescription);
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, '## Building');
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, '```bash');
  WriteLn(ReadmeFile, 'fpdev project build .');
  WriteLn(ReadmeFile, '```');
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, '## Running');
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, '```bash');
  WriteLn(ReadmeFile, 'fpdev project run .');
  WriteLn(ReadmeFile, '```');
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, '## License');
  WriteLn(ReadmeFile, '');
  WriteLn(ReadmeFile, 'MIT');
  CloseFile(ReadmeFile);
end;

procedure TProjectTemplateGenerator.WriteGitIgnoreFile(const ATargetDir, AProjectName: string);
var
  GitIgnoreFile: TextFile;
begin
  AssignFile(GitIgnoreFile, ATargetDir + PathDelim + '.gitignore');
  Rewrite(GitIgnoreFile);
  WriteLn(GitIgnoreFile, '# Compiled units');
  WriteLn(GitIgnoreFile, '*.o');
  WriteLn(GitIgnoreFile, '*.ppu');
  WriteLn(GitIgnoreFile, '*.a');
  WriteLn(GitIgnoreFile, '*.compiled');
  WriteLn(GitIgnoreFile, '*.res');
  WriteLn(GitIgnoreFile, '*.rst');
  WriteLn(GitIgnoreFile, '*.rsj');
  WriteLn(GitIgnoreFile, '');
  WriteLn(GitIgnoreFile, '# Executables');
  {$IFDEF MSWINDOWS}
  WriteLn(GitIgnoreFile, '*.exe');
  WriteLn(GitIgnoreFile, '*.dll');
  {$ELSE}
  WriteLn(GitIgnoreFile, AProjectName);
  WriteLn(GitIgnoreFile, '*.so');
  WriteLn(GitIgnoreFile, '*.dylib');
  {$ENDIF}
  WriteLn(GitIgnoreFile, '');
  WriteLn(GitIgnoreFile, '# Lazarus files');
  WriteLn(GitIgnoreFile, '*.lps');
  WriteLn(GitIgnoreFile, 'backup/');
  WriteLn(GitIgnoreFile, 'lib/');
  WriteLn(GitIgnoreFile, '');
  WriteLn(GitIgnoreFile, '# IDE folders');
  WriteLn(GitIgnoreFile, '.lazarus/');
  WriteLn(GitIgnoreFile, '.vscode/');
  CloseFile(GitIgnoreFile);
end;

procedure TProjectTemplateGenerator.WriteConsoleProject(const ATargetDir, AProjectName: string);
var
  MainFile: TextFile;
  ProjectFile: TextFile;
  MainFileName, ProjectFileName: string;
  SafeProgramName: string;
begin
  // Convert project name to valid Pascal identifier (replace hyphens with underscores)
  SafeProgramName := StringReplace(AProjectName, '-', '_', [rfReplaceAll]);
  
  // Create main program file
  MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
  AssignFile(MainFile, MainFileName);
  Rewrite(MainFile);
  WriteLn(MainFile, 'program ', SafeProgramName, ';');
  WriteLn(MainFile, '');
  WriteLn(MainFile, '{$mode objfpc}{$H+}');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'uses');
  WriteLn(MainFile, '  SysUtils;');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'begin');
  WriteLn(MainFile, '  WriteLn(''Hello from ', AProjectName, '!'');');
  WriteLn(MainFile, 'end.');
  CloseFile(MainFile);

  // Create .lpi project file for console app
  ProjectFileName := ATargetDir + PathDelim + AProjectName + '.lpi';
  AssignFile(ProjectFile, ProjectFileName);
  Rewrite(ProjectFile);
  WriteLn(ProjectFile, '<?xml version="1.0" encoding="UTF-8"?>');
  WriteLn(ProjectFile, '<CONFIG>');
  WriteLn(ProjectFile, '  <ProjectOptions>');
  WriteLn(ProjectFile, '    <Version Value="12"/>');
  WriteLn(ProjectFile, '    <General>');
  WriteLn(ProjectFile, '      <Flags>');
  WriteLn(ProjectFile, '        <MainUnitHasCreateFormStatements Value="False"/>');
  WriteLn(ProjectFile, '        <MainUnitHasTitleStatement Value="False"/>');
  WriteLn(ProjectFile, '        <MainUnitHasScaledStatement Value="False"/>');
  WriteLn(ProjectFile, '      </Flags>');
  WriteLn(ProjectFile, '      <SessionStorage Value="InProjectDir"/>');
  WriteLn(ProjectFile, '      <Title Value="', AProjectName, '"/>');
  WriteLn(ProjectFile, '      <UseAppBundle Value="False"/>');
  WriteLn(ProjectFile, '      <ResourceType Value="res"/>');
  WriteLn(ProjectFile, '    </General>');
  WriteLn(ProjectFile, '    <BuildModes>');
  WriteLn(ProjectFile, '      <Item Name="Default" Default="True"/>');
  WriteLn(ProjectFile, '    </BuildModes>');
  WriteLn(ProjectFile, '    <Units>');
  WriteLn(ProjectFile, '      <Unit>');
  WriteLn(ProjectFile, '        <Filename Value="', AProjectName, '.lpr"/>');
  WriteLn(ProjectFile, '        <IsPartOfProject Value="True"/>');
  WriteLn(ProjectFile, '      </Unit>');
  WriteLn(ProjectFile, '    </Units>');
  WriteLn(ProjectFile, '  </ProjectOptions>');
  WriteLn(ProjectFile, '  <CompilerOptions>');
  WriteLn(ProjectFile, '    <Version Value="11"/>');
  WriteLn(ProjectFile, '    <Target>');
  WriteLn(ProjectFile, '      <Filename Value="', AProjectName, '"/>');
  WriteLn(ProjectFile, '    </Target>');
  WriteLn(ProjectFile, '    <SearchPaths>');
  WriteLn(ProjectFile, '      <IncludeFiles Value="$(ProjOutDir)"/>');
  WriteLn(ProjectFile, '      <UnitOutputDirectory Value="lib/$(TargetCPU)-$(TargetOS)"/>');
  WriteLn(ProjectFile, '    </SearchPaths>');
  WriteLn(ProjectFile, '  </CompilerOptions>');
  WriteLn(ProjectFile, '</CONFIG>');
  CloseFile(ProjectFile);
end;

procedure TProjectTemplateGenerator.WriteGUIProject(const ATargetDir, AProjectName: string);
var
  MainFile: TextFile;
  ProjectFile: TextFile;
  MainFileName, ProjectFileName: string;
begin
  // Create Lazarus project file
  ProjectFileName := ATargetDir + PathDelim + AProjectName + '.lpi';
  AssignFile(ProjectFile, ProjectFileName);
  Rewrite(ProjectFile);
  WriteLn(ProjectFile, '<?xml version="1.0" encoding="UTF-8"?>');
  WriteLn(ProjectFile, '<CONFIG>');
  WriteLn(ProjectFile, '  <ProjectOptions>');
  WriteLn(ProjectFile, '    <Version Value="12"/>');
  WriteLn(ProjectFile, '    <General>');
  WriteLn(ProjectFile, '      <Flags>');
  WriteLn(ProjectFile, '        <CompatibilityMode Value="True"/>');
  WriteLn(ProjectFile, '      </Flags>');
  WriteLn(ProjectFile, '      <SessionStorage Value="InProjectDir"/>');
  WriteLn(ProjectFile, '      <Title Value="', AProjectName, '"/>');
  WriteLn(ProjectFile, '      <Scaled Value="True"/>');
  WriteLn(ProjectFile, '      <ResourceType Value="res"/>');
  WriteLn(ProjectFile, '      <UseXPManifest Value="True"/>');
  WriteLn(ProjectFile, '      <XPManifest>');
  WriteLn(ProjectFile, '        <DpiAware Value="True"/>');
  WriteLn(ProjectFile, '      </XPManifest>');
  WriteLn(ProjectFile, '    </General>');
  WriteLn(ProjectFile, '    <BuildModes>');
  WriteLn(ProjectFile, '      <Item Name="Default" Default="True"/>');
  WriteLn(ProjectFile, '    </BuildModes>');
  WriteLn(ProjectFile, '    <Units>');
  WriteLn(ProjectFile, '      <Unit>');
  WriteLn(ProjectFile, '        <Filename Value="', AProjectName, '.lpr"/>');
  WriteLn(ProjectFile, '        <IsPartOfProject Value="True"/>');
  WriteLn(ProjectFile, '      </Unit>');
  WriteLn(ProjectFile, '    </Units>');
  WriteLn(ProjectFile, '  </ProjectOptions>');
  WriteLn(ProjectFile, '  <CompilerOptions>');
  WriteLn(ProjectFile, '    <Version Value="11"/>');
  WriteLn(ProjectFile, '    <Target>');
  WriteLn(ProjectFile, '      <Filename Value="', AProjectName, '"/>');
  WriteLn(ProjectFile, '    </Target>');
  WriteLn(ProjectFile, '    <SearchPaths>');
  WriteLn(ProjectFile, '      <IncludeFiles Value="$(ProjOutDir)"/>');
  WriteLn(ProjectFile, '      <UnitOutputDirectory Value="lib/$(TargetCPU)-$(TargetOS)"/>');
  WriteLn(ProjectFile, '    </SearchPaths>');
  WriteLn(ProjectFile, '    <Linking>');
  WriteLn(ProjectFile, '      <Debugging>');
  WriteLn(ProjectFile, '        <DebugInfoType Value="dsDwarf3"/>');
  WriteLn(ProjectFile, '      </Debugging>');
  WriteLn(ProjectFile, '      <Options>');
  WriteLn(ProjectFile, '        <Win32>');
  WriteLn(ProjectFile, '          <GraphicApplication Value="True"/>');
  WriteLn(ProjectFile, '        </Win32>');
  WriteLn(ProjectFile, '      </Options>');
  WriteLn(ProjectFile, '    </Linking>');
  WriteLn(ProjectFile, '  </CompilerOptions>');
  WriteLn(ProjectFile, '</CONFIG>');
  CloseFile(ProjectFile);

  // Create main program file
  MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
  AssignFile(MainFile, MainFileName);
  Rewrite(MainFile);
  WriteLn(MainFile, 'program ', AProjectName, ';');
  WriteLn(MainFile, '');
  WriteLn(MainFile, '{$mode objfpc}{$H+}');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'uses');
  WriteLn(MainFile, '  {$IFDEF UNIX}');
  WriteLn(MainFile, '  cthreads,');
  WriteLn(MainFile, '  {$ENDIF}');
  WriteLn(MainFile, '  Interfaces, Forms;');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'begin');
  WriteLn(MainFile, '  RequireDerivedFormResource := True;');
  WriteLn(MainFile, '  Application.Scaled := True;');
  WriteLn(MainFile, '  Application.Initialize;');
  WriteLn(MainFile, '  Application.Run;');
  WriteLn(MainFile, 'end.');
  CloseFile(MainFile);
end;

procedure TProjectTemplateGenerator.WriteLibraryProject(const ATargetDir, AProjectName: string);
var
  MainFile: TextFile;
  MainFileName: string;
begin
  // Create library source file
  MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
  AssignFile(MainFile, MainFileName);
  Rewrite(MainFile);
  WriteLn(MainFile, 'library ', AProjectName, ';');
  WriteLn(MainFile, '');
  WriteLn(MainFile, '{$mode objfpc}{$H+}');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'uses');
  WriteLn(MainFile, '  SysUtils;');
  WriteLn(MainFile, '');
  WriteLn(MainFile, '// Export your functions here');
  WriteLn(MainFile, '// function MyExportedFunction: Integer; cdecl;');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'exports');
  WriteLn(MainFile, '  // MyExportedFunction;');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'begin');
  WriteLn(MainFile, 'end.');
  CloseFile(MainFile);
end;

procedure TProjectTemplateGenerator.WriteDefaultProject(const ATargetDir, AProjectName: string);
var
  MainFile: TextFile;
  MainFileName: string;
begin
  MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
  AssignFile(MainFile, MainFileName);
  Rewrite(MainFile);
  WriteLn(MainFile, 'program ', AProjectName, ';');
  WriteLn(MainFile, '');
  WriteLn(MainFile, '{$mode objfpc}{$H+}');
  WriteLn(MainFile, '');
  WriteLn(MainFile, 'begin');
  WriteLn(MainFile, '  WriteLn(''Hello from ', AProjectName, '!'');');
  WriteLn(MainFile, 'end.');
  CloseFile(MainFile);
end;

function TProjectTemplateGenerator.GenerateProjectFiles(const ATemplate: TProjectTemplate;
  const AProjectName, ATargetDir: string): Boolean;
begin
  Result := False;

  try
    // Create README.md
    WriteReadmeFile(ATargetDir, AProjectName, ATemplate.Description);

    // Create .gitignore
    WriteGitIgnoreFile(ATargetDir, AProjectName);

    // Generate project-type specific files
    case ATemplate.ProjectType of
      ptConsole:
        WriteConsoleProject(ATargetDir, AProjectName);

      ptGUI:
        WriteGUIProject(ATargetDir, AProjectName);

      ptLibrary:
        WriteLibraryProject(ATargetDir, AProjectName);

    else
      // Default: console application
      WriteDefaultProject(ATargetDir, AProjectName);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn(_Fmt(CMD_PROJECT_GENERATE_ERROR, [E.Message]));
      Result := False;
    end;
  end;
end;

end.
