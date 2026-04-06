program test_build_cache_deletefiles;

{$mode objfpc}{$H+}

uses
  SysUtils,
  test_temp_paths,
  fpdev.build.cache.deletefiles;

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
  FirstPath := BuildTempFilePath('fpdev-deletefiles', '.tmp');
  SecondPath := BuildTempFilePath('fpdev-deletefiles', '.tmp');
  try
    AssertTrue(PathUsesSystemTempRoot(ExtractFileDir(FirstPath)),
      'temp deletefiles path uses system temp root');
    AssertTrue(FirstPath <> SecondPath, 'temp deletefiles path is unique');
  finally
    CleanupTempDir(ExtractFileDir(FirstPath));
    CleanupTempDir(ExtractFileDir(SecondPath));
  end;
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
  try
    CreateEmptyFile(ArchivePath);
    CreateEmptyFile(MetaPath);

    AssertTrue(BuildCacheDeleteArtifactFiles(ArchivePath, MetaPath),
      'deleting existing archive and meta succeeds');
    AssertTrue(not FileExists(ArchivePath), 'archive file is removed');
    AssertTrue(not FileExists(MetaPath), 'meta file is removed');
  finally
    if FileExists(ArchivePath) then
      DeleteFile(ArchivePath);
    if FileExists(MetaPath) then
      DeleteFile(MetaPath);
    CleanupTempDir(ExtractFileDir(ArchivePath));
    CleanupTempDir(ExtractFileDir(MetaPath));
  end;
end;

procedure TestMissingFilesAreIgnored;
var
  ArchivePath: string;
  MetaPath: string;
begin
  ArchivePath := BuildTempFilePath('fpdev-delete-missing', '.tar.gz');
  MetaPath := BuildTempFilePath('fpdev-delete-missing', '.meta');
  try
    DeleteFile(ArchivePath);
    DeleteFile(MetaPath);

    AssertTrue(BuildCacheDeleteArtifactFiles(ArchivePath, MetaPath),
      'missing files are treated as already deleted');
  finally
    if FileExists(ArchivePath) then
      DeleteFile(ArchivePath);
    if FileExists(MetaPath) then
      DeleteFile(MetaPath);
    CleanupTempDir(ExtractFileDir(ArchivePath));
    CleanupTempDir(ExtractFileDir(MetaPath));
  end;
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
