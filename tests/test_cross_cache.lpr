program test_cross_cache;
{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, Classes,
  fpdev.cross.cache, fpdev.hash, fpdev.utils.fs;

type
  { TCrossCacheTest }
  TCrossCacheTest = class
  private
    FTestCacheDir: string;
    FTestDataDir: string;
    FTestsPassed: Integer;
    FTestsFailed: Integer;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);

    procedure SetupTestEnvironment;
    procedure CleanupTestEnvironment;
    function CreateTestFile(const APath, AContent: string): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Unit tests
    procedure TestCacheDirUsesSystemTempAndUniqueSuffix;
    procedure TestCleanupRemovesNestedDirectories;
    procedure TestCachePathGeneration;
    procedure TestStoreAndRetrieveArchive;
    procedure TestHasValidCache;
    procedure TestInvalidateCache;
    procedure TestCacheWithInvalidChecksum;

    // Property-based tests
    procedure TestProperty5_CacheHitOptimization;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TCrossCacheTest }

constructor TCrossCacheTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  FTestCacheDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fpdev_cache_test-' + IntToHex(PtrUInt(Self), SizeOf(Pointer) * 2) +
    '-' + IntToStr(GetTickCount64) + PathDelim;
  FTestDataDir := 'tests' + PathDelim + 'data' + PathDelim + 'cross' + PathDelim;
end;

destructor TCrossCacheTest.Destroy;
begin
  CleanupTestEnvironment;
  inherited Destroy;
end;

procedure TCrossCacheTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
    WriteLn('  [PASS] ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('  [FAIL] ', AMessage);
  end;
end;

procedure TCrossCacheTest.AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TCrossCacheTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(SameText(AExpected, AActual), AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TCrossCacheTest.SetupTestEnvironment;
begin
  // Create test cache directory
  if not DirectoryExists(FTestCacheDir) then
    ForceDirectories(FTestCacheDir);
end;

procedure TCrossCacheTest.CleanupTestEnvironment;
begin
  if DirectoryExists(FTestCacheDir) then
    DeleteDirRecursive(FTestCacheDir);
end;

function TCrossCacheTest.CreateTestFile(const APath, AContent: string): Boolean;
var
  SL: TStringList;
begin
  Result := False;
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    try
      SL.SaveToFile(APath);
      Result := True;
    except
      // Ignore
    end;
  finally
    SL.Free;
  end;
end;

procedure TCrossCacheTest.RunAllTests;
begin
  WriteLn('=== Cross Toolchain Cache Tests ===');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  SetupTestEnvironment;
  try
    // Unit tests
    WriteLn('--- Unit Tests ---');
    TestCacheDirUsesSystemTempAndUniqueSuffix;
    TestCleanupRemovesNestedDirectories;
    TestCachePathGeneration;
    TestStoreAndRetrieveArchive;
    TestHasValidCache;
    TestInvalidateCache;
    TestCacheWithInvalidChecksum;

    WriteLn;
    WriteLn('--- Property-Based Tests ---');
    TestProperty5_CacheHitOptimization;
  finally
    CleanupTestEnvironment;
  end;

  WriteLn;
  WriteLn('=== Test Results ===');
  WriteLn('Tests Passed: ', FTestsPassed);
  WriteLn('Tests Failed: ', FTestsFailed);
  WriteLn('Total Tests: ', FTestsPassed + FTestsFailed);

  if FTestsFailed = 0 then
    WriteLn('All tests passed!')
  else
    WriteLn('Some tests failed!');
end;

procedure TCrossCacheTest.TestCacheDirUsesSystemTempAndUniqueSuffix;
var
  Other: TCrossCacheTest;
begin
  WriteLn('TestCacheDirUsesSystemTempAndUniqueSuffix:');

  AssertTrue(
    Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(FTestCacheDir)) = 1,
    'Cache directory should live under system temp'
  );

  Other := TCrossCacheTest.Create;
  try
    AssertTrue(
      ExpandFileName(FTestCacheDir) <> ExpandFileName(Other.FTestCacheDir),
      'Cache directory should be unique per test instance'
    );
  finally
    Other.Free;
    SetupTestEnvironment;
  end;

  WriteLn;
end;

procedure TCrossCacheTest.TestCleanupRemovesNestedDirectories;
var
  Other: TCrossCacheTest;
  OtherDir: string;
  NestedDir: string;
  NestedFile: string;
  TestData: TStringList;
begin
  WriteLn('TestCleanupRemovesNestedDirectories:');

  Other := TCrossCacheTest.Create;
  try
    OtherDir := Other.FTestCacheDir;
    NestedDir := IncludeTrailingPathDelimiter(OtherDir) + 'nested' + PathDelim + 'deep';
    NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'cache.txt';
    ForceDirectories(NestedDir);

    TestData := TStringList.Create;
    try
      TestData.Add('cache');
      TestData.SaveToFile(NestedFile);
    finally
      TestData.Free;
    end;
  finally
    Other.Free;
  end;

  AssertFalse(DirectoryExists(OtherDir), 'Cleanup should remove nested cache directories');

  if DirectoryExists(OtherDir) then
    DeleteDirRecursive(OtherDir);
  if not DirectoryExists(FTestCacheDir) then
    ForceDirectories(FTestCacheDir);

  WriteLn;
end;

procedure TCrossCacheTest.TestCachePathGeneration;
var
  Cache: TCrossToolchainCache;
  CachePath: string;
begin
  WriteLn('TestCachePathGeneration:');

  Cache := TCrossToolchainCache.Create(FTestCacheDir);
  try
    // Test that cache returns empty for non-existent files
    CachePath := Cache.GetCachedArchive('win64', 'binutils');
    AssertTrue(CachePath = '', 'Should return empty for non-existent cache');

    // Verify cache directory is set
    AssertEquals(FTestCacheDir, Cache.CacheDir, 'CacheDir should match');
  finally
    Cache.Free;
  end;
  WriteLn;
end;

procedure TCrossCacheTest.TestStoreAndRetrieveArchive;
var
  Cache: TCrossToolchainCache;
  TestFilePath, CachedPath: string;
begin
  WriteLn('TestStoreAndRetrieveArchive:');

  // Create a test file
  TestFilePath := FTestCacheDir + 'test_source.zip';
  AssertTrue(CreateTestFile(TestFilePath, 'test archive content'),
    'Should create test file');

  Cache := TCrossToolchainCache.Create(FTestCacheDir);
  try
    // Store the archive
    AssertTrue(Cache.StoreArchive(TestFilePath, 'win64', 'binutils'),
      'Should store archive successfully');

    // Retrieve the cached archive
    CachedPath := Cache.GetCachedArchive('win64', 'binutils');
    AssertTrue(CachedPath <> '', 'Should find cached archive');
    AssertTrue(FileExists(CachedPath), 'Cached file should exist');
  finally
    Cache.Free;
  end;

  // Cleanup
  DeleteFile(TestFilePath);
  WriteLn;
end;

procedure TCrossCacheTest.TestHasValidCache;
var
  Cache: TCrossToolchainCache;
  TestFilePath, ExpectedSHA256: string;
begin
  WriteLn('TestHasValidCache:');

  // Create a test file with known content
  TestFilePath := FTestCacheDir + 'test_valid.zip';
  AssertTrue(CreateTestFile(TestFilePath, 'known content for sha256'),
    'Should create test file');

  // Calculate expected SHA256
  ExpectedSHA256 := SHA256FileHex(TestFilePath);
  AssertTrue(Length(ExpectedSHA256) = 64, 'SHA256 should be 64 chars');

  Cache := TCrossToolchainCache.Create(FTestCacheDir);
  try
    // Store the archive
    AssertTrue(Cache.StoreArchive(TestFilePath, 'linux64', 'libraries'),
      'Should store archive');

    // Check with correct checksum
    AssertTrue(Cache.HasValidCache('linux64', 'libraries', ExpectedSHA256),
      'Should have valid cache with correct checksum');

    // Check with wrong checksum (must be 64 chars)
    AssertFalse(Cache.HasValidCache('linux64', 'libraries', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
      'Should not have valid cache with wrong checksum');

    // Check for non-existent target
    AssertFalse(Cache.HasValidCache('nonexistent', 'binutils', ExpectedSHA256),
      'Should not have cache for non-existent target');
  finally
    Cache.Free;
  end;

  // Cleanup
  DeleteFile(TestFilePath);
  WriteLn;
end;

procedure TCrossCacheTest.TestInvalidateCache;
var
  Cache: TCrossToolchainCache;
  TestFilePath, CachedPath: string;
begin
  WriteLn('TestInvalidateCache:');

  // Create and store a test file
  TestFilePath := FTestCacheDir + 'test_invalidate.zip';
  AssertTrue(CreateTestFile(TestFilePath, 'content to invalidate'),
    'Should create test file');

  Cache := TCrossToolchainCache.Create(FTestCacheDir);
  try
    // Store the archive
    AssertTrue(Cache.StoreArchive(TestFilePath, 'darwin64', 'binutils'),
      'Should store archive');

    // Verify it exists
    CachedPath := Cache.GetCachedArchive('darwin64', 'binutils');
    AssertTrue(CachedPath <> '', 'Should find cached archive before invalidation');

    // Invalidate
    Cache.InvalidateCache('darwin64', 'binutils');

    // Verify it's gone
    CachedPath := Cache.GetCachedArchive('darwin64', 'binutils');
    AssertTrue(CachedPath = '', 'Should not find cached archive after invalidation');
  finally
    Cache.Free;
  end;

  // Cleanup
  DeleteFile(TestFilePath);
  WriteLn;
end;

procedure TCrossCacheTest.TestCacheWithInvalidChecksum;
var
  Cache: TCrossToolchainCache;
  TestFilePath: string;
begin
  WriteLn('TestCacheWithInvalidChecksum:');

  // Create a test file
  TestFilePath := FTestCacheDir + 'test_checksum.zip';
  AssertTrue(CreateTestFile(TestFilePath, 'checksum test content'),
    'Should create test file');

  Cache := TCrossToolchainCache.Create(FTestCacheDir);
  try
    // Store the archive
    AssertTrue(Cache.StoreArchive(TestFilePath, 'arm64', 'libraries'),
      'Should store archive');

    // Try to validate with completely wrong checksum
    AssertFalse(Cache.HasValidCache('arm64', 'libraries',
      '0000000000000000000000000000000000000000000000000000000000000000'),
      'Should reject cache with wrong checksum');

    // Get actual SHA256
    AssertTrue(Length(Cache.GetCachedSHA256('arm64', 'libraries')) = 64,
      'Should return valid SHA256 for cached file');
  finally
    Cache.Free;
  end;

  // Cleanup
  DeleteFile(TestFilePath);
  WriteLn;
end;

{ Property-Based Tests }

procedure TCrossCacheTest.TestProperty5_CacheHitOptimization;
{
  **Feature: cross-toolchain-download, Property 5: Cache Hit Optimization**
  **Validates: Requirements 2.6, 3.6, 5.1, 5.2**

  *For any* toolchain installation request where a cached archive exists with
  matching SHA256 checksum, no network download SHALL occur and the cached
  archive SHALL be used.

  This test verifies that:
  1. When a file is stored in cache, it can be retrieved
  2. The retrieved file has the same SHA256 as the original
  3. HasValidCache returns true only when checksums match
}
const
  ITERATIONS = 100;
var
  Cache: TCrossToolchainCache;
  i, PassCount: Integer;
  TestFilePath, CachedPath, OriginalSHA256, CachedSHA256: string;
  TestContent: string;
  AllPassed: Boolean;
begin
  WriteLn('TestProperty5_CacheHitOptimization:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');

  AllPassed := True;
  PassCount := 0;

  Cache := TCrossToolchainCache.Create(FTestCacheDir);
  try
    for i := 1 to ITERATIONS do
    begin
      // Generate unique test content for each iteration
      TestContent := 'Test content iteration ' + IntToStr(i) + ' ' +
                     FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);

      TestFilePath := FTestCacheDir + 'prop5_test_' + IntToStr(i) + '.zip';

      // Create test file
      if not CreateTestFile(TestFilePath, TestContent) then
      begin
        AllPassed := False;
        Continue;
      end;

      // Calculate original SHA256
      OriginalSHA256 := SHA256FileHex(TestFilePath);

      // Store in cache
      if not Cache.StoreArchive(TestFilePath, 'target' + IntToStr(i), 'binutils') then
      begin
        AllPassed := False;
        DeleteFile(TestFilePath);
        Continue;
      end;

      // Verify cache hit with correct checksum
      if not Cache.HasValidCache('target' + IntToStr(i), 'binutils', OriginalSHA256) then
      begin
        AllPassed := False;
        DeleteFile(TestFilePath);
        Continue;
      end;

      // Get cached file and verify SHA256 matches
      CachedPath := Cache.GetCachedArchive('target' + IntToStr(i), 'binutils');
      if CachedPath = '' then
      begin
        AllPassed := False;
        DeleteFile(TestFilePath);
        Continue;
      end;

      CachedSHA256 := SHA256FileHex(CachedPath);
      if not SameText(OriginalSHA256, CachedSHA256) then
      begin
        AllPassed := False;
        DeleteFile(TestFilePath);
        Continue;
      end;

      // Verify cache miss with wrong checksum
      if Cache.HasValidCache('target' + IntToStr(i), 'binutils',
         'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff') then
      begin
        AllPassed := False;
        DeleteFile(TestFilePath);
        Continue;
      end;

      Inc(PassCount);

      // Cleanup this iteration
      DeleteFile(TestFilePath);
      Cache.InvalidateCache('target' + IntToStr(i), 'binutils');
    end;

    AssertTrue(AllPassed, 'Property 5: Cache hit optimization (' +
      IntToStr(PassCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  finally
    Cache.Free;
  end;
  WriteLn;
end;

{ Main }

var
  Test: TCrossCacheTest;
begin
  try
    WriteLn('Cross Toolchain Cache Test Suite');
    WriteLn('=================================');
    WriteLn;

    Test := TCrossCacheTest.Create;
    try
      Test.RunAllTests;

      if Test.TestsFailed > 0 then
        ExitCode := 1;
    finally
      Test.Free;
    end;

    WriteLn;
    WriteLn('Test suite completed.');

  except
    on E: Exception do
    begin
      WriteLn('Error running tests: ', E.Message);
      ExitCode := 1;
    end;
  end;

  PauseIfRequested('Press Enter to continue...');
end.
