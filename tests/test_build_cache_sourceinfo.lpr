program test_build_cache_sourceinfo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.oldmeta,
  fpdev.build.cache.sourceinfo;

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

procedure TestCreateSourceArtifactInfo;
var
  OldInfo: TOldMetaArtifactInfo;
  Info: TArtifactInfo;
begin
  Initialize(OldInfo);
  OldInfo.Version := '3.2.2';
  OldInfo.CPU := 'x86_64';
  OldInfo.OS := 'linux';
  OldInfo.SourcePath := '/opt/fpc/3.2.2';
  OldInfo.ArchiveSize := 123456;
  OldInfo.CreatedAt := EncodeDate(2026, 3, 7);

  Info := BuildCacheCreateSourceArtifactInfo('/cache/fpc-3.2.2-x86_64-linux.tar.gz', OldInfo);

  AssertEquals('3.2.2', Info.Version, 'version is copied');
  AssertEquals('x86_64', Info.CPU, 'cpu is copied');
  AssertEquals('linux', Info.OS, 'os is copied');
  AssertEquals('/opt/fpc/3.2.2', Info.SourcePath, 'source path is copied');
  AssertTrue(Info.ArchiveSize = 123456, 'archive size is copied');
  AssertTrue(Info.CreatedAt = EncodeDate(2026, 3, 7), 'created-at is copied');
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux.tar.gz', Info.ArchivePath,
    'archive path is injected by wrapper');
end;

begin
  TestCreateSourceArtifactInfo;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
