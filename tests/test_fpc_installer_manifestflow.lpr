program test_fpc_installer_manifestflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.manifest,
  fpdev.fpc.installer.manifestplan,
  fpdev.fpc.installer.manifestflow,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  GTempRoot: string;

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
  TManifestFlowProbe = class
  public
    PrepareResult: Boolean;
    PrepareError: string;
    FetchResult: Boolean;
    FetchError: string;
    ExtractResult: Boolean;
    NestedResult: Boolean;
    RaiseOnFetch: Boolean;
    PrepareCalls: Integer;
    FetchCalls: Integer;
    ExtractCalls: Integer;
    NestedCalls: Integer;
    LastVersion: string;
    LastDownloadFile: string;
    LastExtractDir: string;
    LastInstallPath: string;
    Plan: TFPCManifestInstallPlan;
    function PreparePlan(const AVersion: string; out APlan: TFPCManifestInstallPlan;
      out AError: string): Boolean;
    function FetchDownload(const APlan: TFPCManifestInstallPlan;
      out AError: string): Boolean;
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
    function ExtractNested(const ATempDir, AInstallPath, ATempFile: string): Boolean;
  end;

function TManifestFlowProbe.PreparePlan(const AVersion: string;
  out APlan: TFPCManifestInstallPlan; out AError: string): Boolean;
begin
  Inc(PrepareCalls);
  LastVersion := AVersion;
  APlan := Plan;
  AError := PrepareError;
  Result := PrepareResult;
end;

function TManifestFlowProbe.FetchDownload(const APlan: TFPCManifestInstallPlan;
  out AError: string): Boolean;
begin
  Inc(FetchCalls);
  LastDownloadFile := APlan.DownloadFile;
  if RaiseOnFetch then
    raise Exception.Create('fetch boom');
  AError := FetchError;
  Result := FetchResult;
  if Result then
    with TStringList.Create do
    try
      Add('downloaded');
      SaveToFile(APlan.DownloadFile);
    finally
      Free;
    end;
end;

function TManifestFlowProbe.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
begin
  Inc(ExtractCalls);
  LastDownloadFile := AArchivePath;
  LastExtractDir := ADestPath;
  Result := ExtractResult;
end;

function TManifestFlowProbe.ExtractNested(const ATempDir, AInstallPath,
  ATempFile: string): Boolean;
begin
  Inc(NestedCalls);
  LastExtractDir := ATempDir;
  LastInstallPath := AInstallPath;
  LastDownloadFile := ATempFile;
  Result := NestedResult;
end;

function MakePlan(const AVersion: string): TFPCManifestInstallPlan;
begin
  Result := Default(TFPCManifestInstallPlan);
  Result.Platform := 'linux-x86_64';
  SetLength(Result.Target.URLs, 2);
  Result.Target.URLs[0] := 'https://example.invalid/fpc-' + AVersion + '.tar';
  Result.Target.URLs[1] := 'https://mirror.invalid/fpc-' + AVersion + '.tar';
  Result.Target.Hash := 'abc123';
  Result.Target.Size := 424242;
  Result.DownloadDir := CreateUniqueTempDir('test_manifestflow_download_dir');
  Result.DownloadFile := Result.DownloadDir + PathDelim + 'fpc-' + AVersion + '.tar';
  Result.ExtractDir := CreateUniqueTempDir('test_manifestflow_extract_dir');
  CleanupTempDir(Result.ExtractDir);
end;

procedure CleanupPlanDirs(const APlan: TFPCManifestInstallPlan);
begin
  if DirectoryExists(APlan.DownloadDir) then
    CleanupTempDir(APlan.DownloadDir);
  if DirectoryExists(APlan.ExtractDir) then
    CleanupTempDir(APlan.ExtractDir);
end;

procedure TestManifestFlowSuccessAndCleanup;
var
  Probe: TManifestFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
  OK: Boolean;
begin
  Probe := TManifestFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_manifestflow_install');
  try
    Probe.PrepareResult := True;
    Probe.FetchResult := True;
    Probe.ExtractResult := True;
    Probe.NestedResult := True;
    Probe.Plan := MakePlan('3.2.2');

    OK := ExecuteFPCManifestInstallFlow('3.2.2', InstallDir, OutBuf, ErrBuf,
      @Probe.PreparePlan, @Probe.FetchDownload, @Probe.ExtractArchive,
      @Probe.ExtractNested);

    Check('manifest flow success returns true', OK, 'expected success');
    Check('manifest flow calls prepare once', Probe.PrepareCalls = 1,
      'prepare calls=' + IntToStr(Probe.PrepareCalls));
    Check('manifest flow calls fetch once', Probe.FetchCalls = 1,
      'fetch calls=' + IntToStr(Probe.FetchCalls));
    Check('manifest flow calls outer extract once', Probe.ExtractCalls = 1,
      'extract calls=' + IntToStr(Probe.ExtractCalls));
    Check('manifest flow calls nested once', Probe.NestedCalls = 1,
      'nested calls=' + IntToStr(Probe.NestedCalls));
    Check('manifest flow prints platform', OutBuf.Contains('Platform: linux-x86_64'),
      'platform missing');
    Check('manifest flow prints mirror count', OutBuf.Contains('Found target with 2 mirror(s)'),
      'mirror count missing');
    Check('manifest flow prints hash', OutBuf.Contains('Hash: abc123'),
      'hash missing');
    Check('manifest flow prints size', OutBuf.Contains('Size: 424242 bytes'),
      'size missing');
    Check('manifest flow forwards install path', Probe.LastInstallPath = InstallDir,
      'install path=' + Probe.LastInstallPath);
    Check('manifest flow deletes downloaded file', not FileExists(Probe.Plan.DownloadFile),
      'download file should be cleaned');
    Check('manifest flow removes extract dir', not DirectoryExists(Probe.Plan.ExtractDir),
      'extract dir should be cleaned');
  finally
    CleanupPlanDirs(Probe.Plan);
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestManifestLoadFailureShowsGuidance;
var
  Probe: TManifestFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
begin
  Probe := TManifestFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.PrepareResult := False;
    Probe.PrepareError := 'Failed to load manifest';

    Check('manifest load failure returns false',
      not ExecuteFPCManifestInstallFlow('3.2.3', '/tmp/fpc', OutBuf, ErrBuf,
        @Probe.PreparePlan, @Probe.FetchDownload, @Probe.ExtractArchive,
        @Probe.ExtractNested),
      'expected failure');
    Check('manifest load failure shows update guidance',
      ErrBuf.Contains('Try running: fpdev fpc update-manifest'), 'guidance missing');
    Check('manifest load failure stops before fetch', Probe.FetchCalls = 0,
      'fetch calls=' + IntToStr(Probe.FetchCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestManifestGenericPrepareError;
var
  Probe: TManifestFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
begin
  Probe := TManifestFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.PrepareResult := False;
    Probe.PrepareError := 'No binary available for FPC 3.2.4 on linux-x86_64';

    Check('manifest prepare error returns false',
      not ExecuteFPCManifestInstallFlow('3.2.4', '/tmp/fpc', OutBuf, ErrBuf,
        @Probe.PreparePlan, @Probe.FetchDownload, @Probe.ExtractArchive,
        @Probe.ExtractNested),
      'expected failure');
    Check('manifest prepare error is forwarded',
      ErrBuf.Contains('No binary available for FPC 3.2.4 on linux-x86_64'),
      'prepare error missing');
  finally
    Probe.Free;
  end;
end;

procedure TestManifestDownloadFailure;
var
  Probe: TManifestFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
begin
  Probe := TManifestFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_manifestflow_download_fail_install');
  try
    Probe.PrepareResult := True;
    Probe.FetchResult := False;
    Probe.FetchError := 'network down';
    Probe.Plan := MakePlan('3.2.5');

    Check('manifest download failure returns false',
      not ExecuteFPCManifestInstallFlow('3.2.5', InstallDir, OutBuf, ErrBuf,
        @Probe.PreparePlan, @Probe.FetchDownload, @Probe.ExtractArchive,
        @Probe.ExtractNested),
      'expected failure');
    Check('manifest download failure reports error',
      ErrBuf.Contains('Download failed: network down'), 'download failure missing');
    Check('manifest download failure skips extract', Probe.ExtractCalls = 0,
      'extract calls=' + IntToStr(Probe.ExtractCalls));
  finally
    CleanupPlanDirs(Probe.Plan);
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestManifestOuterExtractFailureCleansUp;
var
  Probe: TManifestFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
begin
  Probe := TManifestFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_manifestflow_extract_fail_install');
  try
    Probe.PrepareResult := True;
    Probe.FetchResult := True;
    Probe.ExtractResult := False;
    Probe.NestedResult := False;
    Probe.Plan := MakePlan('3.2.6');

    Check('manifest outer extract failure returns false',
      not ExecuteFPCManifestInstallFlow('3.2.6', InstallDir, OutBuf, ErrBuf,
        @Probe.PreparePlan, @Probe.FetchDownload, @Probe.ExtractArchive,
        @Probe.ExtractNested),
      'expected failure');
    Check('manifest outer extract failure reports message',
      ErrBuf.Contains('Extraction failed'), 'extract failure missing');
    Check('manifest outer extract failure cleans download file',
      not FileExists(Probe.Plan.DownloadFile), 'download file should be deleted');
    Check('manifest outer extract failure cleans extract dir',
      not DirectoryExists(Probe.Plan.ExtractDir), 'extract dir should be deleted');
  finally
    CleanupPlanDirs(Probe.Plan);
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestManifestExceptionPath;
var
  Probe: TManifestFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
begin
  Probe := TManifestFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_manifestflow_exception_install');
  try
    Probe.PrepareResult := True;
    Probe.FetchResult := True;
    Probe.RaiseOnFetch := True;
    Probe.Plan := MakePlan('3.2.7');

    Check('manifest exception returns false',
      not ExecuteFPCManifestInstallFlow('3.2.7', InstallDir, OutBuf, ErrBuf,
        @Probe.PreparePlan, @Probe.FetchDownload, @Probe.ExtractArchive,
        @Probe.ExtractNested),
      'expected failure');
    Check('manifest exception reports helper failure',
      ErrBuf.Contains('InstallFromManifest failed: fetch boom'),
      'exception message missing');
  finally
    CleanupPlanDirs(Probe.Plan);
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Manifest Flow Tests ===');
  GTempRoot := CreateUniqueTempDir('test_manifestflow_root');
  try
    TestManifestFlowSuccessAndCleanup;
    TestManifestLoadFailureShowsGuidance;
    TestManifestGenericPrepareError;
    TestManifestDownloadFailure;
    TestManifestOuterExtractFailureCleansUp;
    TestManifestExceptionPath;
  finally
    CleanupTempDir(GTempRoot);
  end;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
