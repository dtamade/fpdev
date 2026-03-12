unit fpdev.fpc.utils;

{$mode objfpc}{$H+}

{
  FPC Utils
  
  Shared utility functions module providing project root discovery, install scope detection,
  archive extraction, checksum calculation/verification, and other common functionality.
  
  This module is key to eliminating code duplication; all modules should use the functions here
  rather than implementing their own.
}

interface

uses
  SysUtils, Classes, fpdev.types, fpdev.fpc.types;

type
  { TArchiveFormat - Archive file format }
  TArchiveFormat = (
    afUnknown,   // Unknown format
    afZip,       // ZIP format
    afTarGz,     // TAR.GZ format
    afTar        // TAR format
  );

{ Project root lookup - Walk upward to find the .fpdev directory }
function FindProjectRoot(const AStartDir: string): string;

{ Install scope detection - Determine whether project-level or user-level based on the current directory }
function DetectInstallScope(const ACurrentDir: string): TInstallScope;

{ Archive format detection - Determine the format based on file extension }
function DetectArchiveFormat(const AFilePath: string): TArchiveFormat;

{ Archive extraction - Supports ZIP and TAR.GZ formats }
function ExtractArchive(const AArchivePath, ADestPath: string): TOperationResult;

{ ZIP archive extraction }
function ExtractZip(const AArchivePath, ADestPath: string): TOperationResult;

{ TAR.GZ archive extraction }
function ExtractTarGz(const AArchivePath, ADestPath: string): TOperationResult;

{ Checksum calculation - Compute a file's SHA256 }
function CalculateFileSHA256(const AFilePath: string): string;

{ Checksum verification - Verify whether a file's SHA256 matches }
function VerifyFileSHA256(const AFilePath, AExpectedHash: string): Boolean;

implementation

uses
  Process, zipper, fpdev.hash;

{ FindProjectRoot - Walk upward to find the .fpdev directory }
function FindProjectRoot(const AStartDir: string): string;
var
  Dir, PrevDir: string;
  UserConfigDir: string;
  Candidate: string;
begin
  Result := '';
  Dir := ExcludeTrailingPathDelimiter(ExpandFileName(AStartDir));

  // Avoid mistaking user-level ~/.fpdev as a project marker when scanning upward.
  {$IFDEF MSWINDOWS}
  UserConfigDir := GetEnvironmentVariable('APPDATA');
  if UserConfigDir <> '' then
    UserConfigDir := ExcludeTrailingPathDelimiter(ExpandFileName(UserConfigDir + PathDelim + '.fpdev'))
  else
    UserConfigDir := ExcludeTrailingPathDelimiter(
      ExpandFileName(GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev')
    );
  {$ELSE}
  UserConfigDir := ExcludeTrailingPathDelimiter(ExpandFileName(GetEnvironmentVariable('HOME') + PathDelim + '.fpdev'));
  {$ENDIF}

  while Dir <> '' do
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Dir + PathDelim + '.fpdev'));
    if DirectoryExists(Candidate) then
    begin
      if (UserConfigDir = '') or (not SameText(Candidate, UserConfigDir)) then
      begin
        Result := ExcludeTrailingPathDelimiter(Dir);
        Exit;
      end;
    end;

    PrevDir := Dir;
    Dir := ExtractFileDir(Dir);

    // Prevent an infinite loop (reached filesystem root)
    if Dir = PrevDir then
      Break;
  end;
end;

{ DetectInstallScope - Detect install scope }
function DetectInstallScope(const ACurrentDir: string): TInstallScope;
var
  ProjectRoot: string;
begin
  Result := isUser;
  
  ProjectRoot := FindProjectRoot(ACurrentDir);
  if ProjectRoot <> '' then
    Result := isProject;
end;

{ DetectArchiveFormat - Detect archive format }
function DetectArchiveFormat(const AFilePath: string): TArchiveFormat;
var
  Ext, LowerPath: string;
begin
  Result := afUnknown;
  LowerPath := LowerCase(AFilePath);
  
  // Check for .tar.gz or .tgz
  if (Pos('.tar.gz', LowerPath) > 0) or (Pos('.tgz', LowerPath) > 0) then
  begin
    Result := afTarGz;
    Exit;
  end;
  
  // Check file extension
  Ext := LowerCase(ExtractFileExt(AFilePath));
  
  if Ext = '.zip' then
    Result := afZip
  else if Ext = '.tar' then
    Result := afTar
  else if Ext = '.gz' then
  begin
    // Might be .tar.gz; check again
    if Pos('.tar', LowerPath) > 0 then
      Result := afTarGz;
  end;
end;

{ ExtractZip - Extract a ZIP archive }
function ExtractZip(const AArchivePath, ADestPath: string): TOperationResult;
var
  Unzipper: TUnZipper;
begin
  Result := OperationSuccess;
  
  if not FileExists(AArchivePath) then
  begin
    Result := OperationError(ecFileSystemError, '归档文件不存在: ' + AArchivePath);
    Exit;
  end;
  
  try
    if not DirectoryExists(ADestPath) then
      ForceDirectories(ADestPath);
    
    Unzipper := TUnZipper.Create;
    try
      Unzipper.FileName := AArchivePath;
      Unzipper.OutputPath := ADestPath;
      Unzipper.Examine;
      Unzipper.UnZipAllFiles;
    finally
      Unzipper.Free;
    end;
  except
    on E: Exception do
      Result := OperationError(ecExtractionFailed, 'ZIP 解压失败: ' + E.Message);
  end;
end;

{ ExtractTarGz - Extract a TAR.GZ archive }
function ExtractTarGz(const AArchivePath, ADestPath: string): TOperationResult;
var
  Process: TProcess;
  ExitCode: Integer;
begin
  Result := OperationSuccess;
  
  if not FileExists(AArchivePath) then
  begin
    Result := OperationError(ecFileSystemError, '归档文件不存在: ' + AArchivePath);
    Exit;
  end;
  
  try
    if not DirectoryExists(ADestPath) then
      ForceDirectories(ADestPath);
    
    Process := TProcess.Create(nil);
    try
      {$IFDEF MSWINDOWS}
      // Windows: use PowerShell or tar (built into Windows 10+)
      Process.Executable := 'tar';
      Process.Parameters.Add('-xzf');
      Process.Parameters.Add(AArchivePath);
      Process.Parameters.Add('-C');
      Process.Parameters.Add(ADestPath);
      {$ELSE}
      // Linux/macOS: use system tar
      Process.Executable := 'tar';
      Process.Parameters.Add('-xzf');
      Process.Parameters.Add(AArchivePath);
      Process.Parameters.Add('-C');
      Process.Parameters.Add(ADestPath);
      {$ENDIF}
      
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;
      
      ExitCode := Process.ExitStatus;
      if ExitCode <> 0 then
        Result := OperationError(ecExtractionFailed,
          'TAR.GZ 解压失败，退出码: ' + IntToStr(ExitCode));
    finally
      Process.Free;
    end;
  except
    on E: Exception do
      Result := OperationError(ecExtractionFailed, 'TAR.GZ 解压异常: ' + E.Message);
  end;
end;

{ ExtractArchive - Unified archive extraction function }
function ExtractArchive(const AArchivePath, ADestPath: string): TOperationResult;
var
  Format: TArchiveFormat;
begin
  Format := DetectArchiveFormat(AArchivePath);
  
  case Format of
    afZip:
      Result := ExtractZip(AArchivePath, ADestPath);
    afTarGz:
      Result := ExtractTarGz(AArchivePath, ADestPath);
    afTar:
      begin
        // TAR format not yet supported, can be extended
        Result := OperationError(ecExtractionFailed, 'Pure TAR format not supported, please use TAR.GZ');
      end;
  else
    Result := OperationError(ecExtractionFailed,
      'Unsupported archive format: ' + ExtractFileExt(AArchivePath));
  end;
end;

{ CalculateFileSHA256 - Compute file SHA256 }
function CalculateFileSHA256(const AFilePath: string): string;
begin
  Result := '';
  
  if not FileExists(AFilePath) then
    Exit;
  
  try
    // Use the existing fpdev.hash module
    Result := SHA256FileHex(AFilePath);
  except
    on E: Exception do
      Result := '';
  end;
end;

{ VerifyFileSHA256 - Verify file SHA256 }
function VerifyFileSHA256(const AFilePath, AExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  
  if AExpectedHash = '' then
    Exit;
  
  ActualHash := CalculateFileSHA256(AFilePath);
  if ActualHash = '' then
    Exit;
  
  // Case-insensitive comparison
  Result := SameText(ActualHash, AExpectedHash);
end;

end.
