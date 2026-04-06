program test_fpc_builder_buildplan;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.fpc.builder;

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

function IndexOfParam(const AParams: TFPCSourceBuildArgs; const AValue: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AParams) do
    if AParams[I] = AValue then
      Exit(I);
end;

procedure TestUnixBuildPlanPinsInstallCommand;
var
  Plan: TFPCSourceBuildPlan;
begin
  Plan := CreateFPCSourceBuildPlanCore(
    '/tmp/install',
    '/tmp/bootstrap/ppcx64',
    4,
    'gmake',
    False
  );

  Check('unix build plan keeps resolved make command',
    Plan.MakeCommand = 'gmake',
    Plan.MakeCommand);
  Check('unix build plan includes bootstrap compiler',
    IndexOfParam(Plan.Params, 'PP=/tmp/bootstrap/ppcx64') >= 0);
  Check('unix build plan pins GINSTALL to system install',
    IndexOfParam(Plan.Params, 'GINSTALL=/usr/bin/install') >= 0);
  Check('unix build plan keeps override version check',
    IndexOfParam(Plan.Params, 'OVERRIDEVERSIONCHECK=1') >= 0);
end;

procedure TestWindowsBuildPlanDoesNotInjectUnixInstallCommand;
var
  Plan: TFPCSourceBuildPlan;
begin
  Plan := CreateFPCSourceBuildPlanCore(
    'C:\fpdev\install',
    'C:\fpdev\bootstrap\fpc.exe',
    4,
    'mingw32-make',
    True
  );

  Check('windows build plan keeps resolved make command',
    Plan.MakeCommand = 'mingw32-make',
    Plan.MakeCommand);
  Check('windows build plan omits unix ginstall override',
    IndexOfParam(Plan.Params, 'GINSTALL=/usr/bin/install') < 0);
end;

begin
  TestUnixBuildPlanPinsInstallCommand;
  TestWindowsBuildPlanDoesNotInjectUnixInstallCommand;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
