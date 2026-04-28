program test_project_commandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.project.generator,
  fpdev.project.commandflow;

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
    procedure Clear;
    function Text: string;
  end;

  TProjectCommandProbe = class
  public
    TemplateList: TProjectTemplateArray;
    ListResult: Boolean;
    ShowResult: Boolean;
    BuildResult: Boolean;
    TestResult: Boolean;
    CleanResult: Boolean;
    CreateResult: Boolean;
    ListCalls: Integer;
    ShowCalls: Integer;
    BuildCalls: Integer;
    TestCalls: Integer;
    CleanCalls: Integer;
    CreateCalls: Integer;
    LastTemplate: string;
    LastName: string;
    LastTargetDir: string;
    LastDir: string;
    LastTarget: string;
    ShowWritesToOut: string;
    ShowWritesToErr: string;
    TestWritesToOut: string;
    TestWritesToErr: string;
    CleanWritesToOut: string;
    CleanWritesToErr: string;
    function GetTemplateList: TProjectTemplateArray;
    function ListTemplates(const Outp: IOutput): Boolean;
    function ShowTemplateInfo(const Outp, Errp: IOutput; const ATemplateName: string): Boolean;
    function BuildProject(const AProjectDir: string; const ATarget: string = ''): Boolean;
    function TestProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean;
    function CleanProject(const Outp, Errp: IOutput; const AProjectDir: string): Boolean;
    function CreateProject(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
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

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TStringOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TProjectCommandProbe.GetTemplateList: TProjectTemplateArray;
begin
  Result := TemplateList;
end;

function TProjectCommandProbe.ListTemplates(const Outp: IOutput): Boolean;
begin
  Inc(ListCalls);
  if Outp <> nil then
    Outp.WriteLn('text-list');
  Result := ListResult;
end;

function TProjectCommandProbe.ShowTemplateInfo(
  const Outp, Errp: IOutput;
  const ATemplateName: string
): Boolean;
begin
  Inc(ShowCalls);
  LastTemplate := ATemplateName;
  if (Outp <> nil) and (ShowWritesToOut <> '') then
    Outp.WriteLn(ShowWritesToOut);
  if (Errp <> nil) and (ShowWritesToErr <> '') then
    Errp.WriteLn(ShowWritesToErr);
  Result := ShowResult;
end;

function TProjectCommandProbe.BuildProject(
  const AProjectDir: string;
  const ATarget: string
): Boolean;
begin
  Inc(BuildCalls);
  LastDir := AProjectDir;
  LastTarget := ATarget;
  Result := BuildResult;
end;

function TProjectCommandProbe.TestProject(
  const Outp, Errp: IOutput;
  const AProjectDir: string
): Boolean;
begin
  Inc(TestCalls);
  LastDir := AProjectDir;
  if (Outp <> nil) and (TestWritesToOut <> '') then
    Outp.WriteLn(TestWritesToOut);
  if (Errp <> nil) and (TestWritesToErr <> '') then
    Errp.WriteLn(TestWritesToErr);
  Result := TestResult;
end;

function TProjectCommandProbe.CleanProject(
  const Outp, Errp: IOutput;
  const AProjectDir: string
): Boolean;
begin
  Inc(CleanCalls);
  LastDir := AProjectDir;
  if (Outp <> nil) and (CleanWritesToOut <> '') then
    Outp.WriteLn(CleanWritesToOut);
  if (Errp <> nil) and (CleanWritesToErr <> '') then
    Errp.WriteLn(CleanWritesToErr);
  Result := CleanResult;
end;

function TProjectCommandProbe.CreateProject(
  const ATemplateName, AProjectName, ATargetDir: string
): Boolean;
begin
  Inc(CreateCalls);
  LastTemplate := ATemplateName;
  LastName := AProjectName;
  LastTargetDir := ATargetDir;
  Result := CreateResult;
end;

procedure InitOutputs(
  out AOutObj, AErrObj: TStringOutput;
  out AOut, AErr: IOutput
);
begin
  AOutObj := TStringOutput.Create;
  AErrObj := TStringOutput.Create;
  AOut := AOutObj;
  AErr := AErrObj;
end;

procedure ReleaseOutputs(
  var AOut, AErr: IOutput;
  var AOutObj, AErrObj: TStringOutput
);
begin
  AErr := nil;
  AOut := nil;
  AErrObj := nil;
  AOutObj := nil;
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

function MakeTemplate(
  const AName, ADisplayName, ADescription: string;
  AProjectType: TProjectType;
  AAvailable: Boolean
): TProjectTemplate;
begin
  Result := Default(TProjectTemplate);
  Result.Name := AName;
  Result.DisplayName := ADisplayName;
  Result.Description := ADescription;
  Result.ProjectType := AProjectType;
  Result.Available := AAvailable;
end;

procedure TestPrepareListHelpRejectsExtraOption;
var
  Plan: TProjectListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectListCommandPlanCore(
      ['--help', '--json'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('list help extra option usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('list help extra option exits', ShouldExit, 'should exit');
    Check('list help extra option writes usage to stderr', ErrpObj.Contains('fpdev project list'), ErrpObj.Text);
    Check('list help extra option keeps stdout empty', Trim(OutpObj.Text) = '', OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareListJsonMode;
var
  Plan: TProjectListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectListCommandPlanCore(
      ['--json'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('list json prepare EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('list json prepare continues', not ShouldExit, 'unexpected exit');
    Check('list json prepare sets flag', Plan.JsonOutput, 'json flag missing');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteListJsonOutput;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  JsonData: TJSONData;
  JsonObject: TJSONObject;
  Templates: TJSONArray;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  JsonData := nil;
  try
    SetLength(Probe.TemplateList, 2);
    Probe.TemplateList[0] := MakeTemplate('console', 'Console App', 'CLI template', ptConsole, True);
    Probe.TemplateList[1] := MakeTemplate('service', 'Service App', 'Daemon template', ptService, False);
    Plan.JsonOutput := True;

    Code := ExecuteProjectListCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ListTemplates,
      @Probe.GetTemplateList
    );

    Check('list json execute EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('list json bypasses text callback', Probe.ListCalls = 0, IntToStr(Probe.ListCalls));
    Check('list json stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);

    JsonData := GetJSON(OutpObj.Text);
    JsonObject := JsonData as TJSONObject;
    Templates := JsonObject.Arrays['templates'];
    Check('list json has two templates', Templates.Count = 2, IntToStr(Templates.Count));
    Check('list json writes template name', Templates.Objects[0].Get('name', '') = 'console', Templates.AsJSON);
    Check('list json maps display_name', Templates.Objects[0].Get('display_name', '') = 'Console App', Templates.AsJSON);
    Check('list json maps type string', Templates.Objects[1].Get('type', '') = 'service', Templates.AsJSON);
    Check('list json maps availability', not Templates.Objects[1].Get('available', True), Templates.AsJSON);
  finally
    JsonData.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteListTextFailureMapsExitError;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  Probe.ListResult := False;
  Plan := Default(TProjectListCommandPlan);
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecuteProjectListCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ListTemplates,
      @Probe.GetTemplateList
    );
    Check('list text failure maps EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('list text callback called once', Probe.ListCalls = 1, IntToStr(Probe.ListCalls));
    Check('list text writes probe output only', OutpObj.Contains('text-list'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareInfoRejectsMissingTemplate;
var
  Plan: TProjectInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectInfoCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('info missing template usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('info missing template exits', ShouldExit, 'should exit');
    Check('info missing template writes missing arg', ErrpObj.Contains('template'), ErrpObj.Text);
    Check('info missing template writes usage', ErrpObj.Contains('fpdev project info'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteInfoDelegatesTemplateName;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  Probe.ShowResult := True;
  Probe.ShowWritesToOut := 'template-info';
  Plan.TemplateName := 'console';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecuteProjectInfoCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ShowTemplateInfo
    );
    Check('info execute EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('info execute passes template', Probe.LastTemplate = 'console', Probe.LastTemplate);
    Check('info execute keeps callback output', OutpObj.Contains('template-info'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareBuildDefaultsDirectoryAndTarget;
var
  Plan: TProjectBuildCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectBuildCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('build default prepare EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('build default prepare continues', not ShouldExit, 'unexpected exit');
    Check('build default dir is dot', Plan.ProjectDir = '.', Plan.ProjectDir);
    Check('build default target empty', Plan.Target = '', Plan.Target);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareBuildAcceptsTarget;
var
  Plan: TProjectBuildCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectBuildCommandPlanCore(
      ['demo', 'win64'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('build target prepare EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('build target prepare keeps dir', Plan.ProjectDir = 'demo', Plan.ProjectDir);
    Check('build target prepare keeps target', Plan.Target = 'win64', Plan.Target);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteBuildWritesSuccessAndFailureMessages;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectBuildCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  Plan.ProjectDir := 'demo';
  Plan.Target := 'linux';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.BuildResult := True;
    Code := ExecuteProjectBuildCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.BuildProject
    );
    Check('build execute success EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('build execute passes dir', Probe.LastDir = 'demo', Probe.LastDir);
    Check('build execute passes target', Probe.LastTarget = 'linux', Probe.LastTarget);
    Check('build execute writes success message', OutpObj.Contains(_(CMD_PROJECT_BUILD_DONE)), OutpObj.Text);

    Probe.BuildResult := False;
    OutpObj.Clear;
    ErrpObj.Clear;
    Code := ExecuteProjectBuildCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.BuildProject
    );
    Check('build execute failure EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('build execute writes failure message', ErrpObj.Contains(_(CMD_PROJECT_BUILD_FAILED)), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareTestDefaultsDirectory;
var
  Plan: TProjectDirectoryCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectTestCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('test default prepare EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('test default dir is dot', Plan.ProjectDir = '.', Plan.ProjectDir);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteTestPreservesCallbackOutput;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectDirectoryCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  Probe.TestResult := True;
  Probe.TestWritesToOut := 'running-tests';
  Plan.ProjectDir := 'tests/demo';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecuteProjectTestCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.TestProject
    );
    Check('test execute EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('test execute passes dir', Probe.LastDir = 'tests/demo', Probe.LastDir);
    Check('test execute preserves output', OutpObj.Contains('running-tests'), OutpObj.Text);
    Check('test execute adds no generic failure text', not ErrpObj.Contains(_(CMD_PROJECT_BUILD_FAILED)), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareCleanRejectsUnexpectedArg;
var
  Plan: TProjectDirectoryCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectCleanCommandPlanCore(
      ['.', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('clean extra arg usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('clean extra arg exits', ShouldExit, 'should exit');
    Check('clean extra arg writes usage', ErrpObj.Contains('fpdev project clean'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteCleanPreservesCallbackOutput;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectDirectoryCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  Probe.CleanResult := True;
  Probe.CleanWritesToOut := 'cleaned-demo';
  Plan.ProjectDir := 'clean/me';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecuteProjectCleanCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.CleanProject
    );
    Check('clean execute EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('clean execute passes dir', Probe.LastDir = 'clean/me', Probe.LastDir);
    Check('clean execute preserves output', OutpObj.Contains('cleaned-demo'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareNewBuildsDefaultAndExplicitTargetDir;
var
  Plan: TProjectNewCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectNewCommandPlanCore(
      ['console', 'demo'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('new default dir prepare EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('new default dir template', Plan.TemplateName = 'console', Plan.TemplateName);
    Check('new default dir name', Plan.ProjectName = 'demo', Plan.ProjectName);
    Check('new default dir target path', Plan.TargetDir = '.' + PathDelim + 'demo', Plan.TargetDir);

    Code := PrepareProjectNewCommandPlanCore(
      ['service', 'worker', 'apps'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('new explicit dir prepare EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('new explicit dir target path', Plan.TargetDir = 'apps' + PathDelim + 'worker', Plan.TargetDir);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareNewRejectsMissingArgs;
var
  Plan: TProjectNewCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectNewCommandPlanCore(
      ['console'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('new missing args usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('new missing args exits', ShouldExit, 'should exit');
    Check('new missing args mentions template name pair', ErrpObj.Contains('template, name'), ErrpObj.Text);
    Check('new missing args writes usage', ErrpObj.Contains('fpdev project new'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteNewWritesSuccessAndFailureMessages;
var
  Probe: TProjectCommandProbe;
  Plan: TProjectNewCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectCommandProbe.Create;
  Plan.TemplateName := 'console';
  Plan.ProjectName := 'demo';
  Plan.TargetDir := 'sandbox' + PathDelim + 'demo';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.CreateResult := True;
    Code := ExecuteProjectNewCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.CreateProject
    );
    Check('new execute success EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('new execute passes template', Probe.LastTemplate = 'console', Probe.LastTemplate);
    Check('new execute passes name', Probe.LastName = 'demo', Probe.LastName);
    Check('new execute passes target dir', Probe.LastTargetDir = 'sandbox' + PathDelim + 'demo', Probe.LastTargetDir);
    Check('new execute writes success message', OutpObj.Contains('demo'), OutpObj.Text);

    Probe.CreateResult := False;
    OutpObj.Clear;
    ErrpObj.Clear;
    Code := ExecuteProjectNewCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.CreateProject
    );
    Check('new execute failure EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('new execute writes failure message', ErrpObj.Contains(_(CMD_PROJECT_NEW_FAILED)), ErrpObj.Text);
    Check('new execute failure keeps error prefix', ErrpObj.Contains(_(MSG_ERROR)), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  TestPrepareListHelpRejectsExtraOption;
  TestPrepareListJsonMode;
  TestExecuteListJsonOutput;
  TestExecuteListTextFailureMapsExitError;
  TestPrepareInfoRejectsMissingTemplate;
  TestExecuteInfoDelegatesTemplateName;
  TestPrepareBuildDefaultsDirectoryAndTarget;
  TestPrepareBuildAcceptsTarget;
  TestExecuteBuildWritesSuccessAndFailureMessages;
  TestPrepareTestDefaultsDirectory;
  TestExecuteTestPreservesCallbackOutput;
  TestPrepareCleanRejectsUnexpectedArg;
  TestExecuteCleanPreservesCallbackOutput;
  TestPrepareNewBuildsDefaultAndExplicitTargetDir;
  TestPrepareNewRejectsMissingArgs;
  TestExecuteNewWritesSuccessAndFailureMessages;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
