program test_lazarus_sourceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.lazarus.sourceflow,
  test_temp_paths;

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

function ArrayContains(const AValues: TLazarusLegacySourceArgs; const AValue: string): Boolean;
var
  Item: string;
begin
  Result := False;
  for Item in AValues do
    if Item = AValue then
      Exit(True);
end;

procedure TestResolveLazarusLegacySourceVersionCore;
begin
  Check(
    'resolve source version prefers requested version',
    ResolveLazarusLegacySourceVersionCore('3.0', '2.2.6', 'main') = '3.0',
    'expected requested version to win'
  );
  Check(
    'resolve source version falls back to current version',
    ResolveLazarusLegacySourceVersionCore('', '2.2.6', 'main') = '2.2.6',
    'expected current version fallback'
  );
  Check(
    'resolve source version falls back to default version',
    ResolveLazarusLegacySourceVersionCore('', '', 'main') = 'main',
    'expected default version fallback'
  );
end;

procedure TestBuildLazarusLegacySourcePathCore;
begin
  Check(
    'build source path core appends lazarus prefix',
    BuildLazarusLegacySourcePathCore('/tmp/fpdev-root', '3.0') =
      '/tmp/fpdev-root' + PathDelim + 'lazarus-3.0',
    'unexpected lazarus source path'
  );
end;

procedure TestCreateLazarusLegacyClonePlanCore;
var
  Plan: TLazarusLegacySourceClonePlan;
begin
  Plan := CreateLazarusLegacyClonePlanCore(
    '3.0',
    'main',
    '/tmp/fpdev-root',
    'https://example.invalid/lazarus.git',
    'lazarus_3_0'
  );

  Check(
    'clone plan keeps requested version',
    Plan.Version = '3.0',
    'got=' + Plan.Version
  );
  Check(
    'clone plan keeps resolved ref name',
    Plan.RefName = 'lazarus_3_0',
    'got=' + Plan.RefName
  );
  Check(
    'clone plan keeps repository url',
    Plan.RepositoryURL = 'https://example.invalid/lazarus.git',
    'got=' + Plan.RepositoryURL
  );
  Check(
    'clone plan builds source path',
    Plan.SourcePath = '/tmp/fpdev-root' + PathDelim + 'lazarus-3.0',
    'got=' + Plan.SourcePath
  );
end;

procedure TestCreateLazarusLegacyUpdatePlanCore;
var
  Plan: TLazarusLegacySourceUpdatePlan;
begin
  Plan := CreateLazarusLegacyUpdatePlanCore(
    '',
    '2.2.6',
    'main',
    '/tmp/fpdev-root'
  );

  Check(
    'update plan follows current version fallback',
    Plan.Version = '2.2.6',
    'got=' + Plan.Version
  );
  Check(
    'update plan builds source path from current version',
    Plan.SourcePath = '/tmp/fpdev-root' + PathDelim + 'lazarus-2.2.6',
    'got=' + Plan.SourcePath
  );
end;

procedure TestBuildLazarusLegacyMakeParamsCore;
var
  Params: TLazarusLegacySourceArgs;
begin
  Params := BuildLazarusLegacyMakeParamsCore(4, '/tmp/mock-fpc');
  Check(
    'make params include clean target',
    ArrayContains(Params, 'clean'),
    'expected clean in make params'
  );
  Check(
    'make params include all target',
    ArrayContains(Params, 'all'),
    'expected all in make params'
  );
  Check(
    'make params include parallel jobs when jobs > 1',
    ArrayContains(Params, '-j4'),
    'expected -j4 in make params'
  );
  Check(
    'make params include custom fpc path when provided',
    ArrayContains(Params, 'PP=/tmp/mock-fpc'),
    'expected PP entry in make params'
  );

  Params := BuildLazarusLegacyMakeParamsCore(1, '');
  Check(
    'make params skip parallel flag when jobs <= 1',
    not ArrayContains(Params, '-j1'),
    'did not expect -j1 in make params'
  );
  Check(
    'make params skip PP entry when no fpc path provided',
    not ArrayContains(Params, 'PP='),
    'did not expect empty PP entry'
  );
end;

procedure TestIsValidLazarusLegacySourceTreeCore;
var
  TempRoot: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_sourceflow_tree');
  try
    ForceDirectories(TempRoot);
    Check(
      'source tree invalid before required directories exist',
      not IsValidLazarusLegacySourceTreeCore(TempRoot),
      'expected invalid source tree before fixture dirs are present'
    );

    ForceDirectories(TempRoot + PathDelim + 'ide');
    ForceDirectories(TempRoot + PathDelim + 'lcl');
    ForceDirectories(TempRoot + PathDelim + 'packager');
    Check(
      'source tree valid after required directories exist',
      IsValidLazarusLegacySourceTreeCore(TempRoot),
      'expected valid source tree after fixture dirs are present'
    );
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('=== Lazarus Sourceflow Tests ===');

  TestResolveLazarusLegacySourceVersionCore;
  TestBuildLazarusLegacySourcePathCore;
  TestCreateLazarusLegacyClonePlanCore;
  TestCreateLazarusLegacyUpdatePlanCore;
  TestBuildLazarusLegacyMakeParamsCore;
  TestIsValidLazarusLegacySourceTreeCore;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
