unit fpdev.lazarus.installcallbacks;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.git.types,
  fpdev.lazarus.commandflow;

type
  ILazarusInstallGitClient = interface(ILazarusGitRuntime)
    ['{0A068E2B-6D30-4497-8C43-8EE286AC557F}']
    function GetBackend: TGitBackend;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    property Backend: TGitBackend read GetBackend;
  end;

  TLazarusInstallGitClientFactory = function(
    const ACliOnly: Boolean
  ): ILazarusInstallGitClient of object;
  TLazarusInstallStateChecker = function(const AVersion: string): Boolean of object;
  TLazarusInstallPathResolver = function(const AVersion: string): string of object;
  TLazarusCompatibleFPCVersionResolver = function(
    const AVersion: string
  ): string of object;

function DownloadLazarusSourceCore(
  const AVersion, ATargetDir: string;
  ACreateGitClient: TLazarusInstallGitClientFactory
): Boolean;

function BuildLazarusFromSourceCore(
  const AConfigManager: IConfigManager;
  const ASourceDir, AInstallDir, AFPCVersion: string
): Boolean;

function SetupLazarusEnvironmentCore(
  const AConfigManager: IConfigManager;
  const AVersion: string;
  AIsVersionInstalled: TLazarusInstallStateChecker;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveCompatibleFPCVersion: TLazarusCompatibleFPCVersionResolver
): Boolean;

implementation

uses
  fpdev.build.toolchain,
  fpdev.constants,
  fpdev.output.console,
  fpdev.output.intf,
  fpdev.utils.fs,
  fpdev.utils.process,
  fpdev.version.registry;

function DownloadLazarusSourceCore(
  const AVersion, ATargetDir: string;
  ACreateGitClient: TLazarusInstallGitClientFactory
): Boolean;
var
  Git: ILazarusInstallGitClient;
  GitTag: string;
  RepositoryURL: string;
begin
  Result := False;
  if not Assigned(ACreateGitClient) then
    Exit;

  GitTag := TVersionRegistry.Instance.GetLazarusGitTag(AVersion);
  RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;

  if GitTag = '' then
    Exit;

  if RepositoryURL = '' then
    RepositoryURL := LAZARUS_OFFICIAL_REPO;

  Git := ACreateGitClient(False);
  if (Git = nil) or (Git.Backend = gbNone) then
    Exit;

  if not DirectoryExists(ExtractFileDir(ATargetDir)) then
    EnsureDir(ExtractFileDir(ATargetDir));

  if DirectoryExists(ATargetDir) then
  begin
    if DirectoryExists(ATargetDir + PathDelim + '.git') then
    begin
      if not Git.Fetch(ATargetDir, 'origin') then
        Exit(False);
      Result := Git.Checkout(ATargetDir, GitTag, True);
    end
    else
    begin
      DeleteDirRecursive(ATargetDir);
      Result := Git.Clone(RepositoryURL, ATargetDir, GitTag);
    end;
  end
  else
    Result := Git.Clone(RepositoryURL, ATargetDir, GitTag);
end;

function BuildLazarusFromSourceCore(
  const AConfigManager: IConfigManager;
  const ASourceDir, AInstallDir, AFPCVersion: string
): Boolean;
var
  LResult: TProcessResult;
  MakeCmd: string;
  Settings: TFPDevSettings;
  ToolchainChecker: TBuildToolchainChecker;
  BuildPlan: TLazarusBuildPlan;
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := False;

  if (AConfigManager = nil) or (not DirectoryExists(ASourceDir)) then
    Exit;

  try
    if not DirectoryExists(AInstallDir) then
      EnsureDir(AInstallDir);

    Settings := AConfigManager.GetSettingsManager.GetSettings;

    ToolchainChecker := TBuildToolchainChecker.Create(False);
    try
      MakeCmd := ToolchainChecker.ResolveMakeCmd;
    finally
      ToolchainChecker.Free;
    end;

    BuildPlan := CreateLazarusBuildPlanCore(
      ASourceDir,
      AInstallDir,
      Settings.InstallRoot,
      AFPCVersion,
      Settings.ParallelJobs,
      MakeCmd,
      GetEnvironmentVariable('PATH'),
      {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
    );

    LResult := TProcessExecutor.RunDirectWithEnv(
      BuildPlan.MakeCommand,
      BuildPlan.Params,
      BuildPlan.SourceDir,
      BuildPlan.EnvVars
    );

    Result := LResult.Success;
  except
    on E: Exception do
    begin
      LOut.WriteLn('BuildFromSource error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function SetupLazarusEnvironmentCore(
  const AConfigManager: IConfigManager;
  const AVersion: string;
  AIsVersionInstalled: TLazarusInstallStateChecker;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveCompatibleFPCVersion: TLazarusCompatibleFPCVersionResolver
): Boolean;
var
  LazarusInfo: TLazarusInfo;
  InstallPath: string;
  FPCVersion: string;
  RepositoryURL: string;
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := False;

  if (AConfigManager = nil) or
     (not Assigned(AIsVersionInstalled)) or
     (not Assigned(AResolveInstallPath)) or
     (not Assigned(AResolveCompatibleFPCVersion)) then
    Exit;

  if not AIsVersionInstalled(AVersion) then
    Exit;

  try
    InstallPath := AResolveInstallPath(AVersion);
    FPCVersion := AResolveCompatibleFPCVersion(AVersion);
    RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;
    if RepositoryURL = '' then
      RepositoryURL := LAZARUS_OFFICIAL_REPO;

    LazarusInfo := Default(TLazarusInfo);
    LazarusInfo.Version := AVersion;
    LazarusInfo.FPCVersion := 'fpc-' + FPCVersion;
    LazarusInfo.InstallPath := InstallPath;
    LazarusInfo.SourceURL := RepositoryURL;
    LazarusInfo.Installed := True;

    Result := AConfigManager.GetLazarusManager.AddLazarusVersion(
      'lazarus-' + AVersion,
      LazarusInfo
    );
    if not Result then
      LOut.WriteLn('SetupEnvironment: failed to add version to config');
  except
    on E: Exception do
    begin
      LOut.WriteLn('SetupEnvironment error: ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
