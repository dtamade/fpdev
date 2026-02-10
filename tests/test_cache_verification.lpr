program test_cache_verification;

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

procedure TestSHA256Calculation;
var
  Cache: TBuildCache;
  CacheDir, TestFile: string;
  TestData: TStringList;
  Hash1, Hash2: string;
begin
  WriteLn('=== TestSHA256Calculation ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-sha256-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create test file with known content
      TestFile := CacheDir + PathDelim + 'test.txt';
      TestData := TStringList.Create;
      try
        TestData.Add('Hello World');
        TestData.SaveToFile(TestFile);
      finally
        TestData.Free;
      end;

      // Test 1: Calculate SHA256 hash
      Hash1 := Cache.CalculateSHA256(TestFile);
      Assert(Hash1 <> '', 'SHA256 hash should not be empty');
      Assert(Length(Hash1) = 64, 'SHA256 hash should be 64 characters (hex)');

      // Test 2: Same file produces same hash
      Hash2 := Cache.CalculateSHA256(TestFile);
      Assert(Hash1 = Hash2, 'Same file should produce same hash');

      // Test 3: Different content produces different hash
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
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestVerificationOnRestore;
var
  Cache: TBuildCache;
  CacheDir, TestArchive, DestDir: string;
  TestData: TStringList;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestVerificationOnRestore ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-verify-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Enable verification
      Cache.SetVerifyOnRestore(True);

      // Create test archive with metadata
      TestArchive := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz';
      TestData := TStringList.Create;
      try
        TestData.Add('Test archive content');
        TestData.SaveToFile(TestArchive);
      finally
        TestData.Free;
      end;

      // Calculate hash and save metadata
      Initialize(Info);
      Info.Version := '3.2.2';
      Info.ArchivePath := TestArchive;
      Info.SHA256 := Cache.CalculateSHA256(TestArchive);
      Info.CreatedAt := Now;

      // Save metadata
      TestData := TStringList.Create;
      try
        TestData.Add('version=' + Info.Version);
        TestData.Add('sha256=' + Info.SHA256);
        TestData.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Info.CreatedAt));
        TestData.SaveToFile(CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.meta');
      finally
        TestData.Free;
      end;

      // Test 1: Verification succeeds with correct hash
      Assert(Cache.VerifyArtifact(TestArchive, Info.SHA256),
        'Verification should succeed with correct hash');

      // Test 2: Verification fails with incorrect hash
      Assert(not Cache.VerifyArtifact(TestArchive, 'incorrect_hash'),
        'Verification should fail with incorrect hash');

      // Test 3: Verification can be disabled
      Cache.SetVerifyOnRestore(False);
      Assert(Cache.VerifyArtifact(TestArchive, 'incorrect_hash'),
        'Verification should be skipped when disabled');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
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

  CacheDir := GetTempDir + 'fpdev-test-cache-perf-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create ~1MB test file
      TestFile := CacheDir + PathDelim + 'large.txt';
      TestData := TStringList.Create;
      try
        for i := 1 to 10000 do
          TestData.Add('Line ' + IntToStr(i) + ' with some test data to make it larger');
        TestData.SaveToFile(TestFile);
      finally
        TestData.Free;
      end;

      // Measure verification time
      StartTime := Now;
      Cache.CalculateSHA256(TestFile);
      EndTime := Now;
      ElapsedMS := MilliSecondsBetween(EndTime, StartTime);

      WriteLn('  Verification time for ~1MB file: ', ElapsedMS, 'ms');

      // Test: Verification should be reasonably fast (< 1000ms for 1MB)
      Assert(ElapsedMS < 1000, 'Verification should complete in < 1000ms for 1MB file');

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
  WriteLn('Running Cache Verification Tests...');
  WriteLn;

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
