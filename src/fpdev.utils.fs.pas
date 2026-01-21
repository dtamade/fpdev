unit fpdev.utils.fs;

{$mode objfpc}{$H+}

{
  Common filesystem utilities for FPDev.
  Consolidates duplicate directory/file operations from multiple modules.
}

interface

uses
  SysUtils, Classes, fphttpclient, opensslsockets
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF};

// Directory operations
function DeleteDirRecursive(const ADir: string): Boolean;
function CopyDirRecursive(const ASrc, ADest: string): Boolean;
function EnsureDir(const ADir: string): Boolean;

// File operations
function CopyFileSafe(const ASrc, ADest: string): Boolean;

// Network operations
{ Downloads a file from URL to local path.
  @param AURL URL to download from
  @param ADestPath Local file path to save to
  @param ATimeoutMS Optional timeout in milliseconds (default 30000)
  @returns True if download succeeded }
function DownloadFile(const AURL, ADestPath: string; ATimeoutMS: Integer = 30000): Boolean;

// Build artifact cleaning
type
  TCleanExtensions = array of string;

const
  // Default Pascal/Lazarus build artifact extensions
  DEFAULT_CLEAN_EXTENSIONS: array[0..7] of string = (
    '.o',        // Object files
    '.ppu',      // Compiled Pascal units
    '.a',        // Static libraries
    '.compiled', // Lazarus compiled marker
    '.res',      // Resource files
    '.rst',      // Resource string files
    '.rsj',      // Resource JSON files
    '.or'        // Object resource files
  );

  // Platform-specific executable extensions
  {$IFDEF MSWINDOWS}
  PLATFORM_EXEC_EXTENSIONS: array[0..1] of string = ('.exe', '.dll');
  {$ELSE}
  PLATFORM_EXEC_EXTENSIONS: array[0..1] of string = ('.so', '.dylib');
  {$ENDIF}

{ Clean build artifacts from directory recursively
  @param ADir Directory to clean
  @param AExtensions Optional custom extensions (nil uses defaults)
  @param AIncludeExec Include platform executables in cleanup
  @returns Number of files deleted }
function CleanBuildArtifacts(const ADir: string;
  const AExtensions: TCleanExtensions = nil;
  const AIncludeExec: Boolean = False): Integer;

implementation

function DeleteDirRecursive(const ADir: string): Boolean;
var
  SR: TSearchRec;
  Path: string;
begin
  Result := True;
  if not DirectoryExists(ADir) then
    Exit(True);

  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      Path := IncludeTrailingPathDelimiter(ADir) + SR.Name;

      if (SR.Attr and faDirectory) <> 0 then
      begin
        if not DeleteDirRecursive(Path) then
          Result := False;
      end
      else
      begin
        if FileExists(Path) then
          if not DeleteFile(Path) then
            Result := False;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  if not RemoveDir(ADir) then
    Result := False;
end;

function CopyFileSafe(const ASrc, ADest: string): Boolean;
var
  SrcStream, DestStream: TFileStream;
begin
  Result := False;
  if (ASrc = '') or (ADest = '') then
    Exit(False);

  try
    ForceDirectories(ExtractFileDir(ADest));
    SrcStream := TFileStream.Create(ASrc, fmOpenRead or fmShareDenyNone);
    try
      DestStream := TFileStream.Create(ADest, fmCreate);
      try
        DestStream.CopyFrom(SrcStream, 0);
        Result := True;
      finally
        DestStream.Free;
      end;
    finally
      SrcStream.Free;
    end;
  except
    Result := False;
  end;
end;

function CopyDirRecursive(const ASrc, ADest: string): Boolean;
var
  SR: TSearchRec;
  SrcPath, DestPath: string;
begin
  Result := True;
  if not DirectoryExists(ASrc) then
    Exit(False);

  ForceDirectories(ADest);

  if FindFirst(IncludeTrailingPathDelimiter(ASrc) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      SrcPath := IncludeTrailingPathDelimiter(ASrc) + SR.Name;
      DestPath := IncludeTrailingPathDelimiter(ADest) + SR.Name;

      if (SR.Attr and faDirectory) <> 0 then
      begin
        if not CopyDirRecursive(SrcPath, DestPath) then
          Result := False;
      end
      else
      begin
        if not CopyFileSafe(SrcPath, DestPath) then
          Result := False;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function EnsureDir(const ADir: string): Boolean;
begin
  if DirectoryExists(ADir) then
    Exit(True);
  Result := ForceDirectories(ADir);
end;

function CleanBuildArtifacts(const ADir: string;
  const AExtensions: TCleanExtensions;
  const AIncludeExec: Boolean): Integer;

  function ShouldClean(const AExt: string; const AExts: TCleanExtensions): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    // Check custom/default extensions
    if Length(AExts) > 0 then
    begin
      for I := 0 to High(AExts) do
        if SameText(AExt, AExts[I]) then
          Exit(True);
    end
    else
    begin
      for I := 0 to High(DEFAULT_CLEAN_EXTENSIONS) do
        if SameText(AExt, DEFAULT_CLEAN_EXTENSIONS[I]) then
          Exit(True);
    end;
    // Check platform executables if requested
    if AIncludeExec then
      for I := 0 to High(PLATFORM_EXEC_EXTENSIONS) do
        if SameText(AExt, PLATFORM_EXEC_EXTENSIONS[I]) then
          Exit(True);
  end;

  function CleanDir(const APath: string): Integer;
  var
    SR: TSearchRec;
    FilePath, FileExt: string;
    {$IFDEF UNIX}
    StatBuf: TStat;
    IsExecutable: Boolean;
    {$ENDIF}
  begin
    Result := 0;
    if not DirectoryExists(APath) then
      Exit;

    if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;

        FilePath := IncludeTrailingPathDelimiter(APath) + SR.Name;

        if (SR.Attr and faDirectory) <> 0 then
        begin
          // Recurse into subdirectories
          Result := Result + CleanDir(FilePath);
        end
        else
        begin
          FileExt := LowerCase(ExtractFileExt(SR.Name));
          if ShouldClean(FileExt, AExtensions) then
          begin
            if DeleteFile(FilePath) then
              Inc(Result);
          end
          {$IFDEF UNIX}
          // On Unix, also check for executables without extension
          else if AIncludeExec and (FileExt = '') then
          begin
            // Check if file has execute permission
            if FpStat(FilePath, StatBuf) = 0 then
            begin
              IsExecutable := (StatBuf.st_mode and S_IXUSR) <> 0;
              if IsExecutable then
              begin
                if DeleteFile(FilePath) then
                  Inc(Result);
              end;
            end;
          end;
          {$ENDIF}
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end;

begin
  Result := CleanDir(ADir);
end;

function DownloadFile(const AURL, ADestPath: string; ATimeoutMS: Integer): Boolean;
var
  HTTPClient: TFPHTTPClient;
  FileStream: TFileStream;
  DestDir: string;
begin
  Result := False;

  if (AURL = '') or (ADestPath = '') then
    Exit;

  try
    // Ensure destination directory exists
    DestDir := ExtractFileDir(ADestPath);
    if (DestDir <> '') and not DirectoryExists(DestDir) then
      ForceDirectories(DestDir);

    HTTPClient := TFPHTTPClient.Create(nil);
    try
      HTTPClient.AllowRedirect := True;
      HTTPClient.ConnectTimeout := ATimeoutMS;
      HTTPClient.IOTimeout := ATimeoutMS;

      // Add common headers
      HTTPClient.AddHeader('User-Agent', 'fpdev/2.0');

      FileStream := TFileStream.Create(ADestPath, fmCreate);
      try
        HTTPClient.Get(AURL, FileStream);
        Result := True;
      finally
        FileStream.Free;
      end;
    finally
      HTTPClient.Free;
    end;
  except
    on E: Exception do
    begin
      // Clean up partial download
      if FileExists(ADestPath) then
        DeleteFile(ADestPath);
      Result := False;
    end;
  end;
end;

end.
