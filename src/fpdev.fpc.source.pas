unit fpdev.fpc.source;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

interface

uses
  SysUtils, Classes, fpdev.source.repo, fpdev.build.manager, fpdev.constants,
  fpdev.fpc.bootstrap, fpdev.utils.process;

type
  // FPCUpDeluxe-inspired build steps
  TFPCBuildStep = (
    bsInit,           // Initialize environment
    bsBootstrap,      // Ensure bootstrap compiler
    bsClone,          // Clone source code
    bsCompiler,       // Build compiler
    bsRTL,            // Build RTL
    bsPackages,       // Build packages
    bsInstall,        // Install binaries
    bsConfig,         // Configure environment
    bsFinished        // Finished
  );

  { TFPCSourceManager }
  TFPCSourceManager = class
  private
    FSourceRoot: string;
    FCurrentVersion: string;
    FBootstrapCompiler: string;
    FCurrentStep: TFPCBuildStep;
    FParallelJobs: Integer;
    FUseCache: Boolean;
    FVerboseOutput: Boolean;
    FBootstrap: TBootstrapManager;  // Bootstrap helper

    function GetSourcePath(const AVersion: string): string;
    function GetSandboxRoot: string;
    function GetVersionFromBranch(const ABranch: string): string;
    function CreateBuildManager(const AAllowInstall: Boolean): TBuildManager;
    function ExecuteCommand(
      const AProgram: string;
      const AArgs: array of string;
      const AWorkingDir: string = ''
    ): Boolean;
    procedure SetCurrentStepValue(AStep: Integer);
    function ReportBuildStepValue(AStep: Integer; const AMessage: string): Boolean;
    procedure WriteStatus(const AText: string);
    function GetRegisteredFPCVersionNames: TStringArray;
    function IsValidSourceDirectory(const APath: string): Boolean;
    function ExecuteBuildSourceCommand(const ASourcePath: string): Boolean;
    function DispatchBuildManagerAction(
      ABuildManager: TBuildManager;
      AAction: Integer;
      const AVersion: string
    ): Boolean;
    function BuildCompilerWithManager(const AVersion: string): Boolean;
    function BuildRTLWithManager(const AVersion: string): Boolean;
    function BuildPackagesWithManager(const AVersion: string): Boolean;
    function InstallBinariesWithManager(const AVersion: string): Boolean;
    function ConfigureEnvironmentWithManager(const AVersion: string): Boolean;
    function TestBuildResultsWithManager(const AVersion: string): Boolean;
    function WriteCacheMarker(const AVersion: string): Boolean;

    // Bootstrap compiler management - private helpers
    function DownloadBootstrapCompilerInternal(const AVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    // Step-by-step build process (FPCUpDeluxe-inspired)
    function InitializeInstall(const {%H-} AVersion: string): Boolean;
    function BuildFPCCompiler(const AVersion: string): Boolean;
    function BuildFPCRTL(const AVersion: string): Boolean;
    function BuildFPCPackages(const AVersion: string): Boolean;
    function InstallFPCBinaries(const AVersion: string): Boolean;
    function ConfigureFPCEnvironment(const AVersion: string): Boolean;
    function TestBuildResults(const AVersion: string): Boolean;
    function ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;

    // Performance optimization methods
    function GetOptimalJobCount: Integer;
    function IsCacheAvailable(const AVersion: string): Boolean;
    function UseCachedBuild(const AVersion: string): Boolean;
    function OptimizeBuildCommand(const ABaseCommand: string): string;
    function CheckBuildPrerequisites(const {%H-} AVersion: string): Boolean;

  protected
    function ProtectedIsCacheAvailable(const AVersion: string): Boolean;
    function ProtectedUseCachedBuild(const AVersion: string): Boolean;
    function ProtectedIsValidSourceDirectory(const APath: string): Boolean;
    function ProtectedGetVersionFromBranch(const ABranch: string): string;
    function ProtectedBuildFPCCompiler(const AVersion: string): Boolean;
    function ProtectedBuildFPCRTL(const AVersion: string): Boolean;
    function ProtectedBuildFPCPackages(const AVersion: string): Boolean;

  public
    constructor Create(const ASourceRoot: string = '');
    destructor Destroy; override;

    // Source management
    function CloneFPCSource(const AVersion: string = 'main'): Boolean;
    function UpdateFPCSource(const AVersion: string = ''): Boolean;
    function SwitchFPCVersion(const AVersion: string): Boolean;
    // Separation of concerns: repository manager
    function Repo: TSourceRepoManager;
    function BuildFPCSource(const AVersion: string = ''): Boolean;
    function InstallFPCVersion(const AVersion: string): Boolean;
    function ListAvailableVersions: TStringArray;
    function ListLocalVersions: TStringArray;

    // Version information
    function GetCurrentVersion: string;
    function IsVersionAvailable(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;

    // Path management
    function GetFPCSourcePath(const AVersion: string = ''): string;
    function GetFPCBuildPath(const AVersion: string = ''): string;

    // Bootstrap compiler management (FPCUpDeluxe-inspired) - for testing
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetBootstrapPath(const AVersion: string): string;
    { DEPRECATED: Use fpdev-repo for bootstrap compilers instead }
    function GetBootstrapDownloadURL(const AVersion: string): string; deprecated 'Use fpdev-repo instead';
    function DownloadBootstrapCompiler(const AVersion: string): Boolean; deprecated 'Use fpdev-repo instead';

    // Properties
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property CurrentVersion: string read GetCurrentVersion;
  end;

const
  // FPC Git repository information - using central constants
  FPC_GIT_URL = FPC_OFFICIAL_REPO;

  // Supported FPC version branches
  FPC_VERSIONS: array[0..6] of record
    Version: string;
    Branch: string;
    Description: string;
  end = (
    (Version: 'main'; Branch: 'main'; Description: 'Development version (unstable)'),
    (Version: '3.2.2'; Branch: 'fixes_3_2'; Description: 'FPC 3.2.2 (stable)'),
    (Version: '3.2.0'; Branch: 'fixes_3_2'; Description: 'FPC 3.2.0 (stable)'),
    (Version: '3.0.4'; Branch: 'release_3_0_4'; Description: 'FPC 3.0.4 (legacy)'),
    (Version: '3.0.2'; Branch: 'release_3_0_2'; Description: 'FPC 3.0.2 (legacy)'),
    (Version: '2.6.4'; Branch: 'release_2_6_4'; Description: 'FPC 2.6.4 (legacy)'),
    (Version: '2.6.2'; Branch: 'release_2_6_2'; Description: 'FPC 2.6.2 (legacy)')
  );

implementation

uses
  fpdev.fpc.types, fpdev.utils.fs, fpdev.version.registry,
  fpdev.fpc.sourceflow,
  fpdev.fpc.sourceinstallflow, fpdev.fpc.sourcebootstrapflow,
  fpdev.fpc.sourcebuildflow, fpdev.fpc.sourcemanagerflow;

function FindStaticFPCVersionIndex(const AVersion: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Version, AVersion) then
      Exit(i);
  end;
end;

function FindStaticFPCBranchIndex(const ABranch: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Branch, ABranch) then
      Exit(i);
  end;
end;

function ResolveStaticFPCVersionFromRef(const ARef: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(FPC_RELEASES) do
  begin
    if SameText(FPC_RELEASES[i].GitTag, ARef) or SameText(FPC_RELEASES[i].Branch, ARef) then
      Exit(FPC_RELEASES[i].Version);
  end;
end;

function RegistryHasFPCReleases(const AReleases: TFPCReleaseArray): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AReleases) do
  begin
    if Trim(AReleases[i].Version) <> '' then
      Exit(True);
  end;
end;

{ TFPCSourceManager }

constructor TFPCSourceManager.Create(const ASourceRoot: string);
begin
  inherited Create;

  if ASourceRoot <> '' then
    FSourceRoot := ASourceRoot
  else
    FSourceRoot := 'sources' + PathDelim + 'fpc';

  FCurrentVersion := '';

  // Performance optimization initialization
  FParallelJobs := GetOptimalJobCount;
  FUseCache := True;
  FVerboseOutput := False;

  // Initialize bootstrap helper
  FBootstrap := TBootstrapManager.Create(FSourceRoot);

  // Ensure source root directory exists
  if not DirectoryExists(FSourceRoot) then
    EnsureDir(FSourceRoot);
end;

function TFPCSourceManager.Repo: TSourceRepoManager;
begin
  // Simple factory: return a lightweight object each time, avoiding persistent fields
  Result := TSourceRepoManager.Create(FSourceRoot);
end;

destructor TFPCSourceManager.Destroy;
begin
  if Assigned(FBootstrap) then
    FBootstrap.Free;
  inherited Destroy;
end;

function TFPCSourceManager.GetSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  if AVersion = '' then
    Version := 'main'
  else
    Version := AVersion;

  Result := FSourceRoot + PathDelim + 'fpc-' + Version;
end;

function TFPCSourceManager.GetSandboxRoot: string;
begin
  Result := FSourceRoot + PathDelim + 'sandbox';
end;

function TFPCSourceManager.GetVersionFromBranch(const ABranch: string): string;
var
  Releases: TFPCReleaseArray;
  i: Integer;
begin
  Result := ABranch;

  Releases := TVersionRegistry.Instance.GetFPCReleases;
  for i := 0 to High(Releases) do
  begin
    if SameText(Releases[i].GitTag, ABranch) or SameText(Releases[i].Branch, ABranch) then
      Exit(Releases[i].Version);
  end;

  if not RegistryHasFPCReleases(Releases) then
  begin
    Result := ResolveStaticFPCVersionFromRef(ABranch);
    if Result <> '' then
      Exit;
  end;

  Result := ABranch;
end;

function TFPCSourceManager.CreateBuildManager(
  const AAllowInstall: Boolean
): TBuildManager;
begin
  Result := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  Result.SetSandboxRoot(GetSandboxRoot);
  Result.SetAllowInstall(AAllowInstall);
end;

function TFPCSourceManager.ExecuteCommand(
  const AProgram: string;
  const AArgs: array of string;
  const AWorkingDir: string
): Boolean;
var
  CommandResult: TProcessResult;
  ExecutablePath: string;
begin
  ExecutablePath := TProcessExecutor.FindExecutable(AProgram);
  if ExecutablePath = '' then
    ExecutablePath := AProgram;

  CommandResult := TProcessExecutor.RunDirect(ExecutablePath, AArgs, AWorkingDir);
  Result := CommandResult.Success;
end;

procedure TFPCSourceManager.SetCurrentStepValue(AStep: Integer);
begin
  if (AStep >= Ord(Low(TFPCBuildStep))) and (AStep <= Ord(High(TFPCBuildStep))) then
    FCurrentStep := TFPCBuildStep(AStep);
end;

function TFPCSourceManager.ReportBuildStepValue(
  AStep: Integer;
  const AMessage: string
): Boolean;
begin
  if (AStep >= Ord(Low(TFPCBuildStep))) and (AStep <= Ord(High(TFPCBuildStep))) then
    Exit(ReportBuildStep(TFPCBuildStep(AStep), AMessage));
  Result := ReportBuildStep(bsFinished, AMessage);
end;

procedure TFPCSourceManager.WriteStatus(const AText: string);
begin
  WriteLn(AText);
end;

function TFPCSourceManager.GetRegisteredFPCVersionNames: TStringArray;
var
  Releases: TFPCReleaseArray;
  i: Integer;
begin
  Result := nil;
  Releases := TVersionRegistry.Instance.GetFPCReleases;
  SetLength(Result, Length(Releases));
  for i := 0 to High(Releases) do
    Result[i] := Releases[i].Version;
end;

function TFPCSourceManager.ExecuteBuildSourceCommand(const ASourcePath: string): Boolean;
begin
  Result := ExecuteCommand('make', ['clean', 'all'], ASourcePath);
end;

function TFPCSourceManager.DispatchBuildManagerAction(
  ABuildManager: TBuildManager;
  AAction: Integer;
  const AVersion: string
): Boolean;
begin
  case AAction of
    FPC_SOURCE_MANAGER_ACTION_BUILD_COMPILER:
      Result := ABuildManager.BuildCompiler(AVersion);
    FPC_SOURCE_MANAGER_ACTION_BUILD_RTL:
      Result := ABuildManager.BuildRTL(AVersion);
    FPC_SOURCE_MANAGER_ACTION_BUILD_PACKAGES:
      Result := ABuildManager.BuildPackages(AVersion);
    FPC_SOURCE_MANAGER_ACTION_INSTALL_BINARIES:
      Result := ABuildManager.Install(AVersion);
    FPC_SOURCE_MANAGER_ACTION_CONFIGURE_ENVIRONMENT:
      Result := ABuildManager.Configure(AVersion);
    FPC_SOURCE_MANAGER_ACTION_TEST_RESULTS:
      Result := ABuildManager.TestResults(AVersion);
  else
    Result := False;
  end;
end;

function TFPCSourceManager.BuildCompilerWithManager(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceBuildManagerBridgeCore(
    AVersion,
    False,
    FPC_SOURCE_MANAGER_ACTION_BUILD_COMPILER,
    @CreateBuildManager,
    @DispatchBuildManagerAction
  );
end;

function TFPCSourceManager.BuildRTLWithManager(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceBuildManagerBridgeCore(
    AVersion,
    False,
    FPC_SOURCE_MANAGER_ACTION_BUILD_RTL,
    @CreateBuildManager,
    @DispatchBuildManagerAction
  );
end;

function TFPCSourceManager.BuildPackagesWithManager(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceBuildManagerBridgeCore(
    AVersion,
    False,
    FPC_SOURCE_MANAGER_ACTION_BUILD_PACKAGES,
    @CreateBuildManager,
    @DispatchBuildManagerAction
  );
end;

function TFPCSourceManager.InstallBinariesWithManager(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceBuildManagerBridgeCore(
    AVersion,
    True,
    FPC_SOURCE_MANAGER_ACTION_INSTALL_BINARIES,
    @CreateBuildManager,
    @DispatchBuildManagerAction
  );
end;

function TFPCSourceManager.ConfigureEnvironmentWithManager(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceBuildManagerBridgeCore(
    AVersion,
    True,
    FPC_SOURCE_MANAGER_ACTION_CONFIGURE_ENVIRONMENT,
    @CreateBuildManager,
    @DispatchBuildManagerAction
  );
end;

function TFPCSourceManager.TestBuildResultsWithManager(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceBuildManagerBridgeCore(
    AVersion,
    True,
    FPC_SOURCE_MANAGER_ACTION_TEST_RESULTS,
    @CreateBuildManager,
    @DispatchBuildManagerAction
  );
end;

function TFPCSourceManager.WriteCacheMarker(const AVersion: string): Boolean;
begin
  Result := WriteFPCSourceCacheMarkerCore(FSourceRoot, AVersion, Now);
end;

function TFPCSourceManager.CloneFPCSource(const AVersion: string): Boolean;
var
  LRepo: TSourceRepoManager;
begin
  LRepo := Repo;
  try
    Result := ExecuteFPCSourceCloneCore(
      AVersion,
      FCurrentVersion,
      @LRepo.CloneFPCSource
    );
  finally
    LRepo.Free;
  end;
end;

function TFPCSourceManager.UpdateFPCSource(const AVersion: string): Boolean;
var
  LRepo: TSourceRepoManager;
begin
  LRepo := Repo;
  try
    Result := ExecuteFPCSourceUpdateCore(
      AVersion,
      FCurrentVersion,
      @LRepo.UpdateFPCSource,
      @WriteStatus
    );
  finally
    LRepo.Free;
  end;
end;

function TFPCSourceManager.SwitchFPCVersion(const AVersion: string): Boolean;
var
  LRepo: TSourceRepoManager;
begin
  LRepo := Repo;
  try
    Result := ExecuteFPCSourceSwitchCore(
      AVersion,
      FCurrentVersion,
      IsVersionInstalled(AVersion),
      @LRepo.SwitchFPCVersion
    );
  finally
    LRepo.Free;
  end;
end;

function TFPCSourceManager.ListAvailableVersions: TStringArray;
begin
  Result := BuildAvailableFPCSourceVersionsCore(@GetRegisteredFPCVersionNames);
end;

function TFPCSourceManager.ListLocalVersions: TStringArray;
begin
  Result := ListLocalFPCSourceVersionsCore(FSourceRoot, @IsValidSourceDirectory);
end;

function TFPCSourceManager.GetCurrentVersion: string;
begin
  Result := FCurrentVersion;
end;

function TFPCSourceManager.IsVersionAvailable(const AVersion: string): Boolean;
var
  Releases: TFPCReleaseArray;
begin
  if TVersionRegistry.Instance.IsFPCVersionValid(AVersion) then
    Exit(True);

  Releases := TVersionRegistry.Instance.GetFPCReleases;
  if RegistryHasFPCReleases(Releases) then
    Exit(False);

  Result := FindStaticFPCVersionIndex(AVersion) >= 0;
end;

function TFPCSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := IsValidSourceDirectory(GetSourcePath(AVersion));
end;

function TFPCSourceManager.GetFPCSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  Result := GetSourcePath(Version);
end;

function TFPCSourceManager.GetFPCBuildPath(const AVersion: string): string;
begin
  Result := GetFPCSourcePath(AVersion) + PathDelim + 'build';
end;

function TFPCSourceManager.BuildFPCSource(const AVersion: string): Boolean;
var
  Version, SourcePath: string;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  SourcePath := GetFPCSourcePath(Version);

  if not IsValidSourceDirectory(SourcePath) then
  begin
    WriteLn('[FAIL] Invalid FPC source directory: ', SourcePath);
    Exit;
  end;

  WriteLn;
  Result := ExecuteFPCSourceBuildCore(
    Version,
    SourcePath,
    @IsValidSourceDirectory,
    @ExecuteBuildSourceCommand
  );
end;

function TFPCSourceManager.InstallFPCVersion(const AVersion: string): Boolean;
var
  State: TFPCSourceInstallState;
  Callbacks: TFPCSourceInstallCallbacks;
begin
  WriteLn;
  State := Default(TFPCSourceInstallState);
  State.Version := AVersion;
  State.PreviousVersion := FCurrentVersion;
  State.UseCache := FUseCache;

  Callbacks := Default(TFPCSourceInstallCallbacks);
  Callbacks.SetCurrentStep := @SetCurrentStepValue;
  Callbacks.ReportStep := @ReportBuildStepValue;
  Callbacks.InitializeInstall := @InitializeInstall;
  Callbacks.EnsureBootstrap := @EnsureBootstrapCompiler;
  Callbacks.CloneSource := @CloneFPCSource;
  Callbacks.IsCacheAvailable := @IsCacheAvailable;
  Callbacks.UseCachedBuild := @UseCachedBuild;
  Callbacks.BuildCompiler := @BuildFPCCompiler;
  Callbacks.BuildRTL := @BuildFPCRTL;
  Callbacks.BuildPackages := @BuildFPCPackages;
  Callbacks.InstallBinaries := @InstallFPCBinaries;
  Callbacks.ConfigureEnvironment := @ConfigureFPCEnvironment;
  Callbacks.TestBuildResults := @TestBuildResults;
  Callbacks.WriteCacheMarker := @WriteCacheMarker;

  Result := ExecuteFPCSourceInstallFlowCore(State, FCurrentVersion, Callbacks);
  if Result then
    WriteLn;
end;

// Bootstrap compiler management - delegate to FBootstrap helper
function TFPCSourceManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  Result := FBootstrap.GetRequiredBootstrapVersion(ATargetVersion);
end;

function TFPCSourceManager.GetBootstrapPath(const AVersion: string): string;
begin
  Result := FBootstrap.GetBootstrapPath(AVersion);
end;

function TFPCSourceManager.GetBootstrapDownloadURL(const AVersion: string): string;
begin
  Result := FBootstrap.GetBootstrapDownloadURL(AVersion);
end;

function TFPCSourceManager.DownloadBootstrapCompilerInternal(const AVersion: string): Boolean;
var
  Callbacks: TFPCSourceBootstrapDownloadCallbacks;
begin
  Callbacks := Default(TFPCSourceBootstrapDownloadCallbacks);
  Callbacks.Log := @WriteStatus;
  Callbacks.GetDownloadURL := @FBootstrap.GetBootstrapDownloadURL;
  Callbacks.GetBootstrapPath := @FBootstrap.GetBootstrapPath;
  Result := ExecuteFPCSourceBootstrapDownloadCore(AVersion, FSourceRoot, Callbacks);
end;

function TFPCSourceManager.DownloadBootstrapCompiler(const AVersion: string): Boolean;
begin
  Result := DownloadBootstrapCompilerInternal(AVersion);
end;

function TFPCSourceManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  Callbacks: TFPCSourceBootstrapEnsureCallbacks;
begin
  Callbacks := Default(TFPCSourceBootstrapEnsureCallbacks);
  Callbacks.GetRequiredVersion := @FBootstrap.GetRequiredBootstrapVersion;
  Callbacks.FindSystemCompiler := @FBootstrap.FindSystemFPC;
  Callbacks.IsCompatibleCompiler := @FBootstrap.IsCompatibleBootstrap;
  Callbacks.GetBootstrapPath := @FBootstrap.GetBootstrapPath;
  Callbacks.DownloadBootstrap := @DownloadBootstrapCompilerInternal;
  Result := ExecuteFPCSourceEnsureBootstrapCore(
    ATargetVersion,
    FBootstrapCompiler,
    Callbacks
  );
end;

// Step-by-step build process (FPCUpDeluxe-inspired)
function TFPCSourceManager.InitializeInstall(const {%H-} AVersion: string): Boolean;
begin
  // AVersion parameter reserved for future use
  if AVersion <> '' then;
  // Create necessary directories
  EnsureDir(FSourceRoot);
  EnsureDir(FSourceRoot + PathDelim + 'bootstrap');
  Result := True;
end;

function TFPCSourceManager.BuildFPCCompiler(const AVersion: string): Boolean;
var
  LSourcePath: string;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  Result := ExecuteFPCSourceManagedBuildStepCore(
    AVersion,
    LSourcePath,
    @IsValidSourceDirectory,
    @BuildCompilerWithManager
  );
end;

function TFPCSourceManager.BuildFPCRTL(const AVersion: string): Boolean;
var
  LSourcePath: string;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  Result := ExecuteFPCSourceManagedBuildStepCore(
    AVersion,
    LSourcePath,
    @IsValidSourceDirectory,
    @BuildRTLWithManager
  );
end;

function TFPCSourceManager.BuildFPCPackages(const AVersion: string): Boolean;
var
  LSourcePath: string;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  Result := ExecuteFPCSourceManagedBuildStepCore(
    AVersion,
    LSourcePath,
    @IsValidSourceDirectory,
    @BuildPackagesWithManager
  );
end;

function TFPCSourceManager.InstallFPCBinaries(const AVersion: string): Boolean;
var
  LSourcePath: string;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  Result := ExecuteFPCSourceManagedBuildStepCore(
    AVersion,
    LSourcePath,
    @IsValidSourceDirectory,
    @InstallBinariesWithManager
  );
end;

function TFPCSourceManager.ConfigureFPCEnvironment(const AVersion: string): Boolean;
var
  LSourcePath: string;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  Result := ExecuteFPCSourceManagedBuildStepCore(
    AVersion,
    LSourcePath,
    @IsValidSourceDirectory,
    @ConfigureEnvironmentWithManager
  );
end;

function TFPCSourceManager.TestBuildResults(const AVersion: string): Boolean;
var
  LSourcePath: string;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  Result := ExecuteFPCSourceManagedBuildStepCore(
    AVersion,
    LSourcePath,
    @IsValidSourceDirectory,
    @TestBuildResultsWithManager
  );
end;

function TFPCSourceManager.ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;
begin
  // Suppress unused parameter hints
  if AStep = bsFinished then; // Step type available for future logging
  if AMessage <> '' then;     // Message available for future logging
  Result := True;
end;

// Performance optimization methods
function TFPCSourceManager.GetOptimalJobCount: Integer;
begin
  // Use environment variable if available
  Result := StrToIntDef(GetEnvironmentVariable('NUMBER_OF_PROCESSORS'), 0);

  // Fallback to reasonable default
  if Result <= 0 then
    Result := 4;

  // Limit to reasonable range
  if Result < 1 then Result := 1;
  if Result > 16 then Result := 16;

end;

function TFPCSourceManager.IsCacheAvailable(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceCacheAvailableCore(FSourceRoot, AVersion);
end;

function TFPCSourceManager.UseCachedBuild(const AVersion: string): Boolean;
begin
  Result := ExecuteFPCSourceUseCachedBuildCore(
    FSourceRoot,
    AVersion,
    GetFPCSourcePath(AVersion),
    @IsValidSourceDirectory
  );
end;

function TFPCSourceManager.ProtectedIsCacheAvailable(const AVersion: string): Boolean;
begin
  Result := IsCacheAvailable(AVersion);
end;

function TFPCSourceManager.ProtectedUseCachedBuild(const AVersion: string): Boolean;
begin
  Result := UseCachedBuild(AVersion);
end;

function TFPCSourceManager.ProtectedIsValidSourceDirectory(const APath: string): Boolean;
begin
  Result := IsValidSourceDirectory(APath);
end;

function TFPCSourceManager.ProtectedGetVersionFromBranch(const ABranch: string): string;
begin
  Result := GetVersionFromBranch(ABranch);
end;

function TFPCSourceManager.ProtectedBuildFPCCompiler(const AVersion: string): Boolean;
begin
  Result := BuildFPCCompiler(AVersion);
end;

function TFPCSourceManager.ProtectedBuildFPCRTL(const AVersion: string): Boolean;
begin
  Result := BuildFPCRTL(AVersion);
end;

function TFPCSourceManager.ProtectedBuildFPCPackages(const AVersion: string): Boolean;
begin
  Result := BuildFPCPackages(AVersion);
end;

function TFPCSourceManager.OptimizeBuildCommand(const ABaseCommand: string): string;
begin
  Result := ABaseCommand;

  // Add parallel jobs
  if FParallelJobs > 1 then
    Result := Result + ' -j' + IntToStr(FParallelJobs);

  // Add optimization flags
  Result := Result + ' OPT="-O2"';

  // Reduce verbosity if not needed
  if not FVerboseOutput then
    Result := Result + ' VERBOSE=0';

end;

function TFPCSourceManager.CheckBuildPrerequisites(const {%H-} AVersion: string): Boolean;
begin
  Result := CheckFPCSourceBuildPrerequisitesCore(
    AVersion,
    FBootstrapCompiler,
    @ExecuteCommand
  );
end;

function TFPCSourceManager.IsValidSourceDirectory(const APath: string): Boolean;
var
  CompilerPath, RTLPath, MakefilePath: string;
begin
  Result := False;

  // Check basic directory structure
  if not DirectoryExists(APath) then
    Exit;

  // Check key directories and files
  CompilerPath := APath + PathDelim + 'compiler';
  RTLPath := APath + PathDelim + 'rtl';
  MakefilePath := APath + PathDelim + 'Makefile';

  // Validate source directory integrity
  if DirectoryExists(CompilerPath) and
     DirectoryExists(RTLPath) and
     FileExists(MakefilePath) then
  begin
    Result := True;
  end
  else
  begin
    if not DirectoryExists(CompilerPath) then
    if not DirectoryExists(RTLPath) then
    if not FileExists(MakefilePath) then
  end;
end;

end.
