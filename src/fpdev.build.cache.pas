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
    FileExt: string;          // NEW: File extension (.tar or .tar.gz)
    AccessCount: Integer;     // Phase 3: Access count for statistics
    LastAccessed: TDateTime;  // Phase 3: Last access time for LRU
  end;

  { TCacheIndexStats - Cache index statistics }
  TCacheIndexStats = record
    TotalEntries: Integer;    // Number of cached versions
    TotalSize: Int64;         // Total cache size in bytes
    OldestVersion: string;    // Oldest cached version
    NewestVersion: string;    // Newest cached version
    OldestDate: TDateTime;    // Oldest entry date
    NewestDate: TDateTime;    // Newest entry date
  end;

  { TCacheDetailedStats - Detailed cache statistics (Phase 3) }
  TCacheDetailedStats = record
    TotalEntries: Integer;       // Number of cached versions
    TotalSize: Int64;            // Total cache size in bytes
    TotalAccesses: Integer;      // Total access count across all entries
    AverageEntrySize: Int64;     // Average entry size in bytes
    MostAccessedVersion: string; // Version with most accesses
    MostAccessedCount: Integer;  // Access count of most accessed version
    LeastAccessedVersion: string;// Version with least accesses
    LeastAccessedCount: Integer; // Access count of least accessed version
  end;

  { TBuildCache - Build cache management
    B068: 线程安全说明
    - 此类设计为单线程使用（命令行工具的正常场景）
    - 懒加载标志 FIndexLoaded 和共享对象 FIndexEntries 无同步保护
    - 并发访问可能导致重复加载或竞态读写
    - 如需多线程支持，需添加临界区保护 }
  TBuildCache = class
  private
    FCacheDir: string;
    FCacheDirWithDelim: string;  // Cached path with delimiter for performance
    FEntries: TStringList;  // Version -> entry line
    FCacheHits: Integer;    // Statistics: cache hits
    FCacheMisses: Integer;  // Statistics: cache misses
    FTTLDays: Integer;      // Time-to-live in days (0 = never expire)
    FVerifyOnRestore: Boolean;  // Verify SHA256 on restore (default: True)
    FMaxCacheSizeBytes: Int64;  // Max cache size in bytes (0 = unlimited)
    FIndexEntries: TStringList; // Cache index: version -> JSON entry
    FIndexLoaded: Boolean;      // 懒加载标志
    function GetCacheFilePath: string;
    function GetEntryCount: Integer;
    procedure LoadEntries;
    procedure SaveEntries;
    { B066: 懒加载辅助 - 无返回值因为空索引是有效状态
      与 TResourceRepository.EnsureManifestLoaded 不同，索引是可选缓存而非必需资源 }
    procedure EnsureIndexLoaded;
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
    function SaveBinaryArtifact(const AVersion, ADownloadedFile: string; const ASHA256: string = ''): Boolean;
    function RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;
    function GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;

    { Cache statistics }
    function GetCacheStats: string;
    procedure ClearStats;

    { Cache statistics (Phase 3) }
    procedure RecordAccess(const AVersion: string);
    function GetDetailedStats: TCacheDetailedStats;
    function GetLeastRecentlyUsed: string;
    function GetStatsReport: string;

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

    { Cache space management (LRU-based) }
    procedure SetMaxCacheSizeGB(ASizeGB: Integer);
    function GetMaxCacheSizeGB: Integer;
    procedure SetMaxCacheSizeMB(ASizeMB: Integer);
    procedure SaveArtifactMetadata(const AInfo: TArtifactInfo);
    procedure CleanupLRU;

    { JSON metadata format (Phase 2) }
    function GetJSONMetaPath(const AVersion: string): string;
    function HasMetadataJSON(const AVersion: string): Boolean;
    procedure SaveMetadataJSON(const AInfo: TArtifactInfo);
    function LoadMetadataJSON(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
    function MigrateMetadataToJSON(const AVersion: string): Boolean;

    { Cache index (Phase 2.2) }
    function GetIndexPath: string;
    procedure RebuildIndex;
    procedure LoadIndex;
    procedure SaveIndex;
    function GetIndexEntryCount: Integer;
    function LookupIndexEntry(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
    procedure UpdateIndexEntry(const AInfo: TArtifactInfo);
    procedure RemoveIndexEntry(const AVersion: string);
    function GetIndexStatistics: TCacheIndexStats;

    property CacheDir: string read FCacheDir;
    property CacheHits: Integer read FCacheHits;
    property CacheMisses: Integer read FCacheMisses;
    property EntryCount: Integer read GetEntryCount;
  end;

implementation

uses
  fpdev.build.cache.entries,
  fpdev.build.cache.fileops,
  fpdev.build.cache.indexio,
  fpdev.build.cache.indexjson,
  fpdev.build.cache.indexstats,
  fpdev.build.cache.key,
  fpdev.build.cache.metajson,
  fpdev.build.cache.oldmeta,
  fpdev.build.cache.rebuildscan,
  fpdev.build.cache.statsreport,
  fpdev.build.cache.ttl,
  fpdev.build.cache.verify,
  StrUtils, DateUtils, fpjson, jsonparser;

{ TBuildCache }

constructor TBuildCache.Create(const ACacheDir: string);
begin
  inherited Create;
  FCacheDir := ACacheDir;
  FCacheDirWithDelim := IncludeTrailingPathDelimiter(ACacheDir);  // Cache for performance
  FEntries := TStringList.Create;
  FEntries.Sorted := True;
  FEntries.Duplicates := dupIgnore;
  FIndexEntries := TStringList.Create;
  FIndexEntries.Sorted := True;
  FIndexEntries.Duplicates := dupIgnore;
  FCacheHits := 0;
  FCacheMisses := 0;
  FTTLDays := 30;  // Default: 30 days
  FVerifyOnRestore := True;  // Default: verify on restore
  FMaxCacheSizeBytes := Int64(10) * 1024 * 1024 * 1024;  // Default: 10 GB in bytes
  FIndexLoaded := False;  // 懒加载：不在构造时加载
  if DirectoryExists(FCacheDir) then
  begin
    LoadEntries;
    // LoadIndex deferred to EnsureIndexLoaded
  end;
end;

destructor TBuildCache.Destroy;
begin
  FEntries.Free;
  FIndexEntries.Free;
  inherited Destroy;
end;

function TBuildCache.GetCurrentCPU: string;
begin
  Result := BuildCacheGetCurrentCPU;
end;

function TBuildCache.GetCurrentOS: string;
begin
  Result := BuildCacheGetCurrentOS;
end;

function TBuildCache.GetArtifactKey(const AVersion: string): string;
begin
  Result := BuildCacheGetArtifactKey(AVersion);
end;

function TBuildCache.FileCopy(const ASource, ADest: string): Boolean;
begin
  Result := BuildCacheFileCopy(ASource, ADest);
end;

function TBuildCache.GetArtifactArchivePath(const AVersion: string): string;
begin
  Result := FCacheDirWithDelim + GetArtifactKey(AVersion) + '.tar.gz';
end;

function TBuildCache.GetArtifactMetaPath(const AVersion: string): string;
begin
  Result := FCacheDirWithDelim + GetArtifactKey(AVersion) + '.meta';
end;

function TBuildCache.RunCommand(const ACmd: string; const AArgs: array of string; const AWorkDir: string): Boolean;
begin
  Result := BuildCacheRunCommand(ACmd, AArgs, AWorkDir);
end;

function TBuildCache.GetCacheFilePath: string;
begin
  Result := BuildCacheGetCacheFilePath(FCacheDirWithDelim);
end;

function TBuildCache.GetEntryCount: Integer;
begin
  Result := BuildCacheGetEntryCount(FEntries);
end;

procedure TBuildCache.LoadEntries;
var
  F: TextFile;
  Line: string;
  FileOpened: Boolean;
begin
  if not FileExists(GetCacheFilePath) then Exit;
  AssignFile(F, GetCacheFilePath);
  FileOpened := False;
  try
    Reset(F);
    FileOpened := True;
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      if Line <> '' then
        FEntries.Add(Line);
    end;
  finally
    if FileOpened then
      CloseFile(F);
  end;
end;

procedure TBuildCache.SaveEntries;
var
  F: TextFile;
  i: Integer;
  FileOpened: Boolean;
begin
  ForceDirectories(FCacheDir);
  AssignFile(F, GetCacheFilePath);
  FileOpened := False;
  try
    Rewrite(F);
    FileOpened := True;
    for i := 0 to FEntries.Count - 1 do
      WriteLn(F, FEntries[i]);
  finally
    if FileOpened then
      CloseFile(F);
  end;
end;

function TBuildCache.FindEntry(const AVersion: string): Integer;
begin
  Result := BuildCacheFindEntry(FEntries, AVersion);
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
  SourceArchive, BinaryMetaPath: string;
begin
  // Check for both source and binary artifacts
  SourceArchive := GetArtifactArchivePath(AVersion);
  BinaryMetaPath := FCacheDirWithDelim +
    GetArtifactKey(AVersion) + '-binary.meta';

  // For binary artifacts, check if metadata file exists (more reliable than checking archive)
  // The metadata file contains the actual file extension (.tar or .tar.gz)
  Result := FileExists(SourceArchive) or FileExists(BinaryMetaPath);
end;

function TBuildCache.SaveArtifacts(const AVersion, AInstallPath: string): Boolean;
var
  ArchivePath, MetaPath: string;
  SR: TSearchRec;
  ArchiveSize: Int64;
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

  // Get archive size
  ArchiveSize := 0;
  if FindFirst(ArchivePath, faAnyFile, SR) = 0 then
  begin
    try
      ArchiveSize := SR.Size;
    finally
      FindClose(SR);
    end;
  end;

  // Write metadata file using helper
  BuildCacheSaveOldMeta(MetaPath, AVersion, GetCurrentCPU, GetCurrentOS,
    AInstallPath, ArchiveSize);
  Result := True;
end;

function TBuildCache.RestoreArtifacts(const AVersion, ADestPath: string): Boolean;
var
  ArchivePath: string;
  Info: TArtifactInfo;
begin
  Result := False;

  ArchivePath := GetArtifactArchivePath(AVersion);
  if not FileExists(ArchivePath) then
    Exit;

  // Verify integrity before extraction (Fix: add integrity verification)
  if FVerifyOnRestore then
  begin
    if GetArtifactInfo(AVersion, Info) and (Info.SHA256 <> '') then
    begin
      if not VerifyArtifact(ArchivePath, Info.SHA256) then
      begin
        WriteLn('Error: Cache integrity verification failed for ', AVersion);
        WriteLn('  Expected SHA256: ', Info.SHA256);
        WriteLn('  The cached artifact may be corrupted or tampered with.');
        Inc(FCacheMisses);
        Exit;
      end;
    end;
  end;

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
  MetaPath, ArchivePath: string;
  OldInfo: TOldMetaArtifactInfo;
begin
  Result := False;
  Initialize(AInfo);

  MetaPath := GetArtifactMetaPath(AVersion);
  ArchivePath := GetArtifactArchivePath(AVersion);

  if not BuildCacheLoadOldMeta(MetaPath, OldInfo) then
    Exit;

  // Copy from old format to TArtifactInfo
  AInfo.Version := OldInfo.Version;
  AInfo.CPU := OldInfo.CPU;
  AInfo.OS := OldInfo.OS;
  AInfo.SourcePath := OldInfo.SourcePath;
  AInfo.ArchiveSize := OldInfo.ArchiveSize;
  AInfo.CreatedAt := OldInfo.CreatedAt;
  AInfo.ArchivePath := ArchivePath;

  Result := AInfo.Version <> '';
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

  if FindFirst(FCacheDirWithDelim + '*.tar.gz', faAnyFile, SR) = 0 then
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
    if FindFirst(FCacheDirWithDelim + 'fpc-*.tar.gz', faAnyFile, SR) = 0 then
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

function TBuildCache.SaveBinaryArtifact(const AVersion, ADownloadedFile: string; const ASHA256: string = ''): Boolean;
var
  ArchivePath, MetaPath: string;
  SR: TSearchRec;
  SHA256Hash: string;
  FileExt: string;
  ArchiveSize: Int64;
begin
  Result := False;

  if not FileExists(ADownloadedFile) then
    Exit;

  // Ensure cache directory exists
  ForceDirectories(FCacheDir);

  // Generate binary artifact paths (with -binary suffix)
  // Preserve original file extension (.tar or .tar.gz)
  // Handle compound extensions like .tar.gz
  FileExt := ExtractFileExt(ADownloadedFile);
  if (FileExt = '.gz') and (LowerCase(ExtractFileExt(ChangeFileExt(ADownloadedFile, ''))) = '.tar') then
    FileExt := '.tar.gz';

  ArchivePath := FCacheDirWithDelim +
    GetArtifactKey(AVersion) + '-binary' + FileExt;
  MetaPath := FCacheDirWithDelim +
    GetArtifactKey(AVersion) + '-binary.meta';

  // Copy downloaded file to cache
  try
    if not FileCopy(ADownloadedFile, ArchivePath) then
      Exit;
  except
    on E: Exception do
    begin
      // Silent failure - file copy error
      Exit;
    end;
  end;

  // Get archive size
  ArchiveSize := 0;
  if FindFirst(ArchivePath, faAnyFile, SR) = 0 then
  begin
    try
      ArchiveSize := SR.Size;
    finally
      FindClose(SR);
    end;
  end;

  // Use provided SHA256 hash or calculate placeholder
  if ASHA256 <> '' then
    SHA256Hash := ASHA256
  else
    SHA256Hash := IntToHex(ArchiveSize, 16);  // Fallback: use file size as placeholder

  // Write metadata file using helper
  BuildCacheSaveBinaryMeta(MetaPath, AVersion, GetCurrentCPU, GetCurrentOS,
    SHA256Hash, FileExt, ArchiveSize);
  Result := True;
end;

function TBuildCache.RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;
var
  ArchivePath: string;
  Info: TArtifactInfo;
  FileExt: string;
  TarFlags: string;
begin
  Result := False;

  // Get file extension from metadata to find the correct archive file
  if not GetBinaryArtifactInfo(AVersion, Info) then
    Exit;

  FileExt := Info.FileExt;
  if FileExt = '' then
    FileExt := '.tar.gz';  // Default fallback

  ArchivePath := FCacheDirWithDelim +
    GetArtifactKey(AVersion) + '-binary' + FileExt;

  if not FileExists(ArchivePath) then
    Exit;

  // Verify integrity before extraction (Fix: add integrity verification)
  if FVerifyOnRestore then
  begin
    if Info.SHA256 <> '' then
    begin
      if not VerifyArtifact(ArchivePath, Info.SHA256) then
      begin
        WriteLn('Error: Cache integrity verification failed for ', AVersion);
        WriteLn('  Expected SHA256: ', Info.SHA256);
        WriteLn('  The cached artifact may be corrupted or tampered with.');
        Inc(FCacheMisses);
        Exit;
      end;
    end;
  end;

  // Ensure destination directory exists
  ForceDirectories(ADestPath);

  // Determine tar flags based on file extension
  if (FileExt = '.tar.gz') or (FileExt = '.tgz') then
    TarFlags := '-xzf'  // Gzipped tar
  else if FileExt = '.tar' then
    TarFlags := '-xf'   // Plain tar
  else
    TarFlags := '-xzf'; // Default to gzipped

  // Extract archive (strip top-level directory to extract directly into target)
  {$IFDEF MSWINDOWS}
  if not RunCommand('tar', ['--version'], '') then
  begin
    // Try 7z as fallback
    Result := RunCommand('7z', ['x', '-y', '-o' + ADestPath, ArchivePath], '');
  end
  else
    Result := RunCommand('tar', [TarFlags, ArchivePath, '-C', ADestPath, '--strip-components=1'], '');
  {$ELSE}
  Result := RunCommand('tar', [TarFlags, ArchivePath, '-C', ADestPath, '--strip-components=1'], '');
  {$ENDIF}

  if Result then
    Inc(FCacheHits)
  else
    Inc(FCacheMisses);
end;

function TBuildCache.GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  MetaPath: string;
  BinaryInfo: TBinaryMetaArtifactInfo;
begin
  Result := False;
  Initialize(AInfo);

  MetaPath := FCacheDirWithDelim +
    GetArtifactKey(AVersion) + '-binary.meta';

  if not BuildCacheLoadBinaryMeta(MetaPath, BinaryInfo) then
    Exit;

  // Copy from binary format to TArtifactInfo
  AInfo.Version := BinaryInfo.Version;
  AInfo.CPU := BinaryInfo.CPU;
  AInfo.OS := BinaryInfo.OS;
  AInfo.SourceType := BinaryInfo.SourceType;
  AInfo.SHA256 := BinaryInfo.SHA256;
  AInfo.FileExt := BinaryInfo.FileExt;
  AInfo.ArchiveSize := BinaryInfo.ArchiveSize;
  AInfo.CreatedAt := BinaryInfo.CreatedAt;
  AInfo.ArchivePath := FCacheDirWithDelim +
    GetArtifactKey(AVersion) + '-binary' + BinaryInfo.FileExt;

  Result := AInfo.Version <> '';
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
begin
  Result := BuildCacheIsExpired(AInfo.CreatedAt, FTTLDays);
end;

procedure TBuildCache.CleanExpired;
var
  SR: TSearchRec;
  Version: string;
  Info: TArtifactInfo;
begin
  if not DirectoryExists(FCacheDir) then
    Exit;

  // Scan all .meta files
  if FindFirst(FCacheDirWithDelim + '*.meta', faAnyFile, SR) = 0 then
  begin
    repeat
      // Extract version from filename using helper
      Version := BuildCacheExtractVersionFromFilename(SR.Name);

      if Version <> '' then
      begin
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
begin
  Result := BuildCacheCalculateSHA256(AFilePath);
end;

function TBuildCache.VerifyArtifact(const AArchivePath, AExpectedHash: string): Boolean;
begin
  // If verification is disabled, always return True
  if not FVerifyOnRestore then
    Exit(True);

  Result := BuildCacheVerifyFileHash(AArchivePath, AExpectedHash);

  if not Result then
    WriteLn('Warning: Cache verification failed for ', AArchivePath);
end;

{ Cache Space Management Methods }

procedure TBuildCache.SetMaxCacheSizeGB(ASizeGB: Integer);
begin
  if ASizeGB = 0 then
    FMaxCacheSizeBytes := 0  // Unlimited
  else
    FMaxCacheSizeBytes := Int64(ASizeGB) * 1024 * 1024 * 1024;
end;

function TBuildCache.GetMaxCacheSizeGB: Integer;
begin
  if FMaxCacheSizeBytes = 0 then
    Result := 0  // Unlimited
  else
    Result := FMaxCacheSizeBytes div (1024 * 1024 * 1024);
end;

procedure TBuildCache.SetMaxCacheSizeMB(ASizeMB: Integer);
begin
  if ASizeMB = 0 then
    FMaxCacheSizeBytes := 0  // Unlimited
  else
    FMaxCacheSizeBytes := Int64(ASizeMB) * 1024 * 1024;
end;

procedure TBuildCache.SaveArtifactMetadata(const AInfo: TArtifactInfo);
var
  MetaPath: string;
  MetaFile: TStringList;
begin
  MetaPath := GetArtifactMetaPath(AInfo.Version);

  MetaFile := TStringList.Create;
  try
    MetaFile.Add('version=' + AInfo.Version);
    MetaFile.Add('cpu=' + GetCurrentCPU);
    MetaFile.Add('os=' + GetCurrentOS);
    MetaFile.Add('archive_path=' + AInfo.ArchivePath);
    MetaFile.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', AInfo.CreatedAt));

    MetaFile.SaveToFile(MetaPath);
  finally
    MetaFile.Free;
  end;
end;

procedure TBuildCache.CleanupLRU;
var
  SR: TSearchRec;
  Entries: array of TArtifactInfo;
  Count: Integer;
  TotalSize, MaxSize: Int64;
  i, j: Integer;
  OldestEntry: TArtifactInfo;
  OldestIndex: Integer;
  Version, MetaPath: string;
  TempInfo: TArtifactInfo;
begin
  // If unlimited cache (0 = unlimited), do nothing
  if FMaxCacheSizeBytes = 0 then
    Exit;

  if not DirectoryExists(FCacheDir) then
    Exit;

  // Collect all cache entries
  Entries := nil;
  Count := 0;
  SetLength(Entries, 100);  // Initial capacity

  if FindFirst(FCacheDirWithDelim + '*.tar.gz', faAnyFile, SR) = 0 then
  begin
    repeat
      if Count >= Length(Entries) then
        SetLength(Entries, Length(Entries) * 2);

      Initialize(Entries[Count]);
      Entries[Count].ArchivePath := FCacheDirWithDelim + SR.Name;
      Entries[Count].ArchiveSize := SR.Size;

      // Extract version from filename using helper
      Version := BuildCacheExtractVersionFromFilename(SR.Name);
      if Version <> '' then
      begin
        Entries[Count].Version := Version;

        // Try to get CreatedAt from metadata, fallback to file time
        if GetArtifactInfo(Version, TempInfo) or GetBinaryArtifactInfo(Version, TempInfo) then
          Entries[Count].CreatedAt := TempInfo.CreatedAt
        else
          Entries[Count].CreatedAt := SR.TimeStamp;
      end
      else
        Entries[Count].CreatedAt := SR.TimeStamp;

      Inc(Count);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  SetLength(Entries, Count);

  // Calculate total size
  TotalSize := 0;
  for i := 0 to Count - 1 do
    TotalSize := TotalSize + Entries[i].ArchiveSize;

  MaxSize := FMaxCacheSizeBytes;

  // Remove oldest entries until under limit
  while (TotalSize > MaxSize) and (Count > 0) do
  begin
    // Find oldest entry
    OldestIndex := 0;
    OldestEntry := Entries[0];
    for i := 1 to Count - 1 do
    begin
      if Entries[i].CreatedAt < OldestEntry.CreatedAt then
      begin
        OldestEntry := Entries[i];
        OldestIndex := i;
      end;
    end;

    // Delete oldest entry
    if FileExists(OldestEntry.ArchivePath) then
      DeleteFile(OldestEntry.ArchivePath);

    // Delete metadata file
    MetaPath := ChangeFileExt(OldestEntry.ArchivePath, '.meta');
    if FileExists(MetaPath) then
      DeleteFile(MetaPath);

    TotalSize := TotalSize - OldestEntry.ArchiveSize;

    // Remove from array
    for j := OldestIndex to Count - 2 do
      Entries[j] := Entries[j + 1];
    Dec(Count);
  end;
end;

{ JSON Metadata Format Methods }

function TBuildCache.GetJSONMetaPath(const AVersion: string): string;
begin
  Result := FCacheDirWithDelim + GetArtifactKey(AVersion) + '.json';
end;

function TBuildCache.HasMetadataJSON(const AVersion: string): Boolean;
begin
  Result := BuildCacheHasMetadataJSON(GetJSONMetaPath(AVersion));
end;

procedure TBuildCache.SaveMetadataJSON(const AInfo: TArtifactInfo);
begin
  BuildCacheSaveMetadataJSON(
    GetJSONMetaPath(AInfo.Version),
    AInfo.Version, AInfo.CPU, AInfo.OS, AInfo.ArchivePath,
    AInfo.ArchiveSize, AInfo.CreatedAt,
    AInfo.SourceType, AInfo.SHA256, AInfo.DownloadURL, AInfo.SourcePath,
    AInfo.AccessCount, AInfo.LastAccessed
  );
end;

function TBuildCache.LoadMetadataJSON(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  HelperInfo: TMetaJSONArtifactInfo;
begin
  Result := BuildCacheLoadMetadataJSON(GetJSONMetaPath(AVersion), HelperInfo);
  if Result then
  begin
    AInfo.Version := HelperInfo.Version;
    AInfo.CPU := HelperInfo.CPU;
    AInfo.OS := HelperInfo.OS;
    AInfo.ArchivePath := HelperInfo.ArchivePath;
    AInfo.ArchiveSize := HelperInfo.ArchiveSize;
    AInfo.CreatedAt := HelperInfo.CreatedAt;
    AInfo.SourceType := HelperInfo.SourceType;
    AInfo.SHA256 := HelperInfo.SHA256;
    AInfo.DownloadURL := HelperInfo.DownloadURL;
    AInfo.SourcePath := HelperInfo.SourcePath;
    AInfo.AccessCount := HelperInfo.AccessCount;
    AInfo.LastAccessed := HelperInfo.LastAccessed;
  end
  else
    Initialize(AInfo);
end;

function TBuildCache.MigrateMetadataToJSON(const AVersion: string): Boolean;
var
  OldMetaPath, BackupPath: string;
  Info: TArtifactInfo;
begin
  Result := False;

  // Check if old .meta file exists
  OldMetaPath := GetArtifactMetaPath(AVersion);
  if not FileExists(OldMetaPath) then
    Exit;

  // Read old format using existing GetArtifactInfo
  if not GetArtifactInfo(AVersion, Info) then
    Exit;

  // Save in new JSON format
  SaveMetadataJSON(Info);

  // Verify JSON was created
  if not HasMetadataJSON(AVersion) then
    Exit;

  // Backup old .meta file
  BackupPath := OldMetaPath + '.bak';
  if FileExists(BackupPath) then
    DeleteFile(BackupPath);
  RenameFile(OldMetaPath, BackupPath);

  Result := True;
end;

{ Cache Index Methods }

function TBuildCache.GetIndexPath: string;
begin
  Result := FCacheDirWithDelim + 'cache-index.json';
end;

procedure TBuildCache.LoadIndex;
var
  IndexPath: string;
begin
  FIndexEntries.Clear;

  IndexPath := GetIndexPath;
  BuildCacheLoadIndexEntries(IndexPath, FIndexEntries);
  FIndexLoaded := True;
end;

procedure TBuildCache.EnsureIndexLoaded;
begin
  if not FIndexLoaded then
    LoadIndex;
end;

procedure TBuildCache.SaveIndex;
begin
  ForceDirectories(FCacheDir);
  BuildCacheSaveIndexEntries(GetIndexPath, FIndexEntries);
end;

procedure TBuildCache.RebuildIndex;
var
  Versions: SysUtils.TStringArray;
  Info: TArtifactInfo;
  i: Integer;
begin
  // B065: 清空并标记为已加载，防止 UpdateIndexEntry 回灌旧索引
  FIndexEntries.Clear;
  FIndexLoaded := True;

  if not DirectoryExists(FCacheDir) then
    Exit;

  Versions := BuildCacheListMetadataVersions(FCacheDirWithDelim);
  for i := 0 to High(Versions) do
  begin
    if LoadMetadataJSON(Versions[i], Info) then
      UpdateIndexEntry(Info);
  end;

  SaveIndex;
end;

function TBuildCache.GetIndexEntryCount: Integer;
begin
  EnsureIndexLoaded;
  Result := FIndexEntries.Count;
end;

function TBuildCache.LookupIndexEntry(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  EntryJSON: string;
  JSONObj: TJSONObject;
  DateStr: string;
  LastAccessedStr: string;
begin
  Result := False;
  Initialize(AInfo);
  EnsureIndexLoaded;

  EntryJSON := BuildCacheGetIndexEntryJSON(FIndexEntries, AVersion);
  if EntryJSON = '' then
    Exit;

  try
    if not BuildCacheParseIndexEntryJSON(EntryJSON, JSONObj) then
      Exit;

    try
      AInfo.Version := JSONObj.Get('version', '');
      AInfo.CPU := JSONObj.Get('cpu', '');
      AInfo.OS := JSONObj.Get('os', '');
      AInfo.ArchivePath := JSONObj.Get('archive_path', '');
      AInfo.ArchiveSize := JSONObj.Get('archive_size', Int64(0));
      AInfo.SourceType := JSONObj.Get('source_type', '');
      AInfo.SHA256 := JSONObj.Get('sha256', '');
      AInfo.DownloadURL := JSONObj.Get('download_url', '');
      AInfo.SourcePath := JSONObj.Get('source_path', '');
      AInfo.AccessCount := JSONObj.Get('access_count', 0);

      BuildCacheGetNormalizedIndexDates(JSONObj, DateStr, LastAccessedStr);

      if DateStr <> '' then
        AInfo.CreatedAt := BuildCacheParseDateTimeString(DateStr);

      if LastAccessedStr <> '' then
        AInfo.LastAccessed := BuildCacheParseDateTimeString(LastAccessedStr)
      else
        AInfo.LastAccessed := 0;

      Result := AInfo.Version <> '';
    finally
      JSONObj.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TBuildCache.UpdateIndexEntry(const AInfo: TArtifactInfo);
var
  Idx: Integer;
  EntryStr: string;
begin
  EnsureIndexLoaded;
  EntryStr := BuildCacheBuildIndexEntryJSON(
    AInfo.Version,
    AInfo.CPU,
    AInfo.OS,
    AInfo.ArchivePath,
    AInfo.ArchiveSize,
    AInfo.SourceType,
    AInfo.SHA256,
    AInfo.DownloadURL,
    AInfo.SourcePath,
    AInfo.AccessCount,
    AInfo.CreatedAt,
    AInfo.LastAccessed);

  // For sorted list, we need to delete and re-add
  Idx := FIndexEntries.IndexOfName(AInfo.Version);
  if Idx >= 0 then
    FIndexEntries.Delete(Idx);
  FIndexEntries.Add(EntryStr);
end;

procedure TBuildCache.RemoveIndexEntry(const AVersion: string);
var
  Idx: Integer;
begin
  EnsureIndexLoaded;
  Idx := FIndexEntries.IndexOfName(AVersion);
  if Idx >= 0 then
    FIndexEntries.Delete(Idx);
end;

function TBuildCache.GetIndexStatistics: TCacheIndexStats;
var
  i: Integer;
  Info: TArtifactInfo;
begin
  EnsureIndexLoaded;
  Initialize(Result);
  Result.TotalEntries := FIndexEntries.Count;

  BuildCacheIndexStatsInit(Result.TotalSize, Result.OldestDate, Result.NewestDate,
    Result.OldestVersion, Result.NewestVersion);

  for i := 0 to FIndexEntries.Count - 1 do
  begin
    if LookupIndexEntry(FIndexEntries.Names[i], Info) then
      BuildCacheIndexStatsAccumulate(Info.Version, Info.ArchiveSize, Info.CreatedAt,
        Result.TotalSize, Result.OldestDate, Result.NewestDate,
        Result.OldestVersion, Result.NewestVersion);
  end;

  BuildCacheIndexStatsFinalize(Result.TotalEntries, Result.OldestDate, Result.NewestDate);
end;

{ Phase 3: Statistics Enhancement Methods }

procedure TBuildCache.RecordAccess(const AVersion: string);
var
  Info: TArtifactInfo;
begin
  if not LookupIndexEntry(AVersion, Info) then
    Exit;

  // Update access count and last accessed time
  Inc(Info.AccessCount);
  Info.LastAccessed := Now;

  // Update index entry
  UpdateIndexEntry(Info);

  // Save to JSON metadata file
  SaveMetadataJSON(Info);

  // Save index
  SaveIndex;
end;

function TBuildCache.GetDetailedStats: TCacheDetailedStats;
var
  i: Integer;
  Info: TArtifactInfo;
begin
  EnsureIndexLoaded;
  Initialize(Result);
  Result.TotalEntries := FIndexEntries.Count;
  Result.TotalSize := 0;
  Result.TotalAccesses := 0;
  Result.MostAccessedCount := -1;
  Result.LeastAccessedCount := MaxInt;

  for i := 0 to FIndexEntries.Count - 1 do
  begin
    if LookupIndexEntry(FIndexEntries.Names[i], Info) then
    begin
      Result.TotalSize := Result.TotalSize + Info.ArchiveSize;
      Result.TotalAccesses := Result.TotalAccesses + Info.AccessCount;

      if Info.AccessCount > Result.MostAccessedCount then
      begin
        Result.MostAccessedCount := Info.AccessCount;
        Result.MostAccessedVersion := Info.Version;
      end;

      if Info.AccessCount < Result.LeastAccessedCount then
      begin
        Result.LeastAccessedCount := Info.AccessCount;
        Result.LeastAccessedVersion := Info.Version;
      end;
    end;
  end;

  // Calculate average entry size
  if Result.TotalEntries > 0 then
    Result.AverageEntrySize := Result.TotalSize div Result.TotalEntries
  else
    Result.AverageEntrySize := 0;

  // Reset counts if no entries found
  if Result.TotalEntries = 0 then
  begin
    Result.MostAccessedCount := 0;
    Result.LeastAccessedCount := 0;
  end;
end;

function TBuildCache.GetLeastRecentlyUsed: string;
var
  i: Integer;
  Info: TArtifactInfo;
  OldestTime: TDateTime;
  LRUVersion: string;
  HasNeverAccessed: Boolean;
begin
  EnsureIndexLoaded;
  Result := '';
  OldestTime := MaxDateTime;
  LRUVersion := '';
  HasNeverAccessed := False;

  // First pass: find any never-accessed entries (they are the true LRU)
  for i := 0 to FIndexEntries.Count - 1 do
  begin
    if LookupIndexEntry(FIndexEntries.Names[i], Info) then
    begin
      if Info.LastAccessed = 0 then
      begin
        // Never accessed - use CreatedAt to compare among never-accessed entries
        if (not HasNeverAccessed) or (Info.CreatedAt < OldestTime) then
        begin
          OldestTime := Info.CreatedAt;
          LRUVersion := Info.Version;
          HasNeverAccessed := True;
        end;
      end;
    end;
  end;

  // If we found never-accessed entries, return the oldest one
  if HasNeverAccessed then
  begin
    Result := LRUVersion;
    Exit;
  end;

  // Second pass: all entries have been accessed, find the one with oldest LastAccessed
  OldestTime := MaxDateTime;
  for i := 0 to FIndexEntries.Count - 1 do
  begin
    if LookupIndexEntry(FIndexEntries.Names[i], Info) then
    begin
      if Info.LastAccessed < OldestTime then
      begin
        OldestTime := Info.LastAccessed;
        LRUVersion := Info.Version;
      end;
    end;
  end;

  Result := LRUVersion;
end;

function TBuildCache.GetStatsReport: string;
var
  Stats: TCacheDetailedStats;
begin
  Stats := GetDetailedStats;
  Result := BuildCacheFormatStatsReport(
    Stats.TotalEntries,
    Stats.TotalSize,
    Stats.TotalAccesses,
    Stats.MostAccessedVersion,
    Stats.MostAccessedCount,
    Stats.LeastAccessedVersion,
    Stats.LeastAccessedCount);
end;

end.
