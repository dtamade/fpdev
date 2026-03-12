program test_build_cache_access;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.access;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure TestRecordAccessInfoIncrementsCountAndUpdatesTimestamp;
var
  Info: TArtifactInfo;
  Updated: TArtifactInfo;
  AccessedAt: TDateTime;
begin
  Initialize(Info);
  Info.Version := '3.2.0';
  Info.AccessCount := 2;
  Info.LastAccessed := 0;

  AccessedAt := EncodeDateTime(2026, 3, 6, 10, 11, 12, 0);
  Updated := BuildCacheRecordAccessInfo(Info, AccessedAt);

  AssertTrue(Updated.AccessCount = 3,
    'access helper increments access count');
  AssertTrue(Updated.LastAccessed = AccessedAt,
    'access helper updates last accessed timestamp');
  AssertTrue(Info.AccessCount = 2,
    'access helper does not mutate original record');
end;

procedure TestRecordAccessInfoPreservesMetadata;
var
  Info: TArtifactInfo;
  Updated: TArtifactInfo;
  AccessedAt: TDateTime;
begin
  Initialize(Info);
  Info.Version := '3.2.1';
  Info.CPU := 'x86_64';
  Info.OS := 'linux';
  Info.ArchivePath := '/tmp/fpc-3.2.1.tar.gz';
  Info.ArchiveSize := 123456;
  Info.CreatedAt := EncodeDate(2026, 1, 1);
  Info.SourcePath := '/opt/fpc/3.2.1';
  Info.SourceType := 'source';
  Info.SHA256 := 'abc123';
  Info.DownloadURL := 'https://example.invalid/fpc.tar.gz';
  Info.FileExt := '.tar.gz';
  Info.AccessCount := 0;

  AccessedAt := EncodeDateTime(2026, 3, 6, 13, 14, 15, 0);
  Updated := BuildCacheRecordAccessInfo(Info, AccessedAt);

  AssertEquals('3.2.1', Updated.Version, 'version is preserved');
  AssertEquals('x86_64', Updated.CPU, 'cpu is preserved');
  AssertEquals('linux', Updated.OS, 'os is preserved');
  AssertEquals('/tmp/fpc-3.2.1.tar.gz', Updated.ArchivePath, 'archive path is preserved');
  AssertTrue(Updated.ArchiveSize = 123456, 'archive size is preserved');
  AssertTrue(Updated.CreatedAt = EncodeDate(2026, 1, 1), 'created-at is preserved');
  AssertEquals('/opt/fpc/3.2.1', Updated.SourcePath, 'source path is preserved');
  AssertEquals('source', Updated.SourceType, 'source type is preserved');
  AssertEquals('abc123', Updated.SHA256, 'sha256 is preserved');
  AssertEquals('https://example.invalid/fpc.tar.gz', Updated.DownloadURL, 'download url is preserved');
  AssertEquals('.tar.gz', Updated.FileExt, 'file extension is preserved');
  AssertTrue(Updated.AccessCount = 1, 'access count starts from zero and increments');
end;

begin
  TestRecordAccessInfoIncrementsCountAndUpdatesTimestamp;
  TestRecordAccessInfoPreservesMetadata;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
