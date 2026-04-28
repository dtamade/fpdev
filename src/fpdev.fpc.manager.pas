unit fpdev.fpc.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.fpc.manager

FPC version management service


## Notice

If you redistribute or use this in your own project, please keep this project's copyright notice. Thanks.

fafafaStudio
Email:dtamade@gmail.com
QQ group: 685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.fpc.source,
  fpdev.types, fpdev.fpc.types, fpdev.fpc.metadata, fpdev.resource.repo, fpdev.utils.fs, fpdev.utils.process,
  fpdev.git.runtime, fpdev.i18n, fpdev.i18n.strings,
  fpdev.fpc.activation, fpdev.fpc.validator, fpdev.fpc.version, fpdev.fpc.installer,
  fpdev.fpc.installsurfaceflow,
  fpdev.fpc.maintenanceflow,
  fpdev.fpc.residualflow,
  fpdev.fpc.runtimeflow,
  fpdev.fpc.builder,
  fpdev.build.cache, fpdev.paths;

type
  { TFPCManager }
  TFPCManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;  // Resource repository manager
    FActivationMgr: TFPCActivationManager;  // Activation service (Facade delegation)
    FValidatorMgr: TFPCValidator;  // Validation service (Facade delegation)
    FVersionMgr: TFPCVersionManager;  // Version service (Facade delegation)
    FInstallerMgr: TFPCBinaryInstaller;  // Binary installation service (Facade delegation)
    FBuilderMgr: TFPCSourceBuilder;  // Source build service (Facade delegation)
    FBuildCache: TBuildCache;  // Build artifact cache for fast version switching

    FOut: IOutput;
    FErr: IOutput;

    function DownloadSource(const AVersion, ATargetDir: string): Boolean;
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function SourceDirExists(const APath: string): Boolean;
    function CleanSourceArtifacts(const ASourceDir: string): Integer;
    function LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
    function TryReadStatusMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
    function TrySetDefaultVersionSilently(const AVersion: string): Boolean;
    function ActivateVersionWithBinPath(const AVersion, ABinPath: string): TActivationResult;
    function ExecuteInstalledFPCInfo(const AExecutable: string): TProcessResult;
    procedure EnsureManagedCompilerLayout(const AVersion, AInstallPath: string);
    function ResolveMetadataScope(const AVersion, AInstallPath: string): TInstallScope;
    function InferStatusScope(const AVersion, AInstallPath: string): TFPCStatusScope;
    function WriteInstallMetadata(const AVersion, AInstallPath: string;
      AFromSource: Boolean): Boolean;
    function UpdateVerificationMetadata(const AVersion, AInstallPath: string;
      const AVerifResult: TVerificationResult): Boolean;
    function RefreshInstallVerificationMetadata(const AVersion,
      AInstallPath: string): Boolean;
    procedure ConfigureInstaller(ANoCache, AOfflineMode: Boolean);
    procedure DeleteManagedPath(const APath: string);
    procedure RemoveToolchainFromConfig(const AName: string);
    function CreateGitRuntime: IFPCGitRuntime;

    // Bootstrap compiler management (delegated to FBuilderMgr)
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetCurrentFPCVersion: string;
    function GetBootstrapCompilerPath(const AVersion: string): string;
    function IsBootstrapAvailable(const AVersion: string): Boolean;
    function EnsureBootstrapWithBuilder(const ATargetVersion: string): Boolean;
    function InstallBinaryBootstrapFallback(const ATargetVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
    function VerifyInstalledExecutableVersion(const AFPCExe, AVersion: string;
      out AError: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager; const AOut: IOutput = nil; const AErr: IOutput = nil);
    destructor Destroy; override;

    // Version management
    function GetAvailableVersions: TFPCVersionArray;
    function GetInstalledVersions: TFPCVersionArray;
    function InstallVersion(
      const AVersion: string;
      const AFromSource: Boolean = False;
      const APrefix: string = '';
      const AEnsure: Boolean = False;
      const ANoCache: Boolean = False;
      const AOfflineMode: Boolean = False
    ): Boolean;
    function UninstallVersion(const AVersion: string): Boolean;
    function ListVersions(const AShowAll: Boolean = False): Boolean; overload;
    function ListVersions(const Outp: IOutput; const AShowAll: Boolean = False): Boolean; overload;
    function SetDefaultVersion(const AVersion: string): Boolean; overload;
    function SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function GetCurrentVersion: string;
    function ActivateVersion(const AVersion: string): TActivationResult;

    // Binary installation
    function GetBinaryDownloadURL(const AVersion: string): string;
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
    function GetBinaryDownloadURLLegacy(const AVersion: string): string;
    function DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
    function VerifyChecksum(const AFilePath, AVersion: string): Boolean;
    function AddToolchainToConfig(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
    function InstallFromBinary(const AVersion: string; const APrefix: string = ''): Boolean;

    // Source management
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // Toolchain operations
    function ShowVersionInfo(const AVersion: string): Boolean; overload;
    function ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean; overload;
    function TestInstallation(const AVersion: string): Boolean; overload;
    function TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;
    function GetStatus(out AStatus: TFPCStatusInfo; out AError: string): Boolean;

    // Metadata operations (public for testing)
    function WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
    function ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;

    // Environment setup (public for cache restore)
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
  end;

// Export index update procedure for subcommands to call
procedure FPC_UpdateIndex(const AConfigPath: string = '');

implementation

uses
  fpdev.output.console, fpdev.version.registry, fpdev.fpc.installer.config,
  fpdev.fpc.metadataflow, fpdev.fpc.utils,
  fpdev.fpc.verifyflow, fpdev.fpc.statusflow, fpdev.fpc.versionflow,
  fpdev.fpc.bootstrapflow,
  fpdev.fpc.indexflow;

type
  TFPCGitRuntimeAdapter = class(TInterfacedObject, IFPCGitRuntime)
  private
    FGit: IGitRuntime;
  public
    constructor Create(const AGit: IGitRuntime = nil);
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

constructor TFPCGitRuntimeAdapter.Create(const AGit: IGitRuntime);
begin
  inherited Create;
  if AGit <> nil then
    FGit := AGit
  else
    FGit := NewGitRuntime;
end;

function TFPCGitRuntimeAdapter.BackendAvailable: Boolean;
begin
  Result := (FGit <> nil) and FGit.BackendAvailable;
end;

function TFPCGitRuntimeAdapter.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TFPCGitRuntimeAdapter.HasRemote(const APath: string): Boolean;
begin
  Result := FGit.HasRemote(APath);
end;

function TFPCGitRuntimeAdapter.Pull(const APath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(APath);
end;

function TFPCGitRuntimeAdapter.GetLastError: string;
begin
  Result := FGit.LastError;
end;

// --- FPC command helpers (no inline vars) ----------------------------------

procedure FPC_UpdateIndex(const AConfigPath: string);
begin
  ExecuteFPCUpdateIndexCore(AConfigPath);
end;


{ TFPCManager }

constructor TFPCManager.Create(AConfigManager: IConfigManager; const AOut: IOutput; const AErr: IOutput);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;  // Lazy initialization

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := ExcludeTrailingPathDelimiter(Trim(Settings.InstallRoot));

  // Ensure InstallRoot is resolved before creating sub-services that snapshot it.
  if FInstallRoot = '' then
  begin
    FInstallRoot := ExcludeTrailingPathDelimiter(GetDataRoot);
    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  // Ensure the install directory exists
  if not DirectoryExists(FInstallRoot) then
    EnsureDir(FInstallRoot);

  // Initialize build cache
  FBuildCache := TBuildCache.Create(BuildBuildCacheDirFromInstallRoot(FInstallRoot));

  // Create facade services (after InstallRoot is resolved)
  FActivationMgr := TFPCActivationManager.Create(AConfigManager);  // Activation service
  FValidatorMgr := TFPCValidator.Create(AConfigManager);  // Validation service
  FVersionMgr := TFPCVersionManager.Create(AConfigManager);  // Version service
  FInstallerMgr := TFPCBinaryInstaller.Create(AConfigManager, FOut, FErr);  // Installer service
  FBuilderMgr := TFPCSourceBuilder.Create(AConfigManager, FOut, FErr);  // Builder service

  // Pass cache instance to installer for binary caching
  FInstallerMgr.SetCache(FBuildCache);
end;

destructor TFPCManager.Destroy;
begin
  if Assigned(FBuildCache) then
    FBuildCache.Free;
  if Assigned(FBuilderMgr) then
    FBuilderMgr.Free;
  if Assigned(FInstallerMgr) then
    FInstallerMgr.Free;
  if Assigned(FVersionMgr) then
    FVersionMgr.Free;
  if Assigned(FValidatorMgr) then
    FValidatorMgr.Free;
  if Assigned(FActivationMgr) then
    FActivationMgr.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TFPCManager.WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
begin
  Result := WriteFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': WriteMetadata failed');
end;

function TFPCManager.ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
begin
  Result := ReadFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': ReadMetadata failed');
end;

function TFPCManager.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := FVersionMgr.GetVersionInstallPath(AVersion);
end;

function TFPCManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := FVersionMgr.IsVersionInstalled(AVersion);
end;

function TFPCManager.ValidateVersion(const AVersion: string): Boolean;
begin
  // Delegate to version manager service
  Result := FVersionMgr.ValidateVersion(AVersion);
end;

function TFPCManager.GetAvailableVersions: TFPCVersionArray;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetAvailableVersions;
end;

function TFPCManager.GetInstalledVersions: TFPCVersionArray;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetInstalledVersions;
end;

function TFPCManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.DownloadSource(AVersion, ATargetDir);
end;

{ Bootstrap Compiler Management }

function TFPCManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetRequiredBootstrapVersion(ATargetVersion);
end;

function TFPCManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
begin
  Result := ExecuteManagedFPCBootstrapEnsureCore(
    ATargetVersion,
    FOut,
    @EnsureBootstrapWithBuilder,
    @InstallBinaryBootstrapFallback
  );
end;

function TFPCManager.EnsureBootstrapWithBuilder(const ATargetVersion: string): Boolean;
begin
  Result := Assigned(FBuilderMgr) and FBuilderMgr.EnsureBootstrapCompiler(ATargetVersion);
end;

function TFPCManager.InstallBinaryBootstrapFallback(
  const ATargetVersion: string): Boolean;
begin
  Result := Assigned(FInstallerMgr) and FInstallerMgr.InstallFromBinary(ATargetVersion);
end;

function TFPCManager.GetCurrentFPCVersion: string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetCurrentFPCVersion;
end;

function TFPCManager.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetBootstrapCompilerPath(AVersion);
end;

function TFPCManager.IsBootstrapAvailable(const AVersion: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.IsBootstrapAvailable(AVersion);
end;

function TFPCManager.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.BuildFromSource(ASourceDir, AInstallDir);
end;

function TFPCManager.SourceDirExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

function TFPCManager.CleanSourceArtifacts(const ASourceDir: string): Integer;
begin
  Result := CleanBuildArtifacts(ASourceDir, nil, True);
end;

function TFPCManager.LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.GetToolchain('fpc-' + AVersion, AInfo);
end;

function TFPCManager.TryReadStatusMetadata(const AInstallPath: string;
  out AMeta: TFPDevMetadata): Boolean;
begin
  Result := ReadFPCMetadata(AInstallPath, AMeta);
end;

function TFPCManager.TrySetDefaultVersionSilently(const AVersion: string): Boolean;
begin
  Result := FVersionMgr.SetDefaultVersion(AVersion);
end;

function TFPCManager.ActivateVersionWithBinPath(const AVersion,
  ABinPath: string): TActivationResult;
var
  ActivationResult: fpdev.fpc.activation.TActivationResult;
begin
  ActivationResult := FActivationMgr.ActivateVersion(AVersion, ABinPath);
  Result := Default(TActivationResult);
  Result.Success := ActivationResult.Success;
  Result.Scope := ActivationResult.Scope;
  Result.ActivationScript := ActivationResult.ActivationScript;
  Result.VSCodeSettings := ActivationResult.VSCodeSettings;
  Result.ShellCommand := ActivationResult.ShellCommand;
  Result.ErrorMessage := ActivationResult.ErrorMessage;
end;

function TFPCManager.ExecuteInstalledFPCInfo(const AExecutable: string): TProcessResult;
begin
  Result := TProcessExecutor.Execute(AExecutable, ['-i'], '');
end;

function TFPCManager.VerifyInstalledExecutableVersion(const AFPCExe, AVersion: string;
  out AError: string): Boolean;
begin
  Result := VerifyInstalledExecutableVersionCore(AFPCExe, AVersion, AError);
end;

procedure TFPCManager.EnsureManagedCompilerLayout(const AVersion, AInstallPath: string);
begin
  EnsureManagedFPCInstallLayout(AInstallPath, AVersion, FOut);
end;

function TFPCManager.ResolveMetadataScope(const AVersion, AInstallPath: string): TInstallScope;
begin
  Result := ResolveFPCMetadataScopeCore(
    AInstallPath,
    GetVersionInstallPath(AVersion),
    FActivationMgr.DetectInstallScope(GetCurrentDir)
  );
end;

function TFPCManager.InferStatusScope(const AVersion, AInstallPath: string): TFPCStatusScope;
begin
  Result := InferFPCStatusScopeCore(
    AVersion,
    AInstallPath,
    fpdev.fpc.utils.FindProjectRoot(GetCurrentDir),
    FInstallRoot
  );
end;

function TFPCManager.WriteInstallMetadata(const AVersion, AInstallPath: string;
  AFromSource: Boolean): Boolean;
begin
  Result := ExecuteManagedFPCWriteInstallMetadataCore(
    AVersion,
    AInstallPath,
    AFromSource,
    FErr,
    @ResolveMetadataScope
  );
end;

function TFPCManager.UpdateVerificationMetadata(const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult): Boolean;
begin
  Result := ExecuteManagedFPCUpdateVerificationMetadataCore(
    AVersion,
    AInstallPath,
    AVerifResult,
    FErr,
    @ResolveMetadataScope
  );
end;

function TFPCManager.RefreshInstallVerificationMetadata(const AVersion,
  AInstallPath: string): Boolean;
begin
  Result := ExecuteManagedFPCRefreshVerificationMetadataCore(
    AVersion,
    AInstallPath,
    FErr,
    @UpdateVerificationMetadata
  );
end;

procedure TFPCManager.ConfigureInstaller(ANoCache, AOfflineMode: Boolean);
begin
  if Assigned(FInstallerMgr) then
  begin
    FInstallerMgr.SetNoCache(ANoCache);
    FInstallerMgr.SetOfflineMode(AOfflineMode);
  end;
end;

procedure TFPCManager.DeleteManagedPath(const APath: string);
begin
  DeleteDirRecursive(APath);
end;

procedure TFPCManager.RemoveToolchainFromConfig(const AName: string);
begin
  FConfigManager.GetToolchainManager.RemoveToolchain(AName);
end;

function TFPCManager.CreateGitRuntime: IFPCGitRuntime;
begin
  Result := TFPCGitRuntimeAdapter.Create;
end;

function TFPCManager.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
begin
  Result := ExecuteManagedFPCSetupEnvironmentCore(
    AVersion,
    AInstallPath,
    FOut,
    FErr,
    @GetVersionInstallPath,
    @AddToolchainToConfig
  );
end;

function TFPCManager.AddToolchainToConfig(const AName: string; const AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.AddToolchain(AName, AInfo);
end;

function TFPCManager.InstallVersion(
  const AVersion: string;
  const AFromSource: Boolean;
  const APrefix: string;
  const AEnsure: Boolean;
  const ANoCache: Boolean;
  const AOfflineMode: Boolean
): Boolean;
var
  State: TFPCInstallSurfaceState;
  Callbacks: TFPCInstallSurfaceCallbacks;
begin
  Result := False;

  try
    State := Default(TFPCInstallSurfaceState);
    State.Version := AVersion;
    State.InstallRoot := FInstallRoot;
    State.Prefix := APrefix;
    State.FromSource := AFromSource;
    State.Ensure := AEnsure;
    State.NoCache := ANoCache;
    State.OfflineMode := AOfflineMode;

    Callbacks := Default(TFPCInstallSurfaceCallbacks);
    Callbacks.ValidateVersion := @ValidateVersion;
    Callbacks.GetVersionInstallPath := @GetVersionInstallPath;
    Callbacks.IsVersionInstalled := @IsVersionInstalled;
    Callbacks.ConfigureInstaller := @ConfigureInstaller;
    Callbacks.RefreshInstallVerificationMetadata := @RefreshInstallVerificationMetadata;
    Callbacks.VerifyInstalledExecutable := @VerifyInstalledExecutableVersion;
    Callbacks.DownloadSource := @DownloadSource;
    Callbacks.EnsureBootstrap := @EnsureBootstrapCompiler;
    Callbacks.BuildFromSource := @BuildFromSource;
    Callbacks.WriteMetadata := @WriteInstallMetadata;
    Callbacks.SetupEnvironment := @SetupEnvironment;
    Callbacks.InstallBinary := @InstallFromBinary;

    if Assigned(FBuildCache) then
    begin
      Callbacks.HasCachedArtifacts := @FBuildCache.HasArtifacts;
      Callbacks.RestoreCachedArtifacts := @FBuildCache.RestoreArtifacts;
      Callbacks.SaveBuildArtifacts := @FBuildCache.SaveArtifacts;
    end;

    Result := ExecuteManagedFPCInstallSurfaceCore(
      State,
      FOut,
      FErr,
      Callbacks
    );
  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallVersion failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.UninstallVersion(const AVersion: string): Boolean;
begin
  Result := False;

  try
    Result := ExecuteManagedFPCUninstallCore(
      AVersion,
      @IsVersionInstalled,
      @GetVersionInstallPath,
      @DeleteManagedPath,
      @RemoveToolchainFromConfig
    );

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': UninstallVersion failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.ListVersions(const AShowAll: Boolean): Boolean;
begin
  Result := ListVersions(nil, AShowAll);
end;

function TFPCManager.ListVersions(const Outp: IOutput; const AShowAll: Boolean): Boolean;
var
  Versions: fpdev.fpc.types.TFPCVersionArray;
  TargetOut: IOutput;
begin
  Result := True;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;

    if Outp <> nil then
      TargetOut := Outp
    else
      TargetOut := FOut;

    Result := WriteManagedFPCVersionListCore(
      Versions,
      FConfigManager.GetToolchainManager.GetDefaultToolchain,
      AShowAll,
      TargetOut
    );

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := SetDefaultVersion(nil, nil, AVersion);
end;

function TFPCManager.SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  try
    Result := SetManagedFPCDefaultVersionCore(
      AVersion,
      Outp,
      Errp,
      @IsVersionInstalled,
      @TrySetDefaultVersionSilently
    );
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.GetCurrentVersion: string;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetCurrentVersion;
end;

function TFPCManager.GetStatus(out AStatus: TFPCStatusInfo; out AError: string): Boolean;
var
  Version: string;
  DefaultInstallPath: string;
begin
  Version := GetCurrentVersion;
  DefaultInstallPath := '';
  if Version <> '' then
    DefaultInstallPath := GetVersionInstallPath(Version);

  Result := BuildManagedFPCStatusCore(
    Version,
    DefaultInstallPath,
    @LookupToolchainInfo,
    @TryReadStatusMetadata,
    @InferStatusScope,
    AStatus,
    AError
  );
end;

function TFPCManager.ActivateVersion(const AVersion: string): TActivationResult;
begin
  Result := ActivateManagedFPCVersionCore(
    AVersion,
    @IsVersionInstalled,
    @GetVersionInstallPath,
    @ActivateVersionWithBinPath,
    @TrySetDefaultVersionSilently
  );
end;

function TFPCManager.UpdateSources(const AVersion: string): Boolean;
begin
  Result := ExecuteManagedFPCUpdateSourcesCore(
    AVersion,
    FInstallRoot,
    FOut,
    FErr,
    @GetCurrentVersion,
    @SourceDirExists,
    @CreateGitRuntime
  );
end;

function TFPCManager.CleanSources(const AVersion: string): Boolean;
begin
  Result := ExecuteManagedFPCCleanSourcesCore(
    AVersion,
    FInstallRoot,
    FOut,
    FErr,
    @GetCurrentVersion,
    @SourceDirExists,
    @CleanSourceArtifacts
  );
end;

function TFPCManager.ShowVersionInfo(const AVersion: string): Boolean;
begin
  Result := ShowVersionInfo(nil, AVersion);
end;

function TFPCManager.ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean;
var
  InfoOut: IOutput;
  ErrorOut: IOutput;
begin
  if Outp <> nil then
  begin
    InfoOut := Outp;
    ErrorOut := Outp;
  end
  else
  begin
    InfoOut := FOut;
    ErrorOut := FErr;
  end;

  Result := ExecuteFPCShowVersionInfoCore(
    AVersion, InfoOut, ErrorOut,
    @ValidateVersion, @IsVersionInstalled, @GetVersionInstallPath, @LookupToolchainInfo
  );
end;

function TFPCManager.TestInstallation(const AVersion: string): Boolean;
begin
  Result := TestInstallation(nil, nil, AVersion);
end;

function TFPCManager.TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Result := ExecuteFPCTestInstallationCore(
    AVersion, Outp, Errp, @IsVersionInstalled, @GetVersionInstallPath, @ExecuteInstalledFPCInfo
  );
end;

function TFPCManager.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
begin
  Result := ExecuteManagedFPCVerificationSurfaceCore(
    AVersion,
    GetVersionInstallPath(AVersion),
    @FValidatorMgr.VerifyInstallation,
    @UpdateVerificationMetadata,
    VerifResult
  );
end;

// ============================================================================
// Binary Installation Methods - Delegated to FInstallerMgr
// ============================================================================

function TFPCManager.GetBinaryDownloadURL(const AVersion: string): string;
begin
  Result := FInstallerMgr.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCManager.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstallerMgr.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCManager.GetBinaryDownloadURLLegacy(const AVersion: string): string;
begin
  Result := FInstallerMgr.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCManager.DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstallerMgr.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCManager.VerifyChecksum(const AFilePath, AVersion: string): Boolean;
begin
  Result := FInstallerMgr.VerifyChecksum(AFilePath, AVersion);
end;

function TFPCManager.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
begin
  Result := FInstallerMgr.ExtractArchive(AArchivePath, ADestPath);
end;

function TFPCManager.InstallFromBinary(const AVersion: string; const APrefix: string): Boolean;
begin
  Result := FInstallerMgr.InstallFromBinary(AVersion, APrefix);
end;

end.
