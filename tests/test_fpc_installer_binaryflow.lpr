program test_fpc_installer_binaryflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.installer.binaryflow;

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
  TBinaryFlowProbe = class
  public
    ManifestResult: Boolean;
    RepoResult: Boolean;
    SourceForgeResult: Boolean;
    RaiseOnManifest: Boolean;
    RaiseOnRepo: Boolean;
    RaiseOnSourceForge: Boolean;
    ManifestCalls: Integer;
    RepoCalls: Integer;
    SourceForgeCalls: Integer;
    LastVersion: string;
    LastPlatform: string;
    LastInstallPath: string;
    function InstallFromManifest(const AVersion, AInstallPath: string): Boolean;
    function TryInstallFromRepo(const AVersion, APlatform, AInstallPath: string): Boolean;
    function InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;
  end;

function TBinaryFlowProbe.InstallFromManifest(const AVersion, AInstallPath: string): Boolean;
begin
  Inc(ManifestCalls);
  LastVersion := AVersion;
  LastInstallPath := AInstallPath;
  if RaiseOnManifest then
    raise Exception.Create('manifest boom');
  Result := ManifestResult;
end;

function TBinaryFlowProbe.TryInstallFromRepo(const AVersion, APlatform, AInstallPath: string): Boolean;
begin
  Inc(RepoCalls);
  LastVersion := AVersion;
  LastPlatform := APlatform;
  LastInstallPath := AInstallPath;
  if RaiseOnRepo then
    raise Exception.Create('repo boom');
  Result := RepoResult;
end;

function TBinaryFlowProbe.InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;
begin
  Inc(SourceForgeCalls);
  LastVersion := AVersion;
  LastInstallPath := AInstallPath;
  if RaiseOnSourceForge then
    raise Exception.Create('sourceforge boom');
  Result := SourceForgeResult;
end;

procedure TestManifestSuccessShortCircuitsFallbacks;
var
  Probe: TBinaryFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TBinaryFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.ManifestResult := True;

    OK := ExecuteFPCBinaryInstallFlow('3.2.2', 'linux-x86_64', '/tmp/fpc-3.2.2',
      OutBuf, ErrBuf, @Probe.InstallFromManifest, @Probe.TryInstallFromRepo,
      @Probe.InstallFromSourceForge);

    Check('manifest success returns true', OK, 'expected success');
    Check('manifest called once', Probe.ManifestCalls = 1,
      'manifest calls=' + IntToStr(Probe.ManifestCalls));
    Check('manifest success skips repo', Probe.RepoCalls = 0,
      'repo calls=' + IntToStr(Probe.RepoCalls));
    Check('manifest success skips sourceforge', Probe.SourceForgeCalls = 0,
      'sourceforge calls=' + IntToStr(Probe.SourceForgeCalls));
    Check('manifest receives version', Probe.LastVersion = '3.2.2',
      'version=' + Probe.LastVersion);
    Check('manifest receives install path', Probe.LastInstallPath = '/tmp/fpc-3.2.2',
      'path=' + Probe.LastInstallPath);
    Check('header includes version', OutBuf.Contains('FPC Binary Installation: 3.2.2'),
      'version header missing');
    Check('header includes target', OutBuf.Contains('Target: /tmp/fpc-3.2.2'),
      'target missing');
    Check('header includes platform', OutBuf.Contains('Platform: linux-x86_64'),
      'platform missing');
    Check('manifest success message present', OutBuf.Contains('Manifest-based installation successful'),
      'manifest success missing');
    Check('manifest success keeps stderr quiet', not ErrBuf.Contains('InstallFromBinary failed'),
      'unexpected stderr output');
  finally
    Probe.Free;
  end;
end;

procedure TestRepoFallbackUsesPlatformAndPath;
var
  Probe: TBinaryFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TBinaryFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.ManifestResult := False;
    Probe.RepoResult := True;

    OK := ExecuteFPCBinaryInstallFlow('3.2.3', 'linux-aarch64', '/opt/fpc-3.2.3',
      OutBuf, ErrBuf, @Probe.InstallFromManifest, @Probe.TryInstallFromRepo,
      @Probe.InstallFromSourceForge);

    Check('repo fallback returns true', OK, 'expected success');
    Check('repo fallback runs manifest once', Probe.ManifestCalls = 1,
      'manifest calls=' + IntToStr(Probe.ManifestCalls));
    Check('repo fallback runs repo once', Probe.RepoCalls = 1,
      'repo calls=' + IntToStr(Probe.RepoCalls));
    Check('repo fallback skips sourceforge', Probe.SourceForgeCalls = 0,
      'sourceforge calls=' + IntToStr(Probe.SourceForgeCalls));
    Check('repo fallback passes version', Probe.LastVersion = '3.2.3',
      'version=' + Probe.LastVersion);
    Check('repo fallback passes platform', Probe.LastPlatform = 'linux-aarch64',
      'platform=' + Probe.LastPlatform);
    Check('repo fallback passes install path', Probe.LastInstallPath = '/opt/fpc-3.2.3',
      'path=' + Probe.LastInstallPath);
    Check('repo fallback message present', OutBuf.Contains('trying fpdev-repo'),
      'repo fallback message missing');
    Check('repo fallback omits sourceforge summary', not OutBuf.Contains('Binary package installed from SourceForge'),
      'unexpected SourceForge summary');
  finally
    Probe.Free;
  end;
end;

procedure TestSourceForgeFallbackPrintsSummary;
var
  Probe: TBinaryFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TBinaryFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.ManifestResult := False;
    Probe.RepoResult := False;
    Probe.SourceForgeResult := True;

    OK := ExecuteFPCBinaryInstallFlow('3.2.4', 'linux-x86_64', '/srv/fpc-3.2.4',
      OutBuf, ErrBuf, @Probe.InstallFromManifest, @Probe.TryInstallFromRepo,
      @Probe.InstallFromSourceForge);

    Check('sourceforge fallback returns true', OK, 'expected success');
    Check('sourceforge fallback runs manifest once', Probe.ManifestCalls = 1,
      'manifest calls=' + IntToStr(Probe.ManifestCalls));
    Check('sourceforge fallback runs repo once', Probe.RepoCalls = 1,
      'repo calls=' + IntToStr(Probe.RepoCalls));
    Check('sourceforge fallback runs sourceforge once', Probe.SourceForgeCalls = 1,
      'sourceforge calls=' + IntToStr(Probe.SourceForgeCalls));
    Check('sourceforge step message present', OutBuf.Contains('[4/4] Attempting SourceForge download'),
      'sourceforge step missing');
    Check('sourceforge summary present', OutBuf.Contains('Installation Summary'),
      'installation summary missing');
    Check('sourceforge summary mentions source', OutBuf.Contains('Binary package installed from SourceForge'),
      'sourceforge source summary missing');
  finally
    Probe.Free;
  end;
end;

procedure TestAllFallbacksFail;
var
  Probe: TBinaryFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TBinaryFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.ManifestResult := False;
    Probe.RepoResult := False;
    Probe.SourceForgeResult := False;

    OK := ExecuteFPCBinaryInstallFlow('3.2.5', 'linux-x86_64', '/tmp/fpc-3.2.5',
      OutBuf, ErrBuf, @Probe.InstallFromManifest, @Probe.TryInstallFromRepo,
      @Probe.InstallFromSourceForge);

    Check('all fallbacks fail returns false', not OK, 'expected failure');
    Check('all fallbacks hit sourceforge', Probe.SourceForgeCalls = 1,
      'sourceforge calls=' + IntToStr(Probe.SourceForgeCalls));
    Check('failed flow skips sourceforge summary', not OutBuf.Contains('Installation Summary'),
      'unexpected installation summary');
  finally
    Probe.Free;
  end;
end;

procedure TestExceptionsReportInstallerFailure;
var
  Probe: TBinaryFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OK: Boolean;
begin
  Probe := TBinaryFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.ManifestResult := False;
    Probe.RepoResult := False;
    Probe.RaiseOnSourceForge := True;

    OK := ExecuteFPCBinaryInstallFlow('3.2.6', 'linux-x86_64', '/tmp/fpc-3.2.6',
      OutBuf, ErrBuf, @Probe.InstallFromManifest, @Probe.TryInstallFromRepo,
      @Probe.InstallFromSourceForge);

    Check('exception path returns false', not OK, 'expected failure');
    Check('exception path reaches sourceforge callback', Probe.SourceForgeCalls = 1,
      'sourceforge calls=' + IntToStr(Probe.SourceForgeCalls));
    Check('exception path reports installer failure', ErrBuf.Contains('InstallFromBinary failed - sourceforge boom'),
      'exception message missing');
  finally
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Binary Flow Tests ===');

  TestManifestSuccessShortCircuitsFallbacks;
  TestRepoFallbackUsesPlatformAndPath;
  TestSourceForgeFallbackPrintsSummary;
  TestAllFallbacksFail;
  TestExceptionsReportInstallerFailure;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
