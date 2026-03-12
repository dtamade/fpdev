program test_build_cache_deletefiles;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.deletefiles;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GTempPathSequence: Int64 = 0;

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
  Inc(GTempPathSequence);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + APrefix + '-' + IntToStr(GetTickCount64) + '-'
    + IntToStr(GTempPathSequence) + AExt;
end;

procedure TestBuildTempFilePathUsesSystemTempAndUniqueSuffix;
var
  FirstPath: string;
  SecondPath: string;
  TempRoot: string;
begin
  FirstPath := BuildTempFilePath('fpdev-deletefiles', '.tmp');
  SecondPath := BuildTempFilePath('fpdev-deletefiles', '.tmp');
  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));

  AssertTrue(Pos(TempRoot, ExpandFileName(FirstPath)) = 1,
    'temp deletefiles path uses system temp root');
  AssertTrue(FirstPath <> SecondPath, 'temp deletefiles path is unique');
end;

procedure CreateEmptyFile(const APath: string);
var
  F: TextFile;
begin
  AssignFile(F, APath);
  Rewrite(F);
  CloseFile(F);
end;

procedure TestDeletesExistingArchiveAndMeta;
var
  ArchivePath: string;
  MetaPath: string;
begin
  ArchivePath := BuildTempFilePath('fpdev-delete-archive', '.tar.gz');
  MetaPath := BuildTempFilePath('fpdev-delete-archive', '.meta');
  CreateEmptyFile(ArchivePath);
  CreateEmptyFile(MetaPath);

  AssertTrue(BuildCacheDeleteArtifactFiles(ArchivePath, MetaPath),
    'deleting existing archive and meta succeeds');
  AssertTrue(not FileExists(ArchivePath), 'archive file is removed');
  AssertTrue(not FileExists(MetaPath), 'meta file is removed');
end;

procedure TestMissingFilesAreIgnored;
var
  ArchivePath: string;
  MetaPath: string;
begin
  ArchivePath := BuildTempFilePath('fpdev-delete-missing', '.tar.gz');
  MetaPath := BuildTempFilePath('fpdev-delete-missing', '.meta');
  DeleteFile(ArchivePath);
  DeleteFile(MetaPath);

  AssertTrue(BuildCacheDeleteArtifactFiles(ArchivePath, MetaPath),
    'missing files are treated as already deleted');
end;

begin
  TestBuildTempFilePathUsesSystemTempAndUniqueSuffix;
  TestDeletesExistingArchiveAndMeta;
  TestMissingFilesAreIgnored;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
