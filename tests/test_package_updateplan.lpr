program test_package_updateplan;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.package.types,
  fpdev.package.updateplan;

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

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure TestBuildPackageUpdatePlanSelectsLatestVersion;
var
  Available: TPackageArray;
  Plan: TPackageUpdatePlan;
begin
  SetLength(Available, 3);
  Available[0].Name := 'alpha';
  Available[0].Version := '1.0.0';
  Available[1].Name := 'alpha';
  Available[1].Version := '1.2.0';
  Available[2].Name := 'beta';
  Available[2].Version := '9.0.0';

  AssertTrue(
    BuildPackageUpdatePlanCore('alpha', '1.0.0', Available, Plan),
    'update plan is built for installed package'
  );
  AssertEquals('1.2.0', Plan.LatestVersion, 'latest version is selected');
  AssertTrue(Plan.UpdateNeeded, 'update is marked as needed');
end;

procedure TestBuildPackageUpdatePlanHandlesUpToDateVersion;
var
  Available: TPackageArray;
  Plan: TPackageUpdatePlan;
begin
  SetLength(Available, 1);
  Available[0].Name := 'alpha';
  Available[0].Version := '1.2.0';

  AssertTrue(
    BuildPackageUpdatePlanCore('alpha', '1.2.0', Available, Plan),
    'update plan is built for current version'
  );
  AssertTrue(not Plan.UpdateNeeded, 'no update is needed when installed version is latest');
end;

procedure TestBuildPackageUpdatePlanFailsForMissingPackage;
var
  Available: TPackageArray;
  Plan: TPackageUpdatePlan;
begin
  SetLength(Available, 1);
  Available[0].Name := 'beta';
  Available[0].Version := '9.0.0';

  AssertTrue(
    not BuildPackageUpdatePlanCore('alpha', '1.0.0', Available, Plan),
    'missing package does not build update plan'
  );
end;

begin
  TestBuildPackageUpdatePlanSelectsLatestVersion;
  TestBuildPackageUpdatePlanHandlesUpToDateVersion;
  TestBuildPackageUpdatePlanFailsForMissingPackage;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
