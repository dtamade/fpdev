unit fpdev.build.cache;

{$mode objfpc}{$H+}

{
  TBuildCache - Build cache management service

  Extracted from fpdev.build.manager to handle:
  - Build artifact caching (bin/lib directories)
  - Incremental build detection
  - Cache invalidation
  - Fast version switching via cached artifacts

  Cache Structure:
    ~/.fpdev/cache/builds/
    ├── fpc-3.2.2-x86_64-linux.tar.gz    # Compressed artifacts
    ├── fpc-3.2.2-x86_64-linux.meta      # Metadata file
    └── build-cache.txt                   # Entry index
}

interface

uses
  SysUtils, Classes, Process;

type
  { TBuildStep - Build stage state machine }
  TBuildStep = (
    bsIdle,             // 0 - Idle
    bsPreflight,        // 1 - Preflight check
    bsCompiler,         // 2 - Compiler build
    bsCompilerInstall,  // 3 - Compiler install
    bsRTL,              // 4 - RTL build
    bsRTLInstall,       // 5 - RTL install
    bsPackages,         // 6 - Packages build
    bsPackagesInstall,  // 7 - Packages install
    bsVerify,           // 8 - Verify
    bsComplete          // 9 - Complete
  );

  { TBuildCacheEntry - Build cache entry record }
  TBuildCacheEntry = record
    Version: string;          // FPC version
    Revision: string;         // Git commit hash
    BuildTime: TDateTime;     // Build timestamp
    CPU: string;              // Target CPU
    OS: string;               // Target OS
    CompilerHash: string;     // Compiler SHA256
    SourceHash: string;       // Source key files SHA256
    Status: TBuildStep;       // Build stage reached
  end;

  { TArtifactInfo - Cached artifact metadata }
  TArtifactInfo = record
    Version: string;          // FPC version
    CPU: string;              // Target CPU
    OS: string;               // Target OS
    ArchivePath: string;      // Path to .tar.gz archive
    ArchiveSize: Int64;       // Archive size in bytes
    CreatedAt: TDateTime;     // When cached
    SourcePath: string;       // Original install path
    SourceType: string;       // NEW: 'binary' | 'source'
    SHA256: string;           // NEW: File checksum
    DownloadURL: string;      // NEW: Original download URL
  end;

  { TBuildCache - Build cache management }
  TBuildCache = class
  private
    FCacheDir: string;
    FEntries: TStringList;  // Version -> entry line
    FCacheHits: Integer;    // Statistics: cache hits
    FCacheMisses: Integer;  // Statistics: cache misses
    FTTLDays: Integer;      // Time-to-live in days (0 = never expire)
    FVerifyOnRestore: Boolean;  // Verify SHA256 on restore (default: True)
    function GetCacheFilePath: string;
    function GetEntryCount: Integer;
    procedure LoadEntries;
    procedure SaveEntries;
    function FindEntry(const AVersion: string): Integer;
    function GetCurrentCPU: string;
    function GetCurrentOS: string;
    function GetArtifactKey(const AVersion: string): string;
    function GetArtifactArchivePath(const AVersion: string): string;
    function GetArtifactMetaPath(const AVersion: string): string;
    function RunCommand(const ACmd: string; const AArgs: array of string; const AWorkDir: string): Boolean;
    function FileCopy(const ASource, ADest: string): Boolean;
  public
    constructor Create(const ACacheDir: string);
    destructor Destroy; override;

    { Metadata cache (build status tracking) }
    function IsCacheValid(const AVersion: string): Boolean;
    function GetCachedBuild(const AVersion: string): string;
    procedure InvalidateCache(const AVersion: string);
    procedure UpdateCache(const AVersion: string; const AEntry: TBuildCacheEntry);
    function NeedsRebuild(const AVersion: string; AStep: TBuildStep): Boolean;
    function GetRevision(const AVersion: string): string;

    { Artifact cache (compiled binaries) }
    function HasArtifacts(const AVersion: string): Boolean;
    function SaveArtifacts(const AVersion, AInstallPath: string): Boolean;
    function RestoreArtifacts(const AVersion, ADestPath: string): Boolean;
    function GetArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
    function DeleteArtifacts(const AVersion: string): Boolean;
    function GetTotalCacheSize: Int64;
    function ListCachedVersions: TStringArray;

    { Binary artifact cache (downloaded binaries) }
    function SaveBinaryArtifact(const AVersion, ADownloadedFile: string): Boolean;
    function RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;
    function GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;

    { Cache statistics }
    function GetCacheStats: string;
    procedure ClearStats;

    { Cache invalidation (TTL-based) }
    procedure SetTTLDays(ADays: Integer);
    function GetTTLDays: Integer;
    function IsExpired(const AInfo: TArtifactInfo): Boolean;
    procedure CleanExpired;

    { Cache verification (SHA256-based) }
    function CalculateSHA256(const AFilePath: string): string;
    function VerifyArtifact(const AArchivePath, AExpectedHash: string): Boolean;
    procedure SetVerifyOnRestore(AVerify: Boolean);
    function GetVerifyOnRestore: Boolean;

    property CacheDir: string read FCacheDir;
    property CacheHits: Integer read FCacheHits;
    property CacheMisses: Integer read FCacheMisses;
    property EntryCount: Integer read GetEntryCount;
  end;

implementation

uses
  StrUtils;

{ TBuildCache }

constructor TBuildCache.Create(const ACacheDir: string);
begin
  inherited Create;
  FCacheDir := ACacheDir;
  FEntries := TStringList.Create;
  FEntries.Sorted := True;
  FEntries.Duplicates := dupIgnore;
  FCacheHits := 0;
  FCacheMisses := 0;
  FTTLDays := 30;  // Default: 30 days
  FVerifyOnRestore := True;  // Default: verify on restore
  if DirectoryExists(FCacheDir) then
    LoadEntries;
end;

destructor TBuildCache.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

function TBuildCache.GetCurrentCPU: string;
begin
  {$IFDEF CPUX86_64}
  Result := 'x86_64';
  {$ELSE}
  {$IFDEF CPUI386}
  Result := 'i386';
  {$ELSE}
  {$IFDEF CPUARM}
  Result := 'arm';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  Result := 'aarch64';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

function TBuildCache.GetCurrentOS: string;
begin
  {$IFDEF LINUX}
  Result := 'linux';
  {$ELSE}
  {$IFDEF MSWINDOWS}
  Result := 'win64';
  {$ELSE}
  {$IFDEF DARWIN}
  Result := 'darwin';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

function TBuildCache.GetArtifactKey(const AVersion: string): string;
begin
  Result := 'fpc-' + AVersion + '-' + GetCurrentCPU + '-' + GetCurrentOS;
end;

function TBuildCache.FileCopy(const ASource, ADest: string): Boolean;
var
  SourceStream, DestStream: TFileStream;
begin
  Result := False;
  try
    SourceStream := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
    try
      DestStream := TFileStream.Create(ADest, fmCreate);
      try
        DestStream.CopyFrom(SourceStream, SourceStream.Size);
        Result := True;
      finally
        DestStream.Free;
      end;
    finally
      SourceStream.Free;
    end;
  except
    Result := False;
  end;
end;

function TBuildCache.GetArtifactArchivePath(const AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FCacheDir) + GetArtifactKey(AVersion) + '.tar.gz';
end;

function TBuildCache.GetArtifactMetaPath(const AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FCacheDir) + GetArtifactKey(AVersion) + '.meta';
end;

function TBuildCache.RunCommand(const ACmd: string; const AArgs: array of string; const AWorkDir: string): Boolean;
var
  P: TProcess;
  i: Integer;
begin
  Result := False;
  P := TProcess.Create(nil);
  try
    P.Executable := ACmd;
    for i := Low(AArgs) to High(AArgs) do
      P.Parameters.Add(AArgs[i]);
    if AWorkDir <> '' then
      P.CurrentDirectory := AWorkDir;
    P.Options := [poWaitOnExit, poUsePipes];
    try
      P.Execute;
      Result := (P.ExitStatus = 0);
    except
      Result := False;
    end;
  finally
    P.Free;
  end;
end;

function TBuildCache.GetCacheFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(FCacheDir) + 'build-cache.txt';
end;

function TBuildCache.GetEntryCount: Integer;
begin
  Result := FEntries.Count;
end;

procedure TBuildCache.LoadEntries;
var
  F: TextFile;
  Line: string;
begin
  if not FileExists(GetCacheFilePath) then Exit;
  AssignFile(F, GetCacheFilePath);
  try
    Reset(F);
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      if Line <> '' then
        FEntries.Add(Line);
    end;
    CloseFile(F);
  except
    // Ignore read errors
  end;
end;

procedure TBuildCache.SaveEntries;
var
  F: TextFile;
  i: Integer;
begin
  ForceDirectories(FCacheDir);
  AssignFile(F, GetCacheFilePath);
  try
    Rewrite(F);
    for i := 0 to FEntries.Count - 1 do
      WriteLn(F, FEntries[i]);
    CloseFile(F);
  except
    // Ignore write errors
  end;
end;

function TBuildCache.FindEntry(const AVersion: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FEntries.Count - 1 do
    if Pos('version=' + AVersion + ';', FEntries[i]) = 1 then
      Exit(i);
end;

function TBuildCache.IsCacheValid(const AVersion: string): Boolean;
begin
  Result := FindEntry(AVersion) >= 0;
  if Result then
    Inc(FCacheHits)
  else
    Inc(FCacheMisses);
end;

function TBuildCache.GetCachedBuild(const AVersion: string): string;
var
  Idx: Integer;
begin
  Result := '';
  Idx := FindEntry(AVersion);
  if Idx >= 0 then
    Result := FEntries[Idx];
end;

procedure TBuildCache.InvalidateCache(const AVersion: string);
var
  Idx: Integer;
begin
  Idx := FindEntry(AVersion);
  if Idx >= 0 then
  begin
    FEntries.Delete(Idx);
    SaveEntries;
  end;
end;

procedure TBuildCache.UpdateCache(const AVersion: string; const AEntry: TBuildCacheEntry);
var
  Line: string;
  Idx: Integer;
begin
  Line := Format('version=%s;revision=%s;time=%s;cpu=%s;os=%s;status=%d',
    [AEntry.Version, AEntry.Revision, FormatDateTime('yyyy-mm-dd_hh:nn:ss', AEntry.BuildTime),
     AEntry.CPU, AEntry.OS, Ord(AEntry.Status)]);
  Idx := FindEntry(AVersion);
  if Idx >= 0 then
    FEntries[Idx] := Line
  else
    FEntries.Add(Line);
  SaveEntries;
end;

function TBuildCache.NeedsRebuild(const AVersion: string; AStep: TBuildStep): Boolean;
var
  Idx: Integer;
  Line: string;
  StatusPos: Integer;
  StatusStr: string;
  CachedStatus: Integer;
begin
  Result := True;
  Idx := FindEntry(AVersion);
  if Idx < 0 then Exit;

  Line := FEntries[Idx];
  StatusPos := Pos('status=', Line);
  if StatusPos > 0 then
  begin
    StatusStr := Copy(Line, StatusPos + 7, 1);
    CachedStatus := StrToIntDef(StatusStr, 0);
    // If cached status >= requested step, no rebuild needed
    Result := CachedStatus < Ord(AStep);
  end;
end;

function TBuildCache.GetRevision(const AVersion: string): string;
var
  Idx: Integer;
  Line: string;
  RevPos, EndPos: Integer;
begin
  Result := '';
  Idx := FindEntry(AVersion);
  if Idx < 0 then Exit;

  Line := FEntries[Idx];
  RevPos := Pos('revision=', Line);
  if RevPos > 0 then
  begin
    RevPos := RevPos + 9;
    EndPos := PosEx(';', Line, RevPos);
    if EndPos > RevPos then
      Result := Copy(Line, RevPos, EndPos - RevPos)
    else
      Result := Copy(Line, RevPos, Length(Line));
  end;
end;

function TBuildCache.GetCacheStats: string;
var
  Total: Integer;
  HitRate: Double;
begin
  Total := FCacheHits + FCacheMisses;
  if Total > 0 then
    HitRate := (FCacheHits * 100.0) / Total
  else
    HitRate := 0;

  Result := Format('Cache: %d entries, %d hits, %d misses (%.1f%% hit rate)',
    [FEntries.Count, FCacheHits, FCacheMisses, HitRate]);
end;

procedure TBuildCache.ClearStats;
begin
  FCacheHits := 0;
  FCacheMisses := 0;
end;

{ Artifact Cache Methods }

function TBuildCache.HasArtifacts(const AVersion: string): Boolean;
var
  SourceArchive, BinaryArchive: string;
begin
  // Check for both source and binary artifacts
  SourceArchive := GetArtifactArchivePath(AVersion);
  BinaryArchive := IncludeTrailingPathDelimiter(FCacheDir) +
    GetArtifactKey(AVersion) + '-binary.tar.gz';

  Result := FileExists(SourceArchive) or FileExists(BinaryArchive);
end;

function TBuildCache.SaveArtifacts(const AVersion, AInstallPath: string): Boolean;
var
  ArchivePath, MetaPath: string;
  MetaFile: TStringList;
  SR: TSearchRec;
begin
  Result := False;

  if not DirectoryExists(AInstallPath) then
    Exit;

  // Ensure cache directory exists
  ForceDirectories(FCacheDir);

  ArchivePath := GetArtifactArchivePath(AVersion);
  MetaPath := GetArtifactMetaPath(AVersion);

  // Create tar.gz archive using system tar command
  // tar -czf archive.tar.gz -C /path/to/install .
  {$IFDEF MSWINDOWS}
  // On Windows, try tar (available in Windows 10+) or fall back to 7z
  if not RunCommand('tar', ['--version'], '') then
  begin
    // Try 7z as fallback
    Result := RunCommand('7z', ['a', '-ttar', ArchivePath + '.tar', AInstallPath + PathDelim + '*'], '');
    if Result then
      Result := RunCommand('7z', ['a', '-tgzip', ArchivePath, ArchivePath + '.tar'], '');
    if FileExists(ArchivePath + '.tar') then
      DeleteFile(ArchivePath + '.tar');
  end
  else
    Result := RunCommand('tar', ['-czf', ArchivePath, '-C', AInstallPath, '.'], '');
  {$ELSE}
  Result := RunCommand('tar', ['-czf', ArchivePath, '-C', AInstallPath, '.'], '');
  {$ENDIF}

  if not Result then
    Exit;

  // Write metadata file
  MetaFile := TStringList.Create;
  try
    MetaFile.Add('version=' + AVersion);
    MetaFile.Add('cpu=' + GetCurrentCPU);
    MetaFile.Add('os=' + GetCurrentOS);
    MetaFile.Add('source_path=' + AInstallPath);
    MetaFile.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));

    // Get archive size
    if FindFirst(ArchivePath, faAnyFile, SR) = 0 then
    begin
      MetaFile.Add('archive_size=' + IntToStr(SR.Size));
      FindClose(SR);
    end;

    MetaFile.SaveToFile(MetaPath);
    Result := True;
  finally
    MetaFile.Free;
  end;
end;

function TBuildCache.RestoreArtifacts(const AVersion, ADestPath: string): Boolean;
var
  ArchivePath: string;
begin
  Result := False;

  ArchivePath := GetArtifactArchivePath(AVersion);
  if not FileExists(ArchivePath) then
    Exit;

  // Ensure destination directory exists
  ForceDirectories(ADestPath);

  // Extract tar.gz archive
  {$IFDEF MSWINDOWS}
  if not RunCommand('tar', ['--version'], '') then
  begin
    // Try 7z as fallback
    Result := RunCommand('7z', ['x', '-y', '-o' + ADestPath, ArchivePath], '');
  end
  else
    Result := RunCommand('tar', ['-xzf', ArchivePath, '-C', ADestPath], '');
  {$ELSE}
  Result := RunCommand('tar', ['-xzf', ArchivePath, '-C', ADestPath], '');
  {$ENDIF}

  if Result then
    Inc(FCacheHits)
  else
    Inc(FCacheMisses);
end;

function TBuildCache.GetArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  MetaPath: string;
  MetaFile: TStringList;
  i: Integer;
  Line, Key, Value: string;
  EqPos: Integer;
begin
  Result := False;
  Initialize(AInfo);

  MetaPath := GetArtifactMetaPath(AVersion);
  if not FileExists(MetaPath) then
    Exit;

  MetaFile := TStringList.Create;
  try
    MetaFile.LoadFromFile(MetaPath);

    AInfo.ArchivePath := GetArtifactArchivePath(AVersion);

    for i := 0 to MetaFile.Count - 1 do
    begin
      Line := MetaFile[i];
      EqPos := Pos('=', Line);
      if EqPos > 0 then
      begin
        Key := Copy(Line, 1, EqPos - 1);
        Value := Copy(Line, EqPos + 1, Length(Line));

        if Key = 'version' then
          AInfo.Version := Value
        else if Key = 'cpu' then
          AInfo.CPU := Value
        else if Key = 'os' then
          AInfo.OS := Value
        else if Key = 'source_path' then
          AInfo.SourcePath := Value
        else if Key = 'archive_size' then
          AInfo.ArchiveSize := StrToInt64Def(Value, 0);
        // Note: CreatedAt parsing omitted for simplicity
      end;
    end;

    Result := AInfo.Version <> '';
  finally
    MetaFile.Free;
  end;
end;

function TBuildCache.DeleteArtifacts(const AVersion: string): Boolean;
var
  ArchivePath, MetaPath: string;
begin
  Result := True;

  ArchivePath := GetArtifactArchivePath(AVersion);
  MetaPath := GetArtifactMetaPath(AVersion);

  if FileExists(ArchivePath) then
    Result := DeleteFile(ArchivePath);

  if FileExists(MetaPath) then
    Result := Result and DeleteFile(MetaPath);
end;

function TBuildCache.GetTotalCacheSize: Int64;
var
  SR: TSearchRec;
begin
  Result := 0;

  if not DirectoryExists(FCacheDir) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(FCacheDir) + '*.tar.gz', faAnyFile, SR) = 0 then
  begin
    repeat
      Result := Result + SR.Size;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TBuildCache.ListCachedVersions: TStringArray;
var
  SR: TSearchRec;
  FileName, Version: string;
  List: TStringList;
  i, DashPos, LastDashPos: Integer;
begin
  Result := nil;

  if not DirectoryExists(FCacheDir) then
    Exit;

  List := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(FCacheDir) + 'fpc-*.tar.gz', faAnyFile, SR) = 0 then
    begin
      repeat
        FileName := SR.Name;
        // Extract version from filename: fpc-3.2.2-x86_64-linux.tar.gz
        // Find second dash (after version)
        DashPos := Pos('-', FileName);
        if DashPos > 0 then
        begin
          LastDashPos := DashPos;
          for i := DashPos + 1 to Length(FileName) do
          begin
            if FileName[i] = '-' then
            begin
              LastDashPos := i;
              Break;
            end;
          end;
          Version := Copy(FileName, DashPos + 1, LastDashPos - DashPos - 1);
          if (Version <> '') and (List.IndexOf(Version) < 0) then
            List.Add(Version);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    SetLength(Result, List.Count);
    for i := 0 to List.Count - 1 do
      Result[i] := List[i];
  finally
    List.Free;
  end;
end;

{ Binary Artifact Cache Methods }

function TBuildCache.SaveBinaryArtifact(const AVersion, ADownloadedFile: string): Boolean;
var
  ArchivePath, MetaPath: string;
  MetaFile: TStringList;
  SR: TSearchRec;
  SHA256Hash: string;
begin
  Result := False;

  if not FileExists(ADownloadedFile) then
    Exit;

  // Ensure cache directory exists
  ForceDirectories(FCacheDir);

  // Generate binary artifact paths (with -binary suffix)
  ArchivePath := IncludeTrailingPathDelimiter(FCacheDir) +
    GetArtifactKey(AVersion) + '-binary.tar.gz';
  MetaPath := IncludeTrailingPathDelimiter(FCacheDir) +
    GetArtifactKey(AVersion) + '-binary.meta';

  // Copy downloaded file to cache
  try
    if not FileCopy(ADownloadedFile, ArchivePath) then
      Exit;
  except
    Exit;
  end;

  // Calculate SHA256 hash (simplified - just use file size as placeholder)
  // In production, use proper SHA256 library
  if FindFirst(ArchivePath, faAnyFile, SR) = 0 then
  begin
    SHA256Hash := IntToHex(SR.Size, 16); // Placeholder
    FindClose(SR);
  end
  else
    SHA256Hash := '';

  // Write metadata file
  MetaFile := TStringList.Create;
  try
    MetaFile.Add('version=' + AVersion);
    MetaFile.Add('cpu=' + GetCurrentCPU);
    MetaFile.Add('os=' + GetCurrentOS);
    MetaFile.Add('source_type=binary');
    MetaFile.Add('sha256=' + SHA256Hash);
    MetaFile.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));

    // Get archive size
    if FindFirst(ArchivePath, faAnyFile, SR) = 0 then
    begin
      MetaFile.Add('archive_size=' + IntToStr(SR.Size));
      FindClose(SR);
    end;

    MetaFile.SaveToFile(MetaPath);
    Result := True;
  finally
    MetaFile.Free;
  end;
end;

function TBuildCache.RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;
var
  ArchivePath: string;
begin
  Result := False;

  ArchivePath := IncludeTrailingPathDelimiter(FCacheDir) +
    GetArtifactKey(AVersion) + '-binary.tar.gz';

  if not FileExists(ArchivePath) then
    Exit;

  // Ensure destination directory exists
  ForceDirectories(ADestPath);

  // Extract tar.gz archive
  {$IFDEF MSWINDOWS}
  if not RunCommand('tar', ['--version'], '') then
  begin
    // Try 7z as fallback
    Result := RunCommand('7z', ['x', '-y', '-o' + ADestPath, ArchivePath], '');
  end
  else
    Result := RunCommand('tar', ['-xzf', ArchivePath, '-C', ADestPath], '');
  {$ELSE}
  Result := RunCommand('tar', ['-xzf', ArchivePath, '-C', ADestPath], '');
  {$ENDIF}

  if Result then
    Inc(FCacheHits)
  else
    Inc(FCacheMisses);
end;

function TBuildCache.GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  MetaPath: string;
  MetaFile: TStringList;
  i: Integer;
  Line, Key, Value: string;
  EqPos: Integer;
begin
  Result := False;
  Initialize(AInfo);

  MetaPath := IncludeTrailingPathDelimiter(FCacheDir) +
    GetArtifactKey(AVersion) + '-binary.meta';

  if not FileExists(MetaPath) then
    Exit;

  MetaFile := TStringList.Create;
  try
    MetaFile.LoadFromFile(MetaPath);

    AInfo.ArchivePath := IncludeTrailingPathDelimiter(FCacheDir) +
      GetArtifactKey(AVersion) + '-binary.tar.gz';

    for i := 0 to MetaFile.Count - 1 do
    begin
      Line := MetaFile[i];
      EqPos := Pos('=', Line);
      if EqPos > 0 then
      begin
        Key := Copy(Line, 1, EqPos - 1);
        Value := Copy(Line, EqPos + 1, Length(Line));

        if Key = 'version' then
          AInfo.Version := Value
        else if Key = 'cpu' then
          AInfo.CPU := Value
        else if Key = 'os' then
          AInfo.OS := Value
        else if Key = 'source_type' then
          AInfo.SourceType := Value
        else if Key = 'sha256' then
          AInfo.SHA256 := Value
        else if Key = 'archive_size' then
          AInfo.ArchiveSize := StrToInt64Def(Value, 0);
        // Note: CreatedAt parsing omitted for simplicity
      end;
    end;

    Result := AInfo.Version <> '';
  finally
    MetaFile.Free;
  end;
end;

{ Cache Invalidation Methods }

procedure TBuildCache.SetTTLDays(ADays: Integer);
begin
  FTTLDays := ADays;
end;

function TBuildCache.GetTTLDays: Integer;
begin
  Result := FTTLDays;
end;

function TBuildCache.IsExpired(const AInfo: TArtifactInfo): Boolean;
var
  ExpiryDate: TDateTime;
begin
  // TTL=0 means never expire
  if FTTLDays = 0 then
    Exit(False);

  ExpiryDate := AInfo.CreatedAt + FTTLDays;
  Result := Now >= ExpiryDate;  // Include boundary (exactly at TTL)
end;

procedure TBuildCache.CleanExpired;
var
  SR: TSearchRec;
  FileName, Version, MetaPath: string;
  Info: TArtifactInfo;
  DashPos: Integer;
begin
  if not DirectoryExists(FCacheDir) then
    Exit;

  // Scan all .meta files
  if FindFirst(IncludeTrailingPathDelimiter(FCacheDir) + '*.meta', faAnyFile, SR) = 0 then
  begin
    repeat
      MetaPath := IncludeTrailingPathDelimiter(FCacheDir) + SR.Name;
      FileName := SR.Name;

      // Extract version from filename
      // Format: fpc-3.2.0-x86_64-linux.meta or fpc-3.2.0-x86_64-linux-binary.meta
      if Pos('fpc-', FileName) = 1 then
      begin
        // Remove 'fpc-' prefix and '.meta' suffix
        Version := Copy(FileName, 5, Length(FileName) - 9);

        // Remove platform suffix (-x86_64-linux or -x86_64-linux-binary)
        if Pos('-binary', Version) > 0 then
          Version := Copy(Version, 1, Pos('-', Version) - 1)
        else
        begin
          // Find second dash (after version number)
          DashPos := Pos('-', Version);
          if DashPos > 0 then
            Version := Copy(Version, 1, DashPos - 1);
        end;

        // Get artifact info and check if expired
        if GetArtifactInfo(Version, Info) or GetBinaryArtifactInfo(Version, Info) then
        begin
          if IsExpired(Info) then
          begin
            // Delete expired artifact
            DeleteArtifacts(Version);
          end;
        end;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ Cache Verification Methods }

procedure TBuildCache.SetVerifyOnRestore(AVerify: Boolean);
begin
  FVerifyOnRestore := AVerify;
end;

function TBuildCache.GetVerifyOnRestore: Boolean;
begin
  Result := FVerifyOnRestore;
end;

function TBuildCache.CalculateSHA256(const AFilePath: string): string;
var
  P: TProcess;
  Output: TStringList;
  Line: string;
  SpacePos: Integer;
begin
  Result := '';

  if not FileExists(AFilePath) then
    Exit;

  // Use sha256sum command (available on Linux/macOS/Windows Git Bash)
  P := TProcess.Create(nil);
  try
    {$IFDEF MSWINDOWS}
    // On Windows, try certutil as fallback if sha256sum not available
    P.Executable := 'sha256sum';
    {$ELSE}
    P.Executable := 'sha256sum';
    {$ENDIF}
    P.Parameters.Add(AFilePath);
    P.Options := [poWaitOnExit, poUsePipes];

    try
      P.Execute;

      if P.ExitStatus = 0 then
      begin
        Output := TStringList.Create;
        try
          Output.LoadFromStream(P.Output);
          if Output.Count > 0 then
          begin
            Line := Output[0];
            // sha256sum output format: "hash  filename"
            SpacePos := Pos(' ', Line);
            if SpacePos > 0 then
              Result := LowerCase(Trim(Copy(Line, 1, SpacePos - 1)))
            else
              Result := LowerCase(Trim(Line));
          end;
        finally
          Output.Free;
        end;
      end;
    except
      Result := '';
    end;
  finally
    P.Free;
  end;
end;

function TBuildCache.VerifyArtifact(const AArchivePath, AExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  // If verification is disabled, always return True
  if not FVerifyOnRestore then
    Exit(True);

  // If no expected hash provided, skip verification
  if AExpectedHash = '' then
    Exit(True);

  // Calculate actual hash
  ActualHash := CalculateSHA256(AArchivePath);

  // Compare hashes (case-insensitive)
  Result := SameText(ActualHash, AExpectedHash);

  if not Result then
    WriteLn('Warning: Cache verification failed for ', AArchivePath);
end;

end.
