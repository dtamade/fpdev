program test_build_cache_artifactmeta;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.cache.artifactmeta;

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

function BuildTempMetaPath: string;
begin
  Inc(GTempPathSequence);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + 'fpdev-artifactmeta-' + IntToStr(GetTickCount64) + '-'
    + IntToStr(GTempPathSequence) + '.meta';
end;

procedure TestBuildTempMetaPathUsesSystemTempAndUniqueSuffix;
var
  FirstPath: string;
  SecondPath: string;
  TempRoot: string;
begin
  FirstPath := BuildTempMetaPath;
  SecondPath := BuildTempMetaPath;
  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));

  AssertTrue(Pos(TempRoot, ExpandFileName(FirstPath)) = 1,
    'temp metadata path uses system temp root');
  AssertTrue(FirstPath <> SecondPath, 'temp metadata path is unique');
end;

procedure TestWriteArtifactMetadataFile;
var
  MetaPath: string;
  Content: TStringList;
  CreatedAt: TDateTime;
begin
  MetaPath := BuildTempMetaPath;
  DeleteFile(MetaPath);
  CreatedAt := EncodeDateTime(2026, 3, 7, 8, 9, 10, 0);

  BuildCacheSaveArtifactMeta(MetaPath, '3.2.2', 'x86_64', 'linux',
    '/cache/fpc-3.2.2-x86_64-linux.tar.gz', CreatedAt);

  AssertTrue(FileExists(MetaPath), 'metadata file is created');

  Content := TStringList.Create;
  try
    Content.LoadFromFile(MetaPath);
    AssertTrue(Pos('version=3.2.2', Content.Text) > 0, 'version is written');
    AssertTrue(Pos('cpu=x86_64', Content.Text) > 0, 'cpu is written');
    AssertTrue(Pos('os=linux', Content.Text) > 0, 'os is written');
    AssertTrue(Pos('archive_path=/cache/fpc-3.2.2-x86_64-linux.tar.gz', Content.Text) > 0,
      'archive path is written');
    AssertTrue(Pos('created_at=2026-03-07 08:09:10', Content.Text) > 0,
      'created_at is written with expected format');
  finally
    Content.Free;
  end;

  DeleteFile(MetaPath);
end;

begin
  TestBuildTempMetaPathUsesSystemTempAndUniqueSuffix;
  TestWriteArtifactMetadataFile;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
