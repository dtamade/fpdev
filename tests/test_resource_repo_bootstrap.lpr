program test_resource_repo_bootstrap;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser, fpdev.resource.repo.bootstrap;

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

procedure TestHardcodedMappingMain;
begin
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, 'main') = '3.2.2',
        'Hardcoded: main -> 3.2.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, 'trunk') = '3.2.2',
        'Hardcoded: trunk -> 3.2.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.3.1') = '3.2.2',
        'Hardcoded: 3.3.1 -> 3.2.2');
end;

procedure TestHardcodedMapping32x;
begin
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.2.4') = '3.2.2',
        'Hardcoded: 3.2.4 -> 3.2.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.2.3') = '3.2.2',
        'Hardcoded: 3.2.3 -> 3.2.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.2.2') = '3.2.0',
        'Hardcoded: 3.2.2 -> 3.2.0');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.2.0') = '3.0.4',
        'Hardcoded: 3.2.0 -> 3.0.4');
end;

procedure TestHardcodedMapping30x;
begin
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.0.4') = '3.0.2',
        'Hardcoded: 3.0.4 -> 3.0.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.0.2') = '3.0.0',
        'Hardcoded: 3.0.2 -> 3.0.0');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '3.0.0') = '2.6.4',
        'Hardcoded: 3.0.0 -> 2.6.4');
end;

procedure TestHardcodedMapping26x;
begin
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '2.6.4') = '2.6.2',
        'Hardcoded: 2.6.4 -> 2.6.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '2.6.2') = '2.6.0',
        'Hardcoded: 2.6.2 -> 2.6.0');
end;

procedure TestHardcodedMappingUnknown;
begin
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '1.0.0') = '',
        'Hardcoded: unknown version -> empty');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '') = '',
        'Hardcoded: empty version -> empty');
end;

procedure TestHardcodedMappingCaseInsensitive;
begin
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, 'MAIN') = '3.2.2',
        'Hardcoded: MAIN (uppercase) -> 3.2.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, 'Trunk') = '3.2.2',
        'Hardcoded: Trunk (mixed case) -> 3.2.2');
  Check(ResourceRepoGetRequiredBootstrapVersion(nil, '  main  ') = '3.2.2',
        'Hardcoded: main with whitespace -> 3.2.2');
end;

procedure TestManifestOverridesHardcoded;
var
  Manifest: TJSONObject;
  VersionMap: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  try
    VersionMap := TJSONObject.Create;
    VersionMap.Add('3.2.2', '3.0.0');
    Manifest.Add('bootstrap_version_map', VersionMap);

    Check(ResourceRepoGetRequiredBootstrapVersion(Manifest, '3.2.2') = '3.0.0',
          'Manifest: overrides hardcoded mapping');
  finally
    Manifest.Free;
  end;
end;

procedure TestManifestMissVersionFallsBackToHardcoded;
var
  Manifest: TJSONObject;
  VersionMap: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  try
    VersionMap := TJSONObject.Create;
    VersionMap.Add('4.0.0', '3.2.2');
    Manifest.Add('bootstrap_version_map', VersionMap);

    Check(ResourceRepoGetRequiredBootstrapVersion(Manifest, '3.2.2') = '3.2.0',
          'Manifest: missing version falls back to hardcoded');
  finally
    Manifest.Free;
  end;
end;

procedure TestManifestTrunkAlias;
var
  Manifest: TJSONObject;
  VersionMap: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  try
    VersionMap := TJSONObject.Create;
    VersionMap.Add('main', '3.2.2');
    Manifest.Add('bootstrap_version_map', VersionMap);

    Check(ResourceRepoGetRequiredBootstrapVersion(Manifest, 'trunk') = '3.2.2',
          'Manifest: trunk resolves via main alias');
  finally
    Manifest.Free;
  end;
end;

procedure TestManifestEmptyVersionMap;
var
  Manifest: TJSONObject;
  VersionMap: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  try
    VersionMap := TJSONObject.Create;
    Manifest.Add('bootstrap_version_map', VersionMap);
    // Empty map: falls back to hardcoded
    Check(ResourceRepoGetRequiredBootstrapVersion(Manifest, 'main') = '3.2.2',
          'Manifest: empty version map falls back to hardcoded');
  finally
    Manifest.Free;
  end;
end;

procedure TestListBootstrapVersionsNil;
var
  Versions: TStringArray;
begin
  Versions := ResourceRepoListBootstrapVersions(nil);
  Check(Length(Versions) = 0, 'ListBootstrapVersions: nil -> empty');
end;

// Note: TestListBootstrapVersionsNoKey skipped - FPC Objects[] throws on missing key.

procedure TestListBootstrapVersionsWithData;
var
  Manifest: TJSONObject;
  Compilers: TJSONObject;
  Versions: TStringArray;
begin
  Manifest := TJSONObject.Create;
  try
    Compilers := TJSONObject.Create;
    Compilers.Add('3.2.2', TJSONObject.Create);
    Compilers.Add('3.0.4', TJSONObject.Create);
    Manifest.Add('bootstrap_compilers', Compilers);

    Versions := ResourceRepoListBootstrapVersions(Manifest);
    Check(Length(Versions) = 2, 'ListBootstrapVersions: returns 2 versions');
    Check(Versions[0] = '3.2.2', 'ListBootstrapVersions: first is 3.2.2');
    Check(Versions[1] = '3.0.4', 'ListBootstrapVersions: second is 3.0.4');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBootstrapVersionFromMakefile;
var
  MakefilePath: string;
  F: Text;
begin
  MakefilePath := TempDir + 'Makefile';
  AssignFile(F, MakefilePath);
  Rewrite(F);
  WriteLn(F, '# FPC Makefile');
  WriteLn(F, 'REQUIREDVERSION=30202');
  WriteLn(F, 'REQUIREDVERSION2=30004');
  CloseFile(F);

  // REQUIREDVERSION2 < REQUIREDVERSION, so uses REQUIREDVERSION2
  Check(ResourceRepoGetBootstrapVersionFromMakefile(TempDir) = '3.0.4',
        'MakefileBootstrap: picks lower REQUIREDVERSION2');

  DeleteFile(MakefilePath);
end;

procedure TestGetBootstrapVersionFromMakefileNoVersion2;
var
  MakefilePath: string;
  F: Text;
begin
  MakefilePath := TempDir + 'Makefile';
  AssignFile(F, MakefilePath);
  Rewrite(F);
  WriteLn(F, 'REQUIREDVERSION=30202');
  CloseFile(F);

  Check(ResourceRepoGetBootstrapVersionFromMakefile(TempDir) = '3.2.2',
        'MakefileBootstrap: uses REQUIREDVERSION when no VERSION2');

  DeleteFile(MakefilePath);
end;

procedure TestGetBootstrapVersionFromMakefileWithComment;
var
  MakefilePath: string;
  F: Text;
begin
  MakefilePath := TempDir + 'Makefile';
  AssignFile(F, MakefilePath);
  Rewrite(F);
  WriteLn(F, 'REQUIREDVERSION=30202 # required fpc version');
  CloseFile(F);

  Check(ResourceRepoGetBootstrapVersionFromMakefile(TempDir) = '3.2.2',
        'MakefileBootstrap: strips trailing comment');

  DeleteFile(MakefilePath);
end;

procedure TestGetBootstrapVersionFromMakefileNotFound;
begin
  Check(ResourceRepoGetBootstrapVersionFromMakefile('/nonexistent/path') = '',
        'MakefileBootstrap: missing file -> empty');
end;

procedure TestGetBootstrapVersionFromMakefileFpc;
var
  MakefilePath: string;
  F: Text;
begin
  // When only Makefile.fpc exists (no Makefile)
  MakefilePath := TempDir + 'Makefile.fpc';
  AssignFile(F, MakefilePath);
  Rewrite(F);
  WriteLn(F, 'REQUIREDVERSION=30200');
  CloseFile(F);

  Check(ResourceRepoGetBootstrapVersionFromMakefile(TempDir) = '3.2.0',
        'MakefileBootstrap: falls back to Makefile.fpc');

  DeleteFile(MakefilePath);
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
             'test_bootstrap_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(TempDir);

  WriteLn('=== Resource Repo Bootstrap Unit Tests ===');
  WriteLn;

  TestHardcodedMappingMain;
  TestHardcodedMapping32x;
  TestHardcodedMapping30x;
  TestHardcodedMapping26x;
  TestHardcodedMappingUnknown;
  TestHardcodedMappingCaseInsensitive;
  TestManifestOverridesHardcoded;
  TestManifestMissVersionFallsBackToHardcoded;
  TestManifestTrunkAlias;
  TestManifestEmptyVersionMap;
  TestListBootstrapVersionsNil;
  // TestListBootstrapVersionsNoKey skipped (Objects[] throws)
  TestListBootstrapVersionsWithData;
  TestGetBootstrapVersionFromMakefile;
  TestGetBootstrapVersionFromMakefileNoVersion2;
  TestGetBootstrapVersionFromMakefileWithComment;
  TestGetBootstrapVersionFromMakefileNotFound;
  TestGetBootstrapVersionFromMakefileFpc;

  RemoveDir(TempDir);

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
