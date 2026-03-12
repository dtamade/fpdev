program test_build_cache_jsonsave;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.metajson,
  fpdev.build.cache.jsonsave;

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

procedure TestCreateMetaJSONArtifactInfo;
var
  HelperInfo: TMetaJSONArtifactInfo;
  Info: TArtifactInfo;
  AccessedAt: TDateTime;
begin
  AccessedAt := EncodeDateTime(2026, 3, 7, 12, 34, 56, 0);
  Initialize(Info);
  Info.Version := '3.2.4';
  Info.CPU := 'x86_64';
  Info.OS := 'linux';
  Info.ArchivePath := '/cache/fpc-3.2.4-x86_64-linux.tar.gz';
  Info.ArchiveSize := 12345678;
  Info.CreatedAt := EncodeDate(2026, 3, 7);
  Info.SourceType := 'source';
  Info.SHA256 := 'abc123';
  Info.DownloadURL := 'https://example.invalid/fpc.tar.gz';
  Info.SourcePath := '/opt/fpc/3.2.4';
  Info.AccessCount := 9;
  Info.LastAccessed := AccessedAt;

  HelperInfo := BuildCacheCreateMetaJSONArtifactInfo(Info);

  AssertEquals('3.2.4', HelperInfo.Version, 'version is copied');
  AssertEquals('x86_64', HelperInfo.CPU, 'cpu is copied');
  AssertEquals('linux', HelperInfo.OS, 'os is copied');
  AssertEquals('/cache/fpc-3.2.4-x86_64-linux.tar.gz', HelperInfo.ArchivePath,
    'archive path is copied');
  AssertTrue(HelperInfo.ArchiveSize = 12345678, 'archive size is copied');
  AssertTrue(HelperInfo.CreatedAt = EncodeDate(2026, 3, 7), 'created-at is copied');
  AssertEquals('source', HelperInfo.SourceType, 'source type is copied');
  AssertEquals('abc123', HelperInfo.SHA256, 'sha256 is copied');
  AssertEquals('https://example.invalid/fpc.tar.gz', HelperInfo.DownloadURL,
    'download url is copied');
  AssertEquals('/opt/fpc/3.2.4', HelperInfo.SourcePath, 'source path is copied');
  AssertTrue(HelperInfo.AccessCount = 9, 'access count is copied');
  AssertTrue(HelperInfo.LastAccessed = AccessedAt, 'last accessed is copied');
end;

begin
  TestCreateMetaJSONArtifactInfo;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
