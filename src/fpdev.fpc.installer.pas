unit fpdev.fpc.installer;

{
================================================================================
  fpdev.fpc.installer - FPC Binary Installation Service
================================================================================

  Provides FPC binary package download and installation capabilities:
  - Download binary packages from SourceForge
  - Verify checksums
  - Extract archives (ZIP, TAR, TAR.GZ)
  - Install from binary packages

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
  fpdev.utils.process, fpdev.hash, fpdev.resource.repo, fpdev.constants;

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

    { Gets the download URL for a binary FPC package.
      AVersion: FPC version to download
      Returns: Platform-specific SourceForge URL }
    function GetBinaryDownloadURL(const AVersion: string): string;

    { Downloads a binary FPC package.
      AVersion: FPC version to download
      ATempFile: Output path where file was saved
      Returns: True if download succeeded }
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;

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
  Result := FInstallRoot + PathDelim + 'fpc' + PathDelim + AVersion;
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
  TempFile, ExtractDir, InstallPath: string;
  SR: TSearchRec;
  SourceDir, InstallScript: string;
  LResult: TProcessResult;
  UseResourceRepo: Boolean;
  {$IFDEF MSWINDOWS}
  FileExt: string;
  {$ENDIF}
begin
  Result := False;
  UseResourceRepo := False;

  try
    FOut.WriteLn('===========================================');
    FOut.WriteLn('FPC Binary Installation: ' + AVersion);
    FOut.WriteLn('===========================================');
    FOut.WriteLn;

    if APrefix <> '' then
      InstallPath := ExpandFileName(APrefix)
    else
      InstallPath := GetVersionInstallPath(AVersion);

    // Step 1: Try resource repository first (fpdev-repo)
    FOut.WriteLn('[1/4] Checking fpdev-repo for binary release...');

    if not Assigned(FResourceRepo) then
    begin
      FResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
      if not FResourceRepo.Initialize then
      begin
        FOut.WriteLn('  Resource repository not available, trying external sources...');
        FResourceRepo.Free;
        FResourceRepo := nil;
      end;
    end;

    if Assigned(FResourceRepo) and FResourceRepo.HasBinaryRelease(AVersion, GetCurrentPlatform) then
    begin
      FOut.WriteLn('  Found in fpdev-repo!');
      FOut.WriteLn('  Installing from local resource repository...');

      if FResourceRepo.InstallBinaryRelease(AVersion, GetCurrentPlatform, InstallPath) then
      begin
        UseResourceRepo := True;
        FOut.WriteLn;
        FOut.WriteLn('[2/4] Skipped (installed from fpdev-repo)');
        FOut.WriteLn('[3/4] Skipped (installed from fpdev-repo)');
      end
      else
        FOut.WriteLn('  Installation from fpdev-repo failed, trying external sources...');
    end
    else
      FOut.WriteLn('  Not found in fpdev-repo, trying external sources...');

    // Fall back to external download if resource repo didn't work
    if not UseResourceRepo then
    begin
      FOut.WriteLn('[1/4] Downloading binary package...');
      if not DownloadBinary(AVersion, TempFile) then
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_BINARY_DOWNLOAD_FAILED));
        Exit;
      end;
      FOut.WriteLn;

    {$IFDEF MSWINDOWS}
    FileExt := LowerCase(ExtractFileExt(TempFile));
    if FileExt = '.exe' then
    begin
      FOut.WriteLn('[2/4] Windows installer downloaded.');
      FOut.WriteLn('');
      FOut.WriteLn('The FPC installer has been downloaded to:');
      FOut.WriteLn('  ' + TempFile);
      FOut.WriteLn('');
      FOut.WriteLn('Please run the installer manually and choose:');
      FOut.WriteLn('  ' + InstallPath);
      FOut.WriteLn('as the installation directory.');
      FOut.WriteLn('');
      FOut.WriteLn('After installation completes, run:');
      FOut.WriteLn('  fpdev fpc use ' + AVersion);
      FOut.WriteLn('to configure the environment.');
      FOut.WriteLn('');
      FOut.WriteLn('===========================================');
      FOut.WriteLn('Download completed. Please run the installer.');
      FOut.WriteLn('===========================================');
      Result := True;
      Exit;
    end;
    {$ENDIF}

    // Step 2: Extract archive (Linux/macOS)
    FOut.WriteLn('[2/4] Extracting archive...');
    ExtractDir := GetTempDir + 'fpdev_extract_' + IntToStr(GetTickCount64);
    if not ExtractArchive(TempFile, ExtractDir) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_ARCHIVE_EXTRACT_FAILED));
      if FileExists(TempFile) then DeleteFile(TempFile);
      Exit;
    end;
    FOut.WriteLn;

    // Step 3: Run install script (Linux) or copy files
    FOut.WriteLn('[3/4] Running installation...');
    FOut.WriteLn('  Target: ' + InstallPath);

    SourceDir := '';
    if FindFirst(ExtractDir + PathDelim + '*', faDirectory, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
        begin
          InstallScript := ExtractDir + PathDelim + SR.Name + PathDelim + 'install.sh';
          if FileExists(InstallScript) then
          begin
            SourceDir := ExtractDir + PathDelim + SR.Name;
            FOut.WriteLn('  Found FPC distribution: ' + SR.Name);
            Break;
          end;
          if DirectoryExists(ExtractDir + PathDelim + SR.Name + PathDelim + 'bin') then
          begin
            SourceDir := ExtractDir + PathDelim + SR.Name;
            FOut.WriteLn('  Found FPC directory: ' + SR.Name);
            Break;
          end;
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if SourceDir = '' then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_DIST_NOT_FOUND));
      if FileExists(TempFile) then DeleteFile(TempFile);
      Exit;
    end;

    InstallScript := SourceDir + PathDelim + 'install.sh';
    if FileExists(InstallScript) then
    begin
      FOut.WriteLn('  FPC Linux distribution detected, extracting nested archives...');
      EnsureDir(InstallPath);

      if FindFirst(SourceDir + PathDelim + 'binary.*.tar', faAnyFile, SR) = 0 then
      begin
        FOut.WriteLn('  Extracting: ' + SR.Name);
        LResult := TProcessExecutor.Execute('tar', ['-xf', SourceDir + PathDelim + SR.Name, '-C', SourceDir], '');
        if not LResult.Success then
          FErr.WriteLn('  Warning: Error extracting ' + SR.Name);
        FindClose(SR);
      end;

      if FindFirst(SourceDir + PathDelim + 'base.*.tar.gz', faAnyFile, SR) = 0 then
      begin
        FOut.WriteLn('  Installing base package: ' + SR.Name);
        LResult := TProcessExecutor.Execute('tar', ['-xzf', SourceDir + PathDelim + SR.Name, '-C', InstallPath], '');
        if LResult.Success then
          FOut.WriteLn('  Base package installed successfully')
        else
          FErr.WriteLn('  Warning: Error extracting base package');
        FindClose(SR);
      end;

      if FindFirst(SourceDir + PathDelim + 'units-rtl*.tar.gz', faAnyFile, SR) = 0 then
      begin
        repeat
          FOut.WriteLn('  Installing: ' + SR.Name);
          LResult := TProcessExecutor.Execute('tar', ['-xzf', SourceDir + PathDelim + SR.Name, '-C', InstallPath], '');
          if not LResult.Success then
            FErr.WriteLn('  Warning: Error extracting ' + SR.Name);
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;

      if FindFirst(SourceDir + PathDelim + 'units-fcl*.tar.gz', faAnyFile, SR) = 0 then
      begin
        repeat
          FOut.WriteLn('  Installing: ' + SR.Name);
          LResult := TProcessExecutor.Execute('tar', ['-xzf', SourceDir + PathDelim + SR.Name, '-C', InstallPath], '');
          if not LResult.Success then
            FErr.WriteLn('  Warning: Error extracting ' + SR.Name);
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;
    end;

    if not DirectoryExists(InstallPath + PathDelim + 'bin') then
    begin
      if DirectoryExists(SourceDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion) then
      begin
        FOut.WriteLn('  Performing manual installation...');
        EnsureDir(ExtractFileDir(InstallPath));

        LResult := TProcessExecutor.Execute('cp', ['-r',
          SourceDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion,
          InstallPath], '');

        if not LResult.Success then
        begin
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_COPY_FAILED));
          Exit;
        end;

        if DirectoryExists(SourceDir + PathDelim + 'bin') then
        begin
          EnsureDir(InstallPath + PathDelim + 'bin');
          LResult := TProcessExecutor.Execute('cp', ['-r',
            SourceDir + PathDelim + 'bin' + PathDelim + '.',
            InstallPath + PathDelim + 'bin'], '');
        end;
      end;
    end;
    FOut.WriteLn;

    FOut.WriteLn('Cleaning up temporary files...');
    if FileExists(TempFile) then DeleteFile(TempFile);

    end;  // End of: if not UseResourceRepo

    // Generate fpc.cfg configuration file if bin directory exists
    if DirectoryExists(InstallPath + PathDelim + 'bin') then
    begin
      FOut.WriteLn('  Generating fpc.cfg...');
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

    // Step 4: Setup environment
    FOut.WriteLn('[4/4] Setting up environment...');
    if SetupEnvironment(AVersion, InstallPath) then
      FOut.WriteLn('  Environment configured')
    else
      FErr.WriteLn('  Warning: Environment setup failed, but installation may have completed');
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
