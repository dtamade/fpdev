program test_build_cache_binaryinfo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.oldmeta,
  fpdev.build.cache.binaryinfo;

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

procedure TestBuildBinaryMetaPath;
begin
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux-binary.meta',
    BuildCacheGetBinaryMetaPath('/cache/', 'fpc-3.2.2-x86_64-linux'),
    'meta path uses -binary.meta suffix');
end;

procedure TestCreateBinaryArtifactInfo;
var
  BinaryInfo: TBinaryMetaArtifactInfo;
  Info: TArtifactInfo;
begin
  Initialize(BinaryInfo);
  BinaryInfo.Version := '3.2.2';
  BinaryInfo.CPU := 'x86_64';
  BinaryInfo.OS := 'linux';
  BinaryInfo.SourceType := 'binary';
  BinaryInfo.SHA256 := 'abc123';
  BinaryInfo.FileExt := '.tar.gz';
  BinaryInfo.ArchiveSize := 2048;
  BinaryInfo.CreatedAt := EncodeDate(2026, 3, 7);

  Info := BuildCacheCreateBinaryArtifactInfo('/cache/',
    'fpc-3.2.2-x86_64-linux', BinaryInfo);

  AssertEquals('3.2.2', Info.Version, 'version is copied');
  AssertEquals('x86_64', Info.CPU, 'cpu is copied');
  AssertEquals('linux', Info.OS, 'os is copied');
  AssertEquals('binary', Info.SourceType, 'source type is copied');
  AssertEquals('abc123', Info.SHA256, 'sha256 is copied');
  AssertEquals('.tar.gz', Info.FileExt, 'file extension is copied');
  AssertTrue(Info.ArchiveSize = 2048, 'archive size is copied');
  AssertTrue(Info.CreatedAt = EncodeDate(2026, 3, 7), 'created-at is copied');
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux-binary.tar.gz', Info.ArchivePath,
    'archive path uses binary suffix and stored extension');
end;

begin
  TestBuildBinaryMetaPath;
  TestCreateBinaryArtifactInfo;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
