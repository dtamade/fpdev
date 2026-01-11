unit fpdev.build.cache;

{$mode objfpc}{$H+}

{
  TBuildCache - Build cache management service

  Extracted from fpdev.build.manager to handle:
  - Build artifact caching
  - Incremental build detection
  - Cache invalidation
}

interface

uses
  SysUtils, Classes;

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

  { TBuildCache - Build cache management }
  TBuildCache = class
  private
    FCacheDir: string;
    FEntries: TStringList;  // Version -> entry line
    FCacheHits: Integer;    // Statistics: cache hits
    FCacheMisses: Integer;  // Statistics: cache misses
    function GetCacheFilePath: string;
    function GetEntryCount: Integer;
    procedure LoadEntries;
    procedure SaveEntries;
    function FindEntry(const AVersion: string): Integer;
  public
    constructor Create(const ACacheDir: string);
    destructor Destroy; override;
    function IsCacheValid(const AVersion: string): Boolean;
    function GetCachedBuild(const AVersion: string): string;
    procedure InvalidateCache(const AVersion: string);
    procedure UpdateCache(const AVersion: string; const AEntry: TBuildCacheEntry);
    function NeedsRebuild(const AVersion: string; AStep: TBuildStep): Boolean;
    function GetRevision(const AVersion: string): string;
    { Cache statistics }
    function GetCacheStats: string;
    procedure ClearStats;
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
  if DirectoryExists(FCacheDir) then
    LoadEntries;
end;

destructor TBuildCache.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
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

end.
