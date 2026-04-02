program test_build_cache_binarypresence;

{$mode objfpc}{$H+}

uses
  SysUtils,
  test_temp_paths,
  fpdev.build.cache.binarypresence;

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
  FirstPath := BuildTempFilePath('fpdev-binarypresence', '.tmp');
  SecondPath := BuildTempFilePath('fpdev-binarypresence', '.tmp');
  try
    AssertTrue(PathUsesSystemTempRoot(ExtractFileDir(FirstPath)),
      'temp binarypresence path uses system temp root');
    AssertTrue(FirstPath <> SecondPath, 'temp binarypresence path is unique');
  finally
    CleanupTempDir(ExtractFileDir(FirstPath));
    CleanupTempDir(ExtractFileDir(SecondPath));
  end;
end;

procedure CreateEmptyFile(const AFilePath: string);
var
  F: TextFile;
begin
  AssignFile(F, AFilePath);
  Rewrite(F);
  CloseFile(F);
end;

procedure TestSourceArchiveIsEnough;
var
  TempFile: string;
begin
  TempFile := BuildTempFilePath('fpdev-binarypresence-source', '.tar.gz');
  CreateEmptyFile(TempFile);
  try
    AssertTrue(BuildCacheHasArtifactFiles(TempFile, '/nonexistent/meta'),
      'source archive alone counts as cached artifact');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    CleanupTempDir(ExtractFileDir(TempFile));
  end;
end;

procedure TestBinaryMetaIsEnough;
var
  TempFile: string;
begin
  TempFile := BuildTempFilePath('fpdev-binarypresence-binary', '.meta');
  CreateEmptyFile(TempFile);
  try
    AssertTrue(BuildCacheHasArtifactFiles('/nonexistent/archive', TempFile),
      'binary meta alone counts as cached artifact');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    CleanupTempDir(ExtractFileDir(TempFile));
  end;
end;

procedure TestNoArtifactsReturnsFalse;
begin
  AssertTrue(not BuildCacheHasArtifactFiles('/nonexistent/archive', '/nonexistent/meta'),
    'missing source archive and binary meta returns false');
end;

begin
  TestBuildTempFilePathUsesSystemTempAndUniqueSuffix;
  TestSourceArchiveIsEnough;
  TestBinaryMetaIsEnough;
  TestNoArtifactsReturnsFalse;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
