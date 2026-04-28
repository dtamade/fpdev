program test_fpc_bootstrapflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.bootstrapflow;

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

  TBootstrapFlowHarness = class
  public
    EnsureCalls: Integer;
    InstallCalls: Integer;
    EnsureResults: array of Boolean;
    InstallResult: Boolean;
    function EnsureBootstrap(const ATargetVersion: string): Boolean;
    function InstallBinaryFallback(const ATargetVersion: string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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

function TBootstrapFlowHarness.EnsureBootstrap(const ATargetVersion: string): Boolean;
begin
  Inc(EnsureCalls);
  if ATargetVersion = '' then;
  if EnsureCalls <= Length(EnsureResults) then
    Result := EnsureResults[EnsureCalls - 1]
  else
    Result := False;
end;

function TBootstrapFlowHarness.InstallBinaryFallback(
  const ATargetVersion: string): Boolean;
begin
  Inc(InstallCalls);
  if ATargetVersion = '' then;
  Result := InstallResult;
end;

procedure TestBuilderSuccessShortCircuitsFallback;
var
  Harness: TBootstrapFlowHarness;
  OutBuf: TStringOutput;
  OK: Boolean;
begin
  Harness := TBootstrapFlowHarness.Create;
  OutBuf := TStringOutput.Create;
  try
    SetLength(Harness.EnsureResults, 1);
    Harness.EnsureResults[0] := True;

    OK := ExecuteManagedFPCBootstrapEnsureCore(
      '3.2.2',
      OutBuf,
      @Harness.EnsureBootstrap,
      @Harness.InstallBinaryFallback
    );

    Check('bootstrapflow builder success returns true', OK, 'expected success');
    Check('bootstrapflow builder success only ensures once', Harness.EnsureCalls = 1,
      'ensure calls=' + IntToStr(Harness.EnsureCalls));
    Check('bootstrapflow builder success skips installer fallback', Harness.InstallCalls = 0,
      'install calls=' + IntToStr(Harness.InstallCalls));
    Check('bootstrapflow builder success keeps fallback message quiet',
      not OutBuf.Contains('Attempting binary bootstrap fallback for FPC'),
      'unexpected fallback output');
  finally
    Harness.Free;
  end;
end;

procedure TestBuilderFailureWithoutInstallerCallback;
var
  Harness: TBootstrapFlowHarness;
  OutBuf: TStringOutput;
  OK: Boolean;
begin
  Harness := TBootstrapFlowHarness.Create;
  OutBuf := TStringOutput.Create;
  try
    SetLength(Harness.EnsureResults, 1);
    Harness.EnsureResults[0] := False;

    OK := ExecuteManagedFPCBootstrapEnsureCore(
      '3.2.2',
      OutBuf,
      @Harness.EnsureBootstrap,
      nil
    );

    Check('bootstrapflow missing installer callback returns false', not OK, 'expected failure');
    Check('bootstrapflow missing installer callback keeps builder attempts at one', Harness.EnsureCalls = 1,
      'ensure calls=' + IntToStr(Harness.EnsureCalls));
    Check('bootstrapflow missing installer callback keeps install count at zero', Harness.InstallCalls = 0,
      'install calls=' + IntToStr(Harness.InstallCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestFallbackInstallAndRetrySuccess;
var
  Harness: TBootstrapFlowHarness;
  OutBuf: TStringOutput;
  OK: Boolean;
begin
  Harness := TBootstrapFlowHarness.Create;
  OutBuf := TStringOutput.Create;
  try
    SetLength(Harness.EnsureResults, 2);
    Harness.EnsureResults[0] := False;
    Harness.EnsureResults[1] := True;
    Harness.InstallResult := True;

    OK := ExecuteManagedFPCBootstrapEnsureCore(
      '3.2.2',
      OutBuf,
      @Harness.EnsureBootstrap,
      @Harness.InstallBinaryFallback
    );

    Check('bootstrapflow fallback retry success returns true', OK, 'expected success');
    Check('bootstrapflow fallback retry ensures twice', Harness.EnsureCalls = 2,
      'ensure calls=' + IntToStr(Harness.EnsureCalls));
    Check('bootstrapflow fallback retry installs once', Harness.InstallCalls = 1,
      'install calls=' + IntToStr(Harness.InstallCalls));
    Check('bootstrapflow fallback retry writes attempt message',
      OutBuf.Contains('Attempting binary bootstrap fallback for FPC 3.2.2...'),
      'attempt message missing');
    Check('bootstrapflow fallback retry writes installed message',
      OutBuf.Contains('Binary bootstrap fallback installed FPC 3.2.2'),
      'installed message missing');
  finally
    Harness.Free;
  end;
end;

procedure TestFallbackInstallSuccessButRetryStillFails;
var
  Harness: TBootstrapFlowHarness;
  OutBuf: TStringOutput;
  OK: Boolean;
begin
  Harness := TBootstrapFlowHarness.Create;
  OutBuf := TStringOutput.Create;
  try
    SetLength(Harness.EnsureResults, 2);
    Harness.EnsureResults[0] := False;
    Harness.EnsureResults[1] := False;
    Harness.InstallResult := True;

    OK := ExecuteManagedFPCBootstrapEnsureCore(
      '3.2.2',
      OutBuf,
      @Harness.EnsureBootstrap,
      @Harness.InstallBinaryFallback
    );

    Check('bootstrapflow retry failure returns false', not OK, 'expected failure');
    Check('bootstrapflow retry failure still ensures twice', Harness.EnsureCalls = 2,
      'ensure calls=' + IntToStr(Harness.EnsureCalls));
    Check('bootstrapflow retry failure still installs once', Harness.InstallCalls = 1,
      'install calls=' + IntToStr(Harness.InstallCalls));
    Check('bootstrapflow retry failure still reports install message',
      OutBuf.Contains('Binary bootstrap fallback installed FPC 3.2.2'),
      'installed message missing');
  finally
    Harness.Free;
  end;
end;

procedure TestFallbackInstallFailureStopsRetry;
var
  Harness: TBootstrapFlowHarness;
  OutBuf: TStringOutput;
  OK: Boolean;
begin
  Harness := TBootstrapFlowHarness.Create;
  OutBuf := TStringOutput.Create;
  try
    SetLength(Harness.EnsureResults, 1);
    Harness.EnsureResults[0] := False;
    Harness.InstallResult := False;

    OK := ExecuteManagedFPCBootstrapEnsureCore(
      '3.2.2',
      OutBuf,
      @Harness.EnsureBootstrap,
      @Harness.InstallBinaryFallback
    );

    Check('bootstrapflow fallback install failure returns false', not OK, 'expected failure');
    Check('bootstrapflow fallback install failure ensures once', Harness.EnsureCalls = 1,
      'ensure calls=' + IntToStr(Harness.EnsureCalls));
    Check('bootstrapflow fallback install failure installs once', Harness.InstallCalls = 1,
      'install calls=' + IntToStr(Harness.InstallCalls));
    Check('bootstrapflow fallback install failure writes attempt message',
      OutBuf.Contains('Attempting binary bootstrap fallback for FPC 3.2.2...'),
      'attempt message missing');
    Check('bootstrapflow fallback install failure skips installed message',
      not OutBuf.Contains('Binary bootstrap fallback installed FPC 3.2.2'),
      'unexpected installed message');
  finally
    Harness.Free;
  end;
end;

begin
  TestBuilderSuccessShortCircuitsFallback;
  TestBuilderFailureWithoutInstallerCallback;
  TestFallbackInstallAndRetrySuccess;
  TestFallbackInstallSuccessButRetryStillFails;
  TestFallbackInstallFailureStopsRetry;

  if FailCount > 0 then
  begin
    WriteLn(Format('FAIL: %d checks failed', [FailCount]));
    Halt(1);
  end;

  WriteLn(Format('PASS: %d checks passed', [PassCount]));
end.
