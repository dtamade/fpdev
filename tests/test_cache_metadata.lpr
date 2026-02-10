program test_cache_metadata;

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

procedure TestJSONMetadataWrite;
var
  Cache: TBuildCache;
  CacheDir, MetaPath: string;
  MetaContent: TStringList;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestJSONMetadataWrite ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-json-write-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create artifact info
      Initialize(Info);
      Info.Version := '3.2.2';
      Info.CPU := 'x86_64';
      Info.OS := 'linux';
      Info.ArchivePath := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz';
      Info.ArchiveSize := 12345678;
      Info.CreatedAt := Now;
      Info.SourceType := 'source';
      Info.SHA256 := 'abc123def456';
      Info.DownloadURL := 'https://example.com/fpc.tar.gz';

      // Save metadata in JSON format
      Cache.SaveMetadataJSON(Info);

      // Verify JSON file was created
      MetaPath := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.json';
      Assert(FileExists(MetaPath), 'JSON metadata file should be created');

      // Read and verify JSON structure
      MetaContent := TStringList.Create;
      try
        MetaContent.LoadFromFile(MetaPath);
        Assert(Pos('"version"', MetaContent.Text) > 0, 'JSON should contain version field');
        Assert(Pos('"cpu"', MetaContent.Text) > 0, 'JSON should contain cpu field');
        Assert(Pos('"os"', MetaContent.Text) > 0, 'JSON should contain os field');
        Assert(Pos('"archive_size"', MetaContent.Text) > 0, 'JSON should contain archive_size field');
        Assert(Pos('"created_at"', MetaContent.Text) > 0, 'JSON should contain created_at field');
        Assert(Pos('"source_type"', MetaContent.Text) > 0, 'JSON should contain source_type field');
        Assert(Pos('"sha256"', MetaContent.Text) > 0, 'JSON should contain sha256 field');
        Assert(Pos('"3.2.2"', MetaContent.Text) > 0, 'JSON should contain version value');
      finally
        MetaContent.Free;
      end;

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
    begin
      DeleteFile(CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.json');
      RemoveDir(CacheDir);
    end;
  end;
end;

procedure TestJSONMetadataRead;
var
  Cache: TBuildCache;
  CacheDir, MetaPath: string;
  MetaContent: TStringList;
  Info: TArtifactInfo;
  TestTime: TDateTime;
begin
  WriteLn('=== TestJSONMetadataRead ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-json-read-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    // Create JSON metadata file manually
    MetaPath := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.json';
    TestTime := EncodeDateTime(2026, 1, 16, 10, 30, 0, 0);

    MetaContent := TStringList.Create;
    try
      MetaContent.Add('{');
      MetaContent.Add('  "version": "3.2.2",');
      MetaContent.Add('  "cpu": "x86_64",');
      MetaContent.Add('  "os": "linux",');
      MetaContent.Add('  "archive_path": "' + CacheDir + '/fpc-3.2.2-x86_64-linux.tar.gz",');
      MetaContent.Add('  "archive_size": 87654321,');
      MetaContent.Add('  "created_at": "2026-01-16T10:30:00",');
      MetaContent.Add('  "source_type": "binary",');
      MetaContent.Add('  "sha256": "deadbeef123456",');
      MetaContent.Add('  "download_url": "https://example.com/fpc.tar.gz",');
      MetaContent.Add('  "access_count": 5,');
      MetaContent.Add('  "last_accessed": "2026-01-16T12:00:00"');
      MetaContent.Add('}');
      MetaContent.SaveToFile(MetaPath);
    finally
      MetaContent.Free;
    end;

    Cache := TBuildCache.Create(CacheDir);
    try
      // Read metadata from JSON
      Assert(Cache.LoadMetadataJSON('3.2.2', Info), 'Should successfully load JSON metadata');

      // Verify all fields were parsed correctly
      Assert(Info.Version = '3.2.2', 'Version should be parsed correctly');
      Assert(Info.CPU = 'x86_64', 'CPU should be parsed correctly');
      Assert(Info.OS = 'linux', 'OS should be parsed correctly');
      Assert(Info.ArchiveSize = 87654321, 'ArchiveSize should be parsed correctly');
      Assert(Info.SourceType = 'binary', 'SourceType should be parsed correctly');
      Assert(Info.SHA256 = 'deadbeef123456', 'SHA256 should be parsed correctly');
      Assert(Info.DownloadURL = 'https://example.com/fpc.tar.gz', 'DownloadURL should be parsed correctly');

      // Verify date parsing (allow 1 second tolerance)
      Assert(Abs(Info.CreatedAt - TestTime) < (1 / 86400), 'CreatedAt should be parsed correctly');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
    begin
      DeleteFile(MetaPath);
      RemoveDir(CacheDir);
    end;
  end;
end;

procedure TestBackwardCompatibility;
var
  Cache: TBuildCache;
  CacheDir, OldMetaPath: string;
  MetaContent: TStringList;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestBackwardCompatibility ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-compat-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    // Create old-format .meta file (key=value format)
    OldMetaPath := CacheDir + PathDelim + 'fpc-3.2.0-x86_64-linux.meta';
    MetaContent := TStringList.Create;
    try
      MetaContent.Add('version=3.2.0');
      MetaContent.Add('cpu=x86_64');
      MetaContent.Add('os=linux');
      MetaContent.Add('source_path=/opt/fpc/3.2.0');
      MetaContent.Add('archive_size=55555555');
      MetaContent.Add('created_at=2026-01-15 08:00:00');
      MetaContent.SaveToFile(OldMetaPath);
    finally
      MetaContent.Free;
    end;

    Cache := TBuildCache.Create(CacheDir);
    try
      // Test 1: Old format should still be readable via GetArtifactInfo
      Assert(Cache.GetArtifactInfo('3.2.0', Info), 'Should read old .meta format');
      Assert(Info.Version = '3.2.0', 'Version from old format should be correct');
      Assert(Info.ArchiveSize = 55555555, 'ArchiveSize from old format should be correct');

      // Test 2: HasMetadataJSON should return false for old format
      Assert(not Cache.HasMetadataJSON('3.2.0'), 'Old format should not be detected as JSON');

      // Test 3: HasMetadataJSON should return true after migration
      // (Migration would be triggered by MigrateToJSON method)

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
    begin
      DeleteFile(OldMetaPath);
      RemoveDir(CacheDir);
    end;
  end;
end;

procedure TestMetadataMigration;
var
  Cache: TBuildCache;
  CacheDir, OldMetaPath, NewMetaPath: string;
  MetaContent: TStringList;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestMetadataMigration ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-migrate-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    // Create old-format .meta file
    OldMetaPath := CacheDir + PathDelim + 'fpc-3.2.1-x86_64-linux.meta';
    MetaContent := TStringList.Create;
    try
      MetaContent.Add('version=3.2.1');
      MetaContent.Add('cpu=x86_64');
      MetaContent.Add('os=linux');
      MetaContent.Add('source_path=/opt/fpc/3.2.1');
      MetaContent.Add('archive_size=66666666');
      MetaContent.Add('created_at=2026-01-14 09:00:00');
      MetaContent.SaveToFile(OldMetaPath);
    finally
      MetaContent.Free;
    end;

    Cache := TBuildCache.Create(CacheDir);
    try
      // Test 1: Migrate old format to JSON
      Assert(Cache.MigrateMetadataToJSON('3.2.1'), 'Migration should succeed');

      // Test 2: JSON file should exist after migration
      NewMetaPath := CacheDir + PathDelim + 'fpc-3.2.1-x86_64-linux.json';
      Assert(FileExists(NewMetaPath), 'JSON file should exist after migration');

      // Test 3: Old .meta file should be backed up
      Assert(FileExists(OldMetaPath + '.bak'), 'Old .meta should be backed up');

      // Test 4: Data integrity - read migrated JSON and verify
      Assert(Cache.LoadMetadataJSON('3.2.1', Info), 'Should load migrated JSON');
      Assert(Info.Version = '3.2.1', 'Migrated version should be correct');
      Assert(Info.ArchiveSize = 66666666, 'Migrated archive_size should be correct');

      // Test 5: HasMetadataJSON should return true after migration
      Assert(Cache.HasMetadataJSON('3.2.1'), 'Should detect JSON after migration');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
    begin
      DeleteFile(OldMetaPath);
      DeleteFile(OldMetaPath + '.bak');
      DeleteFile(CacheDir + PathDelim + 'fpc-3.2.1-x86_64-linux.json');
      RemoveDir(CacheDir);
    end;
  end;
end;

procedure TestJSONRoundTrip;
var
  Cache: TBuildCache;
  CacheDir: string;
  InfoIn, InfoOut: TArtifactInfo;
  TestTime: TDateTime;
begin
  WriteLn('=== TestJSONRoundTrip ===');

  CacheDir := GetTempDir + 'fpdev-test-cache-roundtrip-' + IntToStr(Random(10000));
  ForceDirectories(CacheDir);

  try
    Cache := TBuildCache.Create(CacheDir);
    try
      // Create artifact info with all fields
      TestTime := EncodeDateTime(2026, 1, 16, 14, 30, 45, 0);
      Initialize(InfoIn);
      InfoIn.Version := '3.2.3';
      InfoIn.CPU := 'aarch64';
      InfoIn.OS := 'darwin';
      InfoIn.ArchivePath := CacheDir + PathDelim + 'fpc-3.2.3-aarch64-darwin.tar.gz';
      InfoIn.ArchiveSize := 99999999;
      InfoIn.CreatedAt := TestTime;
      InfoIn.SourceType := 'source';
      InfoIn.SHA256 := 'roundtrip123456789';
      InfoIn.DownloadURL := 'https://roundtrip.example.com/fpc.tar.gz';
      InfoIn.SourcePath := '/opt/fpc/3.2.3';

      // Save to JSON
      Cache.SaveMetadataJSON(InfoIn);

      // Load from JSON
      Assert(Cache.LoadMetadataJSON('3.2.3', InfoOut), 'Should load saved JSON');

      // Verify round-trip integrity
      Assert(InfoOut.Version = InfoIn.Version, 'Version should survive round-trip');
      Assert(InfoOut.CPU = InfoIn.CPU, 'CPU should survive round-trip');
      Assert(InfoOut.OS = InfoIn.OS, 'OS should survive round-trip');
      Assert(InfoOut.ArchiveSize = InfoIn.ArchiveSize, 'ArchiveSize should survive round-trip');
      Assert(InfoOut.SourceType = InfoIn.SourceType, 'SourceType should survive round-trip');
      Assert(InfoOut.SHA256 = InfoIn.SHA256, 'SHA256 should survive round-trip');
      Assert(InfoOut.DownloadURL = InfoIn.DownloadURL, 'DownloadURL should survive round-trip');
      Assert(Abs(InfoOut.CreatedAt - InfoIn.CreatedAt) < (1 / 86400), 'CreatedAt should survive round-trip');

    finally
      Cache.Free;
    end;
  finally
    // Cleanup
    if DirectoryExists(CacheDir) then
    begin
      DeleteFile(CacheDir + PathDelim + 'fpc-3.2.3-aarch64-darwin.json');
      RemoveDir(CacheDir);
    end;
  end;
end;

begin
  Randomize;
  WriteLn('Running Cache JSON Metadata Tests...');
  WriteLn;

  TestJSONMetadataWrite;
  TestJSONMetadataRead;
  TestBackwardCompatibility;
  TestMetadataMigration;
  TestJSONRoundTrip;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
