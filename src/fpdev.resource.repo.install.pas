unit fpdev.resource.repo.install;

{$mode objfpc}{$H+}

{
  B226: Install operation helpers for TResourceRepository

  Extracts resource installation logic as pure functions.
  Each function receives dependencies as parameters rather than
  accessing TResourceRepository private state directly.
}

interface

uses
  SysUtils, Classes,
  fpdev.resource.repo.types;

type
  TRepoLogProc = procedure(const AMsg: string) of object;
  TRepoLogFmtProc = procedure(const AFormat: string; const AArgs: array of const) of object;
  TRepoVerifyFunc = function(const AFile, AExpectedSHA256: string): Boolean of object;

  { TRepoInstallContext - Shared context for install operations }
  TRepoInstallContext = record
    LocalPath: string;
    Log: TRepoLogProc;
    LogFmt: TRepoLogFmtProc;
    VerifyChecksum: TRepoVerifyFunc;
  end;

{ Install bootstrap compiler from repository to destination }
function RepoInstallBootstrapCompiler(
  const ACtx: TRepoInstallContext;
  const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;

{ Install binary release (FPC/Lazarus) with mirror fallback }
function RepoInstallBinaryRelease(
  const ACtx: TRepoInstallContext;
  const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;

{ Install cross-compilation toolchain }
function RepoInstallCrossToolchain(
  const ACtx: TRepoInstallContext;
  const AInfo: TCrossToolchainInfo;
  const ATarget, ADestDir: string): Boolean;

{ Install package from repository }
function RepoInstallPackage(
  const ACtx: TRepoInstallContext;
  const AInfo: TRepoPackageInfo;
  const AName, AVersion, ADestDir: string): Boolean;

implementation

uses
  fpdev.utils.fs, fpdev.utils.process;

{$IFDEF MSWINDOWS}
const
  XCOPY_RECURSIVE_SWITCH = '/E';
  XCOPY_ASSUME_DIRECTORY_SWITCH = '/I';
  XCOPY_QUIET_SWITCH = '/Q';
  XCOPY_OVERWRITE_SWITCH = '/Y';
{$ENDIF}

{ Helper: Download file with mirror fallback }
function DownloadWithFallback(
  const ACtx: TRepoInstallContext;
  const AURL: string;
  const AMirrors: array of string;
  const ADestFile: string): Boolean;
var
  i: Integer;
begin
  Result := False;

  // Try primary URL
  ACtx.LogFmt('Downloading from: %s', [AURL]);
  Result := DownloadFile(AURL, ADestFile);

  // If primary fails, try mirrors
  if not Result then
  begin
    for i := 0 to High(AMirrors) do
    begin
      ACtx.LogFmt('Primary URL failed, trying mirror %d: %s', [i + 1, AMirrors[i]]);
      Result := DownloadFile(AMirrors[i], ADestFile);
      if Result then
        Break;
    end;
  end;
end;

{ Helper: Extract archive based on file extension }
function ExtractArchiveFile(const AArchivePath, ADestDir: string): Boolean;
var
  LowerPath: string;
begin
  LowerPath := LowerCase(AArchivePath);

  if (Pos('.tar.gz', LowerPath) > 0) or (Pos('.tgz', LowerPath) > 0) then
    Result := TProcessExecutor.Run('tar', ['-xzf', AArchivePath, '-C', ADestDir], '')
  else if Pos('.tar', LowerPath) > 0 then
    Result := TProcessExecutor.Run('tar', ['-xf', AArchivePath, '-C', ADestDir], '')
  else if Pos('.zip', LowerPath) > 0 then
    Result := TProcessExecutor.Run('unzip', ['-q', '-o', AArchivePath, '-d', ADestDir], '')
  else
    Result := False;
end;

{ RepoInstallBootstrapCompiler }

function RepoInstallBootstrapCompiler(
  const ACtx: TRepoInstallContext;
  const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;
var
  SourceDir, DestPath, ExeName: string;
begin
  Result := False;

  ACtx.LogFmt('Installing bootstrap compiler %s for %s...', [AVersion, APlatform]);

  // Source directory in resource repository
  SourceDir := ACtx.LocalPath + PathDelim + AInfo.Path;
  if not DirectoryExists(SourceDir) then
  begin
    ACtx.LogFmt('Error: Bootstrap compiler source directory not found: %s', [SourceDir]);
    Exit;
  end;

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  ACtx.LogFmt('Source: %s', [SourceDir]);
  ACtx.LogFmt('Destination: %s', [ADestDir]);

  // Copy entire directory
  {$IFDEF MSWINDOWS}
  Result := TProcessExecutor.Run(
    'xcopy',
    [
      SourceDir,
      ADestDir,
      XCOPY_RECURSIVE_SWITCH,
      XCOPY_ASSUME_DIRECTORY_SWITCH,
      XCOPY_QUIET_SWITCH,
      XCOPY_OVERWRITE_SWITCH
    ],
    ''
  );
  {$ELSE}
  Result := TProcessExecutor.Run('cp', ['-r', SourceDir + PathDelim + '.', ADestDir], '');
  {$ENDIF}

  if not Result then
  begin
    ACtx.Log('Failed to copy bootstrap compiler files');
    Exit;
  end;

  // Verify executable
  ExeName := ExtractFileName(AInfo.Executable);
  DestPath := ADestDir + PathDelim + ExeName;

  if not FileExists(DestPath) then
  begin
    ACtx.LogFmt('Bootstrap compiler executable not found after installation: %s', [DestPath]);
    Exit(False);
  end;

  // Set execute permissions on Unix
  {$IFNDEF MSWINDOWS}
  TProcessExecutor.Run('chmod', ['+x', DestPath], '');
  if FileExists(ADestDir + PathDelim + 'ppcx64') then
    TProcessExecutor.Run('chmod', ['+x', ADestDir + PathDelim + 'ppcx64'], '');
  {$ENDIF}

  // Verify checksum if provided
  if AInfo.SHA256 <> '' then
  begin
    if not ACtx.VerifyChecksum(DestPath, AInfo.SHA256) then
    begin
      ACtx.Log('Checksum verification failed');
      Exit(False);
    end;
  end;

  ACtx.Log('Bootstrap compiler installed successfully');
  ACtx.LogFmt('  Executable: %s', [DestPath]);
  Result := True;
end;

{ RepoInstallBinaryRelease }

function RepoInstallBinaryRelease(
  const ACtx: TRepoInstallContext;
  const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;
var
  ArchivePath, TempFile: string;
  DownloadSuccess: Boolean;
begin
  Result := False;

  ACtx.LogFmt('Installing FPC %s binary release for %s...', [AVersion, APlatform]);

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  // Determine archive path - either download from URL or use local file
  TempFile := '';
  if AInfo.URL <> '' then
  begin
    // Download from URL with mirror fallback
    TempFile := GetTempDir + 'fpdev_download_' + IntToStr(GetTickCount64) + ExtractFileExt(AInfo.URL);
    DownloadSuccess := DownloadWithFallback(ACtx, AInfo.URL, AInfo.Mirrors, TempFile);

    if not DownloadSuccess then
    begin
      ACtx.Log('Error: Failed to download binary release from all sources');
      if FileExists(TempFile) then
        DeleteFile(TempFile);
      Exit;
    end;

    ArchivePath := TempFile;
    ACtx.Log('Download completed');
  end
  else if AInfo.Path <> '' then
  begin
    // v1.0 backward compatibility: use local file from repository
    ArchivePath := ACtx.LocalPath + PathDelim + AInfo.Path;
    if not FileExists(ArchivePath) then
    begin
      ACtx.LogFmt('Error: Binary release archive not found: %s', [ArchivePath]);
      Exit;
    end;
  end
  else
  begin
    ACtx.Log('Error: No URL or archive path specified in manifest');
    Exit;
  end;

  ACtx.LogFmt('Source: %s', [ArchivePath]);
  ACtx.LogFmt('Destination: %s', [ADestDir]);

  // Verify checksum
  if AInfo.SHA256 <> '' then
  begin
    ACtx.Log('Verifying checksum...');
    if not ACtx.VerifyChecksum(ArchivePath, AInfo.SHA256) then
    begin
      ACtx.Log('Error: Checksum verification failed');
      if TempFile <> '' then
        DeleteFile(TempFile);
      Exit;
    end;
    ACtx.Log('Checksum verified');
  end;

  // Extract archive
  Result := ExtractArchiveFile(ArchivePath, ADestDir);

  // Clean up temp file
  if TempFile <> '' then
    DeleteFile(TempFile);

  if Result then
    ACtx.Log('Binary release installed successfully')
  else
    ACtx.Log('Error: Failed to extract archive');
end;

{ RepoInstallCrossToolchain }

function RepoInstallCrossToolchain(
  const ACtx: TRepoInstallContext;
  const AInfo: TCrossToolchainInfo;
  const ATarget, ADestDir: string): Boolean;
var
  BinutilsPath, LibsPath: string;
begin
  Result := False;

  ACtx.LogFmt('Installing cross toolchain for %s...', [ATarget]);

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  // Install binutils if specified
  if AInfo.BinutilsArchive <> '' then
  begin
    BinutilsPath := ACtx.LocalPath + PathDelim + AInfo.BinutilsArchive;
    if not FileExists(BinutilsPath) then
    begin
      ACtx.LogFmt('Error: Binutils archive not found: %s', [BinutilsPath]);
      Exit;
    end;

    // Verify checksum
    if (AInfo.BinutilsSHA256 <> '') and not ACtx.VerifyChecksum(BinutilsPath, AInfo.BinutilsSHA256) then
    begin
      ACtx.Log('Error: Binutils checksum verification failed');
      Exit;
    end;

    ACtx.Log('Extracting binutils...');
    if not TProcessExecutor.Run('tar', ['-xzf', BinutilsPath, '-C', ADestDir], '') then
    begin
      ACtx.Log('Error: Failed to extract binutils');
      Exit;
    end;
  end;

  // Install libraries if specified
  if AInfo.LibsArchive <> '' then
  begin
    LibsPath := ACtx.LocalPath + PathDelim + AInfo.LibsArchive;
    if not FileExists(LibsPath) then
    begin
      ACtx.LogFmt('Error: Libraries archive not found: %s', [LibsPath]);
      Exit;
    end;

    // Verify checksum
    if (AInfo.LibsSHA256 <> '') and not ACtx.VerifyChecksum(LibsPath, AInfo.LibsSHA256) then
    begin
      ACtx.Log('Error: Libraries checksum verification failed');
      Exit;
    end;

    ACtx.Log('Extracting libraries...');
    if not TProcessExecutor.Run('tar', ['-xzf', LibsPath, '-C', ADestDir], '') then
    begin
      ACtx.Log('Error: Failed to extract libraries');
      Exit;
    end;
  end;

  ACtx.Log('Cross toolchain installed successfully');
  ACtx.LogFmt('  Target: %s (%s-%s)', [AInfo.DisplayName, AInfo.CPU, AInfo.OS]);
  ACtx.LogFmt('  Location: %s', [ADestDir]);
  Result := True;
end;

{ RepoInstallPackage }

function RepoInstallPackage(
  const ACtx: TRepoInstallContext;
  const AInfo: TRepoPackageInfo;
  const AName, AVersion, ADestDir: string): Boolean;
var
  ArchivePath: string;
begin
  Result := False;

  ACtx.LogFmt('Installing package %s version %s...', [AName, AVersion]);

  // Find archive
  if AInfo.Archive <> '' then
    ArchivePath := ACtx.LocalPath + PathDelim + AInfo.Archive
  else
    ArchivePath := ACtx.LocalPath + PathDelim + 'packages' + PathDelim + AInfo.Category +
                   PathDelim + AName + PathDelim + AName + '-' + AInfo.Version + '.tar.gz';

  if not FileExists(ArchivePath) then
  begin
    ACtx.LogFmt('Error: Package archive not found: %s', [ArchivePath]);
    Exit;
  end;

  // Verify checksum
  if (AInfo.SHA256 <> '') and not ACtx.VerifyChecksum(ArchivePath, AInfo.SHA256) then
  begin
    ACtx.Log('Error: Package checksum verification failed');
    Exit;
  end;

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  ACtx.LogFmt('Extracting package to %s...', [ADestDir]);

  // Extract archive
  if TProcessExecutor.Run('tar', ['-xzf', ArchivePath, '-C', ADestDir], '') then
  begin
    ACtx.Log('Package installed successfully');
    ACtx.LogFmt('  Name: %s', [AInfo.Name]);
    ACtx.LogFmt('  Version: %s', [AInfo.Version]);
    ACtx.LogFmt('  Location: %s', [ADestDir]);
    Result := True;
  end
  else
    ACtx.Log('Error: Failed to extract package archive');
end;

end.
