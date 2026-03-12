program test_build_cache_jsoninfo;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.metajson,
  fpdev.build.cache.jsoninfo;

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

procedure TestCreateJSONArtifactInfo;
var
  HelperInfo: TMetaJSONArtifactInfo;
  Info: TArtifactInfo;
begin
  Initialize(HelperInfo);
  HelperInfo.Version := '3.2.3';
  HelperInfo.CPU := 'aarch64';
  HelperInfo.OS := 'darwin';
  HelperInfo.ArchivePath := '/cache/fpc-3.2.3-aarch64-darwin.tar.gz';
  HelperInfo.ArchiveSize := 99999999;
  HelperInfo.CreatedAt := EncodeDate(2026, 3, 7);
  HelperInfo.SourceType := 'source';
  HelperInfo.SHA256 := 'roundtrip123456789';
  HelperInfo.DownloadURL := 'https://roundtrip.example.com/fpc.tar.gz';
  HelperInfo.SourcePath := '/opt/fpc/3.2.3';
  HelperInfo.AccessCount := 7;
  HelperInfo.LastAccessed := EncodeDateTime(2026, 3, 7, 10, 11, 12, 0);

  Info := BuildCacheCreateJSONArtifactInfo(HelperInfo);

  AssertEquals('3.2.3', Info.Version, 'version is copied');
  AssertEquals('aarch64', Info.CPU, 'cpu is copied');
  AssertEquals('darwin', Info.OS, 'os is copied');
  AssertEquals('/cache/fpc-3.2.3-aarch64-darwin.tar.gz', Info.ArchivePath,
    'archive path is copied');
  AssertTrue(Info.ArchiveSize = 99999999, 'archive size is copied');
  AssertTrue(Info.CreatedAt = EncodeDate(2026, 3, 7), 'created-at is copied');
  AssertEquals('source', Info.SourceType, 'source type is copied');
  AssertEquals('roundtrip123456789', Info.SHA256, 'sha256 is copied');
  AssertEquals('https://roundtrip.example.com/fpc.tar.gz', Info.DownloadURL,
    'download url is copied');
  AssertEquals('/opt/fpc/3.2.3', Info.SourcePath, 'source path is copied');
  AssertTrue(Info.AccessCount = 7, 'access count is copied');
  AssertTrue(Info.LastAccessed = EncodeDateTime(2026, 3, 7, 10, 11, 12, 0),
    'last accessed is copied');
end;

begin
  TestCreateJSONArtifactInfo;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
