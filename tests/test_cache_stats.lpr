program test_cache_stats;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.cache, fpdev.build.cache.types;

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

procedure CleanupTestDir(const ADir: string);
var
  SR: TSearchRec;
begin
  if not DirectoryExists(ADir) then Exit;

  // Delete all files in directory
  if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
        DeleteFile(ADir + PathDelim + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(ADir);
end;

procedure TestAccessTracking;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestAccessTracking ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-stats-access';
  CleanupTestDir(CacheDir);  // Clean before creating
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create cache entry
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

      // Test 1: Initial access count should be 0
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry');
      Assert(Info.AccessCount = 0, 'Initial access count should be 0');

      // Test 2: Record access and verify count increases
      Cache.RecordAccess('3.2.0');
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry after access');
      Assert(Info.AccessCount = 1, 'Access count should be 1 after first access');

      // Test 3: Multiple accesses
      Cache.RecordAccess('3.2.0');
      Cache.RecordAccess('3.2.0');
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Should find entry after multiple accesses');
      Assert(Info.AccessCount = 3, 'Access count should be 3 after three accesses');

      // Test 4: Last accessed time should be updated
      Assert(Info.LastAccessed > 0, 'LastAccessed should be set');
      Assert(Abs(Info.LastAccessed - Now) < (1 / 1440), 'LastAccessed should be recent (within 1 minute)');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    CleanupTestDir(CacheDir);
  end;
end;

procedure TestAccessPersistence;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestAccessPersistence ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-stats-persist';
  CleanupTestDir(CacheDir);  // Clean before creating
  ForceDirectories(CacheDir);

  try
    // Create cache and record accesses
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

    // Create new cache instance and verify access count persisted
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
    // Cleanup
    CleanupTestDir(CacheDir);
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

  CacheDir := GetTempDir + 'fpdev-test-cache-stats-detailed';
  CleanupTestDir(CacheDir);  // Clean before creating
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create multiple entries with different access patterns
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;  // 10 MB
      Info.CreatedAt := Now - 2;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 20000000;  // 20 MB
      Info.CreatedAt := Now - 1;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 30000000;  // 30 MB
      Info.CreatedAt := Now;
      Info.AccessCount := 0;
      Info.LastAccessed := 0;
      Cache.SaveMetadataJSON(Info);

      Cache.RebuildIndex;

      // Record different access patterns
      Cache.RecordAccess('3.2.0');  // 1 access
      Cache.RecordAccess('3.2.1');  // 3 accesses
      Cache.RecordAccess('3.2.1');
      Cache.RecordAccess('3.2.1');
      Cache.RecordAccess('3.2.2');  // 2 accesses
      Cache.RecordAccess('3.2.2');

      // Get detailed statistics
      Stats := Cache.GetDetailedStats;

      // Test basic stats
      Assert(Stats.TotalEntries = 3, 'Total entries should be 3');
      Assert(Stats.TotalSize = 60000000, 'Total size should be 60 MB');

      // Test access stats
      Assert(Stats.TotalAccesses = 6, 'Total accesses should be 6');
      Assert(Stats.MostAccessedVersion = '3.2.1', 'Most accessed version should be 3.2.1');
      Assert(Stats.MostAccessedCount = 3, 'Most accessed count should be 3');

      // Test average size
      Assert(Stats.AverageEntrySize = 20000000, 'Average entry size should be 20 MB');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    CleanupTestDir(CacheDir);
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

  CacheDir := GetTempDir + 'fpdev-test-cache-stats-lru';
  CleanupTestDir(CacheDir);  // Clean before creating
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create entries
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

      // Access 3.2.0 and 3.2.2, but not 3.2.1
      Cache.RecordAccess('3.2.0');
      Sleep(100);  // Small delay to ensure different timestamps
      Cache.RecordAccess('3.2.2');

      // Get least recently used version
      LRUVersion := Cache.GetLeastRecentlyUsed;
      Assert(LRUVersion = '3.2.1', 'LRU version should be 3.2.1 (never accessed)');

      // Now access 3.2.1
      Cache.RecordAccess('3.2.1');

      // LRU should now be 3.2.0 (accessed first)
      LRUVersion := Cache.GetLeastRecentlyUsed;
      Assert(LRUVersion = '3.2.0', 'LRU version should be 3.2.0 (accessed earliest)');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    CleanupTestDir(CacheDir);
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

  CacheDir := GetTempDir + 'fpdev-test-cache-stats-report';
  CleanupTestDir(CacheDir);  // Clean before creating
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create entries
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

      // Get formatted report
      Report := Cache.GetStatsReport;

      // Verify report contains key information
      Assert(Pos('entries', LowerCase(Report)) > 0, 'Report should mention entries');
      Assert(Pos('3.2.0', Report) > 0, 'Report should mention version');
      Assert(Pos('access', LowerCase(Report)) > 0, 'Report should mention access');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    CleanupTestDir(CacheDir);
  end;
end;

begin
  Randomize;
  WriteLn('Running Cache Statistics Tests...');
  WriteLn;

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
