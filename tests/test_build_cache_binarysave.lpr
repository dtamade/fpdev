program test_build_cache_binarysave;

{$mode objfpc}{$H+}

uses
  SysUtils,
  test_temp_paths,
  fpdev.build.cache.binarysave;

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

function BuildTempFilePath(const APrefix, AExt: string): string;
begin
  Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir(APrefix))
    + 'artifact' + AExt;
end;

procedure TestBuildTempFilePathUsesSystemTempAndUniqueSuffix;
var
  FirstPath: string;
  SecondPath: string;
begin
  FirstPath := BuildTempFilePath('fpdev-binarysave', '.tmp');
  SecondPath := BuildTempFilePath('fpdev-binarysave', '.tmp');
  try
    AssertTrue(PathUsesSystemTempRoot(ExtractFileDir(FirstPath)),
      'temp binarysave path uses system temp root');
    AssertTrue(FirstPath <> SecondPath, 'temp binarysave path is unique');
  finally
    CleanupTempDir(ExtractFileDir(FirstPath));
    CleanupTempDir(ExtractFileDir(SecondPath));
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure CreateFileOfSize(const AFilePath: string; ASize: Integer);
var
  F: File of Byte;
  Index: Integer;
  Value: Byte;
begin
  AssignFile(F, AFilePath);
  Rewrite(F);
  try
    for Index := 1 to ASize do
    begin
      Value := Byte(Index mod 251);
      Write(F, Value);
    end;
  finally
    CloseFile(F);
  end;
end;

procedure TestResolveBinaryFileExt;
begin
  AssertEquals('.tar.gz', BuildCacheResolveBinaryFileExt('/tmp/fpc.tar.gz'),
    'compound tar.gz extension is preserved');
  AssertEquals('.tar', BuildCacheResolveBinaryFileExt('/tmp/fpc.tar'),
    'plain tar extension is preserved');
  AssertEquals('.zip', BuildCacheResolveBinaryFileExt('/tmp/fpc.zip'),
    'other single extension is preserved');
end;

procedure TestBuildBinaryArtifactPaths;
var
  Paths: TBuildCacheBinaryArtifactPaths;
begin
  Paths := BuildCacheBuildBinaryArtifactPaths('/cache/', 'fpc-3.2.2-x86_64-linux', '.tar.gz');
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux-binary.tar.gz', Paths.ArchivePath,
    'archive path includes -binary suffix');
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux-binary.meta', Paths.MetaPath,
    'meta path uses .meta suffix');
end;

procedure TestReadBinaryArchiveSize;
var
  TempFile: string;
begin
  TempFile := BuildTempFilePath('fpdev-binarysave-size', '.bin');
  CreateFileOfSize(TempFile, 321);
  try
    AssertTrue(BuildCacheReadBinaryArchiveSize(TempFile) = 321,
      'archive size is read from file metadata');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    CleanupTempDir(ExtractFileDir(TempFile));
  end;
end;

procedure TestResolveBinarySHA256;
var
  TempFile: string;
  Hash: string;
begin
  TempFile := BuildTempFilePath('fpdev-binarysave-hash', '.bin');
  CreateFileOfSize(TempFile, 64);
  try
    AssertEquals('provided-hash',
      BuildCacheResolveBinarySHA256('provided-hash', TempFile),
      'provided hash wins over computed hash');

    Hash := BuildCacheResolveBinarySHA256('', TempFile);
    AssertTrue(Hash <> '', 'computed hash fallback returns non-empty hash');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    CleanupTempDir(ExtractFileDir(TempFile));
  end;
end;

begin
  TestBuildTempFilePathUsesSystemTempAndUniqueSuffix;
  TestResolveBinaryFileExt;
  TestBuildBinaryArtifactPaths;
  TestReadBinaryArchiveSize;
  TestResolveBinarySHA256;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
