program test_fpc_installversionflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.fpc.installversionflow;

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

  TInstallFlowProbe = class
  public
    VerifyResult: Boolean;
    VerifyError: string;
    HasArtifactsResult: Boolean;
    RestoreArtifactsResult: Boolean;
    SaveArtifactsResult: Boolean;
    DownloadSourceResult: Boolean;
    EnsureBootstrapResult: Boolean;
    BuildFromSourceResult: Boolean;
    SetupEnvironmentResult: Boolean;
    InstallBinaryResult: Boolean;
    WriteMetadataResult: Boolean;
    VerifyCalls: Integer;
    HasArtifactsCalls: Integer;
    RestoreArtifactsCalls: Integer;
    SaveArtifactsCalls: Integer;
    DownloadSourceCalls: Integer;
    EnsureBootstrapCalls: Integer;
    BuildFromSourceCalls: Integer;
    SetupEnvironmentCalls: Integer;
    InstallBinaryCalls: Integer;
    WriteMetadataCalls: Integer;
    LastVerifyExe: string;
    LastInstallPath: string;
    LastSourceDir: string;
    LastPrefix: string;
    LastMetadataInstallPath: string;
    LastMetadataVersion: string;
    LastMetadataFromSource: Boolean;
    function VerifyInstalledExecutable(const AFPCExe, AVersion: string; out AError: string): Boolean;
    function HasArtifacts(const AVersion: string): Boolean;
    function RestoreArtifacts(const AVersion, AInstallPath: string): Boolean;
    function SaveArtifacts(const AVersion, AInstallPath: string): Boolean;
    function DownloadSource(const AVersion, ASourceDir: string): Boolean;
    function EnsureBootstrap(const AVersion: string): Boolean;
    function BuildFromSource(const ASourceDir, AInstallPath: string): Boolean;
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
    function InstallBinary(const AVersion, APrefix: string): Boolean;
    function WriteMetadata(const AVersion, AInstallPath: string;
      AFromSource: Boolean): Boolean;
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

function TInstallFlowProbe.VerifyInstalledExecutable(const AFPCExe, AVersion: string; out AError: string): Boolean;
begin
  Inc(VerifyCalls);
  LastVerifyExe := AFPCExe;
  AError := VerifyError;
  Result := VerifyResult;
end;

function TInstallFlowProbe.HasArtifacts(const AVersion: string): Boolean;
begin
  Inc(HasArtifactsCalls);
  Result := HasArtifactsResult;
end;

function TInstallFlowProbe.RestoreArtifacts(const AVersion, AInstallPath: string): Boolean;
begin
  Inc(RestoreArtifactsCalls);
  LastInstallPath := AInstallPath;
  Result := RestoreArtifactsResult;
end;

function TInstallFlowProbe.SaveArtifacts(const AVersion, AInstallPath: string): Boolean;
begin
  Inc(SaveArtifactsCalls);
  LastInstallPath := AInstallPath;
  Result := SaveArtifactsResult;
end;

function TInstallFlowProbe.DownloadSource(const AVersion, ASourceDir: string): Boolean;
begin
  Inc(DownloadSourceCalls);
  LastSourceDir := ASourceDir;
  Result := DownloadSourceResult;
end;

function TInstallFlowProbe.EnsureBootstrap(const AVersion: string): Boolean;
begin
  Inc(EnsureBootstrapCalls);
  Result := EnsureBootstrapResult;
end;

function TInstallFlowProbe.BuildFromSource(const ASourceDir, AInstallPath: string): Boolean;
begin
  Inc(BuildFromSourceCalls);
  LastSourceDir := ASourceDir;
  LastInstallPath := AInstallPath;
  Result := BuildFromSourceResult;
end;

function TInstallFlowProbe.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
begin
  Inc(SetupEnvironmentCalls);
  LastInstallPath := AInstallPath;
  Result := SetupEnvironmentResult;
end;

function TInstallFlowProbe.InstallBinary(const AVersion, APrefix: string): Boolean;
begin
  Inc(InstallBinaryCalls);
  LastPrefix := APrefix;
  Result := InstallBinaryResult;
end;

function TInstallFlowProbe.WriteMetadata(const AVersion, AInstallPath: string;
  AFromSource: Boolean): Boolean;
begin
  Inc(WriteMetadataCalls);
  LastMetadataVersion := AVersion;
  LastMetadataInstallPath := AInstallPath;
  LastMetadataFromSource := AFromSource;
  Result := WriteMetadataResult;
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

procedure TestReuseInstalledShortCircuitsInstall;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.VerifyResult := True;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/root', '/root/fpc/3.2.2', '', False, False, True,
      True,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      nil, nil, nil,
      nil, nil, nil, nil, nil,
      @Probe.InstallBinary
    );

    Check('reuse installed returns true', OK, 'expected success');
    Check('reuse installed verifies once', Probe.VerifyCalls = 1,
      'verify calls=' + IntToStr(Probe.VerifyCalls));
    Check('reuse installed skips binary install', Probe.InstallBinaryCalls = 0,
      'binary calls=' + IntToStr(Probe.InstallBinaryCalls));
    Check('reuse installed uses executable path',
      Probe.LastVerifyExe = BuildFPCInstalledExecutablePathCore('/root/fpc/3.2.2'),
      'exe=' + Probe.LastVerifyExe);
    Check('reuse installed prints verified message',
      OutBuf.Contains('Installation verified successfully'), 'verified message missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestReuseInstalledFallsBackToReinstall;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.VerifyResult := False;
    Probe.VerifyError := 'broken install';
    Probe.InstallBinaryResult := True;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/root', '/root/fpc/3.2.2', '', False, False, True,
      True,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      nil, nil, nil,
      nil, nil, nil, nil, nil,
      @Probe.InstallBinary
    );

    Check('failed verify continues to reinstall', OK, 'expected success');
    Check('failed verify still calls binary install', Probe.InstallBinaryCalls = 1,
      'binary calls=' + IntToStr(Probe.InstallBinaryCalls));
    Check('failed verify prints warning',
      OutBuf.Contains('Warning: Installation verification failed'), 'warning missing');
    Check('failed verify prints reason',
      OutBuf.Contains('Reason: broken install'), 'reason missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestSourceInstallUsesCacheFastPath;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.HasArtifactsResult := True;
    Probe.RestoreArtifactsResult := True;
    Probe.SetupEnvironmentResult := True;
    Probe.WriteMetadataResult := True;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/install-root', '/install-root/fpc/3.2.2', '', True, False, False,
      True,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      @Probe.HasArtifacts,
      @Probe.RestoreArtifacts,
      @Probe.SaveArtifacts,
      @Probe.DownloadSource,
      @Probe.EnsureBootstrap,
      @Probe.BuildFromSource,
      @Probe.WriteMetadata,
      @Probe.SetupEnvironment,
      @Probe.InstallBinary
    );

    Check('cache fast path returns true', OK, 'expected success');
    Check('cache fast path restores once', Probe.RestoreArtifactsCalls = 1,
      'restore calls=' + IntToStr(Probe.RestoreArtifactsCalls));
    Check('cache fast path skips source download', Probe.DownloadSourceCalls = 0,
      'download calls=' + IntToStr(Probe.DownloadSourceCalls));
    Check('cache fast path runs setup once', Probe.SetupEnvironmentCalls = 1,
      'setup calls=' + IntToStr(Probe.SetupEnvironmentCalls));
    Check('cache fast path writes metadata once', Probe.WriteMetadataCalls = 1,
      'metadata calls=' + IntToStr(Probe.WriteMetadataCalls));
    Check('cache fast path writes metadata for source install', Probe.LastMetadataFromSource,
      'expected source metadata');
    Check('cache fast path metadata install path matches restored install path',
      Probe.LastMetadataInstallPath = '/install-root/fpc/3.2.2',
      'path=' + Probe.LastMetadataInstallPath);
    Check('cache fast path prints restore message',
      OutBuf.Contains('Build cache restored successfully'), 'restore success missing');
    Check('cache fast path prints install done',
      OutBuf.Contains(_Fmt(CMD_FPC_INSTALL_DONE, ['3.2.2'])), 'done missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestSourceInstallBuildsAndCachesAfterCacheMiss;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.HasArtifactsResult := True;
    Probe.RestoreArtifactsResult := False;
    Probe.DownloadSourceResult := True;
    Probe.EnsureBootstrapResult := True;
    Probe.BuildFromSourceResult := True;
    Probe.SetupEnvironmentResult := True;
    Probe.SaveArtifactsResult := True;
    Probe.WriteMetadataResult := True;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/install-root', '/install-root/fpc/3.2.2', '', True, False, False,
      True,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      @Probe.HasArtifacts,
      @Probe.RestoreArtifacts,
      @Probe.SaveArtifacts,
      @Probe.DownloadSource,
      @Probe.EnsureBootstrap,
      @Probe.BuildFromSource,
      @Probe.WriteMetadata,
      @Probe.SetupEnvironment,
      @Probe.InstallBinary
    );

    Check('cache miss build returns true', OK, 'expected success');
    Check('cache miss downloads source once', Probe.DownloadSourceCalls = 1,
      'download calls=' + IntToStr(Probe.DownloadSourceCalls));
    Check('cache miss ensures bootstrap once', Probe.EnsureBootstrapCalls = 1,
      'bootstrap calls=' + IntToStr(Probe.EnsureBootstrapCalls));
    Check('cache miss builds once', Probe.BuildFromSourceCalls = 1,
      'build calls=' + IntToStr(Probe.BuildFromSourceCalls));
    Check('cache miss writes metadata once', Probe.WriteMetadataCalls = 1,
      'metadata calls=' + IntToStr(Probe.WriteMetadataCalls));
    Check('cache miss metadata marks source install', Probe.LastMetadataFromSource,
      'expected source metadata');
    Check('cache miss saves cache once', Probe.SaveArtifactsCalls = 1,
      'save calls=' + IntToStr(Probe.SaveArtifactsCalls));
    Check('cache miss uses canonical source dir',
      Probe.LastSourceDir = BuildFPCSourceInstallPathCore('/install-root', '3.2.2'),
      'source dir=' + Probe.LastSourceDir);
    Check('cache miss prints cache fallback',
      OutBuf.Contains('Cache restore failed, building from source...'), 'cache fallback missing');
    Check('cache miss prints cache save success',
      OutBuf.Contains('Build artifacts cached successfully'), 'cache save missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestSourceInstallReportsBootstrapFailure;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.DownloadSourceResult := True;
    Probe.EnsureBootstrapResult := False;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/install-root', '/install-root/fpc/3.2.2', '', True, False, False,
      True,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      @Probe.HasArtifacts,
      @Probe.RestoreArtifacts,
      @Probe.SaveArtifacts,
      @Probe.DownloadSource,
      @Probe.EnsureBootstrap,
      @Probe.BuildFromSource,
      @Probe.WriteMetadata,
      @Probe.SetupEnvironment,
      @Probe.InstallBinary
    );

    Check('bootstrap failure returns false', not OK, 'expected failure');
    Check('bootstrap failure stops build', Probe.BuildFromSourceCalls = 0,
      'build calls=' + IntToStr(Probe.BuildFromSourceCalls));
    Check('bootstrap failure prints error',
      ErrBuf.Contains(_(CMD_FPC_BOOTSTRAP_CHECK_FAILED)), 'bootstrap error missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestSourceInstallSkipsCacheWhenDisabled;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.HasArtifactsResult := True;
    Probe.RestoreArtifactsResult := True;
    Probe.DownloadSourceResult := True;
    Probe.EnsureBootstrapResult := True;
    Probe.BuildFromSourceResult := True;
    Probe.SetupEnvironmentResult := True;
    Probe.SaveArtifactsResult := True;
    Probe.WriteMetadataResult := True;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/install-root', '/install-root/fpc/3.2.2', '', True, False, False,
      False,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      @Probe.HasArtifacts,
      @Probe.RestoreArtifacts,
      @Probe.SaveArtifacts,
      @Probe.DownloadSource,
      @Probe.EnsureBootstrap,
      @Probe.BuildFromSource,
      @Probe.WriteMetadata,
      @Probe.SetupEnvironment,
      @Probe.InstallBinary
    );

    Check('no-cache source install returns true', OK, 'expected success');
    Check('no-cache skips cache lookup', Probe.HasArtifactsCalls = 0,
      'has calls=' + IntToStr(Probe.HasArtifactsCalls));
    Check('no-cache skips cache restore', Probe.RestoreArtifactsCalls = 0,
      'restore calls=' + IntToStr(Probe.RestoreArtifactsCalls));
    Check('no-cache skips cache save', Probe.SaveArtifactsCalls = 0,
      'save calls=' + IntToStr(Probe.SaveArtifactsCalls));
    Check('no-cache still downloads source', Probe.DownloadSourceCalls = 1,
      'download calls=' + IntToStr(Probe.DownloadSourceCalls));
    Check('no-cache still builds source', Probe.BuildFromSourceCalls = 1,
      'build calls=' + IntToStr(Probe.BuildFromSourceCalls));
    Check('no-cache still writes metadata', Probe.WriteMetadataCalls = 1,
      'metadata calls=' + IntToStr(Probe.WriteMetadataCalls));
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestBinaryInstallWritesMetadata;
var
  Probe: TInstallFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TInstallFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.InstallBinaryResult := True;
    Probe.WriteMetadataResult := True;

    OK := ExecuteFPCInstallVersionCore(
      '3.2.2', '/install-root', '/install-root/fpc/3.2.2', '/custom/prefix',
      False, False, False, True,
      OutRef, ErrRef,
      @Probe.VerifyInstalledExecutable,
      @Probe.HasArtifacts,
      @Probe.RestoreArtifacts,
      @Probe.SaveArtifacts,
      @Probe.DownloadSource,
      @Probe.EnsureBootstrap,
      @Probe.BuildFromSource,
      @Probe.WriteMetadata,
      @Probe.SetupEnvironment,
      @Probe.InstallBinary
    );

    Check('binary install returns true', OK, 'expected success');
    Check('binary install invokes installer once', Probe.InstallBinaryCalls = 1,
      'binary calls=' + IntToStr(Probe.InstallBinaryCalls));
    Check('binary install writes metadata once', Probe.WriteMetadataCalls = 1,
      'metadata calls=' + IntToStr(Probe.WriteMetadataCalls));
    Check('binary install metadata marks binary mode', not Probe.LastMetadataFromSource,
      'expected binary metadata');
    Check('binary install metadata uses resolved prefix path',
      Probe.LastMetadataInstallPath = ExpandFileName('/custom/prefix'),
      'path=' + Probe.LastMetadataInstallPath);
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

begin
  TestReuseInstalledShortCircuitsInstall;
  TestReuseInstalledFallsBackToReinstall;
  TestSourceInstallUsesCacheFastPath;
  TestSourceInstallBuildsAndCachesAfterCacheMiss;
  TestSourceInstallReportsBootstrapFailure;
  TestSourceInstallSkipsCacheWhenDisabled;
  TestBinaryInstallWritesMetadata;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
