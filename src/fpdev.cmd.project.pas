unit fpdev.cmd.project;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.project

FreePascal project management and template system


## Notice

If you redistribute or use this in your own project, please keep this project's copyright notice. Thanks.

fafafaStudio
Email:dtamade@gmail.com
QQ group: 685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config, fpdev.config.interfaces, fpdev.output.intf, fpdev.output.console,
  fpdev.resource.repo, fpdev.resource.repo.types, fpdev.utils.fs, fpdev.utils.process,
  fpdev.i18n, fpdev.i18n.strings,
  fpdev.project.generator, fpdev.project.execflow;

type
  TProjectTemplateArray = array of TProjectTemplate;

  { TProjectManager }
  TProjectManager = class
  private
    FConfigManager: IConfigManager;
    FTemplatesRoot: string;
    FGenerator: TProjectTemplateGenerator;  // Project file generation service

    function GetAvailableTemplates: TProjectTemplateArray;
    function CreateFromTemplate(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
    function ValidateProjectName(const AProjectName: string): Boolean;
    function GetTemplateInfo(const ATemplateName: string): TProjectTemplate;
    function SetupProjectEnvironment(const AProjectDir: string): Boolean;
    function ExecuteProcess(const AExecutable: string;
      const AParams: SysUtils.TStringArray; const AWorkDir: string): TProcessResult;
    function RunDirectProcess(const AExecutable: string;
      const AParams: SysUtils.TStringArray; const AWorkDir: string): TProcessResult;
    procedure CopyTemplateDirectory(const ASrcDir, ADestDir: string);

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

    // Template queries
    function GetTemplateList: TProjectTemplateArray;

    // Project creation
    function CreateProject(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
    function ListTemplates: Boolean; overload;
    function ListTemplates(const Outp: IOutput): Boolean; overload;
    function ShowTemplateInfo(const ATemplateName: string): Boolean; overload;
    function ShowTemplateInfo(const Outp, Errp: IOutput; const ATemplateName: string): Boolean; overload;

    // Project management
    function BuildProject(const AProjectDir: string; const ATarget: string = ''): Boolean;
    function CleanProject(const AProjectDir: string): Boolean; overload;
    function CleanProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean; overload;
    function TestProject(const AProjectDir: string): Boolean; overload;
    function TestProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean; overload;
    function RunProject(const AProjectDir: string; const AArgs: string = ''): Boolean; overload;
    function RunProject(
      const Outp, Errp: IOutput;
      const AProjectDir: string;
      const AArgs: string = ''
    ): Boolean; overload;

    // Template management
    function InstallTemplate(const ATemplatePath: string): Boolean; overload;
    function InstallTemplate(const Outp, Errp: IOutput; const ATemplatePath: string): Boolean; overload;
    function RemoveTemplate(const ATemplateName: string): Boolean; overload;
    function RemoveTemplate(const Outp, Errp: IOutput; const ATemplateName: string): Boolean; overload;
    function UpdateTemplates: Boolean; overload;
    function UpdateTemplates(const Outp, Errp: IOutput): Boolean; overload;
  end;

implementation

const
  PROJECT_NAME_UNIX_PATH_SEPARATOR = '/';

  // Built-in project templates
  BUILTIN_TEMPLATES: array[0..6] of TProjectTemplate = (
    (Name: 'console'; DisplayName: 'Console Application';
      Description: 'Simple console application'; ProjectType: ptConsole; Available: True),
    (Name: 'gui'; DisplayName: 'GUI Application';
      Description: 'Lazarus GUI application'; ProjectType: ptGUI; Available: True),
    (Name: 'library'; DisplayName: 'Dynamic Library';
      Description: 'Shared library project'; ProjectType: ptLibrary; Available: True),
    (Name: 'package'; DisplayName: 'Lazarus Package';
      Description: 'Lazarus package project'; ProjectType: ptPackage; Available: True),
    (Name: 'webapp'; DisplayName: 'Web Application';
      Description: 'Pascal web application'; ProjectType: ptWebApp; Available: True),
    (Name: 'service'; DisplayName: 'System Service';
      Description: 'Background service application'; ProjectType: ptService; Available: True),
    (Name: 'game'; DisplayName: 'Game Project';
      Description: 'Simple game project template'; ProjectType: ptGame; Available: True)
  );

{ TProjectManager }

constructor TProjectManager.Create(AConfigManager: TFPDevConfigManager);
begin
  Create(AConfigManager.AsConfigManager);
end;

constructor TProjectManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FTemplatesRoot := Settings.InstallRoot + PathDelim + 'templates';

  // Ensure the templates directory exists
  EnsureDir(FTemplatesRoot);

  // Initialize project file generator service
  FGenerator := TProjectTemplateGenerator.Create;
end;

destructor TProjectManager.Destroy;
begin
  FGenerator.Free;
  inherited Destroy;
end;

procedure TProjectManager.CopyTemplateDirectory(const ASrcDir, ADestDir: string);
var
  SR: TSearchRec;
  SrcPath, DstPath: string;
  SrcStream, DstStream: TFileStream;
begin
  // Ensure destination directory exists
  EnsureDir(ADestDir);

  // Scan source directory
  if FindFirst(ASrcDir + PathDelim + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      // Skip special directories
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      SrcPath := ASrcDir + PathDelim + SR.Name;
      DstPath := ADestDir + PathDelim + SR.Name;

      if (SR.Attr and faDirectory) <> 0 then
      begin
        // Recursively copy subdirectory
        CopyTemplateDirectory(SrcPath, DstPath);
      end
      else
      begin
        // Copy file
        try
          SrcStream := TFileStream.Create(SrcPath, fmOpenRead or fmShareDenyWrite);
          try
            DstStream := TFileStream.Create(DstPath, fmCreate);
            try
              DstStream.CopyFrom(SrcStream, SrcStream.Size);
            finally
              DstStream.Free;
            end;
          finally
            SrcStream.Free;
          end;
        except
          // Ignore individual file copy errors, continue with next file
        end;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TProjectManager.ValidateProjectName(const AProjectName: string): Boolean;
begin
  Result := (AProjectName <> '') and
            (Pos(' ', AProjectName) = 0) and
            (Pos(PROJECT_NAME_UNIX_PATH_SEPARATOR, AProjectName) = 0) and
            (Pos(PathDelim, AProjectName) = 0);
end;

function TProjectManager.GetTemplateInfo(const ATemplateName: string): TProjectTemplate;
var
  i: Integer;
begin
  Result := Default(TProjectTemplate);

  for i := 0 to High(BUILTIN_TEMPLATES) do
  begin
    if SameText(BUILTIN_TEMPLATES[i].Name, ATemplateName) then
    begin
      Result := BUILTIN_TEMPLATES[i];
      Break;
    end;
  end;
end;

function TProjectManager.GetAvailableTemplates: TProjectTemplateArray;
var
  i: Integer;
begin
  Result := nil;
  SetLength(Result, Length(BUILTIN_TEMPLATES));
  for i := 0 to High(BUILTIN_TEMPLATES) do
    Result[i] := BUILTIN_TEMPLATES[i];
end;

function TProjectManager.GetTemplateList: TProjectTemplateArray;
begin
  Result := GetAvailableTemplates;
end;

function TProjectManager.CreateFromTemplate(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
var
  Template: TProjectTemplate;
begin
  Result := False;

  Template := GetTemplateInfo(ATemplateName);
  if Template.Name = '' then
  begin
    Exit;
  end;

  try
    // Ensure the target directory exists
    if not DirectoryExists(ATargetDir) then
      EnsureDir(ATargetDir);

    // Delegate to the project file generation service
    Result := FGenerator.GenerateProjectFiles(Template, AProjectName, ATargetDir);

  except
    on E: Exception do
      Result := False;
  end;
end;

function TProjectManager.SetupProjectEnvironment(const AProjectDir: string): Boolean;
begin
  Result := True;
  // Future enhancement: create build scripts, IDE configuration, etc.
  if AProjectDir <> '' then; // Suppress unused parameter hint
end;

function TProjectManager.CreateProject(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
var
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := False;

  if not ValidateProjectName(AProjectName) then
  begin
    Exit;
  end;

  try

    // Create project from template
    if not CreateFromTemplate(ATemplateName, AProjectName, ATargetDir) then
    begin
      Exit;
    end;

    // Setup project environment
    if not SetupProjectEnvironment(ATargetDir) then
    begin
      LOut.WriteLn('Warning: Project environment setup incomplete for: ' + ATargetDir);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      LOut.WriteLn('CreateProject exception: ' + E.Message);
      {$ENDIF}
      Result := False;
    end;
  end;
end;

function TProjectManager.ListTemplates: Boolean;
begin
  Result := ListTemplates(nil);
end;

function TProjectManager.ListTemplates(const Outp: IOutput): Boolean;
var
  Templates: TProjectTemplateArray;
  i: Integer;
  Line: string;
  LO: IOutput;
begin
  Result := True;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    Templates := GetAvailableTemplates;


    for i := 0 to High(Templates) do
    begin
      Line := Format('%-10s  ', [Templates[i].Name]);
      case Templates[i].ProjectType of
        ptConsole: Line := Line + 'Console     ';
        ptGUI: Line := Line + 'GUI App     ';
        ptLibrary: Line := Line + 'Library     ';
        ptPackage: Line := Line + 'Package     ';
        ptWebApp: Line := Line + 'Web App     ';
        ptService: Line := Line + 'Service     ';
        ptGame: Line := Line + 'Game        ';
      else
        Line := Line + 'Custom      ';
      end;
      Line := Line + Templates[i].Description;
      LO.WriteLn(Line);
    end;


  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      LO.WriteLn('ListTemplates exception: ' + E.Message);
      {$ENDIF}
      Result := False;
    end;
  end;
end;

function TProjectManager.ShowTemplateInfo(const ATemplateName: string): Boolean;
begin
  Result := ShowTemplateInfo(nil, nil, ATemplateName);
end;

function TProjectManager.ShowTemplateInfo(const Outp, Errp: IOutput; const ATemplateName: string): Boolean;
var
  Template: TProjectTemplate;
  LO: IOutput;
  LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  try
    Template := GetTemplateInfo(ATemplateName);

    if Template.Name = '' then
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TEMPLATE_NOT_FOUND, [ATemplateName]));
      Exit;
    end;


    LO.WriteLn(Format('Name:        %s', [Template.Name]));
    LO.WriteLn(Format('Display:     %s', [Template.DisplayName]));
    LO.WriteLn(Format('Description: %s', [Template.Description]));
    LO.Write('Type:        ');
    case Template.ProjectType of
      ptConsole: LO.WriteLn(_(CMD_PROJECT_TYPE_CONSOLE));
      ptGUI: LO.WriteLn(_(CMD_PROJECT_TYPE_GUI));
      ptLibrary: LO.WriteLn(_(CMD_PROJECT_TYPE_LIBRARY));
      ptPackage: LO.WriteLn(_(CMD_PROJECT_TYPE_PACKAGE));
      ptWebApp: LO.WriteLn(_(CMD_PROJECT_TYPE_WEBAPP));
      ptService: LO.WriteLn(_(CMD_PROJECT_TYPE_SERVICE));
      ptGame: LO.WriteLn(_(CMD_PROJECT_TYPE_GAME));
    else
      LO.WriteLn(_(CMD_PROJECT_TYPE_CUSTOM));
    end;

    Result := True;

  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      LO.WriteLn('ShowTemplateInfo exception: ' + E.Message);
      {$ENDIF}
      Result := False;
    end;
  end;
end;

function TProjectManager.ExecuteProcess(const AExecutable: string;
  const AParams: SysUtils.TStringArray; const AWorkDir: string): TProcessResult;
begin
  Result := TProcessExecutor.Execute(AExecutable, AParams, AWorkDir);
end;

function TProjectManager.RunDirectProcess(const AExecutable: string;
  const AParams: SysUtils.TStringArray; const AWorkDir: string): TProcessResult;
begin
  Result := TProcessExecutor.RunDirect(AExecutable, AParams, AWorkDir);
end;

function TProjectManager.BuildProject(const AProjectDir: string; const ATarget: string): Boolean;
{$IFDEF DEBUG}
var
  LOut: IOutput;
{$ENDIF}
begin
  {$IFDEF DEBUG}
  LOut := TConsoleOutput.Create(True) as IOutput;
  {$ENDIF}
  Result := False;

  try
    Result := ExecuteProjectBuildCore(AProjectDir, ATarget, @RunDirectProcess);
  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      LOut.WriteLn('BuildProject exception: ' + E.Message);
      {$ENDIF}
      Result := False;
    end;
  end;
end;

function TProjectManager.CleanProject(const AProjectDir: string): Boolean;
begin
  Result := CleanProject(nil, nil, AProjectDir);
end;

function TProjectManager.CleanProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean;
var
  DeletedCount: Integer;
  LO: IOutput;
  LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Validate directory exists
  if not DirectoryExists(AProjectDir) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_DIR_NOT_FOUND, [AProjectDir]));
    Exit;
  end;

  try
    // Use shared cleanup function (includes platform executables)
    DeletedCount := CleanBuildArtifacts(AProjectDir, nil, True);
    LO.WriteLn(_Fmt(CMD_PROJECT_CLEANED, [DeletedCount, AProjectDir]));
    Result := True;

  except
    on E: Exception do
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.TestProject(const AProjectDir: string): Boolean;
begin
  Result := TestProject(nil, nil, AProjectDir);
end;

function TProjectManager.TestProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean;
var
  LO: IOutput;
  LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  try
    Result := ExecuteProjectTestCore(AProjectDir, LO, LE, @ExecuteProcess);
  except
    on E: Exception do
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.RunProject(const AProjectDir: string; const AArgs: string): Boolean;
begin
  Result := RunProject(nil, nil, AProjectDir, AArgs);
end;

function TProjectManager.RunProject(const Outp, Errp: IOutput; const AProjectDir: string; const AArgs: string): Boolean;
var
  LO: IOutput;
  LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  try
    Result := ExecuteProjectRunCore(AProjectDir, AArgs, LO, LE, @ExecuteProcess);
  except
    on E: Exception do
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.InstallTemplate(const ATemplatePath: string): Boolean;
begin
  Result := InstallTemplate(nil, nil, ATemplatePath);
end;

function TProjectManager.InstallTemplate(const Outp, Errp: IOutput; const ATemplatePath: string): Boolean;
var
  TemplateName: string;
  DestDir: string;
  SR: TSearchRec;
  SrcFile, DstFile: string;
  SrcStream, DstStream: TFileStream;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if not DirectoryExists(ATemplatePath) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TPL_PATH_NOT_EXIST, [ATemplatePath]));
    Exit;
  end;

  // Extract template name from path
  TemplateName := ExtractFileName(ExcludeTrailingPathDelimiter(ATemplatePath));
  if TemplateName = '' then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PROJECT_TPL_INVALID_PATH));
    Exit;
  end;

  // Create destination directory
  DestDir := FTemplatesRoot + PathDelim + TemplateName;
  if DirectoryExists(DestDir) then
  begin
    LO.WriteLn(_(MSG_WARNING) + ': ' + _Fmt(CMD_PROJECT_TPL_OVERWRITING, [TemplateName]));
  end;

  try
    EnsureDir(DestDir);

    // Copy all files from source to destination
    if FindFirst(ATemplatePath + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and
           ((SR.Attr and faDirectory) = 0) then
        begin
          SrcFile := ATemplatePath + PathDelim + SR.Name;
          DstFile := DestDir + PathDelim + SR.Name;

          SrcStream := TFileStream.Create(SrcFile, fmOpenRead or fmShareDenyWrite);
          try
            DstStream := TFileStream.Create(DstFile, fmCreate);
            try
              DstStream.CopyFrom(SrcStream, SrcStream.Size);
            finally
              DstStream.Free;
            end;
          finally
            SrcStream.Free;
          end;
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    LO.WriteLn(_Fmt(CMD_PROJECT_TPL_INSTALLED, [TemplateName]));
    Result := True;

  except
    on E: Exception do
    begin
      LE.WriteLn(_Fmt(CMD_PROJECT_TPL_INSTALL_ERROR, [E.Message]));
      Result := False;
    end;
  end;
end;

function TProjectManager.RemoveTemplate(const ATemplateName: string): Boolean;
begin
  Result := RemoveTemplate(nil, nil, ATemplateName);
end;

function TProjectManager.RemoveTemplate(const Outp, Errp: IOutput; const ATemplateName: string): Boolean;
var
  TemplateDir: string;
  i: Integer;
  IsBuiltin: Boolean;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if ATemplateName = '' then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PROJECT_TPL_NAME_REQUIRED));
    Exit;
  end;

  // Check if it's a built-in template
  IsBuiltin := False;
  for i := 0 to High(BUILTIN_TEMPLATES) do
  begin
    if SameText(BUILTIN_TEMPLATES[i].Name, ATemplateName) then
    begin
      IsBuiltin := True;
      Break;
    end;
  end;

  if IsBuiltin then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TPL_BUILTIN_REMOVE, [ATemplateName]));
    Exit;
  end;

  // Check if template exists
  TemplateDir := FTemplatesRoot + PathDelim + ATemplateName;
  if not DirectoryExists(TemplateDir) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TPL_NOT_FOUND, [ATemplateName]));
    Exit;
  end;

  try
    DeleteDirRecursive(TemplateDir);
    LO.WriteLn(_Fmt(CMD_PROJECT_TPL_REMOVED, [ATemplateName]));
    Result := True;

  except
    on E: Exception do
    begin
      LE.WriteLn(_Fmt(CMD_PROJECT_TPL_REMOVE_ERROR, [E.Message]));
      Result := False;
    end;
  end;
end;

function TProjectManager.UpdateTemplates: Boolean;
begin
  Result := UpdateTemplates(nil, nil);
end;

function TProjectManager.UpdateTemplates(const Outp, Errp: IOutput): Boolean;
var
  Repo: TResourceRepository;
  RepoConfig: TResourceRepoConfig;
  TemplatesDir, TemplateSrc, TemplateDest: string;
  SR: TSearchRec;
  UpdatedCount, AddedCount: Integer;
  MetaPath: string;
  LO, LE: IOutput;
begin
  Result := False;
  UpdatedCount := 0;
  AddedCount := 0;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  try
    // Create resource repository with default config
    RepoConfig := CreateDefaultConfig;
    Repo := TResourceRepository.Create(RepoConfig);
    try
      // Initialize and update repository
      if not Repo.Initialize then
      begin
        LO.WriteLn(_(MSG_INFO) + ': ' + _(CMD_PROJECT_TPL_REPO_UNAVAIL));
        Exit(True);  // Non-fatal - just skip online update
      end;

      // Force update to get latest templates
      if not Repo.Update(True) then
      begin
        LO.WriteLn(_(MSG_WARNING) + ': ' + _(CMD_PROJECT_TPL_UPDATE_FAILED));
        // Continue anyway - we may have local templates
      end;

      // Look for templates directory in repo
      TemplatesDir := Repo.LocalPath + PathDelim + 'templates';
      if not DirectoryExists(TemplatesDir) then
      begin
        LO.WriteLn(_(MSG_INFO) + ': ' + _(CMD_PROJECT_TPL_NO_TEMPLATES));
        Exit(True);  // Non-fatal - templates may not be in repo yet
      end;

      // Ensure local templates directory exists
      if not DirectoryExists(FTemplatesRoot) then
        EnsureDir(FTemplatesRoot);

      // Scan templates in repo and copy to local
      if FindFirst(TemplatesDir + PathDelim + '*', faDirectory, SR) = 0 then
      begin
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
          begin
            TemplateSrc := TemplatesDir + PathDelim + SR.Name;
            TemplateDest := FTemplatesRoot + PathDelim + SR.Name;

            // Check if template has metadata file (required for valid template)
            MetaPath := TemplateSrc + PathDelim + 'template.json';
            if not FileExists(MetaPath) then
              Continue;  // Skip directories without template.json

            // Check if template needs update (simple: compare existence)
            if DirectoryExists(TemplateDest) then
            begin
              // Template exists, could add version comparison here
              // For now, always update
              Inc(UpdatedCount);
            end
            else
            begin
              // New template
              EnsureDir(TemplateDest);
              Inc(AddedCount);
            end;

            // Copy template files
            CopyTemplateDirectory(TemplateSrc, TemplateDest);
          end;
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;

      // Report results
      if (AddedCount > 0) or (UpdatedCount > 0) then
        LO.WriteLn(_Fmt(CMD_PROJECT_TPL_UPDATED, [AddedCount, UpdatedCount]))
      else
        LO.WriteLn(_(CMD_PROJECT_TPL_UP_TO_DATE));

      Result := True;
    finally
      Repo.Free;
    end;

  except
    on E: Exception do
    begin
      LE.WriteLn(_Fmt(CMD_PROJECT_TPL_UPDATE_ERROR, [E.Message]));
      Result := False;
    end;
  end;
end;

end.
