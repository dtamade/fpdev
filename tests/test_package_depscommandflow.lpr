program test_package_depscommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.depscommandflow;

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

  TDepsProbe = class
  public
    MockDeps: TStringArray;
    RootPackage: string;
    LastPackage: string;
    CallCount: Integer;
    function GetDeps(const APackageName: string): TStringArray;
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

function TDepsProbe.GetDeps(const APackageName: string): TStringArray;
begin
  Inc(CallCount);
  LastPackage := APackageName;
  if SameText(APackageName, RootPackage) then
    Result := MockDeps
  else
    Result := nil;
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
  Plan: TPackageDepsCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageDepsCommandPlanCore(
      ['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', OutpObj.Contains('fpdev package deps'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageDepsCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageDepsCommandPlanCore(
      ['--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage', ErrpObj.Contains('fpdev package deps'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsInvalidDepth;
var
  Plan: TPackageDepsCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageDepsCommandPlanCore(
      ['--depth=abc'], Outp, Errp, Plan, ShouldExit);
    Check('prepare invalid depth returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare invalid depth requests exit', ShouldExit, 'should exit');
    Check('prepare invalid depth writes usage', ErrpObj.Contains('fpdev package deps'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsExtraPositional;
var
  Plan: TPackageDepsCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageDepsCommandPlanCore(
      ['demo', 'extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage', ErrpObj.Contains('fpdev package deps'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareDefaults;
var
  Plan: TPackageDepsCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageDepsCommandPlanCore(
      [], Outp, Errp, Plan, ShouldExit);
    Check('prepare defaults returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare defaults keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare defaults keeps flat false', not Plan.ShowFlat, 'expected tree mode');
    Check('prepare defaults keeps max depth zero', Plan.MaxDepth = 0, IntToStr(Plan.MaxDepth));
    Check('prepare defaults keeps package empty', Plan.PackageName = '', Plan.PackageName);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareFlags;
var
  Plan: TPackageDepsCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageDepsCommandPlanCore(
      ['demo', '--flat', '--depth=2'], Outp, Errp, Plan, ShouldExit);
    Check('prepare flags returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare flags keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare flags keeps package', Plan.PackageName = 'demo', Plan.PackageName);
    Check('prepare flags keeps flat true', Plan.ShowFlat, 'flat missing');
    Check('prepare flags keeps depth', Plan.MaxDepth = 2, IntToStr(Plan.MaxDepth));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteWithDeps;
var
  Plan: TPackageDepsCommandPlan;
  Probe: TDepsProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageDepsCommandPlan);
  Plan.PackageName := 'mormot2';
  Probe := TDepsProbe.Create;
  Probe.RootPackage := 'mormot2';
  SetLength(Probe.MockDeps, 2);
  Probe.MockDeps[0] := 'zlib >= 1.2.0';
  Probe.MockDeps[1] := 'openssl >= 1.1.0';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageDepsCommandPlanCore(Plan, Outp, Errp, @Probe.GetDeps, nil);
    Check('execute with deps returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute with deps calls provider for root', Probe.CallCount >= 1, IntToStr(Probe.CallCount));
    Check('execute with deps shows header', OutpObj.Contains('mormot2'), OutpObj.Text);
    Check('execute with deps shows first dep', OutpObj.Contains('zlib >= 1.2.0'), OutpObj.Text);
    Check('execute with deps shows second dep', OutpObj.Contains('openssl >= 1.1.0'), OutpObj.Text);
    Check('execute with deps shows total', OutpObj.Contains('2'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteNoDeps;
var
  Plan: TPackageDepsCommandPlan;
  Probe: TDepsProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageDepsCommandPlan);
  Plan.PackageName := 'synapse';
  Probe := TDepsProbe.Create;
  Probe.RootPackage := 'synapse';
  Probe.MockDeps := nil;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageDepsCommandPlanCore(Plan, Outp, Errp, @Probe.GetDeps, nil);
    Check('execute no deps returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute no deps shows none', OutpObj.Contains('(none)'), OutpObj.Text);
    Check('execute no deps shows zero total', OutpObj.Contains('0'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteFlatOutput;
var
  Plan: TPackageDepsCommandPlan;
  Probe: TDepsProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageDepsCommandPlan);
  Plan.PackageName := 'mylib';
  Plan.ShowFlat := True;
  Probe := TDepsProbe.Create;
  Probe.RootPackage := 'mylib';
  SetLength(Probe.MockDeps, 2);
  Probe.MockDeps[0] := 'dep-a >= 1.0';
  Probe.MockDeps[1] := 'dep-b >= 2.0';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageDepsCommandPlanCore(Plan, Outp, Errp, @Probe.GetDeps, nil);
    Check('execute flat returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute flat shows header', OutpObj.Contains('mylib'), OutpObj.Text);
    Check('execute flat omits tree connector', not OutpObj.Contains('+--'), OutpObj.Text);
    Check('execute flat prints deps', OutpObj.Contains('  dep-a >= 1.0'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Package Deps Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsInvalidDepth;
  TestPrepareRejectsExtraPositional;
  TestPrepareDefaults;
  TestPrepareFlags;
  TestExecuteWithDeps;
  TestExecuteNoDeps;
  TestExecuteFlatOutput;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
