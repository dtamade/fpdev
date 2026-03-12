program test_cache_ttl;

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

  CacheDir := MakeTempDir('fpdev-test-cache-cleanup');
  AssertPathIsUnderSystemTemp(CacheDir, 'Cleanup temp directory should live under system temp');

  NestedDir := IncludeTrailingPathDelimiter(CacheDir) + 'nested' + PathDelim + 'deep';
  NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'artifact.txt';
  ForceDirectories(NestedDir);

  TestData := TStringList.Create;
  try
    TestData.Add('artifact');
    TestData.SaveToFile(NestedFile);
  finally
    TestData.Free;
  end;

  CleanupTestDir(CacheDir);
  Assert(not DirectoryExists(CacheDir), 'Cleanup should remove nested cache TTL test directory');
end;

procedure TestTTLExpiration;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestTTLExpiration ===');

  CacheDir := MakeTempDir('fpdev-test-cache-ttl');
  AssertPathIsUnderSystemTemp(CacheDir, 'TTL expiration temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Cache.SetTTLDays(0);
      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CreatedAt := IncDay(Now, -365);
      Assert(not Cache.IsExpired(Info), 'TTL=0 should never expire');

      Cache.SetTTLDays(30);
      Info.CreatedAt := IncDay(Now, -15);
      Assert(not Cache.IsExpired(Info), 'Entry within TTL should not be expired');

      Info.CreatedAt := IncDay(Now, -45);
      Assert(Cache.IsExpired(Info), 'Entry beyond TTL should be expired');

      Info.CreatedAt := IncDay(Now, -30);
      Assert(Cache.IsExpired(Info), 'Entry at TTL boundary should be expired');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

procedure TestTTLConfiguration;
var
  Cache: TBuildCache;
  CacheDir: string;
begin
  WriteLn('=== TestTTLConfiguration ===');

  CacheDir := MakeTempDir('fpdev-test-cache-ttl-config');
  AssertPathIsUnderSystemTemp(CacheDir, 'TTL config temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Assert(Cache.GetTTLDays = 30, 'Default TTL should be 30 days');

      Cache.SetTTLDays(60);
      Assert(Cache.GetTTLDays = 60, 'Custom TTL should be 60 days');

      Cache.SetTTLDays(0);
      Assert(Cache.GetTTLDays = 0, 'TTL=0 should be allowed');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

procedure TestCleanExpired;
var
  Cache: TBuildCache;
  CacheDir: string;
  TestFile: string;
  MetaFile: TStringList;
begin
  WriteLn('=== TestCleanExpired ===');

  CacheDir := MakeTempDir('fpdev-test-cache-clean');
  AssertPathIsUnderSystemTemp(CacheDir, 'CleanExpired temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Cache.SetTTLDays(30);

      TestFile := CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz';
      MetaFile := TStringList.Create;
      try
        MetaFile.Add('dummy');
        MetaFile.SaveToFile(TestFile);

        MetaFile.Clear;
        MetaFile.Add('version=3.2.0');
        MetaFile.Add('cpu=x86_64');
        MetaFile.Add('os=linux');
        MetaFile.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', IncDay(Now, -45)));
        MetaFile.SaveToFile(CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.meta');
      finally
        MetaFile.Free;
      end;

      Assert(FileExists(TestFile), 'Test file should exist before cleanup');
      Cache.CleanExpired;
      Assert(not FileExists(TestFile), 'Expired entry should be removed');
    finally
      Cache.Free;
    end;
  finally
    CleanupTestDir(CacheDir);
  end;
end;

begin
  Randomize;
  WriteLn('Running Cache TTL Tests...');
  WriteLn;

  TestCleanupRemovesNestedDirectories;
  TestTTLExpiration;
  TestTTLConfiguration;
  TestCleanExpired;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
