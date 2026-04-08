program test_cache_metadata;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.cache, fpdev.build.cache.types, test_temp_paths;

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

procedure TestCleanupRemovesNestedDirectories;
var
  CacheDir: string;
  NestedDir: string;
  NestedFile: string;
  TestData: TStringList;
begin
  WriteLn('=== TestCleanupRemovesNestedDirectories ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-metadata-cleanup');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Cache metadata cleanup temp directory should live under system temp');

  NestedDir := IncludeTrailingPathDelimiter(CacheDir) + 'nested' + PathDelim + 'deep';
  NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'metadata.json';
  ForceDirectories(NestedDir);

  TestData := TStringList.Create;
  try
    TestData.Add('{"version":"3.2.2"}');
    TestData.SaveToFile(NestedFile);
  finally
    TestData.Free;
  end;

  CleanupTempDir(CacheDir);
  Assert(not DirectoryExists(CacheDir), 'Cleanup should remove nested cache metadata test directory');
end;

procedure TestJSONMetadataWrite;
var
  Cache: TBuildCache;
  CacheDir, MetaPath: string;
  MetaContent: TStringList;
  Info: TArtifactInfo;
begin
  WriteLn('=== TestJSONMetadataWrite ===');

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-json-write');
  Assert(PathUsesSystemTempRoot(CacheDir), 'JSON write temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
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

      Cache.SaveMetadataJSON(Info);

      MetaPath := CacheDir + PathDelim + 'fpc-3.2.2-x86_64-linux.json';
      Assert(FileExists(MetaPath), 'JSON metadata file should be created');

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
    CleanupTempDir(CacheDir);
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

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-json-read');
  Assert(PathUsesSystemTempRoot(CacheDir), 'JSON read temp directory should live under system temp');

  try
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
      Assert(Cache.LoadMetadataJSON('3.2.2', Info), 'Should successfully load JSON metadata');
      Assert(Info.Version = '3.2.2', 'Version should be parsed correctly');
      Assert(Info.CPU = 'x86_64', 'CPU should be parsed correctly');
      Assert(Info.OS = 'linux', 'OS should be parsed correctly');
      Assert(Info.ArchiveSize = 87654321, 'ArchiveSize should be parsed correctly');
      Assert(Info.SourceType = 'binary', 'SourceType should be parsed correctly');
      Assert(Info.SHA256 = 'deadbeef123456', 'SHA256 should be parsed correctly');
      Assert(Info.DownloadURL = 'https://example.com/fpc.tar.gz', 'DownloadURL should be parsed correctly');
      Assert(Abs(Info.CreatedAt - TestTime) < (1 / 86400), 'CreatedAt should be parsed correctly');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
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

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-compat');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Backward compatibility temp directory should live under system temp');

  try
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
      Assert(Cache.GetArtifactInfo('3.2.0', Info), 'Should read old .meta format');
      Assert(Info.Version = '3.2.0', 'Version from old format should be correct');
      Assert(Info.ArchiveSize = 55555555, 'ArchiveSize from old format should be correct');
      Assert(not Cache.HasMetadataJSON('3.2.0'), 'Old format should not be detected as JSON');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
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

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-migrate');
  Assert(PathUsesSystemTempRoot(CacheDir), 'Metadata migration temp directory should live under system temp');

  try
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
      Assert(Cache.MigrateMetadataToJSON('3.2.1'), 'Migration should succeed');
      NewMetaPath := CacheDir + PathDelim + 'fpc-3.2.1-x86_64-linux.json';
      Assert(FileExists(NewMetaPath), 'JSON file should exist after migration');
      Assert(FileExists(OldMetaPath + '.bak'), 'Old .meta should be backed up');
      Assert(Cache.LoadMetadataJSON('3.2.1', Info), 'Should load migrated JSON');
      Assert(Info.Version = '3.2.1', 'Migrated version should be correct');
      Assert(Info.ArchiveSize = 66666666, 'Migrated archive_size should be correct');
      Assert(Cache.HasMetadataJSON('3.2.1'), 'Should detect JSON after migration');
    finally
      Cache.Free;
    end;
  finally
    CleanupTempDir(CacheDir);
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

  CacheDir := CreateUniqueTempDir('fpdev-test-cache-roundtrip');
  Assert(PathUsesSystemTempRoot(CacheDir), 'JSON round-trip temp directory should live under system temp');

  try
    Cache := TBuildCache.Create(CacheDir);
    try
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

      Cache.SaveMetadataJSON(InfoIn);
      Assert(Cache.LoadMetadataJSON('3.2.3', InfoOut), 'Should load saved JSON');
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
    CleanupTempDir(CacheDir);
  end;
end;

begin
  WriteLn('Running Cache JSON Metadata Tests...');
  WriteLn;

  TestCleanupRemovesNestedDirectories;
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
