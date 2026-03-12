program test_fpc_installer_repoflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.installer.repoflow;

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

type
  TRepoFlowProbe = class
  public
    InitResult: Boolean;
    HasReleaseResult: Boolean;
    InstallResult: Boolean;
    InitCalls: Integer;
    HasCalls: Integer;
    InstallCalls: Integer;
    LastVersion: string;
    LastPlatform: string;
    LastInstallPath: string;
    function Initialize: Boolean;
    function HasBinaryRelease(const AVersion, APlatform: string): Boolean;
    function InstallBinaryRelease(const AVersion, APlatform, AInstallPath: string): Boolean;
  end;

function TRepoFlowProbe.Initialize: Boolean;
begin
  Inc(InitCalls);
  Result := InitResult;
end;

function TRepoFlowProbe.HasBinaryRelease(const AVersion, APlatform: string): Boolean;
begin
  Inc(HasCalls);
  LastVersion := AVersion;
  LastPlatform := APlatform;
  Result := HasReleaseResult;
end;

function TRepoFlowProbe.InstallBinaryRelease(const AVersion, APlatform, AInstallPath: string): Boolean;
begin
  Inc(InstallCalls);
  LastVersion := AVersion;
  LastPlatform := APlatform;
  LastInstallPath := AInstallPath;
  Result := InstallResult;
end;

procedure TestRepoFlowSuccess;
var
  Probe: TRepoFlowProbe;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TRepoFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.InitResult := True;
    Probe.HasReleaseResult := True;
    Probe.InstallResult := True;

    OK := ExecuteFPCRepoInstallFlow('3.2.2', 'linux-x86_64', '/tmp/fpc-3.2.2',
      OutBuf, ErrBuf, @Probe.Initialize, @Probe.HasBinaryRelease,
      @Probe.InstallBinaryRelease);

    Check('repo flow success returns true', OK, 'expected success');
    Check('repo init called once', Probe.InitCalls = 1,
      'init calls=' + IntToStr(Probe.InitCalls));
    Check('repo release check called once', Probe.HasCalls = 1,
      'has calls=' + IntToStr(Probe.HasCalls));
    Check('repo install called once', Probe.InstallCalls = 1,
      'install calls=' + IntToStr(Probe.InstallCalls));
    Check('repo flow passes version', Probe.LastVersion = '3.2.2',
      'version=' + Probe.LastVersion);
    Check('repo flow passes platform', Probe.LastPlatform = 'linux-x86_64',
      'platform=' + Probe.LastPlatform);
    Check('repo flow passes install path', Probe.LastInstallPath = '/tmp/fpc-3.2.2',
      'path=' + Probe.LastInstallPath);
    Check('success output mentions installed from repo', OutBuf.Contains('installed from fpdev-repo'),
      'success message missing');
    Check('success path keeps stderr quiet', not ErrBuf.Contains('Failed'),
      'unexpected stderr failure');
  finally
    Probe.Free;
  end;
end;

procedure TestRepoFlowInitFailure;
var
  Probe: TRepoFlowProbe;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TRepoFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.InitResult := False;
    OK := ExecuteFPCRepoInstallFlow('3.2.2', 'linux-x86_64', '/tmp/fpc-3.2.2',
      OutBuf, ErrBuf, @Probe.Initialize, @Probe.HasBinaryRelease,
      @Probe.InstallBinaryRelease);

    Check('init failure returns false', not OK, 'expected failure');
    Check('init failure stops before release check', Probe.HasCalls = 0,
      'has calls=' + IntToStr(Probe.HasCalls));
    Check('init failure stops before install', Probe.InstallCalls = 0,
      'install calls=' + IntToStr(Probe.InstallCalls));
    Check('init failure prints guidance', ErrBuf.Contains('Failed to initialize fpdev-repo'),
      'missing init failure guidance');
  finally
    Probe.Free;
  end;
end;

procedure TestRepoFlowInstallFailureFallsBack;
var
  Probe: TRepoFlowProbe;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TRepoFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.InitResult := True;
    Probe.HasReleaseResult := True;
    Probe.InstallResult := False;

    OK := ExecuteFPCRepoInstallFlow('3.2.2', 'linux-x86_64', '/tmp/fpc-3.2.2',
      OutBuf, ErrBuf, @Probe.Initialize, @Probe.HasBinaryRelease,
      @Probe.InstallBinaryRelease);

    Check('install failure returns false', not OK, 'expected fallback failure');
    Check('install failure still calls install once', Probe.InstallCalls = 1,
      'install calls=' + IntToStr(Probe.InstallCalls));
    Check('install failure emits fallback hint', ErrBuf.Contains('Trying fallback to SourceForge'),
      'fallback hint missing');
  finally
    Probe.Free;
  end;
end;

procedure TestRepoFlowMissingBinarySkipsInstall;
var
  Probe: TRepoFlowProbe;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TRepoFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.InitResult := True;
    Probe.HasReleaseResult := False;
    Probe.InstallResult := True;

    OK := ExecuteFPCRepoInstallFlow('3.2.2', 'linux-x86_64', '/tmp/fpc-3.2.2',
      OutBuf, ErrBuf, @Probe.Initialize, @Probe.HasBinaryRelease,
      @Probe.InstallBinaryRelease);

    Check('missing binary returns false', not OK, 'expected no-release false');
    Check('missing binary skips install call', Probe.InstallCalls = 0,
      'install calls=' + IntToStr(Probe.InstallCalls));
    Check('missing binary still checks release', Probe.HasCalls = 1,
      'has calls=' + IntToStr(Probe.HasCalls));
  finally
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Repo Flow Tests ===');
  TestRepoFlowSuccess;
  TestRepoFlowInitFailure;
  TestRepoFlowInstallFailureFallsBack;
  TestRepoFlowMissingBinarySkipsInstall;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
