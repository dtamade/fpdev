program test_fpc_installer_lifecycleflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config,
  fpdev.paths,
  fpdev.utils,
  fpdev.fpc.interfaces,
  fpdev.fpc.types,
  fpdev.fpc.installer.lifecycleflow,
  test_temp_paths;

type
  TInstallerLifecycleProbe = class
  public
    ValidateVersionResult: Boolean;
    InstallDirExistsResult: Boolean;
    SourceDirExistsResult: Boolean;
    DownloadResult: TOperationResult;
    BuildResult: TOperationResult;
    ProcessResult: TProcessResult;
    ValidateCalls: Integer;
    DownloadCalls: Integer;
    BuildCalls: Integer;
    ProcessCalls: Integer;
    LastValidatedVersion: string;
    LastDownloadVersion: string;
    LastDownloadTargetDir: string;
    LastBuildSourceDir: string;
    LastBuildInstallDir: string;
    LastProcessExecutable: string;
    LastProcessWorkDir: string;
    LastProcessParams: array of string;
    function ValidateVersion(const AVersion: string): Boolean;
    function DirectoryExists(const APath: string): Boolean;
    function DownloadSource(const AVersion, ATargetDir: string): TOperationResult;
    function BuildFromSource(const ASourceDir, AInstallDir: string): TOperationResult;
    function ExecuteProcess(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string): TProcessResult;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
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

function TInstallerLifecycleProbe.ValidateVersion(const AVersion: string): Boolean;
begin
  Inc(ValidateCalls);
  LastValidatedVersion := AVersion;
  Result := ValidateVersionResult;
end;

function TInstallerLifecycleProbe.DirectoryExists(const APath: string): Boolean;
begin
  if Pos(PathDelim + 'sources' + PathDelim, APath) > 0 then
    Result := SourceDirExistsResult
  else
    Result := InstallDirExistsResult;
end;

function TInstallerLifecycleProbe.DownloadSource(const AVersion,
  ATargetDir: string): TOperationResult;
begin
  Inc(DownloadCalls);
  LastDownloadVersion := AVersion;
  LastDownloadTargetDir := ATargetDir;
  Result := DownloadResult;
end;

function TInstallerLifecycleProbe.BuildFromSource(const ASourceDir,
  AInstallDir: string): TOperationResult;
begin
  Inc(BuildCalls);
  LastBuildSourceDir := ASourceDir;
  LastBuildInstallDir := AInstallDir;
  Result := BuildResult;
end;

function TInstallerLifecycleProbe.ExecuteProcess(const AExecutable: string;
  const AParams: array of string; const AWorkDir: string): TProcessResult;
var
  I: Integer;
begin
  Inc(ProcessCalls);
  LastProcessExecutable := AExecutable;
  LastProcessWorkDir := AWorkDir;
  SetLength(LastProcessParams, Length(AParams));
  for I := 0 to High(AParams) do
    LastProcessParams[I] := AParams[I];
  Result := ProcessResult;
end;

procedure TestResolveInstallRootUsesConfiguredRoot;
var
  Settings: TFPDevSettings;
begin
  FillChar(Settings, SizeOf(Settings), 0);
  Settings.InstallRoot := '/tmp/custom-root';

  Check(
    'installer lifecycle resolves configured install root',
    ResolveFPCInstallerInstallRootCore(Settings) = '/tmp/custom-root',
    ResolveFPCInstallerInstallRootCore(Settings)
  );
end;

procedure TestResolveInstallRootFallsBackToDataRoot;
var
  Settings: TFPDevSettings;
  ProbeRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
begin
  FillChar(Settings, SizeOf(Settings), 0);
  ProbeRoot := CreateUniqueTempDir('test_fpc_installer_lifecycle_root');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    set_env('FPDEV_DATA_ROOT', ProbeRoot);
    unset_env('XDG_DATA_HOME');
    SetPortableMode(False);

    Check(
      'installer lifecycle falls back to GetDataRoot when config root is empty',
      ResolveFPCInstallerInstallRootCore(Settings) = GetDataRoot,
      ResolveFPCInstallerInstallRootCore(Settings)
    );
  finally
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeRoot);
  end;
end;

procedure TestInstallCoreReturnsInvalidVersionError;
var
  Probe: TInstallerLifecycleProbe;
  State: TFPCInstallerInstallState;
  ResultInfo: TOperationResult;
begin
  Probe := TInstallerLifecycleProbe.Create;
  try
    Probe.ValidateVersionResult := False;
    State.Version := 'bad-version';
    State.InstallRoot := '/managed/root';
    State.FromSource := True;

    ResultInfo := ExecuteFPCInstallerInstallCore(
      State,
      @Probe.ValidateVersion,
      @Probe.DirectoryExists,
      @Probe.DownloadSource,
      @Probe.BuildFromSource
    );

    Check('installer lifecycle returns invalid version error',
      (not ResultInfo.Success) and (ResultInfo.ErrorCode = ecVersionInvalid),
      ResultInfo.ErrorMessage);
    Check('installer lifecycle validates requested version once',
      Probe.ValidateCalls = 1,
      IntToStr(Probe.ValidateCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestInstallCoreEnsureSucceedsWhenAlreadyInstalled;
var
  Probe: TInstallerLifecycleProbe;
  State: TFPCInstallerInstallState;
  ResultInfo: TOperationResult;
begin
  Probe := TInstallerLifecycleProbe.Create;
  try
    Probe.ValidateVersionResult := True;
    Probe.InstallDirExistsResult := True;
    State.Version := '3.2.2';
    State.InstallRoot := '/managed/root';
    State.Ensure := True;
    State.FromSource := True;

    ResultInfo := ExecuteFPCInstallerInstallCore(
      State,
      @Probe.ValidateVersion,
      @Probe.DirectoryExists,
      @Probe.DownloadSource,
      @Probe.BuildFromSource
    );

    Check('installer lifecycle ensure returns success for installed version',
      ResultInfo.Success and (ResultInfo.ErrorCode = ecNone),
      ResultInfo.ErrorMessage);
    Check('installer lifecycle ensure skips download when already installed',
      Probe.DownloadCalls = 0,
      IntToStr(Probe.DownloadCalls));
    Check('installer lifecycle ensure skips build when already installed',
      Probe.BuildCalls = 0,
      IntToStr(Probe.BuildCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestInstallCoreBinaryModeFallsBackToSourcePath;
var
  Probe: TInstallerLifecycleProbe;
  State: TFPCInstallerInstallState;
  ResultInfo: TOperationResult;
begin
  Probe := TInstallerLifecycleProbe.Create;
  try
    Probe.ValidateVersionResult := True;
    Probe.SourceDirExistsResult := False;
    Probe.DownloadResult := OperationSuccess;
    Probe.BuildResult := OperationSuccess;
    State.Version := '3.2.2';
    State.InstallRoot := '/managed/root';
    State.FromSource := False;

    ResultInfo := ExecuteFPCInstallerInstallCore(
      State,
      @Probe.ValidateVersion,
      @Probe.DirectoryExists,
      @Probe.DownloadSource,
      @Probe.BuildFromSource
    );

    Check('installer lifecycle preserves binary-mode fallback success',
      ResultInfo.Success,
      ResultInfo.ErrorMessage);
    Check('installer lifecycle uses source download during binary fallback',
      Probe.DownloadCalls = 1,
      IntToStr(Probe.DownloadCalls));
    Check('installer lifecycle uses source build during binary fallback',
      Probe.BuildCalls = 1,
      IntToStr(Probe.BuildCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestUninstallCoreBuildsPlatformRemoveCommand;
var
  Probe: TInstallerLifecycleProbe;
  ResultInfo: TOperationResult;
begin
  Probe := TInstallerLifecycleProbe.Create;
  try
    Probe.InstallDirExistsResult := True;
    Probe.ProcessResult.ExitCode := 0;
    Probe.ProcessResult.Success := True;

    ResultInfo := ExecuteFPCInstallerUninstallCore(
      '3.2.2',
      '/managed/root/fpc/3.2.2',
      @Probe.DirectoryExists,
      @Probe.ExecuteProcess
    );

    Check('installer lifecycle uninstall returns success when remove command succeeds',
      ResultInfo.Success,
      ResultInfo.ErrorMessage);
    {$IFDEF MSWINDOWS}
    Check('installer lifecycle uninstall uses cmd on windows',
      Probe.LastProcessExecutable = 'cmd',
      Probe.LastProcessExecutable);
    {$ELSE}
    Check('installer lifecycle uninstall uses rm on posix',
      Probe.LastProcessExecutable = 'rm',
      Probe.LastProcessExecutable);
    Check('installer lifecycle uninstall passes recursive remove args',
      (Length(Probe.LastProcessParams) = 2) and
      (Probe.LastProcessParams[0] = '-rf') and
      (Probe.LastProcessParams[1] = '/managed/root/fpc/3.2.2'),
      'arg-count=' + IntToStr(Length(Probe.LastProcessParams)));
    {$ENDIF}
  finally
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Lifecycleflow Tests ===');

  TestResolveInstallRootUsesConfiguredRoot;
  TestResolveInstallRootFallsBackToDataRoot;
  TestInstallCoreReturnsInvalidVersionError;
  TestInstallCoreEnsureSucceedsWhenAlreadyInstalled;
  TestInstallCoreBinaryModeFallsBackToSourcePath;
  TestUninstallCoreBuildsPlatformRemoveCommand;

  WriteLn;
  WriteLn('Pass: ', PassCount);
  WriteLn('Fail: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
