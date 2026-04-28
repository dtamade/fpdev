program test_package_cleancommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.cleancommandflow;

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

  TPackageCleanProbe = class
  public
    CleanResult: Boolean;
    CleanCalls: Integer;
    LastScope: string;
    function Clean(const Scope: string; Outp, Errp: IOutput): Boolean;
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

function TPackageCleanProbe.Clean(const Scope: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(CleanCalls);
  LastScope := Scope;
  if Outp = nil then;
  if Errp = nil then;
  Result := CleanResult;
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

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TPackageCleanCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageCleanCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', OutpObj.Contains('fpdev package clean'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageCleanCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageCleanCommandPlanCore(
      ['cache', '--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage', ErrpObj.Contains('fpdev package clean'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsMissingScope;
var
  Plan: TPackageCleanCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageCleanCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare missing scope returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare missing scope requests exit', ShouldExit, 'should exit');
    Check('prepare missing scope writes usage', ErrpObj.Contains('fpdev package clean'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsInvalidScope;
var
  Plan: TPackageCleanCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageCleanCommandPlanCore(
      ['invalid-scope'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare invalid scope returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare invalid scope requests exit', ShouldExit, 'should exit');
    Check('prepare invalid scope writes usage', ErrpObj.Contains('fpdev package clean'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Plan: TPackageCleanCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageCleanCommandPlanCore(
      ['cache', 'extra', '--dry-run'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage', ErrpObj.Contains('fpdev package clean'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareParsesScopeAndFlags;
var
  Plan: TPackageCleanCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageCleanCommandPlanCore(
      ['all', '--dry-run', '--yes'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare flags returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare flags keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare flags keeps scope', Plan.Scope = 'all', Plan.Scope);
    Check('prepare flags keeps dry-run', Plan.DryRun, 'dry-run missing');
    Check('prepare flags keeps yes', Plan.Yes, 'yes missing');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteDryRunOutputsSelectedPaths;
var
  Plan: TPackageCleanCommandPlan;
  Probe: TPackageCleanProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageCleanCommandPlan);
  Plan.Scope := 'all';
  Plan.DryRun := True;
  Probe := TPackageCleanProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageCleanCommandPlanCore(
      Plan,
      Outp,
      Errp,
      '/tmp/sandbox-probe',
      '/tmp/cache-probe/packages',
      @Probe.Clean
    );
    Check('execute dry-run returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute dry-run keeps clean callback unused', Probe.CleanCalls = 0, IntToStr(Probe.CleanCalls));
    Check('execute dry-run shows sandbox path', OutpObj.Contains('/tmp/sandbox-probe'), OutpObj.Text);
    Check('execute dry-run shows cache path', OutpObj.Contains('/tmp/cache-probe/packages'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteRefusesWithoutYes;
var
  Plan: TPackageCleanCommandPlan;
  Probe: TPackageCleanProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageCleanCommandPlan);
  Plan.Scope := 'cache';
  Probe := TPackageCleanProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageCleanCommandPlanCore(
      Plan,
      Outp,
      Errp,
      '/tmp/sandbox-probe',
      '/tmp/cache-probe/packages',
      @Probe.Clean
    );
    Check('execute without yes returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('execute without yes keeps clean callback unused', Probe.CleanCalls = 0, IntToStr(Probe.CleanCalls));
    Check('execute without yes writes refusal', ErrpObj.Contains('Refusing'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteSuccessCallsCleanAndReturnsOk;
var
  Plan: TPackageCleanCommandPlan;
  Probe: TPackageCleanProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageCleanCommandPlan);
  Plan.Scope := 'sandbox';
  Plan.Yes := True;
  Probe := TPackageCleanProbe.Create;
  Probe.CleanResult := True;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageCleanCommandPlanCore(
      Plan,
      Outp,
      Errp,
      '/tmp/sandbox-probe',
      '/tmp/cache-probe/packages',
      @Probe.Clean
    );
    Check('execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute success calls clean once', Probe.CleanCalls = 1, IntToStr(Probe.CleanCalls));
    Check('execute success keeps scope', Probe.LastScope = 'sandbox', Probe.LastScope);
    Check('execute success writes completion', OutpObj.Contains('Clean complete'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteFailureMapsToExitError;
var
  Plan: TPackageCleanCommandPlan;
  Probe: TPackageCleanProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageCleanCommandPlan);
  Plan.Scope := 'cache';
  Plan.Yes := True;
  Probe := TPackageCleanProbe.Create;
  Probe.CleanResult := False;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageCleanCommandPlanCore(
      Plan,
      Outp,
      Errp,
      '/tmp/sandbox-probe',
      '/tmp/cache-probe/packages',
      @Probe.Clean
    );
    Check('execute failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute failure calls clean once', Probe.CleanCalls = 1, IntToStr(Probe.CleanCalls));
    Check('execute failure writes error summary', ErrpObj.Contains('Clean had errors'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Package Clean Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsMissingScope;
  TestPrepareRejectsInvalidScope;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestPrepareParsesScopeAndFlags;

  TestExecuteDryRunOutputsSelectedPaths;
  TestExecuteRefusesWithoutYes;
  TestExecuteSuccessCallsCleanAndReturnsOk;
  TestExecuteFailureMapsToExitError;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
