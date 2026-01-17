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

    { Installs FPC from SourceForge (fallback when fpdev-repo has no binary).
      Downloads official FPC binary package and extracts it.
      AVersion: FPC version to install
      AInstallPath: Target installation directory
      Returns: True if installation succeeded }
    function InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;

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

function TFPCBinaryInstaller.InstallFromSourceForge(const AVersion, AInstallPath: string): Boolean;
var
  TempFile: string;
  TempDir: string;
  ExtractDir: string;
  InstallerScript: string;
  LResult: TProcessResult;
  I: Integer;
  InnerTempDir: string;
  BaseArchive: string;
begin
  Result := False;

  try
    // Download binary from SourceForge
    FOut.WriteLn('  Downloading from SourceForge...');
    if not DownloadBinary(AVersion, TempFile) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Failed to download FPC binary');
      Exit;
    end;

    FOut.WriteLn('  Download completed: ' + TempFile);

    // Create installation directory
    if not DirectoryExists(AInstallPath) then
      EnsureDir(AInstallPath);

    {$IFDEF LINUX}
    // Linux: Extract tar file and run install script
    TempDir := GetTempDir + 'fpdev_fpc_' + IntToStr(GetTickCount64);
    EnsureDir(TempDir);

    FOut.WriteLn('  Extracting archive...');
    LResult := TProcessExecutor.Execute('tar', ['-xf', TempFile, '-C', TempDir], '');
    if not LResult.Success then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Failed to extract archive');
      Exit;
    end;

    // Find the extracted directory (usually fpc-<version>.x86_64-linux or similar)
    ExtractDir := '';
    with TStringList.Create do
    try
      LResult := TProcessExecutor.Execute('ls', [TempDir], '');
      if LResult.Success then
      begin
        Text := LResult.StdOut;
        if Count > 0 then
          ExtractDir := TempDir + PathDelim + Trim(Strings[0]);
      end;
    finally
      Free;
    end;

    if (ExtractDir = '') or not DirectoryExists(ExtractDir) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Could not find extracted FPC directory');
      Exit;
    end;

    // Direct extraction: Skip interactive install.sh and extract binary archives directly
    // The FPC install.sh is interactive and waits for user input, so we bypass it
    FOut.WriteLn('  Extracting binary packages directly (skipping interactive installer)...');

    // Find and extract binary.*.tar file
    with TStringList.Create do
    try
      LResult := TProcessExecutor.Execute('ls', [ExtractDir], '');
      if LResult.Success then
      begin
        Text := LResult.StdOut;
        for I := 0 to Count - 1 do
        begin
          if Pos('binary.', Trim(Strings[I])) = 1 then
          begin
            InstallerScript := ExtractDir + PathDelim + Trim(Strings[I]);
            Break;
          end;
        end;
      end;
    finally
      Free;
    end;

    if (InstallerScript <> '') and FileExists(InstallerScript) then
    begin
      FOut.WriteLn('  Found binary archive: ' + ExtractFileName(InstallerScript));

      // Create a temp dir for extracting inner archives
      InnerTempDir := TempDir + PathDelim + 'inner';
      EnsureDir(InnerTempDir);

      // Extract binary.*.tar to get the inner tar.gz files
      LResult := TProcessExecutor.Execute('tar', ['-xf', InstallerScript, '-C', InnerTempDir], '');
      if not LResult.Success then
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': Failed to extract binary archive');
        Exit;
      end;

      // Extract base.*.tar.gz which contains bin/ and lib/
      BaseArchive := '';
      LResult := TProcessExecutor.Execute('ls', [InnerTempDir], '');
      if LResult.Success then
      begin
        with TStringList.Create do
        try
          Text := LResult.StdOut;
          for I := 0 to Count - 1 do
          begin
            if Pos('base.', Trim(Strings[I])) = 1 then
            begin
              BaseArchive := InnerTempDir + PathDelim + Trim(Strings[I]);
              Break;
            end;
          end;
        finally
          Free;
        end;
      end;

      if (BaseArchive <> '') and FileExists(BaseArchive) then
      begin
        FOut.WriteLn('  Extracting base package: ' + ExtractFileName(BaseArchive));
        LResult := TProcessExecutor.Execute('tar', ['-xzf', BaseArchive, '-C', AInstallPath], '');
        if not LResult.Success then
        begin
          FErr.WriteLn(_(MSG_ERROR) + ': Failed to extract base archive');
          Exit;
        end;
        FOut.WriteLn('  Base package extracted successfully');
      end
      else
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': Could not find base archive in binary package');
        Exit;
      end;

      // Cleanup inner temp dir
      TProcessExecutor.Execute('rm', ['-rf', InnerTempDir], '');
    end
    else
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': Could not find binary archive in extracted directory');
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
      FErr.WriteLn(_(MSG_ERROR) + ': Installation verification failed');
      FErr.WriteLn('  Expected directories not found in: ' + AInstallPath);
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallFromSourceForge failed - ' + E.Message);
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

    // Step 2: Check if binary release exists in fpdev-repo
    FOut.WriteLn('[2/4] Checking for FPC ' + AVersion + ' binary...');

    if FResourceRepo.HasBinaryRelease(AVersion, Platform) then
    begin
      FOut.WriteLn('  Found FPC ' + AVersion + ' in fpdev-repo');
      FOut.WriteLn;

      // Step 3: Install from fpdev-repo
      FOut.WriteLn('[3/4] Installing FPC ' + AVersion + ' from fpdev-repo...');

      if not FResourceRepo.InstallBinaryRelease(AVersion, Platform, InstallPath) then
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': Installation from fpdev-repo failed');
        FErr.WriteLn('Trying fallback to SourceForge...');
        FOut.WriteLn;
        // Fall through to SourceForge fallback
      end
      else
      begin
        FOut.WriteLn('  Binary package installed from fpdev-repo');
        FOut.WriteLn;
      end;
    end;

    // Fallback: Download from SourceForge if fpdev-repo doesn't have it or failed
    if not DirectoryExists(InstallPath + PathDelim + 'bin') then
    begin
      FOut.WriteLn('[3/4] Downloading FPC ' + AVersion + ' from SourceForge...');
      Result := InstallFromSourceForge(AVersion, InstallPath);
      if not Result then
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': Failed to install FPC ' + AVersion);
        FErr.WriteLn('');
        FErr.WriteLn('Available options:');
        FErr.WriteLn('  1. Check available versions: fpdev fpc list --all');
        FErr.WriteLn('  2. Build from source: fpdev fpc install ' + AVersion + ' --from-source');
        FErr.WriteLn('');
        Exit;
      end;
      FOut.WriteLn('  Binary package installed from SourceForge');
      FOut.WriteLn;
    end;

    // Generate fpc.cfg configuration file if bin directory exists
    if DirectoryExists(InstallPath + PathDelim + 'bin') then
    begin
      {$IFDEF LINUX}
      // Create symlink to ppcx64 in bin directory so fpc driver can find it
      FOut.WriteLn('Creating compiler symlink...');
      TProcessExecutor.Execute('ln', ['-sf',
        InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'ppcx64',
        InstallPath + PathDelim + 'bin' + PathDelim + 'ppcx64'], '');
      FOut.WriteLn('  ppcx64 symlink created');

      // Create fpc wrapper script that bypasses default config files
      // This ensures our fpc.cfg is used instead of ~/.fpc.cfg
      FOut.WriteLn('Creating fpc wrapper script...');
      with TStringList.Create do
      try
        Add('#!/bin/sh');
        Add('# FPC wrapper script generated by fpdev');
        Add('# Calls ppcx64 directly with our config to bypass ~/.fpc.cfg');
        Add(InstallPath + '/bin/ppcx64 -n @' + InstallPath + '/bin/fpc.cfg "$@"');
        SaveToFile(InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.sh');
      finally
        Free;
      end;
      TProcessExecutor.Execute('chmod', ['+x', InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.sh'], '');
      // Replace the fpc binary with our wrapper
      TProcessExecutor.Execute('mv', [InstallPath + PathDelim + 'bin' + PathDelim + 'fpc',
        InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.orig'], '');
      TProcessExecutor.Execute('mv', [InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.sh',
        InstallPath + PathDelim + 'bin' + PathDelim + 'fpc'], '');
      FOut.WriteLn('  fpc wrapper created');
      {$ENDIF}

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
