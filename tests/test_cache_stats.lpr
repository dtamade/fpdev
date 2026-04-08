program test_cache_stats;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.cache, fpdev.build.cache.types, test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure TestCleanupRemovesNestedDirectories;
var
  CacheDir: string;
  NestedDir: string;
  NestedFile: string;
  TestData: TStringList;
begin
  WriteLn('=== TestCleanupRemovesNestedDirectories ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-stats-cleanup');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Cache stats cleanup temp directory should live under system temp');

  NestedDir := IncludeTrailingPathDelimiter(CacheDir) + 'nested' + PathDelim + 'deep';
  NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'artifact.json';
  ForceDirectories(NestedDir);

  TestData := TStringList.Create;
  try
    TestData.Add('{"ok":true}');
    TestData.SaveToFile(NestedFile);
  finally
    TestData.Free;
  end;

  CleanupTempDir(CacheDir);
  Assert(not DirectoryExists(CacheDir), 'Cleanup should remove nested cache stats test directory');
end;

procedure TestAccessTracking;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestAccessTracking ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-stats-access');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Access tracking temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);
      Cache.RebuildIndex;

      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry');
      Assert(Info.AccessCount = 0, 'Initial access count should be 0');

      Cache.RecordAccess('3.2.0');
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry after access');
      Assert(Info.AccessCount = 1, 'Access count should be 1 after first access');

      Cache.RecordAccess('3.2.0');
      Cache.RecordAccess('3.2.0');
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry after multiple accesses');
      Assert(Info.AccessCount = 3, 'Access count should be 3 after three accesses');

      Assert(Info.LastAccessed > 0, 'LastAccessed should be set');
      Assert(Abs(Info.LastAccessed - Now) < (1 / 1440), 'LastAccessed should be recent (within 1 minute)');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
  end;
end;

procedure TestAccessPersistence;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestAccessPersistence ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-stats-persist');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Access persistence temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);
      Cache.RebuildIndex;

      Cache.RecordAccess('3.2.0');
      Cache.RecordAccess('3.2.0');
      Cache.RecordAccess('3.2.0');
    finally
      Cache.Free;
    end;

    Cache := TBuildCache.Create(CacheDir);
    try
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry in new instance');
      WriteLn('  DEBUG: AccessCount = ', Info.AccessCount, ', expected 3');
      Assert(Info.AccessCount = 3, 'Access count should persist across instances');
      Assert(Info.LastAccessed > 0, 'LastAccessed should persist across instances');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
  end;
end;

procedure TestDetailedStats;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
  Stats: TCacheDetailedStats;
begin
  WriteLn('=== TestDetailedStats ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-stats-detailed');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Detailed stats temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now - 2;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 20000000;
      Info.CreatedAt := Now - 1;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 30000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Cache.RebuildIndex;

      Cache.RecordAccess('3.2.0');
      Cache.RecordAccess('3.2.1');
      Cache.RecordAccess('3.2.1');
      Cache.RecordAccess('3.2.1');
      Cache.RecordAccess('3.2.2');
      Cache.RecordAccess('3.2.2');

      Stats := Cache.GetDetailedStats;

      Assert(Stats.TotalEntries = 3, 'Total entries should be 3');
      Assert(Stats.TotalSize = 60000000, 'Total size should be 60 MB');
      Assert(Stats.TotalAccesses = 6, 'Total accesses should be 6');
      Assert(Stats.MostAccessedVersion = '3.2.1', 'Most accessed version should be 3.2.1');
      Assert(Stats.MostAccessedCount = 3, 'Most accessed count should be 3');
      Assert(Stats.AverageEntrySize = 20000000, 'Average entry size should be 20 MB');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
  end;
end;

procedure TestLRUByAccess;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
  LRUVersion: string;
begin
  WriteLn('=== TestLRUByAccess ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-stats-lru');
  Assert(PathUsesSystemTempRoot(CacheDir), 'LRU temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Cache.RebuildIndex;

      Cache.RecordAccess('3.2.0');
      Sleep(100);
      Cache.RecordAccess('3.2.2');

      LRUVersion := Cache.GetLeastRecentlyUsed;
      Assert(LRUVersion = '3.2.1', 'LRU version should be 3.2.1 (never accessed)');

      Cache.RecordAccess('3.2.1');

      LRUVersion := Cache.GetLeastRecentlyUsed;
      Assert(LRUVersion = '3.2.0', 'LRU version should be 3.2.0 (accessed earliest)');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
  end;
end;

procedure TestStatsReport;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
  Report: string;
begin
  WriteLn('=== TestStatsReport ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-stats-report');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Stats report temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);
      Cache.RebuildIndex;

      Cache.RecordAccess('3.2.0');
      Cache.RecordAccess('3.2.0');

      Report := Cache.GetStatsReport;

      Assert(Pos('entries', LowerCase(Report)) > 0, 'Report should mention entries');
      Assert(Pos('3.2.0', Report) > 0, 'Report should mention version');
      Assert(Pos('access', LowerCase(Report)) > 0, 'Report should mention access');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
  end;
end;

begin
  WriteLn('Running Cache Statistics Tests...');
  WriteLn;

  TestCleanupRemovesNestedDirectories;
  TestAccessTracking;
  TestAccessPersistence;
  TestDetailedStats;
  TestLRUByAccess;
  TestStatsReport;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
