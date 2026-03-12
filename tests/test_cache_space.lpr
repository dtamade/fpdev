program test_cache_space;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache, fpdev.build.cache.types, fpdev.utils.fs;

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

function MakeTempDir(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + APrefix + '-' + IntToStr(GetTickCount64) + '-' + IntToStr(Random(10000));
  ForceDirectories(Result);
end;

procedure AssertPathIsUnderSystemTemp(const APath, ATestName: string);
begin
  Assert(
    Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(APath)) = 1,
    ATestName
  );
end;

procedure CleanupTestDir(const ADir: string);
begin
  if DirectoryExists(ADir) then
    DeleteDirRecursive(ADir);
end;

procedure TestCleanupRemovesNestedDirectories;
var
  CacheDir: string;
  NestedDir: string;
  NestedFile: string;
  TestData: TStringList;
begin
  WriteLn('=== TestCleanupRemovesNestedDirectories ===');

  CacheDir := MakeTempDir('fpdev-test-cache-space-cleanup');
  AssertPathIsUnderSystemTemp(CacheDir, 'Cache space cleanup temp directory should live under system temp');

  NestedDir := IncludeTrailingPathDelimiter(CacheDir) + 'nested' + PathDelim + 'deep';
  NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'artifact.bin';
  ForceDirectories(NestedDir);

  TestData := TStringList.Create;
  try
    TestData.Add('artifact');
    TestData.SaveToFile(NestedFile);
  finally
    TestData.Free;
  end;

  CleanupTestDir(CacheDir);
  Assert(not DirectoryExists(CacheDir), 'Cleanup should remove nested cache space test directory');
end;

procedure TestSpaceLimitConfiguration;
var
  Cache: TBuildCache;
  CacheDir: string;
begin
  WriteLn('=== TestSpaceLimitConfiguration ===');

  CacheDir := MakeTempDir('fpdev-test-cache-space-config');
  AssertPathIsUnderSystemTemp(CacheDir, 'Space limit temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Assert(Cache.GetMaxCacheSizeGB = 10, 'Default max cache size should be 10 GB');
      Cache.SetMaxCacheSizeGB(20);
      Assert(Cache.GetMaxCacheSizeGB = 20, 'Custom max cache size should be 20 GB');
      Cache.SetMaxCacheSizeGB(0);
      Assert(Cache.GetMaxCacheSizeGB = 0, 'Max cache size=0 should mean unlimited');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
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

  CacheDir := MakeTempDir('fpdev-test-cache-lru');
  AssertPathIsUnderSystemTemp(CacheDir, 'LRU cleanup temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Cache.SetMaxCacheSizeGB(0);
      Cache.SetMaxCacheSizeMB(1);

      TestData := TStringList.Create;
      try
        for i := 1 to 15000 do
          TestData.Add('Line ' + IntToStr(i) + ' with some test data to make it larger');

        TestFile1 := CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile1);
        Sleep(100);

        Initialize(Info);
        Info.Version := '3.2.0';
        Info.CreatedAt := Now - 2;
        Info.ArchivePath := TestFile1;
        Cache.SaveArtifactMetadata(Info);

        TestFile2 := CacheDir + PathDelim + 'fpc-3.2.1-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile2);
        Sleep(100);

        Initialize(Info);
        Info.Version := '3.2.1';
        Info.CreatedAt := Now - 1;
        Info.ArchivePath := TestFile2;
        Cache.SaveArtifactMetadata(Info);

        TestFile3 := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz';
        TestData.SaveToFile(TestFile3);

        Initialize(Info);
        Info.Version := '3.2.2';
        Info.CreatedAt := Now;
        Info.ArchivePath := TestFile3;
        Cache.SaveArtifactMetadata(Info);
      finally
        TestData.Free;
      end;

      Assert(FileExists(TestFile1) and FileExists(TestFile2) and FileExists(TestFile3),
        'All test files should exist before cleanup');

      Cache.CleanupLRU;
      Assert(not FileExists(TestFile1), 'Oldest file should be removed');
      Assert(not FileExists(TestFile2), 'Middle file should be removed');
      Assert(FileExists(TestFile3), 'Newest file should remain');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
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

  CacheDir := MakeTempDir('fpdev-test-cache-unlimited');
  AssertPathIsUnderSystemTemp(CacheDir, 'Unlimited cache temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Cache.SetMaxCacheSizeGB(0);

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

      Cache.CleanupLRU;
      Assert(FileExists(TestFile1) and FileExists(TestFile2),
        'With unlimited cache, no files should be removed');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

begin
  Randomize;
  WriteLn('Running Cache Space Management Tests...');
  WriteLn;

  TestCleanupRemovesNestedDirectories;
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
