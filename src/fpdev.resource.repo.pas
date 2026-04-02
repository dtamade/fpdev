unit fpdev.resource.repo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DateUtils, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils.git, fpdev.git.runtime,
  fpdev.output.intf,
  fpdev.resource.repo.bootstrapquery,
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
    FMirrorLatencies: array of record
      URL: string;
      Latency: Integer;  // Milliseconds, -1 means unreachable
    end;
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
    function DetectUserRegion: string;
    function SelectBestMirror: string;
    function TestMirrorLatency(const AURL: string; ATimeoutMS: Integer = 5000): Integer;
    { B066: Lazy loading helper - returns Boolean because manifest is a required resource
      Caller must check return value: if not EnsureManifestLoaded then Exit;
      Unlike TBuildCache.EnsureIndexLoaded, manifest loading failure needs explicit handling }
    function EnsureManifestLoaded: Boolean;
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
  fpdev.resource.repo.mirror,
  fpdev.resource.repo.package,
  fpdev.resource.repo.search,
  fpdev.resource.repo.binary,
  fpdev.resource.repo.cross,
  fpdev.resource.repo.distributionflow,
  fpdev.resource.repo.install,
  fpdev.resource.repo.lifecycle,
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

constructor TResourceRepository.Create(const AConfig: TResourceRepoConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FLocalPath := AConfig.LocalPath;
  FLastUpdateCheck := 0;
  FManifestData := nil;
  FManifestLoaded := False;
  FGitOps := TGitRuntime.Create;
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
  // Use TGitOperations for more accurate detection (supports libgit2)
  Result := FGitOps.IsRepository(FLocalPath);
end;

function TResourceRepository.GitClone(const AURL: string): Boolean;
var
  ParentDir: string;
begin
  Result := False;

  // Check if git backend is available
  if FGitOps.Backend = gbNone then
  begin
    Log('Error: No Git backend available (neither libgit2 nor git command found)');
    Exit;
  end;

  LogFmt('Cloning resource repository from %s...', [AURL]);
  LogFmt('  Using backend: %s', [GitBackendToString(FGitOps.Backend)]);

  // Ensure parent directory exists
  ParentDir := ExtractFileDir(FLocalPath);
  if not DirectoryExists(ParentDir) then
    EnsureDir(ParentDir);

  // Clone repository - use TGitOperations
  Result := FGitOps.Clone(AURL, FLocalPath, FConfig.Branch);

  if Result then
    Log('Resource repository cloned successfully')
  else
    LogFmt('Failed to clone from %s: %s', [AURL, FGitOps.LastError]);
end;

function TResourceRepository.GitPull: Boolean;
begin
  // Check if git backend is available
  if FGitOps.Backend = gbNone then
  begin
    Log('Warning: No Git backend available, skipping update');
    Exit(False);
  end;

  Log('Updating resource repository...');
  Result := FGitOps.PullFastForwardOnly(FLocalPath);

  if Result then
    Log('Resource repository updated')
  else
    LogFmt('Warning: Failed to update (using cached version): %s', [FGitOps.LastError]);
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
  ManifestPath: string;
  ManifestData: TJSONObject;
  ManifestLoaded: Boolean;
begin
  ManifestPath := FLocalPath + PathDelim + 'manifest.json';
  ManifestData := nil;
  ManifestLoaded := False;

  Result := LoadResourceRepoManifestCore(
    ManifestPath,
    @Log,
    ManifestData,
    ManifestLoaded
  );

  FreeAndNil(FManifestData);
  FManifestData := ManifestData;
  FManifestLoaded := ManifestLoaded;
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
  Result := 'unknown';
  if not EnsureManifestLoaded then
    Exit;
  Result := FManifestData.Get('version', 'unknown');
end;

function TResourceRepository.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
begin
  Result := False;

  if not EnsureManifestLoaded then
    Exit;

  try
    Result := ResourceRepoHasBootstrapCompiler(FManifestData, AVersion, APlatform);
  except
    on E: Exception do
    begin
      LogFmt('Error checking bootstrap compiler: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
begin
  Result := False;
  System.Initialize(AInfo);

  if not EnsureManifestLoaded then
    Exit;

  try
    Result := ResourceRepoGetBootstrapCompilerInfo(FManifestData, AVersion, APlatform, AInfo);
  except
    on E: Exception do
    begin
      LogFmt('Error getting bootstrap info: %s', [E.Message]);
      Result := False;
    end;
  end;
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
  // B064: Check return value, use fallback on failure
  if not EnsureManifestLoaded then
  begin
    Result := ResourceRepoGetRequiredBootstrapVersion(nil, AFPCVersion);
    Exit;
  end;
  try
    Result := ResourceRepoGetRequiredBootstrapVersion(FManifestData, AFPCVersion);
  except
    on E: Exception do
    begin
      LogFmt('Error getting bootstrap version from manifest: %s', [E.Message]);
      Result := ResourceRepoGetRequiredBootstrapVersion(nil, AFPCVersion);
    end;
  end;
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
  Result := nil;  // B064: Initialize managed type
  // B064: Check return value, return empty array on failure
  if not EnsureManifestLoaded then
    Exit;
  try
    Result := ResourceRepoListBootstrapVersions(FManifestData);
  except
    on E: Exception do
    begin
      LogFmt('Error listing bootstrap versions: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

function TResourceRepository.FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;
var
  RequiredVersion: string;
  AvailableVersions: SysUtils.TStringArray;
  LogLines: SysUtils.TStringArray;
  Index: Integer;
begin
  RequiredVersion := GetRequiredBootstrapVersion(AFPCVersion);
  LogLines := Default(SysUtils.TStringArray);
  SetLength(LogLines, 0);
  AvailableVersions := ListBootstrapVersions;
  Result := SelectBestBootstrapVersionCore(
    RequiredVersion,
    APlatform,
    AvailableVersions,
    @HasBootstrapCompiler,
    LogLines
  );
  for Index := 0 to High(LogLines) do
    Log(LogLines[Index]);
end;

function TResourceRepository.VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;
var
  LResult: TProcessResult;
  ActualSHA256: string;
begin
  Result := False;

  if AExpectedSHA256 = '' then
  begin
    Log('Warning: No checksum provided, skipping verification');
    Exit(True);  // No checksum required, consider it passed
  end;

  LResult := TProcessExecutor.Execute('sha256sum', [AFile], '');
  if LResult.Success then
  begin
    // Extract hash value (first field)
    ActualSHA256 := Trim(Copy(LResult.StdOut, 1, Pos(' ', LResult.StdOut) - 1));

    Result := SameText(ActualSHA256, AExpectedSHA256);

    if Result then
      LogFmt('Checksum verified: %s', [AFile])
    else
    begin
      LogFmt('Checksum mismatch for: %s', [AFile]);
      LogFmt('  Expected: %s', [AExpectedSHA256]);
      LogFmt('  Got:      %s', [ActualSHA256]);
    end;
  end
  else if LResult.ErrorMessage <> '' then
    LogFmt('Error verifying checksum: %s', [LResult.ErrorMessage]);
end;

function TResourceRepository.HasBinaryRelease(const AVersion, APlatform: string): Boolean;
begin
  Result := False;

  if not EnsureManifestLoaded then
    Exit;

  try
    // B067: Use helper function
    Result := ResourceRepoHasBinaryRelease(FManifestData, AVersion, APlatform);
  except
    on E: Exception do
    begin
      LogFmt('Error checking binary release: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
begin
  Result := False;
  System.Initialize(AInfo);

  if not EnsureManifestLoaded then
    Exit;

  try
    Result := ResourceRepoGetBinaryReleaseInfoCore(FManifestData,
      AVersion, APlatform, AInfo);
  except
    on E: Exception do
    begin
      LogFmt('Error getting binary release info: %s', [E.Message]);
      Result := False;
    end;
  end;
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
var
  Info: TPlatformInfo;
begin
  Result := False;

  // Get bootstrap info
  if not GetBootstrapInfo(AVersion, APlatform, Info) then
  begin
    Log('Error: Bootstrap compiler info not found');
    Exit;
  end;

  // B226: Delegate to install helper
  Result := RepoInstallBootstrapCompiler(BuildInstallContext(Self), Info, AVersion, APlatform, ADestDir);
end;

{ Mirror Management }

function TResourceRepository.DetectUserRegion: string;
begin
  Result := ResourceRepoDetectUserRegion(@Log);
end;

function TResourceRepository.TestMirrorLatency(const AURL: string; ATimeoutMS: Integer): Integer;
begin
  Result := ResourceRepoTestMirrorLatency(AURL, ATimeoutMS, @Log);
end;

function TResourceRepository.SelectBestMirror: string;
const
  CACHE_TTL_HOURS = 1;  // Mirror cache 1 hour
var
  Region: string;
  i: Integer;
  CandidateMirrors: array of string;
  CandidateLatencies: TResourceRepoMirrorLatencyArray;
  CandidateCount: Integer;
  BestMirror: string;
begin
  Result := FConfig.URL;  // Default to primary URL

  // Check cache
  if ResourceRepoTryGetCachedMirror(FCachedBestMirror, FMirrorCacheTime,
    CACHE_TTL_HOURS, Now, Result) then
    Exit;

  if not EnsureManifestLoaded then
    Exit;

  // Detect or use configured region
  if FUserRegion <> '' then
    Region := FUserRegion
  else
    Region := DetectUserRegion;

  CandidateMirrors := nil;
  CandidateLatencies := nil;

  try
    CandidateMirrors := ResourceRepoBuildCandidateMirrors(
      FManifestData, Region, FConfig.URL, FConfig.Mirrors);

    BestMirror := ResourceRepoSelectBestMirrorFromCandidates(
      CandidateMirrors, @TestMirrorLatency, 3000, CandidateLatencies);

    CandidateCount := Length(CandidateMirrors);
    SetLength(FMirrorLatencies, CandidateCount);

    for i := 0 to CandidateCount - 1 do
    begin
      FMirrorLatencies[i].URL := CandidateMirrors[i];
      if i <= High(CandidateLatencies) then
        FMirrorLatencies[i].Latency := CandidateLatencies[i]
      else
        FMirrorLatencies[i].Latency := -1;
    end;

    if BestMirror <> '' then
      Result := BestMirror;

    // Cache result
    ResourceRepoSetCachedMirror(Result, Now, FCachedBestMirror, FMirrorCacheTime);

  except
    on E: Exception do
    begin
      LogFmt('Error selecting best mirror: %s', [E.Message]);
      // Fall back to primary URL on any error
      Result := FConfig.URL;
    end;
  end;
end;

function TResourceRepository.GetMirrors: TMirrorArray;
var
  ParsedMirrors: TResourceRepoMirrorInfoArray;
  i: Integer;
begin
  Result := nil;

  if not EnsureManifestLoaded then
    Exit;

  try
    ParsedMirrors := ResourceRepoGetMirrorsFromManifest(FManifestData);
    SetLength(Result, Length(ParsedMirrors));

    for i := 0 to High(ParsedMirrors) do
    begin
      Result[i].Name := ParsedMirrors[i].Name;
      Result[i].URL := ParsedMirrors[i].URL;
      Result[i].Region := ParsedMirrors[i].Region;
      Result[i].Priority := ParsedMirrors[i].Priority;
    end;
  except
    on E: Exception do
    begin
      LogFmt('Error getting mirrors: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

function TResourceRepository.GetBestMirrorURL: string;
begin
  Result := SelectBestMirror;
end;

{ Cross Toolchain Management }

function TResourceRepository.HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;
begin
  Result := False;

  if not EnsureManifestLoaded then
    Exit;

  try
    // B069: Use helper function
    Result := ResourceRepoHasCrossToolchain(FManifestData, ATarget, AHostPlatform);
  except
    on E: Exception do
    begin
      LogFmt('Error checking cross toolchain: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetCrossToolchainInfo(
  const ATarget, AHostPlatform: string;
  out AInfo: TCrossToolchainInfo
): Boolean;
begin
  Result := False;
  System.Initialize(AInfo);

  if not EnsureManifestLoaded then
    Exit;

  try
    Result := ResourceRepoGetCrossToolchainInfoCore(FManifestData,
      ATarget, AHostPlatform, AInfo);
  except
    on E: Exception do
    begin
      LogFmt('Error getting cross toolchain info: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.ListCrossTargets: SysUtils.TStringArray;
begin
  Result := nil;

  if not EnsureManifestLoaded then
    Exit;

  try
    // B069: Use helper function
    Result := ResourceRepoListCrossTargets(FManifestData);
  except
    on E: Exception do
    begin
      LogFmt('Error listing cross targets: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
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
  Result := False;

  try
    Result := ResourceRepoHasPackageCore(FLocalPath, AName, AVersion);
  except
    on E: Exception do
    begin
      LogFmt('Error checking package availability: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;
begin
  Result := False;
  System.Initialize(AInfo);

  try
    Result := ResourceRepoGetPackageInfoCore(FLocalPath, AName, AVersion, AInfo);
  except
    on E: Exception do
    begin
      LogFmt('Error checking package availability: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.ListPackages(const ACategory: string): SysUtils.TStringArray;
begin
  Result := ResourceRepoListPackagesCore(FLocalPath, ACategory);
end;

function TResourceRepository.SearchPackages(const AKeyword: string): SysUtils.TStringArray;
var
  AllPackages: SysUtils.TStringArray;
begin
  AllPackages := ListPackages('');
  Result := ResourceRepoSearchPackagesCore(AllPackages, AKeyword, @GetPackageInfo);
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
