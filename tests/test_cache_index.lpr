program test_cache_index;

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

procedure TestIndexCreation;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
  IndexPath: string;
begin
  WriteLn('=== TestIndexCreation ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-index-create-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create multiple cache entries
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now - 2;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 20000000;
      Info.CreatedAt := Now - 1;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 30000000;
      Info.CreatedAt := Now;
      Cache.SaveMetadataJSON(Info);

      // Build index
      Cache.RebuildIndex;

      // Verify index file was created
      IndexPath := CacheDir + PathDelim + 'cache-index.json';
      Assert(FileExists(IndexPath), 'Index file should be created');

      // Verify index contains all entries
      Assert(Cache.GetIndexEntryCount = 3, 'Index should contain 3 entries');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestIndexLookup;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
  StartTime, EndTime: TDateTime;
  ElapsedMS: Int64;
  i: Integer;
begin
  WriteLn('=== TestIndexLookup ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-index-lookup-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create multiple cache entries
      for i := 0 to 9 do
      begin
        Initialize(Info);
        Info.Version := '3.2.' + IntToStr(i);
        Info.CPU := 'x86_64';
        Info.OS := 'linux';
        Info.ArchiveSize := Int64(i + 1) * 10000000;
        Info.CreatedAt := Now - i;
        Cache.SaveMetadataJSON(Info);
      end;

      // Build index
      Cache.RebuildIndex;

      // Test 1: Lookup by version should succeed
      Assert(Cache.LookupIndexEntry('3.2.5', Info), 'Should find entry by version');
      Assert(Info.Version = '3.2.5', 'Looked up version should match');
      Assert(Info.ArchiveSize = 60000000, 'Looked up size should match');

      // Test 2: Lookup non-existent version should fail
      Assert(not Cache.LookupIndexEntry('9.9.9', Info), 'Should not find non-existent version');

      // Test 3: Measure lookup performance (should be < 10ms)
      StartTime := Now;
      for i := 1 to 100 do
        Cache.LookupIndexEntry('3.2.5', Info);
      EndTime := Now;
      ElapsedMS := MilliSecondsBetween(EndTime, StartTime);
      WriteLn('  100 lookups took: ', ElapsedMS, 'ms');
      Assert(ElapsedMS < 100, 'Lookup should be fast (< 1ms per lookup)');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestIndexUpdate;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestIndexUpdate ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-index-update-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create initial entry
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Cache.SaveMetadataJSON(Info);
      Cache.RebuildIndex;

      Assert(Cache.GetIndexEntryCount = 1, 'Index should have 1 entry initially');

      // Add new entry and update index
      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 20000000;
      Info.CreatedAt := Now;
      Cache.SaveMetadataJSON(Info);
      Cache.UpdateIndexEntry(Info);

      Assert(Cache.GetIndexEntryCount = 2, 'Index should have 2 entries after add');

      // Verify new entry is in index
      Assert(Cache.LookupIndexEntry('3.2.1', Info), 'New entry should be in index');

      // Remove entry from index
      Cache.RemoveIndexEntry('3.2.0');
      Assert(Cache.GetIndexEntryCount = 1, 'Index should have 1 entry after remove');
      Assert(not Cache.LookupIndexEntry('3.2.0', Info), 'Removed entry should not be in index');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestIndexPersistence;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestIndexPersistence ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-index-persist-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    // Create cache and add entries
    Cache := TBuildCache.Create(CacheDir);
    try
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;
      Info.CreatedAt := Now;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 20000000;
      Info.CreatedAt := Now;
      Cache.SaveMetadataJSON(Info);

      Cache.RebuildIndex;
      Assert(Cache.GetIndexEntryCount = 2, 'Index should have 2 entries');
    finally
      Cache.Free;
    end;

    // Create new cache instance and verify index is loaded
    Cache := TBuildCache.Create(CacheDir);
    try
      // Index should be automatically loaded
      Assert(Cache.GetIndexEntryCount = 2, 'Index should persist across instances');
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Entry 3.2.0 should be in loaded index');
      Assert(Cache.LookupIndexEntry('3.2.1', Info), 'Entry 3.2.1 should be in loaded index');
    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestIndexStatistics;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
  Stats: TCacheIndexStats;
begin
  WriteLn('=== TestIndexStatistics ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-index-stats-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create entries with known sizes
      Initialize(Info);
      Info.Version := '3.2.0';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 10000000;  // 10 MB
      Info.CreatedAt := Now - 2;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.1';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 20000000;  // 20 MB
      Info.CreatedAt := Now - 1;
      Cache.SaveMetadataJSON(Info);

      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchiveSize := 30000000;  // 30 MB
      Info.CreatedAt := Now;
      Cache.SaveMetadataJSON(Info);

      Cache.RebuildIndex;

      // Get statistics from index
      Stats := Cache.GetIndexStatistics;

      Assert(Stats.TotalEntries = 3, 'Total entries should be 3');
      Assert(Stats.TotalSize = 60000000, 'Total size should be 60 MB');
      Assert(Stats.OldestVersion = '3.2.0', 'Oldest version should be 3.2.0');
      Assert(Stats.NewestVersion = '3.2.2', 'Newest version should be 3.2.2');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestIndexRebuild;
var
  Cache: TBuildCache;
  CacheDir, IndexPath: string;
  Info: TArtifactInfo;
  IndexContent: TStringList;
begin
  WriteLn('=== TestIndexRebuild ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-index-rebuild-' + IntToStr(Random(10000));
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
      Cache.SaveMetadataJSON(Info);

      Cache.RebuildIndex;
      Assert(Cache.GetIndexEntryCount = 1, 'Index should have 1 entry');

      // Corrupt the index file
      IndexPath := CacheDir + PathDelim + 'cache-index.json';
      IndexContent := TStringList.Create;
      try
        IndexContent.Add('{ invalid json }}}');
        IndexContent.SaveToFile(IndexPath);
      finally
        IndexContent.Free;
      end;

      // Rebuild should recover from corruption
      Cache.RebuildIndex;
      Assert(Cache.GetIndexEntryCount = 1, 'Index should be rebuilt from metadata files');
      Assert(Cache.LookupIndexEntry('3.2.0', Info), 'Entry should be in rebuilt index');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

begin
  Randomize;
  WriteLn('Running Cache Index Tests...');
  WriteLn;

  TestIndexCreation;
  TestIndexLookup;
  TestIndexUpdate;
  TestIndexPersistence;
  TestIndexStatistics;
  TestIndexRebuild;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
