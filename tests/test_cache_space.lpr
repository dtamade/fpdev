program test_cache_space;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache;

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

procedure TestSpaceLimitConfiguration;
var
  Cache: TBuildCache;
  CacheDir: string;
begin
  WriteLn('=== TestSpaceLimitConfiguration ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-space-config-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Test 1: Default limit is 10 GB
      Assert(Cache.GetMaxCacheSizeGB = 10, 'Default max cache size should be 10 GB');

      // Test 2: Custom limit can be set
      Cache.SetMaxCacheSizeGB(20);
      Assert(Cache.GetMaxCacheSizeGB = 20, 'Custom max cache size should be 20 GB');

      // Test 3: Limit=0 means unlimited
      Cache.SetMaxCacheSizeGB(0);
      Assert(Cache.GetMaxCacheSizeGB = 0, 'Max cache size=0 should mean unlimited');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestLRUCleanup;
var
  Cache: TBuildCache;
  CacheDir: string;
  TestFile1, TestFile2, TestFile3: string;
  TestData: TStringList;
  Info: TArtifactInfo;
  i: Integer;
begin
  WriteLn('=== TestLRUCleanup ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-lru-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Set very small cache limit (1 MB = 0.001 GB)
      Cache.SetMaxCacheSizeGB(0);  // Start with unlimited
      Cache.SetMaxCacheSizeMB(1);  // 1 MB limit

      // Create three test archives (each ~500KB)
      TestData := TStringList.Create;
      try
        // Fill with data to make ~500KB (need more lines due to compression)
        for i := 1 to 15000 do
          TestData.Add('Line ' + IntToStr(i) + ' with some test data to make it larger');

        // Create first archive (oldest)
        TestFile1 := CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile1);
        Sleep(100);  // Ensure different timestamps

        // Create metadata for first archive
        Initialize(Info);
        Info.Version := '3.2.0';
        Info.CreatedAt := Now - 2;  // 2 days ago
        Info.ArchivePath := TestFile1;
        Cache.SaveArtifactMetadata(Info);

        // Create second archive (middle)
        TestFile2 := CacheDir + PathDelim + 'fpc-3.2.1-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile2);
        Sleep(100);

        Initialize(Info);
        Info.Version := '3.2.1';
        Info.CreatedAt := Now - 1;  // 1 day ago
        Info.ArchivePath := TestFile2;
        Cache.SaveArtifactMetadata(Info);

        // Create third archive (newest)
        TestFile3 := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile3);

        Initialize(Info);
        Info.Version := '3.2.2';
        Info.CreatedAt := Now;  // Now
        Info.ArchivePath := TestFile3;
        Cache.SaveArtifactMetadata(Info);

      finally
        TestData.Free;
      end;

      // Test 1: All files exist before cleanup
      Assert(FileExists(TestFile1) and FileExists(TestFile2) and FileExists(TestFile3),
        'All test files should exist before cleanup');

      // Test 2: Cleanup removes oldest entries first (LRU)
      Cache.CleanupLRU;

      // After cleanup with 1MB limit, only the newest file should remain
      Assert(not FileExists(TestFile1), 'Oldest file should be removed');
      Assert(not FileExists(TestFile2), 'Middle file should be removed');
      Assert(FileExists(TestFile3), 'Newest file should remain');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestUnlimitedCache;
var
  Cache: TBuildCache;
  CacheDir: string;
  TestFile1, TestFile2: string;
  TestData: TStringList;
  i: Integer;
begin
  WriteLn('=== TestUnlimitedCache ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-unlimited-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Set unlimited cache (0 = unlimited)
      Cache.SetMaxCacheSizeGB(0);

      // Create large test files
      TestData := TStringList.Create;
      try
        for i := 1 to 10000 do
          TestData.Add('Line ' + IntToStr(i) + ' with test data');

        TestFile1 := CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile1);

        TestFile2 := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile2);
      finally
        TestData.Free;
      end;

      // Test: With unlimited cache, cleanup should not remove anything
      Cache.CleanupLRU;
      Assert(FileExists(TestFile1) and FileExists(TestFile2),
        'With unlimited cache, no files should be removed');

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
  WriteLn('Running Cache Space Management Tests...');
  WriteLn;

  TestSpaceLimitConfiguration;
  TestLRUCleanup;
  TestUnlimitedCache;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
