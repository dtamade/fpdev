program test_project_templateflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.output.console,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.project.generator,
  fpdev.project.templateflow,
  test_temp_paths;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

  TTemplateUpdateProbe = class
  public
    InitializeResult: Boolean;
    UpdateResult: Boolean;
    InitializeCalls: Integer;
    UpdateCalls: Integer;
    LastForce: Boolean;
    function Initialize: Boolean;
    function Update(const AForce: Boolean): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TTemplateUpdateProbe.Initialize: Boolean;
begin
  Inc(InitializeCalls);
  Result := InitializeResult;
end;

function TTemplateUpdateProbe.Update(const AForce: Boolean): Boolean;
begin
  Inc(UpdateCalls);
  LastForce := AForce;
  Result := UpdateResult;
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', AName);
    Inc(PassCount);
  end
  else
  begin
    WriteLn('[FAIL] ', AName, ': ', AReason);
    Inc(FailCount);
  end;
end;

function MakeTemplate(const AName, ADisplayName, ADescription: string;
  AProjectType: TProjectType): TProjectTemplate;
begin
  Result := Default(TProjectTemplate);
  Result.Name := AName;
  Result.DisplayName := ADisplayName;
  Result.Description := ADescription;
  Result.ProjectType := AProjectType;
  Result.Available := True;
end;

procedure WriteTextFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

procedure TestFormatProjectTemplateListLineCore;
var
  Template: TProjectTemplate;
  Line: string;
begin
  Template := MakeTemplate('console', 'Console Application', 'Simple console app', ptConsole);
  Line := FormatProjectTemplateListLineCore(Template);
  Check('list line keeps template name', Pos('console', Line) = 1, Line);
  Check('list line keeps console label', Pos('Console', Line) > 0, Line);
  Check('list line keeps description', Pos('Simple console app', Line) > 0, Line);
end;

procedure TestExecuteProjectTemplateInfoCore;
var
  Template: TProjectTemplate;
  OutRef, ErrRef: TStringOutput;
  Outp, Errp: IOutput;
begin
  Template := MakeTemplate('console', 'Console Application', 'Simple console app', ptConsole);
  OutRef := TStringOutput.Create;
  ErrRef := TStringOutput.Create;
  Outp := OutRef;
  Errp := ErrRef;

  Check(
    'template info core succeeds for known template',
    ExecuteProjectTemplateInfoCore('console', Template, Outp, Errp),
    ErrRef.Text
  );
  Check('template info writes display name', OutRef.Contains('Display:'), OutRef.Text);
  Check('template info keeps stderr empty', Trim(ErrRef.Text) = '', ErrRef.Text);
end;

procedure TestExecuteProjectTemplateInstallCoreCopiesNestedFiles;
var
  TempRoot: string;
  SourceDir: string;
  TemplatesRoot: string;
  OutRef, ErrRef: TStringOutput;
  Outp, Errp: IOutput;
begin
  TempRoot := CreateUniqueTempDir('project-templateflow-install');
  try
    SourceDir := TempRoot + PathDelim + 'source-template';
    TemplatesRoot := TempRoot + PathDelim + 'install-root' + PathDelim + 'templates';
    WriteTextFile(SourceDir + PathDelim + 'template.json', '{"name":"source-template"}');
    WriteTextFile(SourceDir + PathDelim + 'src' + PathDelim + 'main.pas', 'program demo;' + LineEnding);

    OutRef := TStringOutput.Create;
    ErrRef := TStringOutput.Create;
    Outp := OutRef;
    Errp := ErrRef;

    Check(
      'template install core succeeds',
      ExecuteProjectTemplateInstallCore(SourceDir, TemplatesRoot, Outp, Errp),
      ErrRef.Text
    );
    Check(
      'template install core copies nested source file',
      FileExists(TemplatesRoot + PathDelim + 'source-template' + PathDelim + 'src' + PathDelim + 'main.pas'),
      'nested file missing after install'
    );
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestExecuteProjectTemplateRemoveCoreRejectsBuiltinAndDeletesCustom;
var
  TempRoot: string;
  TemplatesRoot: string;
  Builtins: TProjectTemplateArray;
  OutRef, ErrRef: TStringOutput;
  Outp, Errp: IOutput;
begin
  TempRoot := CreateUniqueTempDir('project-templateflow-remove');
  try
    TemplatesRoot := TempRoot + PathDelim + 'templates';
    ForceDirectories(TemplatesRoot + PathDelim + 'custom');
    WriteTextFile(TemplatesRoot + PathDelim + 'custom' + PathDelim + 'template.json', '{"name":"custom"}');

    SetLength(Builtins, 1);
    Builtins[0] := MakeTemplate('console', 'Console', 'builtin', ptConsole);

    OutRef := TStringOutput.Create;
    ErrRef := TStringOutput.Create;
    Outp := OutRef;
    Errp := ErrRef;

    Check(
      'template remove core rejects builtin templates',
      not ExecuteProjectTemplateRemoveCore('console', TemplatesRoot, Builtins, Outp, Errp),
      'builtin remove should fail'
    );
    Check('template remove core reports builtin error', Trim(ErrRef.Text) <> '', ErrRef.Text);

    OutRef := TStringOutput.Create;
    ErrRef := TStringOutput.Create;
    Outp := OutRef;
    Errp := ErrRef;
    Check(
      'template remove core deletes custom template directory',
      ExecuteProjectTemplateRemoveCore('custom', TemplatesRoot, Builtins, Outp, Errp),
      ErrRef.Text
    );
    Check(
      'template remove core removes custom directory',
      not DirectoryExists(TemplatesRoot + PathDelim + 'custom'),
      'custom template directory still exists'
    );
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestSyncProjectTemplatesFromRepositoryCoreCopiesOnlyValidTemplates;
var
  TempRoot: string;
  RepoTemplatesDir: string;
  LocalTemplatesRoot: string;
  AddedCount: Integer;
  UpdatedCount: Integer;
begin
  TempRoot := CreateUniqueTempDir('project-templateflow-sync');
  try
    RepoTemplatesDir := TempRoot + PathDelim + 'repo' + PathDelim + 'templates';
    LocalTemplatesRoot := TempRoot + PathDelim + 'local' + PathDelim + 'templates';

    WriteTextFile(RepoTemplatesDir + PathDelim + 'console' + PathDelim + 'template.json',
      '{"name":"console"}');
    WriteTextFile(RepoTemplatesDir + PathDelim + 'console' + PathDelim + 'src' + PathDelim + 'main.pas',
      'program console;' + LineEnding);
    WriteTextFile(RepoTemplatesDir + PathDelim + 'skip-me' + PathDelim + 'README.md',
      'no template metadata');

    Check(
      'template sync core succeeds',
      SyncProjectTemplatesFromRepositoryCore(RepoTemplatesDir, LocalTemplatesRoot, AddedCount, UpdatedCount),
      'sync should succeed'
    );
    Check('template sync counts added template', AddedCount = 1, 'added=' + IntToStr(AddedCount));
    Check('template sync keeps updated count at 0 for fresh copy', UpdatedCount = 0,
      'updated=' + IntToStr(UpdatedCount));
    Check(
      'template sync copies template metadata',
      FileExists(LocalTemplatesRoot + PathDelim + 'console' + PathDelim + 'template.json'),
      'synced template metadata missing'
    );
    Check(
      'template sync skips directories without metadata',
      not DirectoryExists(LocalTemplatesRoot + PathDelim + 'skip-me'),
      'invalid template directory should be skipped'
    );
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestExecuteProjectTemplateUpdateCoreSkipsUnavailableRepo;
var
  Probe: TTemplateUpdateProbe;
  OutRef: TStringOutput;
  Outp: IOutput;
begin
  Probe := TTemplateUpdateProbe.Create;
  OutRef := TStringOutput.Create;
  Outp := OutRef;
  try
    Probe.InitializeResult := False;

    Check(
      'template update core treats unavailable repo as non-fatal',
      ExecuteProjectTemplateUpdateCore('/tmp/missing-repo', '/tmp/local-templates', Outp,
        @Probe.Initialize, @Probe.Update),
      OutRef.Text
    );
    Check('template update core skips update when repo unavailable',
      Probe.UpdateCalls = 0,
      'update calls=' + IntToStr(Probe.UpdateCalls));
    Check('template update core reports unavailable repo',
      OutRef.Contains(_(CMD_PROJECT_TPL_REPO_UNAVAIL)),
      OutRef.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteProjectTemplateUpdateCoreContinuesAfterUpdateFailure;
var
  TempRoot: string;
  RepoRoot: string;
  LocalTemplatesRoot: string;
  Probe: TTemplateUpdateProbe;
  OutRef: TStringOutput;
  Outp: IOutput;
begin
  TempRoot := CreateUniqueTempDir('project-templateflow-update-warning');
  try
    RepoRoot := TempRoot + PathDelim + 'repo';
    LocalTemplatesRoot := TempRoot + PathDelim + 'local' + PathDelim + 'templates';
    WriteTextFile(RepoRoot + PathDelim + 'templates' + PathDelim + 'console' + PathDelim + 'template.json',
      '{"name":"console"}');
    WriteTextFile(RepoRoot + PathDelim + 'templates' + PathDelim + 'console' + PathDelim + 'src' +
      PathDelim + 'main.pas', 'program console;' + LineEnding);

    Probe := TTemplateUpdateProbe.Create;
    OutRef := TStringOutput.Create;
    Outp := OutRef;
    try
      Probe.InitializeResult := True;
      Probe.UpdateResult := False;

      Check(
        'template update core continues after repo update failure',
        ExecuteProjectTemplateUpdateCore(RepoRoot, LocalTemplatesRoot, Outp,
          @Probe.Initialize, @Probe.Update),
        OutRef.Text
      );
      Check('template update core forces repo update',
        Probe.LastForce,
        'force update should be true');
      Check('template update core reports update warning',
        OutRef.Contains(_(CMD_PROJECT_TPL_UPDATE_FAILED)),
        OutRef.Text);
      Check('template update core still copies templates',
        FileExists(LocalTemplatesRoot + PathDelim + 'console' + PathDelim + 'template.json'),
        'copied template metadata missing');
      Check('template update core reports add/update counts',
        OutRef.Contains(_Fmt(CMD_PROJECT_TPL_UPDATED, [1, 0])),
        OutRef.Text);
    finally
      Probe.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestExecuteProjectTemplateUpdateCoreHandlesMissingTemplatesDir;
var
  TempRoot: string;
  RepoRoot: string;
  Probe: TTemplateUpdateProbe;
  OutRef: TStringOutput;
  Outp: IOutput;
begin
  TempRoot := CreateUniqueTempDir('project-templateflow-update-missing');
  try
    RepoRoot := TempRoot + PathDelim + 'repo';
    ForceDirectories(RepoRoot);

    Probe := TTemplateUpdateProbe.Create;
    OutRef := TStringOutput.Create;
    Outp := OutRef;
    try
      Probe.InitializeResult := True;
      Probe.UpdateResult := True;

      Check(
        'template update core treats missing templates dir as non-fatal',
        ExecuteProjectTemplateUpdateCore(RepoRoot, TempRoot + PathDelim + 'local', Outp,
          @Probe.Initialize, @Probe.Update),
        OutRef.Text
      );
      Check('template update core reports missing templates dir',
        OutRef.Contains(_(CMD_PROJECT_TPL_NO_TEMPLATES)),
        OutRef.Text);
    finally
      Probe.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestFormatProjectTemplateListLineCore;
  TestExecuteProjectTemplateInfoCore;
  TestExecuteProjectTemplateInstallCoreCopiesNestedFiles;
  TestExecuteProjectTemplateRemoveCoreRejectsBuiltinAndDeletesCustom;
  TestSyncProjectTemplatesFromRepositoryCoreCopiesOnlyValidTemplates;
  TestExecuteProjectTemplateUpdateCoreSkipsUnavailableRepo;
  TestExecuteProjectTemplateUpdateCoreContinuesAfterUpdateFailure;
  TestExecuteProjectTemplateUpdateCoreHandlesMissingTemplatesDir;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
