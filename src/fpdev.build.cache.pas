unit fpdev.build.cache;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

{
  TBuildCache - Build cache management service

  Extracted from fpdev.build.manager to handle:
  - Build artifact caching (bin/lib directories)
  - Incremental build detection
  - Cache invalidation
  - Fast version switching via cached artifacts

  Cache Structure:
    ~/.fpdev/cache/builds/
    +-- fpc-3.2.2-x86_64-linux.tar.gz    # Compressed artifacts
    +-- fpc-3.2.2-x86_64-linux.meta      # Metadata file
    +-- build-cache.txt                   # Entry index
}

interface

uses
  SysUtils, Classes, Process, fpdev.build.cache.types;

type
  { Types are now in fpdev.build.cache.types unit }
  { Re-exported for backward compatibility }

  { TBuildCache - Build cache management
    B068: Thread safety note
    - This class is designed for single-threaded use (normal scenario for command-line tools)
    - Lazy loading flag FIndexLoaded and shared object FIndexEntries have no synchronization protection
    - Concurrent access may cause duplicate loading or race conditions
    - If multi-threading support is needed, critical section protection must be added }
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
    FIndexLoaded: Boolean;      // Lazy loading flag
    function GetCacheFilePath: string;
    function GetEntryCount: Integer;
    procedure LoadEntries;
    procedure SaveEntries;
    { B066: Lazy loading helper - no return value because empty index is a valid state
      Unlike TResourceRepository.EnsureManifestLoaded, index is optional cache rather than required resource }
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
    function LoadCleanupInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
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
  fpdev.build.cache.access,
  fpdev.build.cache.cleanupinfo,
  fpdev.build.cache.artifactmeta,
  fpdev.build.cache.entryquery,
  fpdev.build.cache.sizelimit,
  fpdev.build.cache.cachestats,
  fpdev.build.cache.sourcepath,
  fpdev.build.cache.jsonpath,
  fpdev.build.cache.jsonsave,
  fpdev.build.cache.jsoninfo,
  fpdev.build.cache.migrationbackup,
  fpdev.build.cache.deletefiles,
  fpdev.build.cache.sourceinfo,
  fpdev.build.cache.expiredscan,
  fpdev.build.cache.binarypresence,
  fpdev.build.cache.binaryinfo,
  fpdev.build.cache.binaryrestore,
  fpdev.build.cache.binarysave,
  fpdev.build.cache.cleanup,
  fpdev.build.cache.cleanupscan,
  fpdev.build.cache.detailedstats,
  fpdev.build.cache.entries,
  fpdev.build.cache.entryio,
  fpdev.build.cache.indexcollect,
  fpdev.build.cache.fileops,
  fpdev.build.cache.indexio,
  fpdev.build.cache.indexjson,
  fpdev.build.cache.indexflow,
  fpdev.build.cache.indexstats,
  fpdev.build.cache.key,
  fpdev.build.cache.lru,
  fpdev.build.cache.metajson,
  fpdev.build.cache.oldmeta,
  fpdev.build.cache.rebuildscan,
  fpdev.build.cache.scan,
  fpdev.build.cache.statsreport,
  fpdev.build.cache.ttl,
  fpdev.build.cache.verify,
  DateUtils, fpjson, jsonparser;

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
  FIndexLoaded := False;  // Lazy loading: not loaded in constructor
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
  Result := BuildCacheGetSourceArchivePath(FCacheDirWithDelim,
    GetArtifactKey(AVersion));
end;

function TBuildCache.GetArtifactMetaPath(const AVersion: string): string;
begin
  Result := BuildCacheGetSourceMetaPath(FCacheDirWithDelim,
    GetArtifactKey(AVersion));
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
begin
  BuildCacheLoadEntriesFile(GetCacheFilePath, FEntries);
end;

procedure TBuildCache.SaveEntries;
begin
  BuildCacheSaveEntriesFile(GetCacheFilePath, FCacheDir, FEntries);
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
  Line := BuildCacheFormatEntryLine(AEntry.Version, AEntry.Revision,
    AEntry.BuildTime, AEntry.CPU, AEntry.OS, Ord(AEntry.Status));
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
begin
  Idx := FindEntry(AVersion);
  if Idx < 0 then
    Result := BuildCacheNeedsRebuildFromEntryLine('', Ord(AStep))
  else
    Result := BuildCacheNeedsRebuildFromEntryLine(FEntries[Idx], Ord(AStep));
end;

function TBuildCache.GetRevision(const AVersion: string): string;
var
  Idx: Integer;
begin
  Result := '';
  Idx := FindEntry(AVersion);
  if Idx >= 0 then
    Result := BuildCacheGetRevisionFromEntryLine(FEntries[Idx]);
end;

function TBuildCache.GetCacheStats: string;
begin
  Result := BuildCacheFormatCacheStats(FEntries.Count, FCacheHits, FCacheMisses);
end;

procedure TBuildCache.ClearStats;
begin
  FCacheHits := 0;
  FCacheMisses := 0;
end;

{ Artifact Cache Methods }

function TBuildCache.HasArtifacts(const AVersion: string): Boolean;
var
  ArtifactKey: string;
  BinaryMetaPath: string;
  SourceArchive: string;
begin
  ArtifactKey := GetArtifactKey(AVersion);
  SourceArchive := GetArtifactArchivePath(AVersion);
  BinaryMetaPath := BuildCacheGetBinaryMetaPath(FCacheDirWithDelim, ArtifactKey);
  Result := BuildCacheHasArtifactFiles(SourceArchive, BinaryMetaPath);
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
    if GetArtifactInfo(AVersion, Info) then
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
  ArchivePath: string;
  MetaPath: string;
  OldInfo: TOldMetaArtifactInfo;
begin
  Result := False;
  Initialize(AInfo);

  MetaPath := GetArtifactMetaPath(AVersion);
  ArchivePath := GetArtifactArchivePath(AVersion);

  if not BuildCacheLoadOldMeta(MetaPath, OldInfo) then
    Exit;

  AInfo := BuildCacheCreateSourceArtifactInfo(ArchivePath, OldInfo);
  Result := AInfo.Version <> '';
end;

function TBuildCache.DeleteArtifacts(const AVersion: string): Boolean;
var
  ArchivePath: string;
  MetaPath: string;
begin
  ArchivePath := GetArtifactArchivePath(AVersion);
  MetaPath := GetArtifactMetaPath(AVersion);
  Result := BuildCacheDeleteArtifactFiles(ArchivePath, MetaPath);
end;

function TBuildCache.GetTotalCacheSize: Int64;
begin
  Result := BuildCacheGetTotalSize(FCacheDir);
end;

function TBuildCache.ListCachedVersions: TStringArray;
begin
  Result := BuildCacheListVersions(FCacheDir);
end;

{ Binary Artifact Cache Methods }

function TBuildCache.SaveBinaryArtifact(const AVersion, ADownloadedFile: string; const ASHA256: string = ''): Boolean;
var
  ArchiveSize: Int64;
  FileExt: string;
  Paths: TBuildCacheBinaryArtifactPaths;
  SHA256Hash: string;
begin
  Result := False;

  if not FileExists(ADownloadedFile) then
    Exit;

  ForceDirectories(FCacheDir);

  FileExt := BuildCacheResolveBinaryFileExt(ADownloadedFile);
  Paths := BuildCacheBuildBinaryArtifactPaths(FCacheDirWithDelim,
    GetArtifactKey(AVersion), FileExt);

  try
    if not FileCopy(ADownloadedFile, Paths.ArchivePath) then
      Exit;
  except
    on E: Exception do
      Exit;
  end;

  ArchiveSize := BuildCacheReadBinaryArchiveSize(Paths.ArchivePath);
  SHA256Hash := BuildCacheResolveBinarySHA256(ASHA256, Paths.ArchivePath);

  BuildCacheSaveBinaryMeta(Paths.MetaPath, AVersion, GetCurrentCPU, GetCurrentOS,
    SHA256Hash, FileExt, ArchiveSize);
  Result := True;
end;

function TBuildCache.RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;
var
  Info: TArtifactInfo;
  Plan: TBuildCacheBinaryRestorePlan;
begin
  Result := False;

  if not GetBinaryArtifactInfo(AVersion, Info) then
    Exit;

  Plan := BuildCacheBuildBinaryRestorePlan(FCacheDirWithDelim,
    GetArtifactKey(AVersion), Info.FileExt);

  if not FileExists(Plan.ArchivePath) then
    Exit;

  if FVerifyOnRestore then
  begin
    if Info.SHA256 <> '' then
    begin
      if not VerifyArtifact(Plan.ArchivePath, Info.SHA256) then
      begin
        WriteLn('Error: Cache integrity verification failed for ', AVersion);
        WriteLn('  Expected SHA256: ', Info.SHA256);
        WriteLn('  The cached artifact may be corrupted or tampered with.');
        Inc(FCacheMisses);
        Exit;
      end;
    end;
  end;

  ForceDirectories(ADestPath);

  {$IFDEF MSWINDOWS}
  if not RunCommand('tar', ['--version'], '') then
  begin
    Result := RunCommand('7z', ['x', '-y', '-o' + ADestPath, Plan.ArchivePath], '');
  end
  else
    Result := RunCommand('tar', [Plan.TarFlags, Plan.ArchivePath, '-C', ADestPath, '--strip-components=1'], '');
  {$ELSE}
  Result := RunCommand('tar', [Plan.TarFlags, Plan.ArchivePath, '-C', ADestPath, '--strip-components=1'], '');
  {$ENDIF}

  if Result then
    Inc(FCacheHits)
  else
    Inc(FCacheMisses);
end;

function TBuildCache.GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  ArtifactKey: string;
  BinaryInfo: TBinaryMetaArtifactInfo;
  MetaPath: string;
begin
  Result := False;
  Initialize(AInfo);

  ArtifactKey := GetArtifactKey(AVersion);
  MetaPath := BuildCacheGetBinaryMetaPath(FCacheDirWithDelim, ArtifactKey);

  if not BuildCacheLoadBinaryMeta(MetaPath, BinaryInfo) then
    Exit;

  AInfo := BuildCacheCreateBinaryArtifactInfo(FCacheDirWithDelim,
    ArtifactKey, BinaryInfo);
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
  Version: string;
  Versions: SysUtils.TStringArray;
begin
  Versions := BuildCacheCollectExpiredVersions(FCacheDirWithDelim,
    @LoadCleanupInfo, @IsExpired);
  for Version in Versions do
    DeleteArtifacts(Version);
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
  FMaxCacheSizeBytes := BuildCacheSizeGBToBytes(ASizeGB);
end;

function TBuildCache.GetMaxCacheSizeGB: Integer;
begin
  Result := BuildCacheBytesToSizeGB(FMaxCacheSizeBytes);
end;

procedure TBuildCache.SetMaxCacheSizeMB(ASizeMB: Integer);
begin
  FMaxCacheSizeBytes := BuildCacheSizeMBToBytes(ASizeMB);
end;

function TBuildCache.LoadCleanupInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Result := BuildCacheLoadCleanupArtifactInfo(AVersion,
    @GetArtifactInfo, @GetBinaryArtifactInfo, AInfo);
end;

procedure TBuildCache.SaveArtifactMetadata(const AInfo: TArtifactInfo);
var
  MetaPath: string;
begin
  MetaPath := GetArtifactMetaPath(AInfo.Version);
  BuildCacheSaveArtifactMeta(MetaPath, AInfo.Version, GetCurrentCPU, GetCurrentOS,
    AInfo.ArchivePath, AInfo.CreatedAt);
end;

procedure TBuildCache.CleanupLRU;
var
  Entries: TBuildCacheArtifactInfoArray;
  Victims: TStringArray;
  Index: Integer;
  MetaPath: string;
begin
  if FMaxCacheSizeBytes = 0 then
    Exit;

  if not DirectoryExists(FCacheDir) then
    Exit;

  Entries := BuildCacheCollectCleanupEntries(FCacheDirWithDelim, @LoadCleanupInfo);
  Victims := BuildCacheSelectCleanupVictims(Entries, FMaxCacheSizeBytes);
  for Index := 0 to High(Victims) do
  begin
    if FileExists(Victims[Index]) then
      DeleteFile(Victims[Index]);
    MetaPath := ChangeFileExt(Victims[Index], '.meta');
    if FileExists(MetaPath) then
      DeleteFile(MetaPath);
  end;
end;

{ JSON Metadata Format Methods }

function TBuildCache.GetJSONMetaPath(const AVersion: string): string;
begin
  Result := BuildCacheGetJSONMetaPath(FCacheDirWithDelim, GetArtifactKey(AVersion));
end;

function TBuildCache.HasMetadataJSON(const AVersion: string): Boolean;
begin
  Result := BuildCacheHasMetadataJSON(GetJSONMetaPath(AVersion));
end;

procedure TBuildCache.SaveMetadataJSON(const AInfo: TArtifactInfo);
var
  HelperInfo: TMetaJSONArtifactInfo;
begin
  HelperInfo := BuildCacheCreateMetaJSONArtifactInfo(AInfo);
  BuildCacheSaveMetadataJSON(
    GetJSONMetaPath(HelperInfo.Version),
    HelperInfo.Version, HelperInfo.CPU, HelperInfo.OS, HelperInfo.ArchivePath,
    HelperInfo.ArchiveSize, HelperInfo.CreatedAt,
    HelperInfo.SourceType, HelperInfo.SHA256, HelperInfo.DownloadURL, HelperInfo.SourcePath,
    HelperInfo.AccessCount, HelperInfo.LastAccessed
  );
end;

function TBuildCache.LoadMetadataJSON(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
var
  HelperInfo: TMetaJSONArtifactInfo;
begin
  Result := BuildCacheLoadMetadataJSON(GetJSONMetaPath(AVersion), HelperInfo);
  if Result then
    AInfo := BuildCacheCreateJSONArtifactInfo(HelperInfo)
  else
    Initialize(AInfo);
end;

function TBuildCache.MigrateMetadataToJSON(const AVersion: string): Boolean;
var
  Info: TArtifactInfo;
  OldMetaPath: string;
begin
  Result := False;

  OldMetaPath := GetArtifactMetaPath(AVersion);
  if not FileExists(OldMetaPath) then
    Exit;

  if not GetArtifactInfo(AVersion, Info) then
    Exit;

  SaveMetadataJSON(Info);
  if not HasMetadataJSON(AVersion) then
    Exit;

  Result := BuildCacheFinalizeMetaMigration(OldMetaPath);
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
  Index: Integer;
  Infos: TBuildCacheRebuildInfoArray;
  Versions: SysUtils.TStringArray;
begin
  // B065: Clear and mark as loaded, prevent UpdateIndexEntry from backfilling old index
  FIndexEntries.Clear;
  FIndexLoaded := True;

  if not DirectoryExists(FCacheDir) then
    Exit;

  Versions := BuildCacheListMetadataVersions(FCacheDirWithDelim);
  Infos := BuildCacheCollectRebuildInfos(Versions, @LoadMetadataJSON);
  for Index := 0 to High(Infos) do
    UpdateIndexEntry(Infos[Index]);

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
begin
  EnsureIndexLoaded;

  EntryJSON := BuildCacheGetIndexEntryJSON(FIndexEntries, AVersion);
  if EntryJSON = '' then
  begin
    Initialize(AInfo);
    Exit(False);
  end;

  Result := BuildCacheLookupIndexArtifactInfo(EntryJSON, AInfo);
end;

procedure TBuildCache.UpdateIndexEntry(const AInfo: TArtifactInfo);
begin
  EnsureIndexLoaded;
  BuildCacheUpsertIndexEntry(FIndexEntries, AInfo);
end;

procedure TBuildCache.RemoveIndexEntry(const AVersion: string);
begin
  EnsureIndexLoaded;
  BuildCacheRemoveIndexEntryVersion(FIndexEntries, AVersion);
end;

function TBuildCache.GetIndexStatistics: TCacheIndexStats;
var
  Infos: TBuildCacheIndexInfoArray;
begin
  EnsureIndexLoaded;
  Infos := BuildCacheCollectIndexInfos(FIndexEntries, @LookupIndexEntry);
  Result := BuildCacheCalculateIndexStats(Infos, FIndexEntries.Count);
end;

{ Phase 3: Statistics Enhancement Methods }

procedure TBuildCache.RecordAccess(const AVersion: string);
begin
  BuildCacheRecordIndexAccessCore(
    AVersion,
    Now,
    @LookupIndexEntry,
    @UpdateIndexEntry,
    @SaveMetadataJSON,
    @SaveIndex
  );
end;

function TBuildCache.GetDetailedStats: TCacheDetailedStats;
var
  Infos: TBuildCacheIndexInfoArray;
begin
  EnsureIndexLoaded;
  Infos := BuildCacheCollectIndexInfos(FIndexEntries, @LookupIndexEntry);
  Result := BuildCacheGetDetailedStatsCore(Infos);
end;

function TBuildCache.GetLeastRecentlyUsed: string;
var
  Infos: TBuildCacheIndexInfoArray;
begin
  EnsureIndexLoaded;
  Infos := BuildCacheCollectIndexInfos(FIndexEntries, @LookupIndexEntry);
  Result := BuildCacheSelectLeastRecentlyUsed(Infos);
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
