unit fpdev.fpc.installer;

{
================================================================================
  fpdev.fpc.installer - FPC Binary Installation Service
================================================================================

  Provides FPC installation capabilities for two surfaces:
  - TFPCBinaryInstaller: runtime binary acquisition via manifest/repo/SourceForge fallback
  - TFPCInstaller: DI-friendly installer facade used by focused unit tests

  Binary installation still prefers manifest metadata and fpdev-repo binaries,
  while keeping the legacy SourceForge fallback for unsupported runtime paths.

  Mirror configuration:
    China users: fpdev system config set mirror gitee
    Global users: fpdev system config set mirror github

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    Installer := TFPCBinaryInstaller.Create(ConfigManager);
    try
      if Installer.InstallFromBinary('3.2.2', '/opt/fpc') then
        WriteLn('Installation complete');
    finally
      Installer.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs,
  fpdev.hash, fpdev.resource.repo,
  fpdev.paths, fpdev.toolchain.fetcher, fpdev.build.cache,
  fpdev.fpc.types, fpdev.fpc.interfaces, fpdev.fpc.version,
  fpdev.fpc.builder, fpdev.fpc.builder.di, fpdev.config,
  fpdev.fpc.installer.extract, fpdev.fpc.installer.config,
  fpdev.fpc.installer.binaryflow, fpdev.fpc.installer.downloadflow,
  fpdev.fpc.installer.environmentflow, fpdev.fpc.installer.iobridge,
  fpdev.fpc.installer.lifecycleflow,
  fpdev.fpc.installer.manifestplan, fpdev.fpc.installer.manifestflow,
  fpdev.fpc.installer.nestedflow, fpdev.fpc.installer.postinstall,
  fpdev.fpc.installer.repoflow, fpdev.fpc.installer.sourceforgeflow,
  fpdev.fpc.installer.archiveflow, fpdev.fpc.installreportflow;

type
  { TFPCBinaryInstaller - FPC binary installation service }
  TFPCBinaryInstaller = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;
    FOut: IOutput;
    FErr: IOutput;
    FCache: TBuildCache;
    FNoCache: Boolean;
    FOfflineMode: Boolean;
    FConfigGen: TFPCConfigGenerator;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;

    { Sets up the toolchain environment after installation. }
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
    function EnsureResourceRepoInitialized: Boolean;
    function RepoHasBinaryRelease(const AVersion, APlatform: string): Boolean;
    function RepoInstallBinaryRelease(const AVersion, APlatform,
      AInstallPath: string): Boolean;
    function ExtractSourceForgeLinuxTarball(const ATempFile,
      ATempDir, AInstallPath: string): Boolean;
    function ExecuteLegacyBinaryHTTPGet(const AURL, ATempFile: string;
      out ADownloadedBytes: Int64; out AError: string): Boolean;
    function ComputeFileSHA256(const AFilePath: string): string;
    function AddToolchainToConfig(const AName: string;
      const AInfo: TToolchainInfo): Boolean;
    function ExtractZipArchive(const AArchivePath, ADestPath: string;
      out AEntryCount: Integer): Boolean;
    function ExtractTarArchive(const AArchivePath, ADestPath: string;
      out AExitCode: Integer): Boolean;
    function ExtractTarGzArchive(const AArchivePath, ADestPath: string;
      out AExitCode: Integer): Boolean;

    { Installs FPC from SourceForge (fallback when fpdev-repo has no binary).
      Downloads official FPC binary package and extracts it.
      AVersion: FPC version to install
      AInstallPath: Target installation directory
      Returns: True if installation succeeded }
    function InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;

    { Installs FPC using manifest system with multi-mirror support and SHA512 verification.
      AVersion: FPC version to install
      AInstallPath: Target installation directory
      Returns: True if installation succeeded }
    function InstallFromManifest(const AVersion, AInstallPath: string): Boolean;
    function PrepareManifestInstallPlan(const AVersion: string;
      out APlan: TFPCManifestInstallPlan; out AError: string): Boolean;
    function FetchManifestDownload(const APlan: TFPCManifestInstallPlan;
      out AError: string): Boolean;

    { Extracts nested FPC binary package from an outer TAR directory.
      Official FPC packages have a two/three-level nesting:
        outer.tar → subdir/binary.ARCH.tar → base.ARCH.tar.gz → actual binaries
      ATempDir: Directory containing the outer TAR extraction
      AInstallPath: Final installation directory
      ATempFile: Original downloaded archive path (used for fallback direct extraction)
      Returns: True if extraction succeeded }
    function ExtractNestedFPCPackage(const ATempDir, AInstallPath, ATempFile: string): Boolean;

    { Attempts to install FPC via fpdev-repo (GitHub/Gitee mirrors).
      Initializes FResourceRepo if needed, checks for binary release, and installs.
      AVersion: FPC version to install
      APlatform: Target platform string (e.g. 'linux-x86_64')
      AInstallPath: Target installation directory
      Returns: True if installation from fpdev-repo succeeded }
    function TryInstallFromRepo(const AVersion, APlatform, AInstallPath: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager;
      AOut: IOutput = nil; AErr: IOutput = nil);
    destructor Destroy; override;

    { DEPRECATED: Gets the download URL for a binary FPC package.
      This method is kept for backward compatibility only.
      New code should use InstallFromBinary which downloads from fpdev-repo.
      AVersion: FPC version to download
      Returns: Platform-specific URL (legacy SourceForge format) }
    function GetBinaryDownloadURL(const AVersion: string): string; deprecated 'Use InstallFromBinary instead';

    { DEPRECATED: Downloads a binary FPC package from legacy sources.
      This method is kept for backward compatibility only.
      New code should use InstallFromBinary which downloads from fpdev-repo.
      AVersion: FPC version to download
      ATempFile: Output path where file was saved
      Returns: True if download succeeded }
    function DownloadBinary(
      const AVersion: string;
      out ATempFile: string
    ): Boolean; deprecated 'Use InstallFromBinary instead';

    { Non-deprecated legacy helpers (SourceForge fallback internals).
      Use these inside implementation to avoid deprecated self-calls. }
    function GetBinaryDownloadURLLegacy(const AVersion: string): string;
    function DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;

    { Verifies checksum of downloaded file.
      AFilePath: Path to file to verify
      AVersion: FPC version (for hash lookup)
      Returns: True if verification succeeded }
    function VerifyChecksum(const AFilePath, AVersion: string): Boolean;

    { Extracts an archive to destination path.
      AArchivePath: Path to archive file
      ADestPath: Destination directory
      Returns: True if extraction succeeded }
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;

    { Installs FPC from binary package.
      AVersion: FPC version to install
      APrefix: Optional custom installation path
      Returns: True if installation succeeded }
    function InstallFromBinary(const AVersion: string; const APrefix: string = ''): Boolean;

    { Sets the build cache instance for binary caching.
      ACache: Cache instance to use (nil to disable caching) }
    procedure SetCache(ACache: TBuildCache);

    { Sets whether to skip cache operations.
      ANoCache: True to skip cache save/restore }
    procedure SetNoCache(ANoCache: Boolean);

    { Sets offline mode for cache-only installation behavior. }
    procedure SetOfflineMode(AOfflineMode: Boolean);

    { Resource repository accessor for external coordination. }
    property ResourceRepo: TResourceRepository read FResourceRepo;
  end;

  { TFPCInstaller - FPC installer with dependency injection for testing }
  TFPCInstaller = class
  private
    FVersionManager: TFPCVersionManager;
    FConfigManager: TFPDevConfigManager;
    FBuilder: TFPCBuilder;
    FFileSystem: IFileSystem;
    FProcessRunner: IProcessRunner;

    function GetResolvedInstallRoot: string;
    function GetInstallDir(const AVersion: string): string;
    function DirectoryExistsAt(const APath: string): Boolean;
    function ExecuteProcess(const AExecutable: string;
      const AParams: array of string; const AWorkDir: string): TProcessResult;
  public
    constructor Create(AVersionManager: TFPCVersionManager;
      AConfigManager: TFPDevConfigManager;
      ABuilder: TFPCBuilder;
      AFileSystem: IFileSystem;
      AProcessRunner: IProcessRunner);
    destructor Destroy; override;

    { Installs FPC version }
    function InstallVersion(const AVersion: string; AFromSource: Boolean;
      const APrefix: string = ''; AEnsure: Boolean = False): TOperationResult;

    { Uninstalls FPC version }
    function UninstallVersion(const AVersion: string): TOperationResult;

    { Gets binary download URL for version }
    function GetBinaryDownloadURL(const AVersion: string): string;

    property VersionManager: TFPCVersionManager read FVersionManager;
    property ConfigManager: TFPDevConfigManager read FConfigManager;
    property Builder: TFPCBuilder read FBuilder;
    property FileSystem: IFileSystem read FFileSystem;
    property ProcessRunner: IProcessRunner read FProcessRunner;
  end;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.output.console;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

procedure WriteOfflineCacheMiss(const AVersion: string; const AErr: IOutput);
begin
  WriteFPCOfflineCacheMissReport(AVersion, AErr);
end;

procedure WriteOfflineCacheRestoreFailure(const AVersion: string;
  const AErr: IOutput);
begin
  WriteFPCOfflineCacheRestoreFailureReport(AVersion, AErr);
end;

{ TFPCBinaryInstaller }

constructor TFPCBinaryInstaller.Create(AConfigManager: IConfigManager;
  AOut: IOutput; AErr: IOutput);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;
  FCache := nil;
  FNoCache := False;
  FOfflineMode := False;

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  FConfigGen := TFPCConfigGenerator.Create(FOut);

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';
    {$ENDIF}
  end;
end;

destructor TFPCBinaryInstaller.Destroy;
begin
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  if Assigned(FConfigGen) then
    FConfigGen.Free;
  inherited Destroy;
end;

procedure TFPCBinaryInstaller.SetCache(ACache: TBuildCache);
begin
  FCache := ACache;
end;

procedure TFPCBinaryInstaller.SetNoCache(ANoCache: Boolean);
begin
  FNoCache := ANoCache;
end;

procedure TFPCBinaryInstaller.SetOfflineMode(AOfflineMode: Boolean);
begin
  FOfflineMode := AOfflineMode;
end;

function TFPCBinaryInstaller.GetVersionInstallPath(const AVersion: string): string;
begin
  // Use install-root derived path to ensure portable mode and test isolation
  Result := BuildFPCInstallDirFromInstallRoot(FInstallRoot, AVersion);
end;

function TFPCBinaryInstaller.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
var
  InstallPath: string;
begin
  if AInstallPath <> '' then
    InstallPath := AInstallPath
  else
    InstallPath := GetVersionInstallPath(AVersion);

  Result := ExecuteFPCEnvironmentRegistrationFlow(AVersion, InstallPath, FErr,
    @AddToolchainToConfig);
end;

function TFPCBinaryInstaller.AddToolchainToConfig(const AName: string;
  const AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.AddToolchain(AName, AInfo);
end;

function TFPCBinaryInstaller.EnsureResourceRepoInitialized: Boolean;
begin
  if Assigned(FResourceRepo) then
    Exit(True);

  FResourceRepo := TResourceRepository.Create(
    CreateConfigWithMirror(
      FConfigManager.GetSettingsManager.GetSettings.Mirror,
      FConfigManager.GetSettingsManager.GetSettings.CustomRepoURL
    )
  );

  Result := FResourceRepo.Initialize;
  if not Result then
  begin
    FResourceRepo.Free;
    FResourceRepo := nil;
  end;
end;

function TFPCBinaryInstaller.RepoHasBinaryRelease(const AVersion,
  APlatform: string): Boolean;
begin
  Result := Assigned(FResourceRepo) and
    FResourceRepo.HasBinaryRelease(AVersion, APlatform);
end;

function TFPCBinaryInstaller.RepoInstallBinaryRelease(const AVersion,
  APlatform, AInstallPath: string): Boolean;
begin
  Result := Assigned(FResourceRepo) and
    FResourceRepo.InstallBinaryRelease(AVersion, APlatform, AInstallPath);
end;

function TFPCBinaryInstaller.TryInstallFromRepo(const AVersion, APlatform, AInstallPath: string): Boolean;
begin
  Result := ExecuteFPCRepoInstallFlow(AVersion, APlatform, AInstallPath,
    FOut, FErr, @EnsureResourceRepoInitialized, @RepoHasBinaryRelease,
    @RepoInstallBinaryRelease);
end;

function TFPCBinaryInstaller.PrepareManifestInstallPlan(const AVersion: string;
  out APlan: TFPCManifestInstallPlan; out AError: string): Boolean;
begin
  Result := PrepareFPCManifestInstallPlan(FConfigManager, AVersion, APlan, AError);
end;

function TFPCBinaryInstaller.FetchManifestDownload(const APlan: TFPCManifestInstallPlan;
  out AError: string): Boolean;
begin
  Result := FetchFromManifest(APlan.Target, APlan.DownloadFile,
    DEFAULT_DOWNLOAD_TIMEOUT_MS, AError);
end;

function TFPCBinaryInstaller.ExtractNestedFPCPackage(const ATempDir, AInstallPath, ATempFile: string): Boolean;
begin
  Result := ExecuteFPCNestedPackageInstallFlow(ATempDir, AInstallPath,
    ATempFile, FOut, FErr, @ExtractArchive);
end;

function TFPCBinaryInstaller.ExtractSourceForgeLinuxTarball(
  const ATempFile, ATempDir, AInstallPath: string): Boolean;
begin
  Result := TFPCArchiveExtractor.ExtractLinuxFPCTarball(
    ATempFile, ATempDir, AInstallPath, FOut, FErr).Success;
end;

function TFPCBinaryInstaller.InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;
begin
  Result := ExecuteFPCSourceForgeInstallFlow(AVersion, AInstallPath,
    FOut, FErr, @DownloadBinaryLegacy, @ExtractSourceForgeLinuxTarball);
end;

function TFPCBinaryInstaller.GetBinaryDownloadURLLegacy(const AVersion: string): string;
begin
  Result := ResolveFPCLegacyBinaryDownloadURL(AVersion);
end;

function TFPCBinaryInstaller.GetBinaryDownloadURL(const AVersion: string): string;
begin
  Result := GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCBinaryInstaller.ExecuteLegacyBinaryHTTPGet(const AURL, ATempFile: string;
  out ADownloadedBytes: Int64; out AError: string): Boolean;
begin
  Result := ExecuteFPCLegacyBinaryHTTPGetBridge(AURL, ATempFile,
    ADownloadedBytes, AError);
end;

function TFPCBinaryInstaller.DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := ExecuteFPCLegacyBinaryDownloadFlow(AVersion, FOut, FErr,
    @ExecuteLegacyBinaryHTTPGet, ATempFile);
end;

function TFPCBinaryInstaller.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCBinaryInstaller.ComputeFileSHA256(const AFilePath: string): string;
begin
  Result := SHA256FileHex(AFilePath);
end;

function TFPCBinaryInstaller.VerifyChecksum(const AFilePath, AVersion: string): Boolean;
begin
  Result := ExecuteFPCLegacyBinaryVerifyFlow(AFilePath, AVersion, FOut, FErr,
    @ComputeFileSHA256);
end;

function TFPCBinaryInstaller.ExtractZipArchive(const AArchivePath,
  ADestPath: string; out AEntryCount: Integer): Boolean;
begin
  Result := ExecuteFPCZipExtractBridge(AArchivePath, ADestPath, AEntryCount);
end;

function TFPCBinaryInstaller.ExtractTarArchive(const AArchivePath,
  ADestPath: string; out AExitCode: Integer): Boolean;
begin
  Result := ExecuteFPCTarExtractBridge(AArchivePath, ADestPath, AExitCode);
end;

function TFPCBinaryInstaller.ExtractTarGzArchive(const AArchivePath,
  ADestPath: string; out AExitCode: Integer): Boolean;
begin
  Result := ExecuteFPCTarGzExtractBridge(AArchivePath, ADestPath, AExitCode);
end;

function TFPCBinaryInstaller.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
begin
  Result := ExecuteFPCInstallerArchiveFlow(AArchivePath, ADestPath,
    FOut, FErr, @ExtractZipArchive, @ExtractTarArchive, @ExtractTarGzArchive);
end;

function TFPCBinaryInstaller.InstallFromBinary(const AVersion: string; const APrefix: string): Boolean;
var
  InstallPath: string;
  Platform: string;
  PostInstallActions: TFPCBinaryPostInstallActions;
  CacheAvailable: Boolean;
begin
  Result := False;

  try
    if APrefix <> '' then
      InstallPath := ExpandFileName(APrefix)
    else
      InstallPath := GetVersionInstallPath(AVersion);

    CacheAvailable := Assigned(FCache) and (not FNoCache);
    if CacheAvailable then
    begin
      if FCache.HasArtifacts(AVersion) then
      begin
        WriteLine(FOut, '[CACHE HIT] Found cached artifact for FPC ' + AVersion);
        WriteLine(FOut, '[CACHE] Restoring from cache to: ' + InstallPath);
        if FCache.RestoreArtifacts(AVersion, InstallPath) then
        begin
          if not EnsureManagedFPCInstallLayout(InstallPath, AVersion, FOut) then
          begin
            FErr.WriteLn(_(MSG_ERROR) + ': InstallFromBinary failed - managed install layout incomplete');
            Exit(False);
          end;

          if SetupEnvironment(AVersion, InstallPath) then
            WriteLine(FOut, '[OK] Toolchain registered successfully')
          else
            WriteLine(FOut, '[WARN] Failed to register toolchain (non-fatal)');

          Result := True;
          Exit;
        end;

        if FOfflineMode then
        begin
          WriteOfflineCacheRestoreFailure(AVersion, FErr);
          Exit(False);
        end;

        WriteLine(FOut, '[WARN] Cache restoration failed, proceeding with download...');
      end
      else if FOfflineMode then
      begin
        WriteOfflineCacheMiss(AVersion, FErr);
        Exit(False);
      end;
    end
    else if FOfflineMode then
    begin
      WriteOfflineCacheMiss(AVersion, FErr);
      Exit(False);
    end;

    Platform := GetCurrentPlatform;

    if not ExecuteFPCBinaryInstallFlow(AVersion, Platform, InstallPath, FOut, FErr,
      @InstallFromManifest, @TryInstallFromRepo, @InstallFromSourceForge) then
      Exit;

    PostInstallActions := ExecuteFPCBinaryPostInstall(AVersion, InstallPath, FOut, FErr,
      FConfigGen, @SetupEnvironment, FCache, FNoCache);

    if not PostInstallActions.ConfigGenerated then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallFromBinary failed - managed install layout incomplete');
      Exit(False);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallFromBinary failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCBinaryInstaller.InstallFromManifest(const AVersion, AInstallPath: string): Boolean;
begin
  Result := ExecuteFPCManifestInstallFlow(AVersion, AInstallPath, FOut, FErr,
    @PrepareManifestInstallPlan, @FetchManifestDownload, @ExtractArchive,
    @ExtractNestedFPCPackage);
end;

{ TFPCInstaller }

constructor TFPCInstaller.Create(AVersionManager: TFPCVersionManager;
  AConfigManager: TFPDevConfigManager;
  ABuilder: TFPCBuilder;
  AFileSystem: IFileSystem;
  AProcessRunner: IProcessRunner);
begin
  inherited Create;
  FVersionManager := AVersionManager;
  FConfigManager := AConfigManager;
  FBuilder := ABuilder;
  FFileSystem := AFileSystem;
  FProcessRunner := AProcessRunner;
end;

destructor TFPCInstaller.Destroy;
begin
  inherited Destroy;
end;

function TFPCInstaller.GetInstallDir(const AVersion: string): string;
begin
  Result := ResolveFPCInstallerVersionInstallDirCore(
    GetResolvedInstallRoot,
    AVersion
  );
end;

function TFPCInstaller.DirectoryExistsAt(const APath: string): Boolean;
begin
  Result := Assigned(FFileSystem) and FFileSystem.DirectoryExists(APath);
end;

function TFPCInstaller.ExecuteProcess(const AExecutable: string;
  const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  if Assigned(FProcessRunner) then
    Exit(FProcessRunner.Execute(AExecutable, AParams, AWorkDir));

  Result.ExitCode := 1;
  Result.StdOut := '';
  Result.StdErr := 'Process runner unavailable';
  Result.Success := False;
end;

function TFPCInstaller.GetResolvedInstallRoot: string;
var
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettings;
  Result := ResolveFPCInstallerInstallRootCore(Settings);
end;

function TFPCInstaller.InstallVersion(const AVersion: string; AFromSource: Boolean;
  const APrefix: string; AEnsure: Boolean): TOperationResult;
var
  State: TFPCInstallerInstallState;
begin
  State.Version := AVersion;
  State.InstallRoot := GetResolvedInstallRoot;
  State.Prefix := APrefix;
  State.FromSource := AFromSource;
  State.Ensure := AEnsure;

  Result := ExecuteFPCInstallerInstallCore(
    State,
    @FVersionManager.ValidateVersion,
    @DirectoryExistsAt,
    @FBuilder.DownloadSource,
    @FBuilder.BuildFromSource
  );
end;

function TFPCInstaller.UninstallVersion(const AVersion: string): TOperationResult;
begin
  Result := ExecuteFPCInstallerUninstallCore(
    GetInstallDir(AVersion),
    @DirectoryExistsAt,
    @ExecuteProcess
  );
end;

function TFPCInstaller.GetBinaryDownloadURL(const AVersion: string): string;
const
  SOURCEFORGE_FILES_BASE = 'https://sourceforge.net/projects/freepascal/files/';
  SOURCEFORGE_FPC_FILE_PREFIX = '/fpc-';
begin
  // Generate SourceForge URL for binary download
  Result := SOURCEFORGE_FILES_BASE;

  {$IFDEF MSWINDOWS}
    {$IFDEF CPU64}
    Result := Result + 'Win64/' + AVersion + SOURCEFORGE_FPC_FILE_PREFIX +
      AVersion + '.x86_64-win64.exe';
    {$ELSE}
    Result := Result + 'Win32/' + AVersion + SOURCEFORGE_FPC_FILE_PREFIX +
      AVersion + '.i386-win32.exe';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPU64}
    Result := Result + 'Linux/' + AVersion + SOURCEFORGE_FPC_FILE_PREFIX +
      AVersion + '.x86_64-linux.tar';
    {$ELSE}
    Result := Result + 'Linux/' + AVersion + SOURCEFORGE_FPC_FILE_PREFIX +
      AVersion + '.i386-linux.tar';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPU64}
    Result := Result + 'macOS/' + AVersion + SOURCEFORGE_FPC_FILE_PREFIX +
      AVersion + '.x86_64-macosx.dmg';
    {$ELSE}
    Result := Result + 'macOS/' + AVersion + SOURCEFORGE_FPC_FILE_PREFIX +
      AVersion + '.i386-macosx.dmg';
    {$ENDIF}
  {$ENDIF}
end;

end.
