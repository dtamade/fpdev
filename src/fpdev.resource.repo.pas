unit fpdev.resource.repo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DateUtils, fpdev.utils.fs,
  fpdev.utils.process, fpdev.git.types, fpdev.git.runtime,
  fpdev.output.intf,
  fpdev.resource.repo.bootstrapquery,
  fpdev.resource.repo.mirror,
  fpdev.resource.repo.mirrorflow,
  fpdev.resource.repo.types;  // TMirrorInfo, TResourceRepoConfig, TPlatformInfo, etc.

type
  // Re-export types for backward compatibility
  // Types are now defined in fpdev.resource.repo.types

  { TPackageInfo - Alias for TRepoPackageInfo (backward compatibility)
    Note: TRepoPackageInfo is used in the types unit to avoid collision
    with fpdev.package.types.TPackageInfo }
  TPackageInfo = TRepoPackageInfo;

  { Resource repository manager
    B068: Thread safety notes
    - This class is designed for single-threaded use (normal scenario for CLI tools)
    - Lazy loading flag FManifestLoaded and shared object FManifestData have no synchronization protection
    - Concurrent access may cause duplicate loading or race conditions
    - If multi-threading support is needed, critical section protection must be added }
  TResourceRepository = class
  private
    FConfig: TResourceRepoConfig;
    FLocalPath: string;
    FLastUpdateCheck: TDateTime;
    FManifestData: TJSONObject;
    FManifestLoaded: Boolean;         // Lazy loading flag
    FUserRegion: string;
    FGitOps: IGitRuntime;
    FCachedBestMirror: string;      // Cached best mirror
    FMirrorCacheTime: TDateTime;    // Mirror cache time
    FMirrorLatencies: TResourceRepoMirrorLatencyStateArray;
    FOutput: IOutput;               // Optional output interface

    procedure Log(const AMsg: string);
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
    function GitClone(const AURL: string): Boolean;
    function GitPull: Boolean;
    function IsGitRepository: Boolean;
    function QueryShortHead(const AWorkDir: string): TProcessResult;
    function GetLastCommitHash: string;
    function NeedsUpdate: Boolean;
    procedure MarkUpdateCheckNow;
    procedure EnsureLocalDir(const APath: string);
    function DetectUserRegion: string;
    function SelectBestMirror: string;
    function TestMirrorLatency(const AURL: string; ATimeoutMS: Integer = 5000): Integer;
    function ParseMirrorsFromManifest(
      const AManifestData: TJSONObject
    ): TResourceRepoMirrorInfoArray;
    function GetGitBackendValue: TGitBackend;
    function CloneRepositoryRuntime(const AURL, ALocalPath,
      ABranch: string): Boolean;
    function PullRepositoryRuntime(const ALocalPath: string): Boolean;
    function GetGitLastErrorValue: string;
    function QueryHasPackageSurface(const ALocalPath, AName,
      AVersion: string): Boolean;
    { B066: Lazy loading helper - returns Boolean because manifest is a required resource
      Caller must check return value: if not EnsureManifestLoaded then Exit;
      Unlike TBuildCache.EnsureIndexLoaded, manifest loading failure needs explicit handling }
    function EnsureManifestLoaded: Boolean;
    function InstallBootstrapWithInfo(const AInfo: TPlatformInfo;
      const AVersion, APlatform, ADestDir: string): Boolean;
    function InstallBinaryReleaseWithInfo(const AInfo: TPlatformInfo;
      const AVersion, APlatform, ADestDir: string): Boolean;
    function InstallCrossToolchainWithInfo(const AInfo: TCrossToolchainInfo;
      const ATarget, ADestDir: string): Boolean;
    function InstallPackageWithInfo(const AInfo: TPackageInfo;
      const AName, AVersion, ADestDir: string): Boolean;

  public
    constructor Create(const AConfig: TResourceRepoConfig);
    destructor Destroy; override;

    // Repository operations
    function Initialize: Boolean;
    function Update(const AForce: Boolean = False): Boolean;
    function GetStatus: string;

    // Manifest operations
    function LoadManifest: Boolean;
    function GetManifestVersion: string;

    // Resource queries - bootstrap compiler
    function HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
    function GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
    function GetBootstrapExecutable(const AVersion, APlatform: string): string;

    // Bootstrap compiler version mapping (multi-version support)
    function GetRequiredBootstrapVersion(const AFPCVersion: string): string;
    function GetBootstrapVersionFromMakefile(const ASourcePath: string): string;
    function ListBootstrapVersions: SysUtils.TStringArray;
    function FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;

    // Resource queries - binary releases (FPC/Lazarus toolchain)
    function HasBinaryRelease(const AVersion, APlatform: string): Boolean;
    function GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
    function GetBinaryReleasePath(const AVersion, APlatform: string): string;

    // Resource queries - cross-compilation toolchain
    function HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;
    function GetCrossToolchainInfo(const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
    function ListCrossTargets: SysUtils.TStringArray;

    // Resource queries - component packages
    function HasPackage(const AName, AVersion: string): Boolean;
    function GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;
    function ListPackages(const ACategory: string = ''): SysUtils.TStringArray;
    function SearchPackages(const AKeyword: string): SysUtils.TStringArray;

    // Resource extraction/installation
    function InstallBootstrap(const AVersion, APlatform, ADestDir: string): Boolean;
    function InstallBinaryRelease(const AVersion, APlatform, ADestDir: string): Boolean;
    function InstallCrossToolchain(const ATarget, AHostPlatform, ADestDir: string): Boolean;
    function InstallPackage(const AName, AVersion, ADestDir: string): Boolean;
    function VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;

    // Mirror management
    function GetMirrors: TMirrorArray;
    function GetBestMirrorURL: string;
    property UserRegion: string read FUserRegion write FUserRegion;

    // Properties
    property LocalPath: string read FLocalPath;
    property LastUpdateCheck: TDateTime read FLastUpdateCheck;
    property Output: IOutput read FOutput write FOutput;
  end;

  // Use SysUtils.TStringArray instead of local declaration

  { Helper functions }
  function GetCurrentPlatform: string;
  function CreateDefaultConfig: TResourceRepoConfig;
  { Creates config based on user mirror settings.
    AMirror: 'auto', 'github', 'gitee', or custom URL
    ACustomURL: Custom repository URL (highest priority, overrides AMirror) }
  function CreateConfigWithMirror(const AMirror: string; const ACustomURL: string = ''): TResourceRepoConfig;

implementation

uses
  fpdev.resource.repo.config,
  fpdev.resource.repo.bootstrap,
  fpdev.resource.repo.bootstrapflow,
  fpdev.resource.repo.package,
  fpdev.resource.repo.packageflow,
  fpdev.resource.repo.search,
  fpdev.resource.repo.binary,
  fpdev.resource.repo.cross,
  fpdev.resource.repo.distributionflow,
  fpdev.resource.repo.install,
  fpdev.resource.repo.lifecycle,
  fpdev.resource.repo.lifecycleflow,
  fpdev.resource.repo.queryflow,
  fpdev.resource.repo.statusflow;

{ Helper function implementation }

function GetCurrentPlatform: string;
begin
  Result := ResourceRepoGetCurrentPlatform;
end;

function CreateDefaultConfig: TResourceRepoConfig;
begin
  Result := ResourceRepoCreateDefaultConfig;
end;

function CreateConfigWithMirror(const AMirror: string; const ACustomURL: string): TResourceRepoConfig;
begin
  Result := ResourceRepoCreateConfigWithMirror(AMirror, ACustomURL);
end;

{ TResourceRepository }

procedure TResourceRepository.Log(const AMsg: string);
begin
  if Assigned(FOutput) then
    FOutput.WriteLn(AMsg);
end;

procedure TResourceRepository.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  if Assigned(FOutput) then
    FOutput.WriteLn(Format(AFormat, AArgs));
end;

procedure TResourceRepository.EnsureLocalDir(const APath: string);
begin
  EnsureDir(APath);
end;

constructor TResourceRepository.Create(const AConfig: TResourceRepoConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FLocalPath := AConfig.LocalPath;
  FLastUpdateCheck := 0;
  FManifestData := nil;
  FManifestLoaded := False;
  FGitOps := NewGitRuntime;
  FCachedBestMirror := '';
  FMirrorCacheTime := 0;
  SetLength(FMirrorLatencies, 0);
end;

destructor TResourceRepository.Destroy;
begin
  FGitOps := nil;
  if Assigned(FManifestData) then
    FManifestData.Free;
  inherited Destroy;
end;

function TResourceRepository.IsGitRepository: Boolean;
begin
  // Use the unified git runtime for accurate repository detection.
  Result := FGitOps.IsRepository(FLocalPath);
end;

function TResourceRepository.GetGitBackendValue: TGitBackend;
begin
  if FGitOps <> nil then
    Result := FGitOps.Backend
  else
    Result := gbNone;
end;

function TResourceRepository.CloneRepositoryRuntime(const AURL, ALocalPath,
  ABranch: string): Boolean;
begin
  Result := (FGitOps <> nil) and FGitOps.Clone(AURL, ALocalPath, ABranch);
end;

function TResourceRepository.PullRepositoryRuntime(const ALocalPath: string): Boolean;
begin
  Result := (FGitOps <> nil) and FGitOps.PullFastForwardOnly(ALocalPath);
end;

function TResourceRepository.GetGitLastErrorValue: string;
begin
  if FGitOps <> nil then
    Result := FGitOps.LastError
  else
    Result := '';
end;

function TResourceRepository.QueryHasPackageSurface(const ALocalPath, AName,
  AVersion: string): Boolean;
begin
  Result := ResourceRepoHasPackageCore(ALocalPath, AName, AVersion);
end;

function TResourceRepository.GitClone(const AURL: string): Boolean;
begin
  Result := ExecuteResourceRepoGitCloneCore(
    AURL,
    FLocalPath,
    FConfig.Branch,
    GetGitBackendValue,
    @CloneRepositoryRuntime,
    @GetGitLastErrorValue,
    @EnsureLocalDir,
    @Log
  );
end;

function TResourceRepository.GitPull: Boolean;
begin
  Result := ExecuteResourceRepoGitPullCore(
    FLocalPath,
    GetGitBackendValue,
    @PullRepositoryRuntime,
    @GetGitLastErrorValue,
    @Log
  );
end;

function TResourceRepository.QueryShortHead(const AWorkDir: string): TProcessResult;
var
  Hash: string;
begin
  Result := Default(TProcessResult);
  Hash := FGitOps.GetShortHeadHash(AWorkDir, 7);
  if Hash <> '' then
  begin
    Result.Success := True;
    Result.ExitCode := 0;
    Result.StdOut := Hash + LineEnding;
  end
  else
  begin
    Result.Success := False;
    Result.ExitCode := 1;
    Result.ErrorMessage := FGitOps.LastError;
  end;
end;

function TResourceRepository.GetLastCommitHash: string;
begin
  Result := GetResourceRepoLastCommitHashCore(FLocalPath, @IsGitRepository, @QueryShortHead);
end;

function TResourceRepository.NeedsUpdate: Boolean;
var
  HoursSinceUpdate: Double;
begin
  if not FConfig.AutoUpdate then
    Exit(False);

  if FLastUpdateCheck = 0 then
    Exit(True);

  HoursSinceUpdate := HoursBetween(Now, FLastUpdateCheck);
  Result := HoursSinceUpdate >= FConfig.UpdateIntervalHours;
end;

procedure TResourceRepository.MarkUpdateCheckNow;
begin
  FLastUpdateCheck := Now;
end;

function TResourceRepository.Initialize: Boolean;
begin
  Result := ExecuteResourceRepoInitializeCore(
    FLocalPath,
    FConfig.URL,
    FConfig.Mirrors,
    NeedsUpdate,
    @IsGitRepository,
    @GetLastCommitHash,
    @GitClone,
    @GitPull,
    @LoadManifest,
    @Log,
    @MarkUpdateCheckNow
  );
end;

function TResourceRepository.Update(const AForce: Boolean): Boolean;
begin
  Result := ExecuteResourceRepoUpdateCore(
    AForce,
    NeedsUpdate,
    FLastUpdateCheck,
    @IsGitRepository,
    @GitPull,
    @LoadManifest,
    @Log,
    @MarkUpdateCheckNow
  );
end;

function TResourceRepository.GetStatus: string;
begin
  Result := BuildResourceRepoStatusCore(FLocalPath, FLastUpdateCheck, @IsGitRepository, @GetLastCommitHash);
end;

function TResourceRepository.LoadManifest: Boolean;
var
  ManifestData: TJSONObject;
  ManifestLoaded: Boolean;
begin
  ManifestData := nil;
  ManifestLoaded := False;

  Result := LoadResourceRepoManifestSurfaceCore(
    FLocalPath,
    @Log,
    ManifestData,
    ManifestLoaded
  );

  ApplyLoadedResourceRepoManifestStateCore(
    FManifestData,
    FManifestLoaded,
    ManifestData,
    ManifestLoaded
  );
end;

function TResourceRepository.EnsureManifestLoaded: Boolean;
begin
  Result := EnsureResourceRepoManifestLoadedCore(
    FManifestLoaded,
    FManifestData,
    @LoadManifest
  );
end;

{ B226: Build install context for delegation to fpdev.resource.repo.install }
function BuildInstallContext(ARepo: TResourceRepository): TRepoInstallContext;
begin
  Result.LocalPath := ARepo.LocalPath;
  Result.Log := @ARepo.Log;
  Result.LogFmt := @ARepo.LogFmt;
  Result.VerifyChecksum := @ARepo.VerifyChecksum;
end;

function TResourceRepository.InstallBootstrapWithInfo(const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;
begin
  Result := RepoInstallBootstrapCompiler(BuildInstallContext(Self), AInfo,
    AVersion, APlatform, ADestDir);
end;

function TResourceRepository.InstallBinaryReleaseWithInfo(const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;
begin
  Result := RepoInstallBinaryRelease(BuildInstallContext(Self), AInfo,
    AVersion, APlatform, ADestDir);
end;

function TResourceRepository.InstallCrossToolchainWithInfo(
  const AInfo: TCrossToolchainInfo; const ATarget, ADestDir: string): Boolean;
begin
  Result := RepoInstallCrossToolchain(BuildInstallContext(Self), AInfo,
    ATarget, ADestDir);
end;

function TResourceRepository.InstallPackageWithInfo(const AInfo: TPackageInfo;
  const AName, AVersion, ADestDir: string): Boolean;
begin
  Result := RepoInstallPackage(BuildInstallContext(Self), AInfo,
    AName, AVersion, ADestDir);
end;

function TResourceRepository.GetManifestVersion: string;
begin
  Result := GetResourceRepoManifestVersionSurfaceCore(
    FManifestData,
    @EnsureManifestLoaded
  );
end;

function TResourceRepository.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
begin
  Result := ExecuteResourceRepoBooleanQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error checking bootstrap compiler: %s',
    AVersion,
    APlatform,
    @ResourceRepoHasBootstrapCompiler
  );
end;

function TResourceRepository.GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
begin
  Result := ExecuteResourceRepoPlatformInfoQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error getting bootstrap info: %s',
    AVersion,
    APlatform,
    AInfo,
    @ResourceRepoGetBootstrapCompilerInfo
  );
end;

function TResourceRepository.GetBootstrapExecutable(const AVersion, APlatform: string): string;
var
  Info: TPlatformInfo;
begin
  Result := '';
  if GetBootstrapInfo(AVersion, APlatform, Info) then
    Result := ResourceRepoGetBootstrapExecutablePath(FLocalPath, Info.Executable);
end;

function TResourceRepository.GetRequiredBootstrapVersion(const AFPCVersion: string): string;
begin
  Result := ExecuteResourceRepoStringQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error getting bootstrap version from manifest: %s',
    AFPCVersion,
    @ResourceRepoGetRequiredBootstrapVersion,
    @ResourceRepoGetRequiredBootstrapVersion
  );
end;

function TResourceRepository.GetBootstrapVersionFromMakefile(const ASourcePath: string): string;
begin
  try
    Result := ResourceRepoGetBootstrapVersionFromMakefile(ASourcePath);
  except
    on E: Exception do
    begin
      LogFmt('Error parsing bootstrap version from Makefile: %s', [E.Message]);
      Result := '';
    end;
  end;
end;

function TResourceRepository.ListBootstrapVersions: SysUtils.TStringArray;
begin
  Result := ExecuteResourceRepoStringArrayQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error listing bootstrap versions: %s',
    @ResourceRepoListBootstrapVersions
  );
end;

function TResourceRepository.FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;
begin
  Result := ExecuteResourceRepoFindBestBootstrapVersionCore(
    AFPCVersion,
    APlatform,
    @GetRequiredBootstrapVersion,
    @ListBootstrapVersions,
    @HasBootstrapCompiler,
    @Log
  );
end;

function TResourceRepository.VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;
begin
  Result := ExecuteResourceRepoVerifyChecksumCore(
    AFile,
    AExpectedSHA256,
    @Log,
    @LogFmt
  );
end;

function TResourceRepository.HasBinaryRelease(const AVersion, APlatform: string): Boolean;
begin
  Result := ExecuteResourceRepoBooleanQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error checking binary release: %s',
    AVersion,
    APlatform,
    @ResourceRepoHasBinaryRelease
  );
end;

function TResourceRepository.GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
begin
  Result := ExecuteResourceRepoPlatformInfoQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error getting binary release info: %s',
    AVersion,
    APlatform,
    AInfo,
    @ResourceRepoGetBinaryReleaseInfoCore
  );
end;

function TResourceRepository.GetBinaryReleasePath(const AVersion, APlatform: string): string;
var
  Info: TPlatformInfo;
begin
  Result := '';
  if GetBinaryReleaseInfo(AVersion, APlatform, Info) then
    Result := FLocalPath + PathDelim + Info.Executable;
end;

function TResourceRepository.InstallBinaryRelease(const AVersion, APlatform, ADestDir: string): Boolean;
begin
  Result := ExecuteResourceRepoInstallBinaryReleaseCore(
    AVersion, APlatform, ADestDir,
    @GetBinaryReleaseInfo,
    @InstallBinaryReleaseWithInfo,
    @Log
  );
end;

function TResourceRepository.InstallBootstrap(const AVersion, APlatform, ADestDir: string): Boolean;
begin
  Result := ExecuteResourceRepoInstallBootstrapCore(
    AVersion,
    APlatform,
    ADestDir,
    @GetBootstrapInfo,
    @InstallBootstrapWithInfo,
    @Log
  );
end;

{ Mirror Management }

function TResourceRepository.DetectUserRegion: string;
begin
  Result := ResourceRepoDetectUserRegion(@Log);
end;

function TResourceRepository.ParseMirrorsFromManifest(
  const AManifestData: TJSONObject
): TResourceRepoMirrorInfoArray;
begin
  Result := ResourceRepoGetMirrorsFromManifest(AManifestData);
end;

function TResourceRepository.TestMirrorLatency(const AURL: string; ATimeoutMS: Integer): Integer;
begin
  Result := ResourceRepoTestMirrorLatency(AURL, ATimeoutMS, @Log);
end;

function TResourceRepository.SelectBestMirror: string;
const
  CACHE_TTL_HOURS = 1;  // Mirror cache 1 hour
begin
  Result := ExecuteResourceRepoSelectBestMirrorSurfaceCore(
    FManifestData,
    FUserRegion,
    FConfig.URL,
    FConfig.Mirrors,
    FCachedBestMirror,
    FMirrorCacheTime,
    FMirrorLatencies,
    CACHE_TTL_HOURS,
    Now,
    @EnsureManifestLoaded,
    @DetectUserRegion,
    @TestMirrorLatency,
    @LogFmt
  );
end;

function TResourceRepository.GetMirrors: TMirrorArray;
begin
  Result := ExecuteResourceRepoGetMirrorsSurfaceCore(
    FManifestData,
    @EnsureManifestLoaded,
    @ParseMirrorsFromManifest,
    @LogFmt
  );
end;

function TResourceRepository.GetBestMirrorURL: string;
begin
  Result := SelectBestMirror;
end;

{ Cross Toolchain Management }

function TResourceRepository.HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;
begin
  Result := ExecuteResourceRepoBooleanQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error checking cross toolchain: %s',
    ATarget,
    AHostPlatform,
    @ResourceRepoHasCrossToolchain
  );
end;

function TResourceRepository.GetCrossToolchainInfo(
  const ATarget, AHostPlatform: string;
  out AInfo: TCrossToolchainInfo
): Boolean;
begin
  Result := ExecuteResourceRepoCrossInfoQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error getting cross toolchain info: %s',
    ATarget,
    AHostPlatform,
    AInfo,
    @ResourceRepoGetCrossToolchainInfoCore
  );
end;

function TResourceRepository.ListCrossTargets: SysUtils.TStringArray;
begin
  Result := ExecuteResourceRepoStringArrayQueryCore(
    FManifestData,
    @EnsureManifestLoaded,
    @LogFmt,
    'Error listing cross targets: %s',
    @ResourceRepoListCrossTargets
  );
end;

function TResourceRepository.InstallCrossToolchain(const ATarget, AHostPlatform, ADestDir: string): Boolean;
begin
  Result := ExecuteResourceRepoInstallCrossToolchainCore(
    ATarget, AHostPlatform, ADestDir,
    @GetCrossToolchainInfo,
    @InstallCrossToolchainWithInfo,
    @Log
  );
end;

{ Package Management }

function TResourceRepository.HasPackage(const AName, AVersion: string): Boolean;
begin
  Result := ExecuteResourceRepoHasPackageSurfaceCore(
    FLocalPath,
    AName,
    AVersion,
    @LogFmt,
    @QueryHasPackageSurface
  );
end;

function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;
begin
  Result := ExecuteResourceRepoPackageInfoSurfaceCore(
    FLocalPath,
    AName,
    AVersion,
    AInfo,
    @LogFmt,
    @ResourceRepoGetPackageInfoCore
  );
end;

function TResourceRepository.ListPackages(const ACategory: string): SysUtils.TStringArray;
begin
  Result := ExecuteResourceRepoPackageListSurfaceCore(
    FLocalPath,
    ACategory,
    @ResourceRepoListPackagesCore
  );
end;

function TResourceRepository.SearchPackages(const AKeyword: string): SysUtils.TStringArray;
begin
  Result := ExecuteResourceRepoPackageSearchSurfaceCore(
    AKeyword,
    @ListPackages,
    @GetPackageInfo,
    @ResourceRepoSearchPackagesCore
  );
end;

function TResourceRepository.InstallPackage(const AName, AVersion, ADestDir: string): Boolean;
begin
  Result := ExecuteResourceRepoInstallPackageCore(
    AName, AVersion, ADestDir,
    @GetPackageInfo,
    @InstallPackageWithInfo,
    @Log
  );
end;

end.
