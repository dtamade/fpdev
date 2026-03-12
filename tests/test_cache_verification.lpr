program test_cache_verification;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
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

  CacheDir := MakeTempDir('fpdev-test-cache-verification-cleanup');
  AssertPathIsUnderSystemTemp(CacheDir, 'Cache verification cleanup temp directory should live under system temp');

  NestedDir := IncludeTrailingPathDelimiter(CacheDir) + 'nested' + PathDelim + 'deep';
  NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'hash.txt';
  ForceDirectories(NestedDir);

  TestData := TStringList.Create;
  try
    TestData.Add('hash');
    TestData.SaveToFile(NestedFile);
  finally
    TestData.Free;
  end;

  CleanupTestDir(CacheDir);
  Assert(not DirectoryExists(CacheDir), 'Cleanup should remove nested cache verification test directory');
end;

procedure TestSHA256Calculation;
var
  Cache: TBuildCache;
  CacheDir, TestFile: string;
  TestData: TStringList;
  Hash1, Hash2: string;
begin
  WriteLn('=== TestSHA256Calculation ===');

  CacheDir := MakeTempDir('fpdev-test-cache-sha256');
  AssertPathIsUnderSystemTemp(CacheDir, 'SHA256 temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      TestFile := CacheDir + PathDelim + 'test.txt';
      TestData := TStringList.Create;
      try
        TestData.Add('Hello World');
        TestData.SaveToFile(TestFile);
      finally
        TestData.Free;
      end;

      Hash1 := Cache.CalculateSHA256(TestFile);
      Assert(Hash1 <> '', 'SHA256 hash should not be empty');
      Assert(Length(Hash1) = 64, 'SHA256 hash should be 64 characters (hex)');

      Hash2 := Cache.CalculateSHA256(TestFile);
      Assert(Hash1 = Hash2, 'Same file should produce same hash');

      TestData := TStringList.Create;
      try
        TestData.Add('Different Content');
        TestData.SaveToFile(TestFile);
      finally
        TestData.Free;
      end;
      Hash2 := Cache.CalculateSHA256(TestFile);
      Assert(Hash1 <> Hash2, 'Different content should produce different hash');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

procedure TestVerificationOnRestore;
var
  Cache: TBuildCache;
  CacheDir, TestArchive: string;
  TestData: TStringList;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestVerificationOnRestore ===');

  CacheDir := MakeTempDir('fpdev-test-cache-verify');
  AssertPathIsUnderSystemTemp(CacheDir, 'Verification temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Cache.SetVerifyOnRestore(True);

      TestArchive := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz';
      TestData := TStringList.Create;
      try
        TestData.Add('Test archive content');
        TestData.SaveToFile(TestArchive);
      finally
        TestData.Free;
      end;

      Initialize(Info);
      Info.Version := '3.2.2';
      Info.ArchivePath := TestArchive;
      Info.SHA256 := Cache.CalculateSHA256(TestArchive);
      Info.CreatedAt := Now;

      TestData := TStringList.Create;
      try
        TestData.Add('version=' + Info.Version);
        TestData.Add('sha256=' + Info.SHA256);
        TestData.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Info.CreatedAt));
        TestData.SaveToFile(CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.meta');
      finally
        TestData.Free;
      end;

      Assert(Cache.VerifyArtifact(TestArchive, Info.SHA256),
        'Verification should succeed with correct hash');
      Assert(not Cache.VerifyArtifact(TestArchive, 'incorrect_hash'),
        'Verification should fail with incorrect hash');

      Cache.SetVerifyOnRestore(False);
      Assert(Cache.VerifyArtifact(TestArchive, 'incorrect_hash'),
        'Verification should be skipped when disabled');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

procedure TestVerificationPerformance;
var
  Cache: TBuildCache;
  CacheDir, TestFile: string;
  TestData: TStringList;
  StartTime, EndTime: TDateTime;
  ElapsedMS: Int64;
  i: Integer;
begin
  WriteLn('=== TestVerificationPerformance ===');

  CacheDir := MakeTempDir('fpdev-test-cache-perf');
  AssertPathIsUnderSystemTemp(CacheDir, 'Verification performance temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      TestFile := CacheDir + PathDelim + 'large.txt';
      TestData := TStringList.Create;
      try
        for i := 1 to 10000 do
          TestData.Add('Line ' + IntToStr(i) + ' with some test data to make it larger');
        TestData.SaveToFile(TestFile);
      finally
        TestData.Free;
      end;

      StartTime := Now;
      Cache.CalculateSHA256(TestFile);
      EndTime := Now;
      ElapsedMS := MilliSecondsBetween(EndTime, StartTime);

      WriteLn('  Verification time for ~1MB file: ', ElapsedMS, 'ms');
      Assert(ElapsedMS < 1000, 'Verification should complete in < 1000ms for 1MB file');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

begin
  Randomize;
  WriteLn('Running Cache Verification Tests...');
  WriteLn;

  TestCleanupRemovesNestedDirectories;
  TestSHA256Calculation;
  TestVerificationOnRestore;
  TestVerificationPerformance;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
