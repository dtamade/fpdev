unit fpdev.project.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.project.manager

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
  fpdev.project.generator, fpdev.project.createflow, fpdev.project.cleanflow, fpdev.project.execflow,
  fpdev.project.templateflow;

type
  TProjectTemplate = fpdev.project.templateflow.TProjectTemplate;
  TProjectTemplateArray = fpdev.project.templateflow.TProjectTemplateArray;

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
begin
  Result := ExecuteProjectCreateFromTemplateCore(
    ATemplateName,
    AProjectName,
    ATargetDir,
    @GetTemplateInfo,
    @FGenerator.GenerateProjectFiles
  );
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

  try
    Result := ExecuteProjectCreateCore(
      ATemplateName,
      AProjectName,
      ATargetDir,
      LOut,
      @ValidateProjectName,
      @CreateFromTemplate,
      @SetupProjectEnvironment
    );

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
  LO: IOutput;
begin
  Result := True;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    Result := ExecuteProjectTemplateListCore(GetAvailableTemplates, LO);
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
    Result := ExecuteProjectTemplateInfoCore(
      ATemplateName,
      GetTemplateInfo(ATemplateName),
      LO,
      LE
    );
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
  LO: IOutput;
  LE: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := ExecuteProjectCleanCore(AProjectDir, LO, LE);
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
begin
  Result := ExecuteProjectTemplateInstallCore(
    ATemplatePath,
    FTemplatesRoot,
    Outp,
    Errp
  );
end;

function TProjectManager.RemoveTemplate(const ATemplateName: string): Boolean;
begin
  Result := RemoveTemplate(nil, nil, ATemplateName);
end;

function TProjectManager.RemoveTemplate(const Outp, Errp: IOutput; const ATemplateName: string): Boolean;
begin
  Result := ExecuteProjectTemplateRemoveCore(
    ATemplateName,
    FTemplatesRoot,
    GetAvailableTemplates,
    Outp,
    Errp
  );
end;

function TProjectManager.UpdateTemplates: Boolean;
begin
  Result := UpdateTemplates(nil, nil);
end;

function TProjectManager.UpdateTemplates(const Outp, Errp: IOutput): Boolean;
var
  Repo: TResourceRepository;
  RepoConfig: TResourceRepoConfig;
  LO, LE: IOutput;
begin
  Result := False;

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
      Result := ExecuteProjectTemplateUpdateCore(
        Repo.LocalPath,
        FTemplatesRoot,
        LO,
        @Repo.Initialize,
        @Repo.Update
      );
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
