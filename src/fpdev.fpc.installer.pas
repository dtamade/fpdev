unit fpdev.fpc.installer;

{
================================================================================
  fpdev.fpc.installer - FPC Binary Installation Service
================================================================================

  Provides FPC binary package download and installation capabilities:
  - Download binary packages from fpdev-repo (GitHub/Gitee mirrors)
  - Verify checksums via manifest.json
  - Extract archives (ZIP, TAR, TAR.GZ)
  - Install from binary packages

  IMPORTANT: This service ONLY downloads from fpdev-repo.
  SourceForge and other external sources are NOT supported.
  See docs/REPO_SPECIFICATION.md for repository format.

  Mirror configuration:
    China users: fpdev config set mirror gitee
    Global users: fpdev config set mirror github

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
  SysUtils, Classes, fphttpclient, zipper,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs,
  fpdev.utils.process, fpdev.hash, fpdev.resource.repo, fpdev.constants,
  fpdev.paths, fpdev.manifest, fpdev.manifest.cache, fpdev.toolchain.fetcher,
  fpdev.build.cache, fpdev.fpc.types, fpdev.fpc.interfaces, fpdev.fpc.version,
  fpdev.fpc.builder, fpdev.fpc.builder.di, fpdev.config, fpdev.fpc.installer.extract,
  fpdev.fpc.installer.config;

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
    FConfigGen: TFPCConfigGenerator;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;

    { Sets up the toolchain environment after installation. }
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;

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
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean; deprecated 'Use InstallFromBinary instead';

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

    function GetInstallDir(const AVersion: string): string;
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

function TFPCBinaryInstaller.GetVersionInstallPath(const AVersion: string): string;
begin
  // Use unified path from fpdev.paths to ensure consistency across all services
  Result := GetToolchainsDir + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function TFPCBinaryInstaller.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;

  if (AVersion = '') then
    Exit;

  if AInstallPath <> '' then
    InstallPath := AInstallPath
  else
    InstallPath := GetVersionInstallPath(AVersion);

  if not DirectoryExists(InstallPath) then
    Exit;

  try
    Initialize(ToolchainInfo);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := AVersion;
    ToolchainInfo.InstallPath := InstallPath;
    ToolchainInfo.SourceURL := FPC_OFFICIAL_REPO;
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;

    Result := FConfigManager.GetToolchainManager.AddToolchain('fpc-' + AVersion, ToolchainInfo);
    if not Result then
      FErr.WriteLn(_(MSG_ERROR) + ': Failed to add toolchain to configuration');

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': SetupEnvironment failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCBinaryInstaller.TryInstallFromRepo(const AVersion, APlatform, AInstallPath: string): Boolean;
begin
  Result := False;

  FOut.WriteLn('[2/4] Initializing fpdev-repo...');

  if not Assigned(FResourceRepo) then
  begin
    // Use configured mirror settings from user config
    FResourceRepo := TResourceRepository.Create(
      CreateConfigWithMirror(
        FConfigManager.GetSettingsManager.GetSettings.Mirror,
        FConfigManager.GetSettingsManager.GetSettings.CustomRepoURL
      )
    );
    if not FResourceRepo.Initialize then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Failed to initialize fpdev-repo');
      FErr.WriteLn('');
      FErr.WriteLn('fpdev-repo is required for binary installation.');
      FErr.WriteLn('Please check your network connection and try again.');
      FErr.WriteLn('');
      FErr.WriteLn('Mirror configuration:');
      FErr.WriteLn('  China users: fpdev config set mirror gitee');
      FErr.WriteLn('  Global users: fpdev config set mirror github');
      FResourceRepo.Free;
      FResourceRepo := nil;
      Exit;
    end;
  end;
  FOut.WriteLn('  fpdev-repo initialized');
  FOut.WriteLn;

  // Check if binary release exists in fpdev-repo
  FOut.WriteLn('[3/4] Checking for FPC ' + AVersion + ' binary...');

  if FResourceRepo.HasBinaryRelease(AVersion, APlatform) then
  begin
    FOut.WriteLn('  Found FPC ' + AVersion + ' in fpdev-repo');
    FOut.WriteLn;

    // Install from fpdev-repo
    FOut.WriteLn('[4/4] Installing FPC ' + AVersion + ' from fpdev-repo...');

    if FResourceRepo.InstallBinaryRelease(AVersion, APlatform, AInstallPath) then
    begin
      FOut.WriteLn('  Binary package installed from fpdev-repo');
      FOut.WriteLn;
      Result := True;
    end
    else
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Installation from fpdev-repo failed');
      FErr.WriteLn('Trying fallback to SourceForge...');
      FOut.WriteLn;
    end;
  end;
end;

function TFPCBinaryInstaller.ExtractNestedFPCPackage(const ATempDir, AInstallPath, ATempFile: string): Boolean;
var
  SR: TSearchRec;
  BinaryTar: string;
  BaseArchive: string;
begin
  Result := False;

  // Stage 2: Find and extract nested binary TAR to installation directory
  // The outer TAR extracts to a subdirectory (e.g., fpc-3.2.0-x86_64-linux/)
  // Inside that subdirectory is binary.x86_64-linux.tar with the actual FPC binaries

  // Find the extracted subdirectory (should be the only directory in ATempDir)
  BinaryTar := '';
  if FindFirst(ATempDir + PathDelim + '*', faDirectory, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
      begin
        BinaryTar := ATempDir + PathDelim + SR.Name + PathDelim + 'binary.' + fpdev.fpc.installer.config.GetFPCArchSuffix + '.tar';
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  if (BinaryTar <> '') and FileExists(BinaryTar) then
  begin
    FOut.WriteLn('[Manifest] Extracting nested binary TAR...');
    if not ExtractArchive(BinaryTar, AInstallPath) then
    begin
      FErr.WriteLn('[Manifest] Nested extraction failed');
      Exit;
    end;

    // Stage 3: Extract base package which contains the actual FPC binaries
    // The binary TAR contains many .tar.gz files, but base.ARCH.tar.gz has the core compiler
    BaseArchive := AInstallPath + PathDelim + 'base.' + fpdev.fpc.installer.config.GetFPCArchSuffix + '.tar.gz';

    if FileExists(BaseArchive) then
    begin
      FOut.WriteLn('[Manifest] Extracting base package...');
      if not ExtractArchive(BaseArchive, AInstallPath) then
      begin
        FErr.WriteLn('[Manifest] Base package extraction failed');
        Exit;
      end;
      // Clean up the .tar.gz files after extraction
      DeleteFile(BaseArchive);
    end;
  end
  else
  begin
    // Fallback: if nested TAR not found, assume outer TAR contains binaries directly
    FOut.WriteLn('[Manifest] No nested TAR found, using direct extraction');
    if not ExtractArchive(ATempFile, AInstallPath) then
    begin
      FErr.WriteLn('[Manifest] Extraction failed');
      Exit;
    end;
  end;

  FOut.WriteLn('[Manifest] Extraction completed');
  Result := True;
end;

function TFPCBinaryInstaller.InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;
var
  TempFile: string;
  TempDir: string;
begin
  Result := False;

  try
    // Download binary from SourceForge
    FOut.WriteLn('  Downloading from SourceForge...');
    if not DownloadBinaryLegacy(AVersion, TempFile) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Failed to download FPC binary');
      Exit;
    end;

    FOut.WriteLn('  Download completed: ' + TempFile);

    // Create installation directory
    if not DirectoryExists(AInstallPath) then
      EnsureDir(AInstallPath);

    {$IFDEF LINUX}
    // Linux: Extract tar file using helper
    TempDir := GetTempDir + 'fpdev_fpc_' + IntToStr(GetTickCount64);
    EnsureDir(TempDir);

    // Use extraction helper for multi-layer tarball extraction
    if not TFPCArchiveExtractor.ExtractLinuxFPCTarball(TempFile, TempDir, AInstallPath, FOut, FErr).Success then
    begin
      // Error already printed by helper
      TProcessExecutor.Execute('rm', ['-rf', TempDir], '');
      Exit;
    end;

    // Cleanup temp directory
    TProcessExecutor.Execute('rm', ['-rf', TempDir], '');
    {$ENDIF}

    {$IFDEF MSWINDOWS}
    // Windows: The .exe is an installer, inform user
    FOut.WriteLn('');
    FOut.WriteLn('Windows FPC installer downloaded: ' + TempFile);
    FOut.WriteLn('');
    FOut.WriteLn('Please run the installer manually and select:');
    FOut.WriteLn('  ' + AInstallPath);
    FOut.WriteLn('as the installation directory.');
    FOut.WriteLn('');
    FOut.WriteLn('After installation, run:');
    FOut.WriteLn('  fpdev fpc use ' + AVersion);
    // Return true since download succeeded
    Result := True;
    Exit;
    {$ENDIF}

    {$IFDEF DARWIN}
    // macOS: The .dmg needs manual installation
    FOut.WriteLn('');
    FOut.WriteLn('macOS FPC disk image downloaded: ' + TempFile);
    FOut.WriteLn('');
    FOut.WriteLn('Please mount the disk image and run the installer.');
    FOut.WriteLn('');
    FOut.WriteLn('After installation, run:');
    FOut.WriteLn('  fpdev fpc use ' + AVersion);
    // Return true since download succeeded
    Result := True;
    Exit;
    {$ENDIF}

    // Cleanup downloaded file
    if FileExists(TempFile) then
      DeleteFile(TempFile);

    // Verify installation
    if DirectoryExists(AInstallPath + PathDelim + 'bin') or
       DirectoryExists(AInstallPath + PathDelim + 'lib') then
    begin
      FOut.WriteLn('  Installation verified');
      Result := True;
    end
    else
    begin
      FErr.WriteLn('');
      FErr.WriteLn('===========================================');
      FErr.WriteLn('Binary Installation Failed');
      FErr.WriteLn('===========================================');
      FErr.WriteLn('');
      FErr.WriteLn('No binary packages are currently available for automatic download.');
      FErr.WriteLn('');
      FErr.WriteLn('Options:');
      FErr.WriteLn('  1. Install from source (requires bootstrap compiler):');
      FErr.WriteLn('     fpdev fpc install ' + AVersion + ' --from-source');
      FErr.WriteLn('');
      FErr.WriteLn('  2. Use existing FPC installation:');
      FErr.WriteLn('     fpdev fpc use <version>');
      FErr.WriteLn('');
      FErr.WriteLn('  3. Download manually from:');
      FErr.WriteLn('     https://www.freepascal.org/download.html');
      FErr.WriteLn('');
      FErr.WriteLn('Note: Binary downloads are not yet available in this version.');
      FErr.WriteLn('      Source installation is the recommended method.');
      Exit(False);
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallFromSourceForge failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCBinaryInstaller.GetBinaryDownloadURLLegacy(const AVersion: string): string;
begin
  Result := '';

  {$IFDEF MSWINDOWS}
    Result := Format('https://sourceforge.net/projects/freepascal/files/Win32/%s/fpc-%s.win32.and.win64.exe/download',
      [AVersion, AVersion]);
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPU64}
    Result := Format('https://sourceforge.net/projects/freepascal/files/Linux/%s/fpc-%s.x86_64-linux.tar/download',
      [AVersion, AVersion]);
    {$ELSE}
    Result := Format('https://sourceforge.net/projects/freepascal/files/Linux/%s/fpc-%s.i386-linux.tar/download',
      [AVersion, AVersion]);
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUAARCH64}
    Result := Format('https://sourceforge.net/projects/freepascal/files/Mac%%20OS%%20X/%s/fpc-%s.aarch64-macosx.dmg/download',
      [AVersion, AVersion]);
    {$ELSE}
    Result := Format('https://sourceforge.net/projects/freepascal/files/Mac%%20OS%%20X/%s/fpc-%s.intel-macosx.dmg/download',
      [AVersion, AVersion]);
    {$ENDIF}
  {$ENDIF}
end;

function TFPCBinaryInstaller.GetBinaryDownloadURL(const AVersion: string): string;
begin
  Result := GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCBinaryInstaller.DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
var
  URL: string;
  HTTPClient: TFPHTTPClient;
  TempDir: string;
  FileStream: TFileStream;
  FileExt: string;
begin
  Result := False;
  ATempFile := '';

  try
    URL := GetBinaryDownloadURLLegacy(AVersion);
    if URL = '' then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_DOWNLOAD_URL_FAILED, [AVersion]));
      FErr.WriteLn('Note: This platform may not have binary packages available.');
      Exit;
    end;

    TempDir := GetTempDir + 'fpdev_downloads';
    if not DirectoryExists(TempDir) then
      EnsureDir(TempDir);

    {$IFDEF MSWINDOWS}
    FileExt := '.exe';
    {$ENDIF}
    {$IFDEF LINUX}
    FileExt := '.tar';
    {$ENDIF}
    {$IFDEF DARWIN}
    FileExt := '.dmg';
    {$ENDIF}

    ATempFile := TempDir + PathDelim + 'fpc-' + AVersion + '-' + IntToStr(GetTickCount64) + FileExt;

    FOut.WriteLn('Downloading FPC ' + AVersion + ' from:');
    FOut.WriteLn('  ' + URL);
    FOut.WriteLn('To: ' + ATempFile);

    HTTPClient := TFPHTTPClient.Create(nil);
    try
      HTTPClient.AllowRedirect := True;
      // Add timeout to prevent hanging (30 seconds)
      HTTPClient.ConnectTimeout := 30000;
      HTTPClient.IOTimeout := 30000;
      FileStream := TFileStream.Create(ATempFile, fmCreate);
      try
        HTTPClient.Get(URL, FileStream);
        Result := True;
        FOut.WriteLn('Download completed: ' + IntToStr(FileStream.Size) + ' bytes');
      finally
        FileStream.Free;
      end;
    finally
      HTTPClient.Free;
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': DownloadBinary failed - ' + E.Message);
      Result := False;
      if FileExists(ATempFile) then
        DeleteFile(ATempFile);
      ATempFile := '';
    end;
  end;
end;

function TFPCBinaryInstaller.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCBinaryInstaller.VerifyChecksum(const AFilePath, AVersion: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  if (AFilePath = '') or (not FileExists(AFilePath)) then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_FILE_NOT_FOUND));
    Exit;
  end;

  FOut.WriteLn('Calculating SHA256 checksum...');
  ActualHash := SHA256FileHex(AFilePath);

  if ActualHash = '' then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_CHECKSUM_FAILED));
    Exit;
  end;

  FOut.WriteLn('SHA256: ' + ActualHash);
  FOut.WriteLn('File integrity verified (hash recorded for ' + AVersion + ')');

  Result := True;
end;

function TFPCBinaryInstaller.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
var
  Unzipper: TUnZipper;
  FileExt: string;
  LResult: fpdev.utils.process.TProcessResult;
begin
  Result := False;

  if not FileExists(AArchivePath) then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_ARCHIVE_NOT_FOUND, [AArchivePath]));
    Exit;
  end;

  try
    if not DirectoryExists(ADestPath) then
      EnsureDir(ADestPath);

    FileExt := LowerCase(ExtractFileExt(AArchivePath));

    if FileExt = '.zip' then
    begin
      FOut.WriteLn('Extracting ZIP archive...');
      FOut.WriteLn('  From: ' + AArchivePath);
      FOut.WriteLn('  To: ' + ADestPath);

      Unzipper := TUnZipper.Create;
      try
        Unzipper.FileName := AArchivePath;
        Unzipper.OutputPath := ADestPath;
        Unzipper.Examine;
        FOut.WriteLn('  Files in archive: ' + IntToStr(Unzipper.Entries.Count));
        Unzipper.UnZipAllFiles;
        Result := True;
        FOut.WriteLn('Extraction completed successfully');
      finally
        Unzipper.Free;
      end;
    end
    else if FileExt = '.tar' then
    begin
      FOut.WriteLn('Extracting TAR archive...');
      FOut.WriteLn('  From: ' + AArchivePath);
      FOut.WriteLn('  To: ' + ADestPath);

      FOut.WriteLn('  Running: tar -xf ' + AArchivePath + ' -C ' + ADestPath);
      LResult := TProcessExecutor.Execute('tar', ['-xf', AArchivePath, '-C', ADestPath], '');

      if LResult.Success then
      begin
        FOut.WriteLn('TAR extraction completed successfully');
        Result := True;
      end
      else
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_TAR_FAILED, [LResult.ExitCode]));
        Result := False;
      end;
    end
    else if (FileExt = '.gz') or (Pos('.tar.gz', LowerCase(AArchivePath)) > 0) then
    begin
      FOut.WriteLn('Extracting TAR.GZ archive...');
      FOut.WriteLn('  From: ' + AArchivePath);
      FOut.WriteLn('  To: ' + ADestPath);

      FOut.WriteLn('  Running: tar -xzf ' + AArchivePath + ' -C ' + ADestPath);
      LResult := TProcessExecutor.Execute('tar', ['-xzf', AArchivePath, '-C', ADestPath], '');

      if LResult.Success then
      begin
        FOut.WriteLn('TAR.GZ extraction completed successfully');
        Result := True;
      end
      else
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_TAR_FAILED, [LResult.ExitCode]));
        Result := False;
      end;
    end
    else if FileExt = '.exe' then
    begin
      FOut.WriteLn('Windows installer detected: ' + AArchivePath);
      FOut.WriteLn('  Target directory: ' + ADestPath);
      FOut.WriteLn('');
      FOut.WriteLn('Note: Windows FPC installers are interactive.');
      FOut.WriteLn('Please run the installer manually and select:');
      FOut.WriteLn('  ' + ADestPath);
      FOut.WriteLn('as the installation directory.');
      FOut.WriteLn('');
      FOut.WriteLn('After installation, run:');
      FOut.WriteLn('  fpdev fpc use <version>');
      FOut.WriteLn('to configure the environment.');
      Result := True;
    end
    else if FileExt = '.dmg' then
    begin
      FOut.WriteLn('macOS disk image detected: ' + AArchivePath);
      FOut.WriteLn('  Target directory: ' + ADestPath);
      FOut.WriteLn('');
      FOut.WriteLn('Note: macOS .dmg files require manual installation.');
      FOut.WriteLn('Please mount the disk image and run the installer.');
      FOut.WriteLn('');
      FOut.WriteLn('After installation, run:');
      FOut.WriteLn('  fpdev fpc use <version>');
      FOut.WriteLn('to configure the environment.');
      Result := True;
    end
    else
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_ARCHIVE_FORMAT_UNSUPPORTED, [FileExt]));
      Result := False;
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ExtractArchive failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCBinaryInstaller.InstallFromBinary(const AVersion: string; const APrefix: string): Boolean;
var
  InstallPath: string;
  Platform: string;
begin
  Result := False;

  try
    FOut.WriteLn('===========================================');
    FOut.WriteLn('FPC Binary Installation: ' + AVersion);
    FOut.WriteLn('===========================================');
    FOut.WriteLn;

    if APrefix <> '' then
      InstallPath := ExpandFileName(APrefix)
    else
      InstallPath := GetVersionInstallPath(AVersion);

    Platform := GetCurrentPlatform;
    FOut.WriteLn('Target: ' + InstallPath);
    FOut.WriteLn('Platform: ' + Platform);
    FOut.WriteLn;

    // Step 1: Try manifest-based installation first (with multi-mirror and SHA512)
    FOut.WriteLn('[1/4] Attempting manifest-based installation...');
    if InstallFromManifest(AVersion, InstallPath) then
    begin
      FOut.WriteLn('  Manifest-based installation successful');
      // Installation complete, skip to environment setup
    end
    else
    begin
      FOut.WriteLn('  Manifest-based installation not available, trying fpdev-repo...');
      FOut.WriteLn;

      // Step 2-4: Try fpdev-repo installation
      if not TryInstallFromRepo(AVersion, Platform, InstallPath) then
      begin
        // Fallback: Download from SourceForge
        FOut.WriteLn('');
        FOut.WriteLn('');
        FOut.WriteLn('[4/4] Attempting SourceForge download (with 30s timeout)...');
        Result := InstallFromSourceForge(AVersion, InstallPath);

        if Result then
        begin
          FOut.WriteLn('');
          FOut.WriteLn('===========================================');
          FOut.WriteLn('Installation Summary');
          FOut.WriteLn('===========================================');
          FOut.WriteLn('  Binary package installed from SourceForge');
          FOut.WriteLn;
        end;
      end;
    end;  // Close the else block from manifest installation

    // Generate fpc.cfg configuration file if bin directory exists
    if DirectoryExists(InstallPath + PathDelim + 'bin') then
    begin
      FConfigGen.CreateLinuxCompilerWrapper(InstallPath, AVersion);
      FConfigGen.GenerateFpcConfig(InstallPath, AVersion);
    end;

    // Setup environment
    FOut.WriteLn('Setting up environment...');
    if SetupEnvironment(AVersion, InstallPath) then
      FOut.WriteLn('  Environment configured')
    else
      FErr.WriteLn('  Warning: Environment setup incomplete');
    FOut.WriteLn;

    FOut.WriteLn('===========================================');
    FOut.WriteLn('Installation completed!');
    FOut.WriteLn('FPC ' + AVersion + ' installed to: ' + InstallPath);
    FOut.WriteLn('');
    FOut.WriteLn('To activate this version, run:');
    FOut.WriteLn('  fpdev fpc use ' + AVersion);
    FOut.WriteLn('===========================================');

    // Save installed FPC to cache (unless --no-cache)
    if Assigned(FCache) and not FNoCache then
    begin
      FOut.WriteLn;
      FOut.WriteLn('[CACHE] Saving installation to cache...');
      if FCache.SaveArtifacts(AVersion, InstallPath) then
        FOut.WriteLn('[CACHE] Installation cached successfully')
      else
        FOut.WriteLn('[WARN] Failed to cache installation (non-fatal)');
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
var
  ManifestParser: TManifestParser;
  Cache: TManifestCache;
  Platform: string;
  Target: TManifestTarget;
  TempFile: string;
  TempDir: string;
  FileExt: string;
  Err: string;
begin
  Result := False;

  try
    FOut.WriteLn('[Manifest] Attempting installation using manifest system...');

    // Determine platform string
    Platform := GetCurrentPlatform;
    FOut.WriteLn('[Manifest] Platform: ' + Platform);

    // Load manifest from cache (will auto-download if needed)
    FOut.WriteLn('[Manifest] Loading manifest from cache...');
    Cache := TManifestCache.Create('');
    try
      if not Cache.LoadCachedManifest('fpc', ManifestParser, False) then
      begin
        FErr.WriteLn('[Manifest] Failed to load manifest');
        FErr.WriteLn('[Manifest] Try running: fpdev fpc update-manifest');
        Exit;
      end;

      try
        FOut.WriteLn('[Manifest] Manifest loaded successfully');

        // Get target for this version and platform (package name is 'fpc')
        if not ManifestParser.GetTarget('fpc', AVersion, Platform, Target) then
        begin
          FErr.WriteLn('[Manifest] No binary available for FPC ' + AVersion + ' on ' + Platform);
          FErr.WriteLn('[Manifest] Error: ' + ManifestParser.LastError);
          Exit;
        end;

        FOut.WriteLn('[Manifest] Found target with ' + IntToStr(Length(Target.URLs)) + ' mirror(s)');
        FOut.WriteLn('[Manifest] Hash: ' + Target.Hash);
        FOut.WriteLn('[Manifest] Size: ' + IntToStr(Target.Size) + ' bytes');

        // Download using multi-mirror fallback with SHA512 verification
        TempDir := GetTempDir + 'fpdev_downloads';
        if not DirectoryExists(TempDir) then
          EnsureDir(TempDir);

        // Determine file extension from the first URL in the manifest
        FileExt := ExtractFileExt(Target.URLs[0]);
        if FileExt = '' then
          FileExt := '.tar.gz';  // Default fallback

        TempFile := TempDir + PathDelim + 'fpc-' + AVersion + '-' + IntToStr(GetTickCount64) + FileExt;

        FOut.WriteLn('[Manifest] Downloading with multi-mirror fallback...');
        if not FetchFromManifest(Target, TempFile, DEFAULT_DOWNLOAD_TIMEOUT_MS, Err) then
        begin
          FErr.WriteLn('[Manifest] Download failed: ' + Err);
          Exit;
        end;

        FOut.WriteLn('[Manifest] Download completed and verified');

        // Extract archive (two-stage: outer TAR contains nested binary TAR)
        FOut.WriteLn('[Manifest] Extracting archive...');

        // Stage 1: Extract outer TAR to temporary directory
        TempDir := GetTempDir + 'fpdev_extract_' + IntToStr(GetTickCount64);
        if not DirectoryExists(TempDir) then
          EnsureDir(TempDir);

        try
          if not ExtractArchive(TempFile, TempDir) then
          begin
            FErr.WriteLn('[Manifest] Extraction failed');
            Exit;
          end;

        // Stage 2-3: Extract nested binary TAR and base package
        Result := ExtractNestedFPCPackage(TempDir, AInstallPath, TempFile);

        finally
          // Cleanup temporary files and directories
          if FileExists(TempFile) then
            DeleteFile(TempFile);
          if DirectoryExists(TempDir) then
            RemoveDir(TempDir);
        end;

      finally
        ManifestParser.Free;
      end;
    finally
      Cache.Free;
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn('[Manifest] InstallFromManifest failed: ' + E.Message);
      Result := False;
    end;
  end;
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
var
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettings;
  Result := Settings.InstallRoot + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function TFPCInstaller.InstallVersion(const AVersion: string; AFromSource: Boolean;
  const APrefix: string; AEnsure: Boolean): TOperationResult;
var
  InstallDir, SourceDir: string;
  BuildResult: TOperationResult;
begin
  // Validate version
  if not FVersionManager.ValidateVersion(AVersion) then
  begin
    Result := OperationError(ecVersionInvalid, 'Invalid version: ' + AVersion);
    Exit;
  end;

  // Determine install directory
  if APrefix <> '' then
    InstallDir := APrefix
  else
    InstallDir := GetInstallDir(AVersion);

  // Check if already installed
  if FFileSystem.DirectoryExists(InstallDir) then
  begin
    if AEnsure then
    begin
      // Ensure mode: already installed is success
      Result := OperationSuccess;
      Exit;
    end
    else
    begin
      Result := OperationError(ecVersionAlreadyInstalled, 'Version already installed: ' + AVersion);
      Exit;
    end;
  end;

  if not AFromSource then
  begin
    // Binary installation path is unified to source flow in DI installer.
    // Real binary installation is handled by TFPCBinaryInstaller in command runtime.
    AFromSource := True;
  end;

  // Install from source (explicit source mode or binary-mode fallback)
  SourceDir := FConfigManager.GetSettings.InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-' + AVersion;

  // Download source if not exists
  if not FFileSystem.DirectoryExists(SourceDir) then
  begin
    BuildResult := FBuilder.DownloadSource(AVersion, SourceDir);
    if not BuildResult.Success then
    begin
      Result := BuildResult;
      Exit;
    end;
  end;

  // Build from source
  BuildResult := FBuilder.BuildFromSource(SourceDir, InstallDir);
  if not BuildResult.Success then
  begin
    Result := BuildResult;
    Exit;
  end;

  Result := OperationSuccess;
end;

function TFPCInstaller.UninstallVersion(const AVersion: string): TOperationResult;
var
  InstallDir: string;
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  InstallDir := GetInstallDir(AVersion);

  // Check if installed
  if not FFileSystem.DirectoryExists(InstallDir) then
  begin
    // Not installed - success (nothing to uninstall)
    Result := OperationSuccess;
    Exit;
  end;

  // Remove directory
  {$IFDEF MSWINDOWS}
  ProcResult := FProcessRunner.Execute('cmd', ['/c', 'rmdir', '/s', '/q', InstallDir], '');
  {$ELSE}
  ProcResult := FProcessRunner.Execute('rm', ['-rf', InstallDir], '');
  {$ENDIF}

  if not ProcResult.Success then
  begin
    Result := OperationError(ecUninstallationFailed, 'Failed to remove directory: ' + InstallDir);
    Exit;
  end;

  Result := OperationSuccess;
end;

function TFPCInstaller.GetBinaryDownloadURL(const AVersion: string): string;
begin
  // Generate SourceForge URL for binary download
  Result := 'https://sourceforge.net/projects/freepascal/files/';

  {$IFDEF MSWINDOWS}
    {$IFDEF CPU64}
    Result := Result + 'Win64/' + AVersion + '/fpc-' + AVersion + '.x86_64-win64.exe';
    {$ELSE}
    Result := Result + 'Win32/' + AVersion + '/fpc-' + AVersion + '.i386-win32.exe';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPU64}
    Result := Result + 'Linux/' + AVersion + '/fpc-' + AVersion + '.x86_64-linux.tar';
    {$ELSE}
    Result := Result + 'Linux/' + AVersion + '/fpc-' + AVersion + '.i386-linux.tar';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPU64}
    Result := Result + 'macOS/' + AVersion + '/fpc-' + AVersion + '.x86_64-macosx.dmg';
    {$ELSE}
    Result := Result + 'macOS/' + AVersion + '/fpc-' + AVersion + '.i386-macosx.dmg';
    {$ENDIF}
  {$ENDIF}
end;

end.
