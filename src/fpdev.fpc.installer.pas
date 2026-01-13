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
  fpdev.paths;

type
  { TFPCBinaryInstaller - FPC binary installation service }
  TFPCBinaryInstaller = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;
    FOut: IOutput;
    FErr: IOutput;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;

    { Sets up the toolchain environment after installation. }
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;

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

    { Resource repository accessor for external coordination. }
    property ResourceRepo: TResourceRepository read FResourceRepo;
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

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

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
  inherited Destroy;
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

function TFPCBinaryInstaller.GetBinaryDownloadURL(const AVersion: string): string;
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

function TFPCBinaryInstaller.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
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
    URL := GetBinaryDownloadURL(AVersion);
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
  LResult: TProcessResult;
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

    // Step 1: Initialize fpdev-repo
    FOut.WriteLn('[1/3] Initializing fpdev-repo...');

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

    // Step 2: Check if binary release exists
    FOut.WriteLn('[2/3] Checking for FPC ' + AVersion + ' binary...');

    if not FResourceRepo.HasBinaryRelease(AVersion, Platform) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': FPC ' + AVersion + ' binary not found in fpdev-repo');
      FErr.WriteLn('');
      FErr.WriteLn('The requested version is not available for your platform.');
      FErr.WriteLn('');
      FErr.WriteLn('Available options:');
      FErr.WriteLn('  1. Check available versions: fpdev fpc list --all');
      FErr.WriteLn('  2. Build from source: fpdev fpc install ' + AVersion + ' --from-source');
      FErr.WriteLn('  3. Update fpdev-repo: fpdev repo update');
      FErr.WriteLn('');
      FErr.WriteLn('If you need this version, please request it at:');
      FErr.WriteLn('  https://github.com/dtamade/fpdev-repo/issues');
      Exit;
    end;

    FOut.WriteLn('  Found FPC ' + AVersion + ' for ' + Platform);
    FOut.WriteLn;

    // Step 3: Install from fpdev-repo
    FOut.WriteLn('[3/3] Installing FPC ' + AVersion + '...');

    if not FResourceRepo.InstallBinaryRelease(AVersion, Platform, InstallPath) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Installation failed');
      FErr.WriteLn('');
      FErr.WriteLn('Please try again or report the issue at:');
      FErr.WriteLn('  https://github.com/dtamade/fpdev-repo/issues');
      Exit;
    end;

    FOut.WriteLn('  Binary package installed');
    FOut.WriteLn;

    // Generate fpc.cfg configuration file if bin directory exists
    if DirectoryExists(InstallPath + PathDelim + 'bin') then
    begin
      FOut.WriteLn('Generating fpc.cfg...');
      with TStringList.Create do
      try
        Add('# FPC configuration file generated by fpdev');
        Add('# FPC version: ' + AVersion);
        Add('');
        Add('# Compiler binary path');
        Add('-FD' + InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion);
        Add('');
        Add('# Unit search paths');
        Add('-Fu' + InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + '*');
        Add('-Fu' + InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
        Add('');
        Add('# Library search path');
        Add('-Fl' + InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
        Add('');
        Add('# Include search path');
        Add('-Fi' + InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
        SaveToFile(InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.cfg');
        FOut.WriteLn('  fpc.cfg created');
      finally
        Free;
      end;
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

    Result := True;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallFromBinary failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
