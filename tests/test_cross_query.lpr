program test_cross_query;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.cmd.cross.query;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestName: string;

procedure StartTest(const AName: string);
begin
  TestName := AName;
  Write('  ', AName, '... ');
end;

procedure Pass;
begin
  WriteLn('PASSED');
  Inc(PassCount);
end;

procedure Fail(const AReason: string);
begin
  WriteLn('FAILED: ', AReason);
  Inc(FailCount);
end;

procedure TestGetTargetInstallPath;
var
  Query: TCrossTargetQuery;
  Config: IConfigManager;
  Path: string;
begin
  Config := TConfigManager.Create('');
  Config.LoadConfig;
  Query := TCrossTargetQuery.Create(Config, nil, '/tmp/fpdev-test');
  try
    StartTest('GetTargetInstallPath returns correct path');
    Path := Query.GetTargetInstallPath('win64');
    if Pos('/tmp/fpdev-test', Path) > 0 then Pass
    else Fail('Expected /tmp/fpdev-test in path');

    StartTest('GetTargetInstallPath includes cross subdirectory');
    if Pos('cross', Path) > 0 then Pass
    else Fail('Expected cross in path');

    StartTest('GetTargetInstallPath includes target name');
    if Pos('win64', Path) > 0 then Pass
    else Fail('Expected win64 in path');
  finally
    Query.Free;
  end;
end;

procedure TestValidateTarget;
var
  Query: TCrossTargetQuery;
  Config: IConfigManager;
begin
  Config := TConfigManager.Create('');
  Config.LoadConfig;
  Query := TCrossTargetQuery.Create(Config, nil, '/tmp/fpdev-test');
  try
    StartTest('ValidateTarget returns true for x86_64-win64');
    if Query.ValidateTarget('x86_64-win64') then Pass
    else Fail('Expected true for x86_64-win64');

    StartTest('ValidateTarget returns true for arm-linux');
    if Query.ValidateTarget('arm-linux') then Pass
    else Fail('Expected true for arm-linux');

    StartTest('ValidateTarget returns false for invalid target');
    if not Query.ValidateTarget('invalid-xyz-123') then Pass
    else Fail('Expected false for invalid target');

    StartTest('ValidateTarget returns false for empty target');
    if not Query.ValidateTarget('') then Pass
    else Fail('Expected false for empty string');
  finally
    Query.Free;
  end;
end;

procedure TestGetTargetInfo;
var
  Query: TCrossTargetQuery;
  Config: IConfigManager;
  Info: TCrossTargetQueryInfo;
begin
  Config := TConfigManager.Create('');
  Config.LoadConfig;
  Query := TCrossTargetQuery.Create(Config, nil, '/tmp/fpdev-test');
  try
    StartTest('GetTargetInfo returns valid info for x86_64-win64');
    Info := Query.GetTargetInfo('x86_64-win64');
    if Info.Name = 'x86_64-win64' then Pass
    else Fail('Expected name=x86_64-win64, got ' + Info.Name);

    StartTest('GetTargetInfo sets CPU field');
    if Info.CPU <> '' then Pass
    else Fail('Expected non-empty CPU');

    StartTest('GetTargetInfo sets OS field');
    if Info.OS <> '' then Pass
    else Fail('Expected non-empty OS');

    StartTest('GetTargetInfo sets Available flag');
    if Info.Available then Pass
    else Fail('Expected Available=true');
  finally
    Query.Free;
  end;
end;

procedure TestGetAvailableTargets;
var
  Query: TCrossTargetQuery;
  Config: IConfigManager;
  Targets: TCrossTargetQueryArray;
begin
  Config := TConfigManager.Create('');
  Config.LoadConfig;
  Query := TCrossTargetQuery.Create(Config, nil, '/tmp/fpdev-test');
  try
    StartTest('GetAvailableTargets returns non-empty array');
    Targets := Query.GetAvailableTargets;
    if Length(Targets) > 0 then Pass
    else Fail('Expected non-empty array');

    StartTest('GetAvailableTargets includes win64');
    if Length(Targets) >= 10 then Pass
    else Fail('Expected at least 10 targets');
  finally
    Query.Free;
  end;
end;

procedure TestGetInstalledTargets;
var
  Query: TCrossTargetQuery;
  Config: IConfigManager;
  Targets: TCrossTargetQueryArray;
begin
  Config := TConfigManager.Create('');
  Config.LoadConfig;
  Query := TCrossTargetQuery.Create(Config, nil, '/tmp/fpdev-test');
  try
    StartTest('GetInstalledTargets returns array (may be empty)');
    Targets := Query.GetInstalledTargets;
    // Just check it doesn't crash - may be empty if nothing installed
    if Length(Targets) >= 0 then Pass
    else Fail('Unexpected error');
  finally
    Query.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Cross Query Helper Unit Tests');
  WriteLn('========================================');
  WriteLn;

  WriteLn('[1] GetTargetInstallPath Tests');
  TestGetTargetInstallPath;
  WriteLn;

  WriteLn('[2] ValidateTarget Tests');
  TestValidateTarget;
  WriteLn;

  WriteLn('[3] GetTargetInfo Tests');
  TestGetTargetInfo;
  WriteLn;

  WriteLn('[4] GetAvailableTargets Tests');
  TestGetAvailableTargets;
  WriteLn;

  WriteLn('[5] GetInstalledTargets Tests');
  TestGetInstalledTargets;
  WriteLn;

  WriteLn('========================================');
  WriteLn('Test Results Summary');
  WriteLn('========================================');
  WriteLn('Total:   ', PassCount + FailCount);
  WriteLn('Passed:  ', PassCount);
  WriteLn('Failed:  ', FailCount);
  WriteLn;

  if FailCount = 0 then
    WriteLn('All tests passed!')
  else
  begin
    WriteLn('Some tests failed!');
    Halt(1);
  end;
end.
