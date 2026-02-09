program test_cross_engine_types;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson,
  fpdev.config.interfaces,
  fpdev.cross.engine.intf,
  fpdev.build.cross;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

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

{ TCrossTarget record tests }

procedure TestCrossTargetDefaultValues;
var
  Target: TCrossTarget;
begin
  Target := Default(TCrossTarget);
  Check(Target.Enabled = False, 'Default TCrossTarget.Enabled is False');
  Check(Target.BinutilsPath = '', 'Default TCrossTarget.BinutilsPath is empty');
  Check(Target.LibrariesPath = '', 'Default TCrossTarget.LibrariesPath is empty');
  Check(Target.CPU = '', 'Default TCrossTarget.CPU is empty');
  Check(Target.OS = '', 'Default TCrossTarget.OS is empty');
  Check(Target.SubArch = '', 'Default TCrossTarget.SubArch is empty');
  Check(Target.ABI = '', 'Default TCrossTarget.ABI is empty');
  Check(Target.BinutilsPrefix = '', 'Default TCrossTarget.BinutilsPrefix is empty');
  Check(Target.CrossOpt = '', 'Default TCrossTarget.CrossOpt is empty');
end;

procedure TestCrossTargetLegacyFieldsCompatible;
var
  Target: TCrossTarget;
begin
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.BinutilsPath := '/usr/bin';
  Target.LibrariesPath := '/usr/lib';
  // Extended fields remain empty -- backward compatible
  Check(Target.Enabled = True, 'Legacy: Enabled field works');
  Check(Target.BinutilsPath = '/usr/bin', 'Legacy: BinutilsPath field works');
  Check(Target.LibrariesPath = '/usr/lib', 'Legacy: LibrariesPath field works');
  Check(Target.CPU = '', 'Legacy: CPU stays empty');
  Check(Target.OS = '', 'Legacy: OS stays empty');
end;

procedure TestCrossTargetExtendedFields;
var
  Target: TCrossTarget;
begin
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.BinutilsPath := '/usr/bin';
  Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';
  Target.CPU := 'arm';
  Target.OS := 'linux';
  Target.SubArch := 'armv7';
  Target.ABI := 'eabihf';
  Target.BinutilsPrefix := 'arm-linux-gnueabihf-';
  Target.CrossOpt := '-CaEABIHF -CfVFPV3';
  Check(Target.CPU = 'arm', 'Extended: CPU field works');
  Check(Target.OS = 'linux', 'Extended: OS field works');
  Check(Target.SubArch = 'armv7', 'Extended: SubArch field works');
  Check(Target.ABI = 'eabihf', 'Extended: ABI field works');
  Check(Target.BinutilsPrefix = 'arm-linux-gnueabihf-', 'Extended: BinutilsPrefix field works');
  Check(Target.CrossOpt = '-CaEABIHF -CfVFPV3', 'Extended: CrossOpt field works');
end;

{ TCrossBuildStage enum tests }

procedure TestCrossBuildStageEnumValues;
begin
  Check(Ord(cbsIdle) = 0, 'cbsIdle = 0');
  Check(Ord(cbsPreflight) = 1, 'cbsPreflight = 1');
  Check(Ord(cbsCompilerCycle) = 2, 'cbsCompilerCycle = 2');
  Check(Ord(cbsCompilerInstall) = 3, 'cbsCompilerInstall = 3');
  Check(Ord(cbsRTLBuild) = 4, 'cbsRTLBuild = 4');
  Check(Ord(cbsRTLInstall) = 5, 'cbsRTLInstall = 5');
  Check(Ord(cbsPackagesBuild) = 6, 'cbsPackagesBuild = 6');
  Check(Ord(cbsPackagesInstall) = 7, 'cbsPackagesInstall = 7');
  Check(Ord(cbsVerify) = 8, 'cbsVerify = 8');
  Check(Ord(cbsComplete) = 9, 'cbsComplete = 9');
  Check(Ord(cbsFailed) = 10, 'cbsFailed = 10');
end;

procedure TestCrossBuildStageToString;
begin
  Check(CrossBuildStageToString(cbsIdle) = 'idle', 'StageToString: idle');
  Check(CrossBuildStageToString(cbsPreflight) = 'preflight', 'StageToString: preflight');
  Check(CrossBuildStageToString(cbsCompilerCycle) = 'compiler_cycle', 'StageToString: compiler_cycle');
  Check(CrossBuildStageToString(cbsCompilerInstall) = 'compiler_install', 'StageToString: compiler_install');
  Check(CrossBuildStageToString(cbsRTLBuild) = 'rtl_build', 'StageToString: rtl_build');
  Check(CrossBuildStageToString(cbsRTLInstall) = 'rtl_install', 'StageToString: rtl_install');
  Check(CrossBuildStageToString(cbsPackagesBuild) = 'packages_build', 'StageToString: packages_build');
  Check(CrossBuildStageToString(cbsPackagesInstall) = 'packages_install', 'StageToString: packages_install');
  Check(CrossBuildStageToString(cbsVerify) = 'verify', 'StageToString: verify');
  Check(CrossBuildStageToString(cbsComplete) = 'complete', 'StageToString: complete');
  Check(CrossBuildStageToString(cbsFailed) = 'failed', 'StageToString: failed');
end;

{ TCrossService uses unified TCrossTarget }

procedure TestCrossServiceUsesUnifiedTarget;
var
  Svc: TCrossService;
  Target: TCrossTarget;
begin
  Svc := TCrossService.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.OS := 'linux';
    Target.ABI := 'eabihf';
    Target.BinutilsPrefix := 'arm-linux-gnueabihf-';
    Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';
    // GenerateFPCConfig should accept unified TCrossTarget
    Check(Svc.GenerateFPCConfig(Target) <> '', 'TCrossService accepts unified TCrossTarget');
  finally
    Svc.Free;
  end;
end;

procedure TestCrossServiceGetArmOptions;
var
  Svc: TCrossService;
  Target: TCrossTarget;
  Opts: string;
begin
  Svc := TCrossService.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.ABI := 'eabihf';
    Opts := Svc.GetArmOptions(Target);
    Check(Pos('-CaEABIHF', Opts) > 0, 'GetArmOptions contains -CaEABIHF for eabihf');
    Check(Pos('-CfVFPV3', Opts) > 0, 'GetArmOptions contains -CfVFPV3 for eabihf');
  finally
    Svc.Free;
  end;
end;

procedure TestCrossServiceTargetTriple;
var
  Svc: TCrossService;
begin
  Svc := TCrossService.Create;
  try
    Check(Svc.GetTargetTriple('arm', 'linux', 'eabihf') = 'arm-linux-eabihf',
      'GetTargetTriple arm-linux-eabihf');
    Check(Svc.GetTargetTriple('x86_64', 'win64', '') = 'x86_64-win64',
      'GetTargetTriple x86_64-win64 (no ABI)');
  finally
    Svc.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Engine Types Unit Tests ===');
  WriteLn;

  TestCrossTargetDefaultValues;
  TestCrossTargetLegacyFieldsCompatible;
  TestCrossTargetExtendedFields;
  TestCrossBuildStageEnumValues;
  TestCrossBuildStageToString;
  TestCrossServiceUsesUnifiedTarget;
  TestCrossServiceGetArmOptions;
  TestCrossServiceTargetTriple;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
