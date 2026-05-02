program test_build_cache_sourceartifactflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache.types,
  fpdev.build.cache.sourceartifactflow,
  test_temp_paths;

type
  TSourceArtifactFlowHarness = class
  public
    RunCommandResult: Boolean;
    RunCommandCalls: Integer;
    LastCmd: string;
    LastArg0: string;
    LastArg1: string;
    LastArg2: string;
    LastWorkDir: string;
    procedure Reset;
    function RunCommand(const ACmd: string; const AArgs: array of string;
      const AWorkDir: string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TSourceArtifactFlowHarness.Reset;
begin
  RunCommandResult := True;
  RunCommandCalls := 0;
  LastCmd := '';
  LastArg0 := '';
  LastArg1 := '';
  LastArg2 := '';
  LastWorkDir := '';
end;

function TSourceArtifactFlowHarness.RunCommand(
  const ACmd: string;
  const AArgs: array of string;
  const AWorkDir: string
): Boolean;
var
  MetaProbe: TSearchRec;
begin
  Inc(RunCommandCalls);
  LastCmd := ACmd;
  if Length(AArgs) > 0 then LastArg0 := AArgs[0] else LastArg0 := '';
  if Length(AArgs) > 1 then LastArg1 := AArgs[1] else LastArg1 := '';
  if Length(AArgs) > 2 then LastArg2 := AArgs[2] else LastArg2 := '';
  LastWorkDir := AWorkDir;

  if RunCommandResult and (ACmd = 'tar') and (Length(AArgs) >= 2) and (AArgs[0] = '-czf') then
  begin
    ForceDirectories(ExtractFileDir(AArgs[1]));
    with TStringList.Create do
    try
      Add('mock archive');
      SaveToFile(AArgs[1]);
    finally
      Free;
    end;
  end;

  if RunCommandResult and (ACmd = 'tar') and (Length(AArgs) >= 4) and
     ((AArgs[0] = '-xzf') or (AArgs[0] = '-xf')) then
  begin
    ForceDirectories(AArgs[3]);
    if FindFirst(AArgs[1], faAnyFile, MetaProbe) = 0 then
      FindClose(MetaProbe);
  end;

  Result := RunCommandResult;
end;

procedure TestSaveSourceArtifactsFailsWhenInstallDirMissing;
var
  TempRoot: string;
  Harness: TSourceArtifactFlowHarness;
  ArchivePath: string;
  MetaPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_sourceartifactflow_missing');
  Harness := TSourceArtifactFlowHarness.Create;
  try
    Harness.Reset;
    ArchivePath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.tar.gz';
    MetaPath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.meta';
    Check('sourceartifactflow save fails when install dir missing',
      not BuildCacheSaveSourceArtifactsCore(
        '3.2.2',
        IncludeTrailingPathDelimiter(TempRoot) + 'missing-install',
        TempRoot,
        ArchivePath,
        MetaPath,
        'x86_64',
        'linux',
        @Harness.RunCommand
      ),
      'expected save failure');
  finally
    Harness.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestGetSourceArtifactInfoReadsOldMeta;
var
  TempRoot: string;
  ArchivePath: string;
  MetaPath: string;
  Info: TArtifactInfo;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_sourceartifactflow_info');
  try
    ArchivePath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.tar.gz';
    MetaPath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.meta';
    with TStringList.Create do
    try
      Add('version=3.2.2');
      Add('cpu=x86_64');
      Add('os=linux');
      Add('source_path=/tmp/fpc-source');
      Add('archive_size=12345');
      Add('created_at=2026-05-02 09:00:00');
      SaveToFile(MetaPath);
    finally
      Free;
    end;

    Check('sourceartifactflow reads old meta format',
      BuildCacheGetSourceArtifactInfoCore(MetaPath, ArchivePath, Info),
      'expected source info success');
    Check('sourceartifactflow injects archive path',
      Info.ArchivePath = ArchivePath,
      'archive=' + Info.ArchivePath);
    Check('sourceartifactflow keeps version',
      Info.Version = '3.2.2',
      'version=' + Info.Version);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestDeleteSourceArtifactsRemovesArchiveAndMeta;
var
  TempRoot: string;
  ArchivePath: string;
  MetaPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_sourceartifactflow_delete');
  try
    ArchivePath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.tar.gz';
    MetaPath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.meta';
    with TStringList.Create do
    try
      Add('archive');
      SaveToFile(ArchivePath);
      Clear;
      Add('version=3.2.2');
      SaveToFile(MetaPath);
    finally
      Free;
    end;

    Check('sourceartifactflow deletes archive and meta',
      BuildCacheDeleteSourceArtifactsCore(ArchivePath, MetaPath),
      'delete should succeed');
    Check('sourceartifactflow removes archive',
      not FileExists(ArchivePath),
      'archive still exists');
    Check('sourceartifactflow removes meta',
      not FileExists(MetaPath),
      'meta still exists');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestRestoreSourceArtifactsRunsTarExtraction;
var
  TempRoot: string;
  Harness: TSourceArtifactFlowHarness;
  ArchivePath: string;
  DestPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_sourceartifactflow_restore');
  Harness := TSourceArtifactFlowHarness.Create;
  try
    Harness.Reset;
    ArchivePath := IncludeTrailingPathDelimiter(TempRoot) + 'artifact.tar.gz';
    DestPath := IncludeTrailingPathDelimiter(TempRoot) + 'restored';
    with TStringList.Create do
    try
      Add('archive');
      SaveToFile(ArchivePath);
    finally
      Free;
    end;

    Check('sourceartifactflow restore succeeds with tar callback',
      BuildCacheRestoreSourceArtifactsCore(
        ArchivePath,
        DestPath,
        @Harness.RunCommand
      ),
      'restore should succeed');
    Check('sourceartifactflow restore uses tar',
      Harness.LastCmd = 'tar',
      'cmd=' + Harness.LastCmd);
    Check('sourceartifactflow restore uses xzf flags',
      Harness.LastArg0 = '-xzf',
      'arg0=' + Harness.LastArg0);
    Check('sourceartifactflow restore targets destination dir',
      DirectoryExists(DestPath),
      'dest missing');
  finally
    Harness.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestSaveSourceArtifactsFailsWhenInstallDirMissing;
  TestGetSourceArtifactInfoReadsOldMeta;
  TestDeleteSourceArtifactsRemovesArchiveAndMeta;
  TestRestoreSourceArtifactsRunsTarExtraction;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
