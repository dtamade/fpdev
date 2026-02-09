program test_cross_engine;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.cross.engine.intf,
  fpdev.cross.opts,
  fpdev.cross.compiler,
  fpdev.cross.engine,
  fpdev.build.manager;

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

{ Helper to create a minimal target }

function MakeTarget(const ACPU, AOS, AABI, ASubArch, ALibPath: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
  Result.ABI := AABI;
  Result.SubArch := ASubArch;
  Result.LibrariesPath := ALibPath;
end;

{ Preflight tests }

procedure TestPreflight_ValidTarget;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7', '/usr/arm-linux-gnueabihf/lib');
    Check(Engine.Preflight(Target, '/tmp/test_src', '/tmp/test_sandbox') = True,
      'Preflight: valid ARM target succeeds in dry-run');
    Check(Engine.GetCurrentStage = cbsPreflight,
      'Preflight: stage is cbsPreflight after success');
  finally
    Engine.Free;
  end;
end;

procedure TestPreflight_MissingCPU;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := Default(TCrossTarget);
    Target.OS := 'linux';
    Check(Engine.Preflight(Target, '/tmp/test_src', '/tmp/test_sandbox') = False,
      'Preflight: missing CPU fails');
    Check(Engine.GetLastError = 'Target CPU not specified',
      'Preflight: error message for missing CPU');
    Check(Engine.GetCurrentStage = cbsFailed,
      'Preflight: stage is cbsFailed after failure');
  finally
    Engine.Free;
  end;
end;

procedure TestPreflight_MissingOS;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Check(Engine.Preflight(Target, '/tmp/test_src', '/tmp/test_sandbox') = False,
      'Preflight: missing OS fails');
    Check(Engine.GetLastError = 'Target OS not specified',
      'Preflight: error message for missing OS');
  finally
    Engine.Free;
  end;
end;

procedure TestPreflight_UnsupportedCPU;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('z80', 'cpm', '', '', '');
    Check(Engine.Preflight(Target, '/tmp/test_src', '/tmp/test_sandbox') = False,
      'Preflight: unsupported CPU fails');
    Check(Pos('Unsupported CPU', Engine.GetLastError) > 0,
      'Preflight: error mentions unsupported CPU');
  finally
    Engine.Free;
  end;
end;

{ Stage transition tests }

procedure TestStageTransitions;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Check(Engine.GetCurrentStage = cbsIdle, 'Stage: initial is cbsIdle');
    Engine.SetDryRun(True);
  finally
    Engine.Free;
  end;
end;

{ Command log tests }

procedure TestCommandLog_Empty;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Check(Engine.GetCommandLogCount = 0, 'CommandLog: empty initially');
  finally
    Engine.Free;
  end;
end;

procedure TestCommandLog_AfterPreflight;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
  Log: TStringArray;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7', '/usr/arm-linux-gnueabihf/lib');
    Engine.Preflight(Target, '/tmp/test_src', '/tmp/test_sandbox');
    Check(Engine.GetCommandLogCount > 0, 'CommandLog: not empty after preflight');
    Log := Engine.GetCommandLog;
    Check(Pos('preflight', Log[0]) > 0, 'CommandLog: first entry mentions preflight');
  finally
    Engine.Free;
  end;
end;

{ CrossOpt integration tests }

procedure TestBuildCrossOpt_ArmEabihf;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7', '/usr/arm-linux-gnueabihf/lib');
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CaEABIHF', Opts) > 0, 'CrossOpt ARM: contains -CaEABIHF');
  Check(Pos('-CfVFPV3', Opts) > 0, 'CrossOpt ARM: contains -CfVFPV3');
  Check(Pos('-CpARMV7A', Opts) > 0, 'CrossOpt ARM: contains -CpARMV7A');
  Check(Pos('-Fl/usr/arm-linux-gnueabihf/lib', Opts) > 0, 'CrossOpt ARM: contains library path');
end;

procedure TestBuildCrossOpt_Win64;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := MakeTarget('x86_64', 'win64', '', '', '');
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '', 'CrossOpt Win64: empty (no special options)');
end;

{ Cross-compiler resolver integration }

procedure TestResolverIntegration_KnownCPUs;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('arm') = 'ppcrossarm',
    'Resolver: arm => ppcrossarm');
  Check(TCrossCompilerResolver.GetPPCrossName('x86_64') = 'ppcrossx64',
    'Resolver: x86_64 => ppcrossx64');
  Check(TCrossCompilerResolver.GetPPCrossName('aarch64') = 'ppcrossa64',
    'Resolver: aarch64 => ppcrossa64');
  Check(TCrossCompilerResolver.GetPPCrossName('i386') = 'ppcross386',
    'Resolver: i386 => ppcross386');
end;

{ DryRun mode tests }

procedure TestDryRun_DoesNotExecute;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/nonexistent_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('x86_64', 'win64', '', '', '');
    // Preflight should succeed in dry-run even with nonexistent paths
    Check(Engine.Preflight(Target, '/tmp/nonexistent_src', '/tmp/nonexistent_sandbox') = True,
      'DryRun: preflight succeeds with nonexistent paths');
  finally
    Engine.Free;
  end;
end;

{ Full build orchestration test (dry-run) }

procedure TestFullBuild_DryRun_LogsAllSteps;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
  Log: TStringArray;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7', '/usr/arm-linux-gnueabihf/lib');

    // Full build in dry-run mode
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', '3.2.2');

    Log := Engine.GetCommandLog;

    Check(Engine.GetCommandLogCount >= 2,
      'FullBuild DryRun: has at least start + preflight log entries');
    Check(Pos('start', Log[0]) > 0,
      'FullBuild DryRun: first log entry is start');
  finally
    Engine.Free;
  end;
end;

{ Interface contract test }

procedure TestInterfaceContract;
var
  BM: TBuildManager;
  Engine: ICrossBuildEngine;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  // Test that TCrossBuildEngine correctly implements ICrossBuildEngine
  Check(Engine.GetCurrentStage = cbsIdle, 'Interface: GetCurrentStage works');
  Check(Engine.GetLastError = '', 'Interface: GetLastError returns empty initially');
  // Engine will be freed by reference counting
end;

{ Verify stage test }

procedure TestVerify_DryRun;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('arm', 'linux', 'eabihf', '', '');
    Check(Engine.Verify(Target, '/tmp/test_sandbox', '3.2.2') = True,
      'Verify: succeeds in dry-run mode');
    Check(Engine.GetCurrentStage = cbsComplete,
      'Verify: stage is cbsComplete after success');
  finally
    Engine.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Build Engine Tests ===');
  WriteLn;

  // Preflight tests
  TestPreflight_ValidTarget;
  TestPreflight_MissingCPU;
  TestPreflight_MissingOS;
  TestPreflight_UnsupportedCPU;

  // Stage tests
  TestStageTransitions;

  // Command log tests
  TestCommandLog_Empty;
  TestCommandLog_AfterPreflight;

  // CrossOpt integration
  TestBuildCrossOpt_ArmEabihf;
  TestBuildCrossOpt_Win64;

  // Resolver integration
  TestResolverIntegration_KnownCPUs;

  // DryRun tests
  TestDryRun_DoesNotExecute;
  TestFullBuild_DryRun_LogsAllSteps;

  // Interface contract
  TestInterfaceContract;

  // Verify
  TestVerify_DryRun;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
