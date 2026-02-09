program test_cross_engine_e2e;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.cross.engine.intf,
  fpdev.cross.engine,
  fpdev.cross.opts,
  fpdev.cross.compiler,
  fpdev.cross.fpccfg,
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

{ E2E: Win64 target dry-run }

procedure TestE2E_Win64_DryRun;
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
    Target := MakeTarget('x86_64', 'win64', '', '', '');
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Log := Engine.GetCommandLog;
    Check(Engine.GetCommandLogCount >= 2,
      'E2E Win64: has log entries');
    Check(Pos('x86_64-win64', Log[0]) > 0,
      'E2E Win64: start entry mentions target');
  finally
    Engine.Free;
  end;
end;

{ E2E: ARM target dry-run }

procedure TestE2E_ARM_DryRun;
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
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7',
      '/usr/arm-linux-gnueabihf/lib');
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', '3.2.2');
    Log := Engine.GetCommandLog;
    Check(Engine.GetCommandLogCount >= 2,
      'E2E ARM: has log entries');
    Check(Pos('arm-linux', Log[0]) > 0,
      'E2E ARM: start entry mentions target');
  finally
    Engine.Free;
  end;
end;

{ E2E: AArch64 target dry-run }

procedure TestE2E_AArch64_DryRun;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Target := MakeTarget('aarch64', 'linux', '', '', '');
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check(Engine.GetCommandLogCount >= 2,
      'E2E AArch64: has log entries');
  finally
    Engine.Free;
  end;
end;

{ E2E: CROSSOPT generation correctness }

procedure TestE2E_CrossOpt_ARM;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7',
    '/usr/arm-linux-gnueabihf/lib');
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '-CaEABIHF -CfVFPV3 -CpARMV7A -Fl/usr/arm-linux-gnueabihf/lib',
    'E2E CrossOpt ARM: complete string matches expected');
end;

procedure TestE2E_CrossOpt_Win64;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := MakeTarget('x86_64', 'win64', '', '', '');
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '',
    'E2E CrossOpt Win64: empty string');
end;

procedure TestE2E_CrossOpt_Mipsel;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := MakeTarget('mipsel', 'linux', 'o32', '', '');
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CaO32', Opts) > 0, 'E2E CrossOpt MIPS: has -CaO32');
  Check(Pos('-CfSOFT', Opts) > 0, 'E2E CrossOpt MIPS: has -CfSOFT');
end;

{ E2E: Compiler resolver }

procedure TestE2E_CompilerResolver;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('x86_64') = 'ppcrossx64',
    'E2E Resolver: x86_64');
  Check(TCrossCompilerResolver.GetPPCrossName('arm') = 'ppcrossarm',
    'E2E Resolver: arm');
  Check(TCrossCompilerResolver.GetPPCrossName('aarch64') = 'ppcrossa64',
    'E2E Resolver: aarch64');
  Check(TCrossCompilerResolver.GetPPCrossName('i386') = 'ppcross386',
    'E2E Resolver: i386');
  Check(TCrossCompilerResolver.GetPPCrossName('riscv64') = 'ppcrossrv64',
    'E2E Resolver: riscv64');
end;

{ E2E: fpc.cfg round-trip }

procedure TestE2E_FPCCfg_RoundTrip;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString(
      '# FPC configuration' + LineEnding +
      '-O2' + LineEnding +
      '-gl' + LineEnding);

    // Insert ARM target
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7',
      '/usr/arm-linux-gnueabihf/lib');
    Target.BinutilsPath := '/usr/bin';
    Target.BinutilsPrefix := 'arm-linux-gnueabihf-';
    Mgr.InsertCrossTarget(Target);

    // Insert Win64 target
    Target := MakeTarget('x86_64', 'win64', '', '', '');
    Target.BinutilsPrefix := 'x86_64-w64-mingw32-';
    Mgr.InsertCrossTarget(Target);

    Content := Mgr.GetContent;

    Check(Pos('-O2', Content) > 0, 'E2E fpc.cfg: original -O2 preserved');
    Check(Pos('-gl', Content) > 0, 'E2E fpc.cfg: original -gl preserved');
    Check(Pos('fpdev-cross:arm-linux', Content) > 0, 'E2E fpc.cfg: ARM section');
    Check(Pos('fpdev-cross:x86_64-win64', Content) > 0, 'E2E fpc.cfg: Win64 section');
    Check(Pos('-CaEABIHF', Content) > 0, 'E2E fpc.cfg: ARM -CaEABIHF');
    Check(Pos('#IFDEF CPUARM', Content) > 0, 'E2E fpc.cfg: ARM CPU ifdef');
    Check(Pos('#IFDEF CPUX86_64', Content) > 0, 'E2E fpc.cfg: Win64 CPU ifdef');

    // Remove ARM
    Mgr.RemoveCrossTarget('arm', 'linux');
    Content := Mgr.GetContent;
    Check(Pos('fpdev-cross:arm-linux', Content) = 0, 'E2E fpc.cfg: ARM removed');
    Check(Pos('fpdev-cross:x86_64-win64', Content) > 0, 'E2E fpc.cfg: Win64 still present');
  finally
    Mgr.Free;
  end;
end;

{ E2E: Stage progression }

procedure TestE2E_StageProgression;
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

    Check(Engine.GetCurrentStage = cbsIdle, 'Stage: starts Idle');

    Engine.Preflight(Target, '/tmp/test_src', '/tmp/sandbox');
    Check(Engine.GetCurrentStage = cbsPreflight, 'Stage: after Preflight');

    Engine.Verify(Target, '/tmp/sandbox', 'main');
    Check(Engine.GetCurrentStage = cbsComplete, 'Stage: after Verify = Complete');
  finally
    Engine.Free;
  end;
end;

{ E2E: Error handling }

procedure TestE2E_ErrorHandling;
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
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/sandbox', 'main');
    Check(Engine.GetCurrentStage = cbsFailed,
      'E2E Error: invalid target => cbsFailed');
    Check(Engine.GetLastError <> '',
      'E2E Error: has error message');
  finally
    Engine.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation E2E Tests ===');
  WriteLn;

  TestE2E_Win64_DryRun;
  TestE2E_ARM_DryRun;
  TestE2E_AArch64_DryRun;

  TestE2E_CrossOpt_ARM;
  TestE2E_CrossOpt_Win64;
  TestE2E_CrossOpt_Mipsel;

  TestE2E_CompilerResolver;

  TestE2E_FPCCfg_RoundTrip;

  TestE2E_StageProgression;

  TestE2E_ErrorHandling;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
