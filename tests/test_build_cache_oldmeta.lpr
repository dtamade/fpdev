program test_build_cache_oldmeta;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.build.cache.oldmeta;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TempDir: string;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure TestParseMetaLine;
var
  Key, Value: string;
begin
  Check(BuildCacheParseMetaLine('version=3.2.2', Key, Value) = True,
        'ParseMetaLine: Valid line returns True');
  Check(Key = 'version', 'ParseMetaLine: Key is "version"');
  Check(Value = '3.2.2', 'ParseMetaLine: Value is "3.2.2"');

  Check(BuildCacheParseMetaLine('key=value=extra', Key, Value) = True,
        'ParseMetaLine: Handles value with = sign');
  Check(Key = 'key', 'ParseMetaLine: Key before first =');
  Check(Value = 'value=extra', 'ParseMetaLine: Value after first =');

  Check(BuildCacheParseMetaLine('noequals', Key, Value) = False,
        'ParseMetaLine: No = returns False');

  Check(BuildCacheParseMetaLine('', Key, Value) = False,
        'ParseMetaLine: Empty string returns False');
end;

procedure TestSaveLoadOldMeta;
var
  MetaPath: string;
  Info: TOldMetaArtifactInfo;
begin
  MetaPath := TempDir + 'test.meta';

  BuildCacheSaveOldMeta(MetaPath, '3.2.2', 'x86_64', 'linux', '/opt/fpc', 1024000);
  Check(FileExists(MetaPath), 'SaveOldMeta: File created');

  Check(BuildCacheLoadOldMeta(MetaPath, Info) = True, 'LoadOldMeta: Returns True');
  Check(Info.Version = '3.2.2', 'LoadOldMeta: Version correct');
  Check(Info.CPU = 'x86_64', 'LoadOldMeta: CPU correct');
  Check(Info.OS = 'linux', 'LoadOldMeta: OS correct');
  Check(Info.SourcePath = '/opt/fpc', 'LoadOldMeta: SourcePath correct');
  Check(Info.ArchiveSize = 1024000, 'LoadOldMeta: ArchiveSize correct');
  Check(Info.CreatedAt > 0, 'LoadOldMeta: CreatedAt is set');

  DeleteFile(MetaPath);
end;

procedure TestLoadOldMetaNonExistent;
var
  Info: TOldMetaArtifactInfo;
begin
  Check(BuildCacheLoadOldMeta('/nonexistent/file.meta', Info) = False,
        'LoadOldMeta: Non-existent returns False');
end;

procedure TestSaveLoadBinaryMeta;
var
  MetaPath: string;
  Info: TBinaryMetaArtifactInfo;
begin
  MetaPath := TempDir + 'test-binary.meta';

  BuildCacheSaveBinaryMeta(MetaPath, '3.2.2', 'x86_64', 'linux',
    'abc123sha256', '.tar.gz', 2048000);
  Check(FileExists(MetaPath), 'SaveBinaryMeta: File created');

  Check(BuildCacheLoadBinaryMeta(MetaPath, Info) = True, 'LoadBinaryMeta: Returns True');
  Check(Info.Version = '3.2.2', 'LoadBinaryMeta: Version correct');
  Check(Info.CPU = 'x86_64', 'LoadBinaryMeta: CPU correct');
  Check(Info.OS = 'linux', 'LoadBinaryMeta: OS correct');
  Check(Info.SourceType = 'binary', 'LoadBinaryMeta: SourceType is binary');
  Check(Info.SHA256 = 'abc123sha256', 'LoadBinaryMeta: SHA256 correct');
  Check(Info.FileExt = '.tar.gz', 'LoadBinaryMeta: FileExt correct');
  Check(Info.ArchiveSize = 2048000, 'LoadBinaryMeta: ArchiveSize correct');

  DeleteFile(MetaPath);
end;

procedure TestLoadBinaryMetaNonExistent;
var
  Info: TBinaryMetaArtifactInfo;
begin
  Check(BuildCacheLoadBinaryMeta('/nonexistent/file.meta', Info) = False,
        'LoadBinaryMeta: Non-existent returns False');
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
             'test_oldmeta_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(TempDir);

  WriteLn('=== Build Cache OldMeta Unit Tests ===');
  WriteLn;

  TestParseMetaLine;
  TestSaveLoadOldMeta;
  TestLoadOldMetaNonExistent;
  TestSaveLoadBinaryMeta;
  TestLoadBinaryMetaNonExistent;

  RemoveDir(TempDir);

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
