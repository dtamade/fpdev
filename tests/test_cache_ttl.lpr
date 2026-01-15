program test_cache_ttl;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
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

procedure TestTTLExpiration;
var
  Cache: TBuildCache;
  CacheDir: string;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestTTLExpiration ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-ttl-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Test 1: Entry with TTL=0 never expires
      Cache.SetTTLDays(0);
      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CreatedAt := IncDay(Now, -365); // 1 year old
      Assert(not Cache.IsExpired(Info), 'TTL=0 should never expire');

      // Test 2: Entry within TTL is not expired
      Cache.SetTTLDays(30);
      Info.CreatedAt := IncDay(Now, -15); // 15 days old
      Assert(not Cache.IsExpired(Info), 'Entry within TTL should not be expired');

      // Test 3: Entry beyond TTL is expired
      Info.CreatedAt := IncDay(Now, -45); // 45 days old
      Assert(Cache.IsExpired(Info), 'Entry beyond TTL should be expired');

      // Test 4: Entry exactly at TTL boundary
      Info.CreatedAt := IncDay(Now, -30); // Exactly 30 days old
      Assert(Cache.IsExpired(Info), 'Entry at TTL boundary should be expired');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
  end;
end;

procedure TestTTLConfiguration;
var
  Cache: TBuildCache;
  CacheDir: string;
begin
  WriteLn('=== TestTTLConfiguration ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-ttl-config-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Test 1: Default TTL is 30 days
      Assert(Cache.GetTTLDays = 30, 'Default TTL should be 30 days');

      // Test 2: Custom TTL can be set
      Cache.SetTTLDays(60);
      Assert(Cache.GetTTLDays = 60, 'Custom TTL should be 60 days');

      // Test 3: TTL=0 means never expire
      Cache.SetTTLDays(0);
      Assert(Cache.GetTTLDays = 0, 'TTL=0 should be allowed');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
      RemoveDir(CacheDir);
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

  CacheDir := GetTempDir + 'fpdev-test-cache-clean-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      Cache.SetTTLDays(30);

      // Create an expired cache entry
      TestFile := CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz';
      MetaFile := TStringList.Create;
      try
        // Create dummy archive
        MetaFile.Add('dummy');
        MetaFile.SaveToFile(TestFile);

        // Create metadata with old timestamp
        MetaFile.Clear;
        MetaFile.Add('version=3.2.0');
        MetaFile.Add('cpu=x86_64');
        MetaFile.Add('os=linux');
        MetaFile.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', IncDay(Now, -45)));
        MetaFile.SaveToFile(CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.meta');
      finally
        MetaFile.Free;
      end;

      // Test: CleanExpired removes expired entries
      Assert(FileExists(TestFile), 'Test file should exist before cleanup');
      Cache.CleanExpired;
      Assert(not FileExists(TestFile), 'Expired entry should be removed');

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
  WriteLn('Running Cache TTL Tests...');
  WriteLn;

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
