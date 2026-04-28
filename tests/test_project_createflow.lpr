program test_project_createflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_temp_paths,
  fpdev.output.intf,
  fpdev.project.generator,
  fpdev.project.createflow;

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
  end;

  TCreateFlowProbe = class
  public
    TemplateValue: TProjectTemplate;
    GenerateResult: Boolean;
    ValidateResult: Boolean;
    CreateResult: Boolean;
    SetupResult: Boolean;
    TemplateCalls: Integer;
    GenerateCalls: Integer;
    ValidateCalls: Integer;
    CreateCalls: Integer;
    SetupCalls: Integer;
    LastTemplateName: string;
    LastGenerateProjectName: string;
    LastGenerateTargetDir: string;
    LastCreateTemplateName: string;
    LastCreateProjectName: string;
    LastCreateTargetDir: string;
    LastSetupProjectDir: string;
    function GetTemplateInfo(const ATemplateName: string): TProjectTemplate;
    function GenerateProjectFiles(const ATemplate: TProjectTemplate;
      const AProjectName, ATargetDir: string): Boolean;
    function ValidateProjectName(const AProjectName: string): Boolean;
    function CreateFromTemplate(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
    function SetupProjectEnvironment(const AProjectDir: string): Boolean;
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

function TCreateFlowProbe.GetTemplateInfo(const ATemplateName: string): TProjectTemplate;
begin
  Inc(TemplateCalls);
  LastTemplateName := ATemplateName;
  Result := TemplateValue;
end;

function TCreateFlowProbe.GenerateProjectFiles(const ATemplate: TProjectTemplate;
  const AProjectName, ATargetDir: string): Boolean;
begin
  Inc(GenerateCalls);
  LastGenerateProjectName := AProjectName;
  LastGenerateTargetDir := ATargetDir;
  if ATemplate.Name = '' then;
  Result := GenerateResult;
end;

function TCreateFlowProbe.ValidateProjectName(const AProjectName: string): Boolean;
begin
  Inc(ValidateCalls);
  if AProjectName = '' then;
  Result := ValidateResult;
end;

function TCreateFlowProbe.CreateFromTemplate(const ATemplateName, AProjectName,
  ATargetDir: string): Boolean;
begin
  Inc(CreateCalls);
  LastCreateTemplateName := ATemplateName;
  LastCreateProjectName := AProjectName;
  LastCreateTargetDir := ATargetDir;
  Result := CreateResult;
end;

function TCreateFlowProbe.SetupProjectEnvironment(const AProjectDir: string): Boolean;
begin
  Inc(SetupCalls);
  LastSetupProjectDir := AProjectDir;
  Result := SetupResult;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestCreateFromTemplateFailsForMissingTemplate;
var
  Probe: TCreateFlowProbe;
begin
  Probe := TCreateFlowProbe.Create;
  try
    Probe.TemplateValue := Default(TProjectTemplate);
    Probe.GenerateResult := True;

    Check('createflow create-from-template returns false for missing template',
      not ExecuteProjectCreateFromTemplateCore(
        'missing',
        'demo',
        '/tmp/fpdev-project-createflow-missing',
        @Probe.GetTemplateInfo,
        @Probe.GenerateProjectFiles
      ),
      'expected failure');
    Check('createflow create-from-template does not call generator for missing template',
      Probe.GenerateCalls = 0,
      'generate calls=' + IntToStr(Probe.GenerateCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestCreateFromTemplateCreatesTargetDirectory;
var
  Probe: TCreateFlowProbe;
  RootDir: string;
  TargetDir: string;
begin
  RootDir := CreateUniqueTempDir('project-createflow-template');
  TargetDir := RootDir + PathDelim + 'demo-app';
  Probe := TCreateFlowProbe.Create;
  try
    Probe.TemplateValue := Default(TProjectTemplate);
    Probe.TemplateValue.Name := 'console';
    Probe.TemplateValue.ProjectType := ptConsole;
    Probe.GenerateResult := True;

    Check('createflow create-from-template succeeds for valid template',
      ExecuteProjectCreateFromTemplateCore(
        'console',
        'demo',
        TargetDir,
        @Probe.GetTemplateInfo,
        @Probe.GenerateProjectFiles
      ),
      'expected success');
    Check('createflow create-from-template creates target directory',
      DirectoryExists(TargetDir),
      'target directory missing');
    Check('createflow create-from-template forwards target dir to generator',
      Probe.LastGenerateTargetDir = TargetDir,
      Probe.LastGenerateTargetDir);
  finally
    Probe.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCreateCoreRejectsInvalidProjectName;
var
  Probe: TCreateFlowProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
begin
  Probe := TCreateFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    Probe.ValidateResult := False;
    Probe.CreateResult := True;
    Probe.SetupResult := True;

    Check('createflow create-core rejects invalid project name',
      not ExecuteProjectCreateCore(
        'console',
        'bad name',
        '/tmp/fpdev-project-createflow-invalid',
        OutRef,
        @Probe.ValidateProjectName,
        @Probe.CreateFromTemplate,
        @Probe.SetupProjectEnvironment
      ),
      'expected failure');
    Check('createflow create-core skips create callback on invalid name',
      Probe.CreateCalls = 0,
      'create calls=' + IntToStr(Probe.CreateCalls));
    Check('createflow create-core skips setup callback on invalid name',
      Probe.SetupCalls = 0,
      'setup calls=' + IntToStr(Probe.SetupCalls));
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestCreateCoreWarnsWhenSetupFailsButKeepsSuccess;
var
  Probe: TCreateFlowProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
begin
  Probe := TCreateFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.CreateResult := True;
    Probe.SetupResult := False;

    Check('createflow create-core returns true when setup fails after create',
      ExecuteProjectCreateCore(
        'console',
        'demo',
        '/tmp/fpdev-project-createflow-warning',
        OutRef,
        @Probe.ValidateProjectName,
        @Probe.CreateFromTemplate,
        @Probe.SetupProjectEnvironment
      ),
      'expected success');
    Check('createflow create-core calls create callback once',
      Probe.CreateCalls = 1,
      'create calls=' + IntToStr(Probe.CreateCalls));
    Check('createflow create-core calls setup callback once',
      Probe.SetupCalls = 1,
      'setup calls=' + IntToStr(Probe.SetupCalls));
    Check('createflow create-core writes setup warning',
      OutBuf.Contains('Warning: Project environment setup incomplete for: /tmp/fpdev-project-createflow-warning'),
      'missing warning output');
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

begin
  TestCreateFromTemplateFailsForMissingTemplate;
  TestCreateFromTemplateCreatesTargetDirectory;
  TestCreateCoreRejectsInvalidProjectName;
  TestCreateCoreWarnsWhenSetupFailsButKeepsSuccess;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
