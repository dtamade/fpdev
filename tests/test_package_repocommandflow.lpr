program test_package_repocommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.repocommandflow;

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

  TPackageRepoProbe = class
  public
    AddResult: Boolean;
    ListResult: Boolean;
    RemoveResult: Boolean;
    UpdateResult: Boolean;
    AddCalls: Integer;
    ListCalls: Integer;
    RemoveCalls: Integer;
    UpdateCalls: Integer;
    LastRepoName: string;
    LastURL: string;
    function AddRepository(const AName, AURL: string; Outp, Errp: IOutput): Boolean;
    function ListRepositories(Outp: IOutput): Boolean;
    function RemoveRepository(const AName: string; Outp, Errp: IOutput): Boolean;
    function UpdateRepositories(Outp, Errp: IOutput): Boolean;
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

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TPackageRepoProbe.AddRepository(const AName, AURL: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(AddCalls);
  LastRepoName := AName;
  LastURL := AURL;
  if Outp = nil then;
  if Errp = nil then;
  Result := AddResult;
end;

function TPackageRepoProbe.ListRepositories(Outp: IOutput): Boolean;
begin
  Inc(ListCalls);
  if Outp <> nil then
    Outp.WriteLn('repo list invoked');
  Result := ListResult;
end;

function TPackageRepoProbe.RemoveRepository(const AName: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(RemoveCalls);
  LastRepoName := AName;
  if Outp = nil then;
  if Errp = nil then;
  Result := RemoveResult;
end;

function TPackageRepoProbe.UpdateRepositories(Outp, Errp: IOutput): Boolean;
begin
  Inc(UpdateCalls);
  if Outp = nil then;
  if Errp = nil then;
  Result := UpdateResult;
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

procedure TestPrepareAddHelpReturnsUsage;
var
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoAddCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare add help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare add help requests exit', ShouldExit, 'should exit');
    Check('prepare add help writes usage', OutpObj.Contains('fpdev package repo add'), OutpObj.Text);
    Check('prepare add help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareAddRejectsUnknownOption;
var
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoAddCommandPlanCore(['demo', 'https://example.test', '--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare add unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare add unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare add unknown option writes usage', ErrpObj.Contains('fpdev package repo add'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareAddRejectsMissingArgs;
var
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoAddCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare add missing args returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare add missing args requests exit', ShouldExit, 'should exit');
    Check('prepare add missing args writes usage', ErrpObj.Contains('fpdev package repo add'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareAddRejectsEmptyArgs;
var
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoAddCommandPlanCore(['', 'https://example.test'], Outp, Errp, Plan, ShouldExit);
    Check('prepare add empty name returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare add empty name requests exit', ShouldExit, 'should exit');

    Code := PreparePackageRepoAddCommandPlanCore(['demo', ''], Outp, Errp, Plan, ShouldExit);
    Check('prepare add empty url returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare add empty url requests exit', ShouldExit, 'should exit');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareAddRejectsUnexpectedArg;
var
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoAddCommandPlanCore(
      ['demo', 'https://example.test', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare add unexpected arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare add unexpected arg requests exit', ShouldExit, 'should exit');
    Check('prepare add unexpected arg writes usage', ErrpObj.Contains('fpdev package repo add'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareAddCapturesNameAndUrl;
var
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoAddCommandPlanCore(
      ['demo', 'https://example.test/index.json'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare add valid args return EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare add valid args does not request exit', not ShouldExit, 'unexpected exit');
    Check('prepare add captures name', Plan.RepoName = 'demo', Plan.RepoName);
    Check('prepare add captures url', Plan.URL = 'https://example.test/index.json', Plan.URL);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteAddRejectsDuplicateRepository;
var
  Probe: TPackageRepoProbe;
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Plan.RepoName := 'dup_repo';
    Plan.URL := 'https://example.test/a';
    Code := ExecutePackageRepoAddCommandPlanCore(Plan, Outp, Errp, True, @Probe.AddRepository);
    Check('execute add duplicate returns EXIT_ALREADY_EXISTS', Code = EXIT_ALREADY_EXISTS, IntToStr(Code));
    Check('execute add duplicate keeps add callback unused', Probe.AddCalls = 0, IntToStr(Probe.AddCalls));
    Check('execute add duplicate writes stderr', ErrpObj.Contains('exist'), ErrpObj.Text);
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteAddDelegatesSuccessPath;
var
  Probe: TPackageRepoProbe;
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.AddResult := True;
    Plan.RepoName := 'demo';
    Plan.URL := 'https://example.test/demo';
    Code := ExecutePackageRepoAddCommandPlanCore(Plan, Outp, Errp, False, @Probe.AddRepository);
    Check('execute add success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute add calls callback once', Probe.AddCalls = 1, IntToStr(Probe.AddCalls));
    Check('execute add passes repo name', Probe.LastRepoName = 'demo', Probe.LastRepoName);
    Check('execute add passes repo url', Probe.LastURL = 'https://example.test/demo', Probe.LastURL);
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteAddReturnsExitErrorOnManagerFailure;
var
  Probe: TPackageRepoProbe;
  Plan: TPackageRepoAddCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.AddResult := False;
    Plan.RepoName := 'demo';
    Plan.URL := 'https://example.test/demo';
    Code := ExecutePackageRepoAddCommandPlanCore(Plan, Outp, Errp, False, @Probe.AddRepository);
    Check('execute add failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareListHelpReturnsUsage;
var
  Plan: TPackageRepoListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoListCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare list help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare list help requests exit', ShouldExit, 'should exit');
    Check('prepare list help writes usage', OutpObj.Contains('fpdev package repo list'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareListRejectsUnexpectedArg;
var
  Plan: TPackageRepoListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoListCommandPlanCore(['unexpected'], Outp, Errp, Plan, ShouldExit);
    Check('prepare list unexpected arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare list unexpected arg requests exit', ShouldExit, 'should exit');
    Check('prepare list unexpected arg writes usage', ErrpObj.Contains('fpdev package repo list'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareListRejectsUnknownOption;
var
  Plan: TPackageRepoListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoListCommandPlanCore(['--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare list unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare list unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare list unknown option writes usage', ErrpObj.Contains('fpdev package repo list'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteListDelegatesSuccessPath;
var
  Probe: TPackageRepoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.ListResult := True;
    Code := ExecutePackageRepoListCommandPlanCore(Outp, @Probe.ListRepositories);
    Check('execute list success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute list calls callback once', Probe.ListCalls = 1, IntToStr(Probe.ListCalls));
    Check('execute list keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteListReturnsExitErrorOnManagerFailure;
var
  Probe: TPackageRepoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.ListResult := False;
    Code := ExecutePackageRepoListCommandPlanCore(Outp, @Probe.ListRepositories);
    Check('execute list failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRemoveHelpReturnsUsage;
var
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoRemoveCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare remove help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare remove help requests exit', ShouldExit, 'should exit');
    Check('prepare remove help writes usage', OutpObj.Contains('fpdev package repo remove'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRemoveRejectsUnknownOption;
var
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoRemoveCommandPlanCore(['repo-name', '--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare remove unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare remove unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare remove unknown option writes usage', ErrpObj.Contains('fpdev package repo remove'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRemoveRejectsMissingName;
var
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoRemoveCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare remove missing name returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare remove missing name requests exit', ShouldExit, 'should exit');
    Check('prepare remove missing name writes usage', ErrpObj.Contains('fpdev package repo remove'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRemoveRejectsEmptyName;
var
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoRemoveCommandPlanCore([''], Outp, Errp, Plan, ShouldExit);
    Check('prepare remove empty name returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare remove empty name requests exit', ShouldExit, 'should exit');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRemoveRejectsUnexpectedArg;
var
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoRemoveCommandPlanCore(['repo-name', 'extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare remove unexpected arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare remove unexpected arg requests exit', ShouldExit, 'should exit');
    Check('prepare remove unexpected arg writes usage', ErrpObj.Contains('fpdev package repo remove'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRemoveCapturesName;
var
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoRemoveCommandPlanCore(['repo-name'], Outp, Errp, Plan, ShouldExit);
    Check('prepare remove valid arg returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare remove valid arg does not request exit', not ShouldExit, 'unexpected exit');
    Check('prepare remove captures name', Plan.RepoName = 'repo-name', Plan.RepoName);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteRemoveRejectsUnknownRepository;
var
  Probe: TPackageRepoProbe;
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Plan.RepoName := 'missing_repo';
    Code := ExecutePackageRepoRemoveCommandPlanCore(Plan, Outp, Errp, False, @Probe.RemoveRepository);
    Check('execute remove unknown repo returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute remove unknown repo keeps callback unused', Probe.RemoveCalls = 0, IntToStr(Probe.RemoveCalls));
    Check('execute remove unknown repo writes stderr', ErrpObj.Contains('not found'), ErrpObj.Text);
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteRemoveDelegatesSuccessPath;
var
  Probe: TPackageRepoProbe;
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.RemoveResult := True;
    Plan.RepoName := 'demo';
    Code := ExecutePackageRepoRemoveCommandPlanCore(Plan, Outp, Errp, True, @Probe.RemoveRepository);
    Check('execute remove success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute remove calls callback once', Probe.RemoveCalls = 1, IntToStr(Probe.RemoveCalls));
    Check('execute remove passes name', Probe.LastRepoName = 'demo', Probe.LastRepoName);
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteRemoveReturnsExitErrorOnManagerFailure;
var
  Probe: TPackageRepoProbe;
  Plan: TPackageRepoRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.RemoveResult := False;
    Plan.RepoName := 'demo';
    Code := ExecutePackageRepoRemoveCommandPlanCore(Plan, Outp, Errp, True, @Probe.RemoveRepository);
    Check('execute remove failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUpdateHelpReturnsUsage;
var
  Plan: TPackageRepoUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoUpdateCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare update help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare update help requests exit', ShouldExit, 'should exit');
    Check('prepare update help writes usage', OutpObj.Contains('fpdev package repo update'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUpdateRejectsUnexpectedArg;
var
  Plan: TPackageRepoUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoUpdateCommandPlanCore(['unexpected'], Outp, Errp, Plan, ShouldExit);
    Check('prepare update unexpected arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare update unexpected arg requests exit', ShouldExit, 'should exit');
    Check('prepare update unexpected arg writes usage', ErrpObj.Contains('fpdev package repo update'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUpdateRejectsUnknownOption;
var
  Plan: TPackageRepoUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageRepoUpdateCommandPlanCore(['--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare update unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare update unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare update unknown option writes usage', ErrpObj.Contains('fpdev package repo update'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUpdateDelegatesSuccessPath;
var
  Probe: TPackageRepoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.UpdateResult := True;
    Code := ExecutePackageRepoUpdateCommandPlanCore(Outp, Errp, @Probe.UpdateRepositories);
    Check('execute update success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute update calls callback once', Probe.UpdateCalls = 1, IntToStr(Probe.UpdateCalls));
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUpdateReturnsExitErrorOnManagerFailure;
var
  Probe: TPackageRepoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  Probe := TPackageRepoProbe.Create;
  try
    Probe.UpdateResult := False;
    Code := ExecutePackageRepoUpdateCommandPlanCore(Outp, Errp, @Probe.UpdateRepositories);
    Check('execute update failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    Probe.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

begin
  TestPrepareAddHelpReturnsUsage;
  TestPrepareAddRejectsUnknownOption;
  TestPrepareAddRejectsMissingArgs;
  TestPrepareAddRejectsEmptyArgs;
  TestPrepareAddRejectsUnexpectedArg;
  TestPrepareAddCapturesNameAndUrl;
  TestExecuteAddRejectsDuplicateRepository;
  TestExecuteAddDelegatesSuccessPath;
  TestExecuteAddReturnsExitErrorOnManagerFailure;

  TestPrepareListHelpReturnsUsage;
  TestPrepareListRejectsUnexpectedArg;
  TestPrepareListRejectsUnknownOption;
  TestExecuteListDelegatesSuccessPath;
  TestExecuteListReturnsExitErrorOnManagerFailure;

  TestPrepareRemoveHelpReturnsUsage;
  TestPrepareRemoveRejectsUnknownOption;
  TestPrepareRemoveRejectsMissingName;
  TestPrepareRemoveRejectsEmptyName;
  TestPrepareRemoveRejectsUnexpectedArg;
  TestPrepareRemoveCapturesName;
  TestExecuteRemoveRejectsUnknownRepository;
  TestExecuteRemoveDelegatesSuccessPath;
  TestExecuteRemoveReturnsExitErrorOnManagerFailure;

  TestPrepareUpdateHelpReturnsUsage;
  TestPrepareUpdateRejectsUnexpectedArg;
  TestPrepareUpdateRejectsUnknownOption;
  TestExecuteUpdateDelegatesSuccessPath;
  TestExecuteUpdateReturnsExitErrorOnManagerFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount <> 0 then
    Halt(1);
end.
