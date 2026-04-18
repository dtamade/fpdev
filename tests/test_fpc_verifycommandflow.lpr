program test_fpc_verifycommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.exitcodes,
  fpdev.fpc.types,
  fpdev.fpc.verifycommandflow;

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

  TFPCVerifyProbe = class
  public
    VerifyResult: Boolean;
    VerificationResult: TVerificationResult;
    InstallPath: string;
    VerifyCalls: Integer;
    InstallPathCalls: Integer;
    LastVersion: string;
    function VerifyInstallation(const AVersion: string; out AVerifResult: TVerificationResult): Boolean;
    function GetInstallPath(const AVersion: string): string;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  GMetadataExists: Boolean = False;

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

function TFPCVerifyProbe.VerifyInstallation(
  const AVersion: string;
  out AVerifResult: TVerificationResult
): Boolean;
begin
  Inc(VerifyCalls);
  LastVersion := AVersion;
  AVerifResult := VerificationResult;
  Result := VerifyResult;
end;

function TFPCVerifyProbe.GetInstallPath(const AVersion: string): string;
begin
  Inc(InstallPathCalls);
  LastVersion := AVersion;
  Result := InstallPath;
end;

function MetadataExists(const AInstallPath: string): Boolean;
begin
  if AInstallPath = '' then;
  Result := GMetadataExists;
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
  Plan: TFPCVerifyCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareFPCVerifyCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', Outp.Contains('fpdev fpc verify'), Outp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsUnexpectedArgs;
var
  Plan: TFPCVerifyCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareFPCVerifyCommandPlanCore(['3.2.2', 'extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare extra arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra arg requests exit', ShouldExit, 'should exit');
    Check('prepare extra arg writes usage', Errp.Contains('fpdev fpc verify'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestExecuteSuccessWithMetadata;
var
  Plan: TFPCVerifyCommandPlan;
  Probe: TFPCVerifyProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan.Version := '3.2.2';
  Probe := TFPCVerifyProbe.Create;
  Probe.VerifyResult := True;
  Probe.VerificationResult.Verified := True;
  Probe.InstallPath := '/tmp/fpc-3.2.2';
  GMetadataExists := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteFPCVerifyCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.VerifyInstallation,
      @Probe.GetInstallPath,
      @MetadataExists
    );
    Check('execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute success calls verifier once', Probe.VerifyCalls = 1, IntToStr(Probe.VerifyCalls));
    Check('execute success prints completion',
      Outp.Contains('Verification complete: FPC 3.2.2 is working correctly'),
      Outp.Text);
    Check('execute success prints metadata pass',
      Outp.Contains('PASS: Metadata file exists'),
      Outp.Text);
    Check('execute success keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteMissingExecutableShowsInstallHint;
var
  Plan: TFPCVerifyCommandPlan;
  Probe: TFPCVerifyProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan.Version := '3.2.2';
  Probe := TFPCVerifyProbe.Create;
  Probe.VerifyResult := False;
  Probe.VerificationResult.ExecutableExists := False;
  Probe.VerificationResult.ErrorMessage := 'missing executable';
  GMetadataExists := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteFPCVerifyCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.VerifyInstallation,
      @Probe.GetInstallPath,
      @MetadataExists
    );
    Check('execute missing executable returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute missing executable prints install hint',
      Errp.Contains('fpdev fpc install 3.2.2'),
      Errp.Text);
    Check('execute missing executable prints original error',
      Errp.Contains('missing executable'),
      Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteSmokeFailureUsesStageTwoReport;
var
  Plan: TFPCVerifyCommandPlan;
  Probe: TFPCVerifyProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan.Version := '3.2.2';
  Probe := TFPCVerifyProbe.Create;
  Probe.VerifyResult := False;
  Probe.VerificationResult.ExecutableExists := True;
  Probe.VerificationResult.DetectedVersion := '3.2.2';
  Probe.VerificationResult.ErrorMessage := 'compile failed';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteFPCVerifyCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.VerifyInstallation,
      @Probe.GetInstallPath,
      @MetadataExists
    );
    Check('execute smoke failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute smoke failure prints version pass first',
      Outp.Contains('PASS: Version verified'),
      Outp.Text);
    Check('execute smoke failure prints stage two header',
      Outp.Contains('[2/3] Compiling hello world test...'),
      Outp.Text);
    Check('execute smoke failure prints hello-world fail',
      Errp.Contains('FAIL: Hello world compilation failed'),
      Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

begin
  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnexpectedArgs;
  TestExecuteSuccessWithMetadata;
  TestExecuteMissingExecutableShowsInstallHint;
  TestExecuteSmokeFailureUsesStageTwoReport;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  WriteLn('Total: ', PassCount + FailCount);

  if FailCount > 0 then
    Halt(1);
end.
