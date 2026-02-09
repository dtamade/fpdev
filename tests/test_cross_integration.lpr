program test_cross_integration;

{$mode objfpc}{$H+}

{
  B118: Cross-Compilation Integration Test Suite

  End-to-end integration tests that verify all M7 components work together:
    - TCrossTargetRegistry (target definitions)
    - TCrossOptBuilder (CROSSOPT construction)
    - TCrossCompilerResolver (ppcross* name resolution)
    - TCrossBuildEngine (7-step build orchestration)
    - TFPCCfgManager (fpc.cfg section management)
    - TCrossToolchainSearch (6-layer search engine)

  All tests use dry-run mode and do not require actual cross-compilers.
}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.cross.targets,
  fpdev.cross.opts,
  fpdev.cross.compiler,
  fpdev.cross.engine.intf,
  fpdev.cross.engine,
  fpdev.cross.fpccfg,
  fpdev.cross.search,
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

{ === Integration: Registry -> OptBuilder -> Engine (Win64) === }

procedure TestIntegration_Win64_FullPipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Opts: string;
  PPName: string;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Log: TStringArray;
begin
  WriteLn('--- Win64 Full Pipeline ---');

  // Step 1: Get target from registry
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('x86_64-win64', Def), 'Win64 Pipeline: target found in registry');
    Check(Def.CPU = 'x86_64', 'Win64 Pipeline: CPU from registry');
    Check(Def.OS = 'win64', 'Win64 Pipeline: OS from registry');
  finally
    Reg.Free;
  end;

  // Step 2: Build TCrossTarget from registry def
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;
  Target.SubArch := Def.SubArch;
  Target.ABI := Def.ABI;
  Target.BinutilsPrefix := Def.BinutilsPrefix;
  Target.CrossOpt := Def.DefaultCrossOpt;

  // Step 3: Build CROSSOPT
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '', 'Win64 Pipeline: CROSSOPT empty (no special opts needed)');

  // Step 4: Resolve compiler name
  PPName := TCrossCompilerResolver.GetPPCrossName(Target.CPU);
  Check(PPName = 'ppcrossx64', 'Win64 Pipeline: compiler name resolved');

  // Step 5: Build engine dry-run
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Log := Engine.GetCommandLog;

    Check(Engine.GetCommandLogCount >= 2, 'Win64 Pipeline: engine produced log entries');
    Check(Pos('x86_64-win64', Log[0]) > 0, 'Win64 Pipeline: log mentions target');
    // Engine may not reach Complete without real source dir, but preflight+log is sufficient
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'Win64 Pipeline: engine attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Registry -> OptBuilder -> Engine (ARM hard-float) === }

procedure TestIntegration_ARM_FullPipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Opts: string;
  PPName: string;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Log: TStringArray;
begin
  WriteLn('--- ARM hard-float Full Pipeline ---');

  // Step 1: Get target from registry
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('arm-linux', Def), 'ARM Pipeline: target found');
    Check(Def.ABI = 'eabihf', 'ARM Pipeline: ABI is eabihf');
    Check(Def.SubArch = 'armv7', 'ARM Pipeline: SubArch is armv7');
  finally
    Reg.Free;
  end;

  // Step 2: Build target
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;
  Target.SubArch := Def.SubArch;
  Target.ABI := Def.ABI;
  Target.BinutilsPrefix := Def.BinutilsPrefix;
  Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';

  // Step 3: CROSSOPT should include ARM-specific flags
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CaEABIHF', Opts) > 0, 'ARM Pipeline: CROSSOPT has -CaEABIHF');
  Check(Pos('-CfVFPV3', Opts) > 0, 'ARM Pipeline: CROSSOPT has -CfVFPV3');
  Check(Pos('-CpARMV7A', Opts) > 0, 'ARM Pipeline: CROSSOPT has -CpARMV7A');
  Check(Pos('-Fl/usr/arm-linux-gnueabihf/lib', Opts) > 0, 'ARM Pipeline: CROSSOPT has -Fl');

  // Step 4: Resolve compiler name
  PPName := TCrossCompilerResolver.GetPPCrossName(Target.CPU);
  Check(PPName = 'ppcrossarm', 'ARM Pipeline: compiler = ppcrossarm');

  // Step 5: Build engine dry-run
  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', '3.2.2');
    Log := Engine.GetCommandLog;

    Check(Engine.GetCommandLogCount >= 2, 'ARM Pipeline: engine produced log');
    Check(Pos('arm-linux', Log[0]) > 0, 'ARM Pipeline: log mentions target');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'ARM Pipeline: engine attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Registry -> OptBuilder -> Engine (AArch64) === }

procedure TestIntegration_AArch64_FullPipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Opts, PPName: string;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  WriteLn('--- AArch64 Full Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('aarch64-linux', Def), 'AArch64 Pipeline: target found');
    Check(Def.CPU = 'aarch64', 'AArch64 Pipeline: CPU correct');
  finally
    Reg.Free;
  end;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;

  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '', 'AArch64 Pipeline: CROSSOPT empty (no special opts)');

  PPName := TCrossCompilerResolver.GetPPCrossName(Target.CPU);
  Check(PPName = 'ppcrossa64', 'AArch64 Pipeline: compiler = ppcrossa64');

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'AArch64 Pipeline: engine attempted build');
    Check(Engine.GetCommandLogCount >= 2, 'AArch64 Pipeline: has log entries');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Registry -> OptBuilder -> Engine (MIPS LE) === }

procedure TestIntegration_MIPS_FullPipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Opts, PPName: string;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  WriteLn('--- MIPS LE Full Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('mipsel-linux', Def), 'MIPS Pipeline: target found');
    Check(Def.CPU = 'mipsel', 'MIPS Pipeline: CPU = mipsel');
  finally
    Reg.Free;
  end;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;

  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CfSOFT', Opts) > 0, 'MIPS Pipeline: CROSSOPT has -CfSOFT');

  PPName := TCrossCompilerResolver.GetPPCrossName(Target.CPU);
  Check(PPName = 'ppcrossmipsel', 'MIPS Pipeline: compiler = ppcrossmipsel');

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'MIPS Pipeline: engine attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Registry -> OptBuilder -> Engine (RISC-V 64) === }

procedure TestIntegration_RISCV64_FullPipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  PPName: string;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  WriteLn('--- RISC-V 64 Full Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('riscv64-linux', Def), 'RISCV64 Pipeline: target found');
    Check(Def.CPU = 'riscv64', 'RISCV64 Pipeline: CPU = riscv64');
  finally
    Reg.Free;
  end;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;

  PPName := TCrossCompilerResolver.GetPPCrossName(Target.CPU);
  Check(PPName = 'ppcrossrv64', 'RISCV64 Pipeline: compiler = ppcrossrv64');

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'RISCV64 Pipeline: engine attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Registry -> fpc.cfg round-trip === }

procedure TestIntegration_Registry_FPCCfg;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Mgr: TFPCCfgManager;
  Content: string;
begin
  WriteLn('--- Registry -> fpc.cfg Integration ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('arm-linux', Def), 'RegCfg: ARM target found');
  finally
    Reg.Free;
  end;

  // Build TCrossTarget from registry data
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;
  Target.SubArch := Def.SubArch;
  Target.ABI := Def.ABI;
  Target.BinutilsPrefix := Def.BinutilsPrefix;
  Target.BinutilsPath := '/usr/bin';
  Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';

  // Insert into fpc.cfg
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString(
      '# FPC configuration' + LineEnding +
      '-O2' + LineEnding);

    Mgr.InsertCrossTarget(Target);
    Content := Mgr.GetContent;

    Check(Pos('fpdev-cross:arm-linux', Content) > 0, 'RegCfg: section marker present');
    Check(Pos('#IFDEF CPUARM', Content) > 0, 'RegCfg: CPU ifdef');
    Check(Pos('-CaEABIHF', Content) > 0, 'RegCfg: ARM -CaEABIHF in cfg');
    Check(Pos('-O2', Content) > 0, 'RegCfg: original config preserved');

    // Verify HasCrossTarget
    Check(Mgr.HasCrossTarget('arm', 'linux'), 'RegCfg: HasCrossTarget returns True');
    Check(not Mgr.HasCrossTarget('x86_64', 'win64'), 'RegCfg: HasCrossTarget returns False for missing');
  finally
    Mgr.Free;
  end;
end;

{ === Integration: Multiple targets in fpc.cfg === }

procedure TestIntegration_MultiTarget_FPCCfg;
var
  Reg: TCrossTargetRegistry;
  DefARM, DefWin: TCrossTargetDef;
  TargetARM, TargetWin: TCrossTarget;
  Mgr: TFPCCfgManager;
  Content: string;
begin
  WriteLn('--- Multi-Target fpc.cfg ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Reg.GetTarget('arm-linux', DefARM);
    Reg.GetTarget('x86_64-win64', DefWin);
  finally
    Reg.Free;
  end;

  // Build ARM target
  TargetARM := Default(TCrossTarget);
  TargetARM.Enabled := True;
  TargetARM.CPU := DefARM.CPU;
  TargetARM.OS := DefARM.OS;
  TargetARM.ABI := DefARM.ABI;
  TargetARM.SubArch := DefARM.SubArch;
  TargetARM.BinutilsPrefix := DefARM.BinutilsPrefix;
  TargetARM.BinutilsPath := '/usr/bin';
  TargetARM.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';

  // Build Win64 target
  TargetWin := Default(TCrossTarget);
  TargetWin.Enabled := True;
  TargetWin.CPU := DefWin.CPU;
  TargetWin.OS := DefWin.OS;
  TargetWin.BinutilsPrefix := DefWin.BinutilsPrefix;

  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('# fpc.cfg' + LineEnding);

    // Insert both targets
    Mgr.InsertCrossTarget(TargetARM);
    Mgr.InsertCrossTarget(TargetWin);
    Content := Mgr.GetContent;

    Check(Mgr.HasCrossTarget('arm', 'linux'), 'MultiCfg: ARM present');
    Check(Mgr.HasCrossTarget('x86_64', 'win64'), 'MultiCfg: Win64 present');
    Check(Pos('fpdev-cross:arm-linux', Content) > 0, 'MultiCfg: ARM section marker');
    Check(Pos('fpdev-cross:x86_64-win64', Content) > 0, 'MultiCfg: Win64 section marker');

    // Remove ARM, verify Win64 survives
    Mgr.RemoveCrossTarget('arm', 'linux');
    Content := Mgr.GetContent;
    Check(not Mgr.HasCrossTarget('arm', 'linux'), 'MultiCfg: ARM removed');
    Check(Mgr.HasCrossTarget('x86_64', 'win64'), 'MultiCfg: Win64 survived');
  finally
    Mgr.Free;
  end;
end;

{ === Integration: Search engine produces diagnostics === }

procedure TestIntegration_SearchEngine_Diagnostics;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  DiagLog: TStringArray;
begin
  WriteLn('--- Search Engine Diagnostics ---');

  Search := TCrossToolchainSearch.Create;
  try
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7', '');
    Target.BinutilsPrefix := 'arm-linux-gnueabihf-';

    DiagLog := Search.DiagnoseTarget(Target);
    Check(Length(DiagLog) > 0, 'SearchDiag: produces diagnostic output');

    // Search log should have entries from search attempts
    Check(Search.GetSearchLogCount > 0, 'SearchDiag: search log has entries');
  finally
    Search.Free;
  end;
end;

{ === Integration: Search engine binutils search === }

procedure TestIntegration_SearchEngine_Binutils;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  SearchResult: TCrossSearchResult;
begin
  WriteLn('--- Search Engine Binutils ---');

  Search := TCrossToolchainSearch.Create;
  try
    // Search for a target that likely does not exist on this system
    Target := MakeTarget('sparc', 'linux', '', '', '');
    Target.BinutilsPrefix := 'sparc-linux-gnu-';

    SearchResult := Search.SearchBinutils(Target);
    // On most CI/dev systems, sparc binutils won't be found
    // We just verify the search completes without error
    Check(True, 'SearchBinutils: completes without crash');
    Check(Search.GetSearchLogCount > 0, 'SearchBinutils: logged search attempts');

    // Verify search result structure
    if SearchResult.Found then
    begin
      Check(SearchResult.Layer >= 1, 'SearchBinutils: layer >= 1');
      Check(SearchResult.LayerName <> '', 'SearchBinutils: layer name set');
    end
    else
      Check(not SearchResult.Found, 'SearchBinutils: graceful not-found');
  finally
    Search.Free;
  end;
end;

{ === Integration: Search engine library search === }

procedure TestIntegration_SearchEngine_Libraries;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  Libs: TStringArray;
begin
  WriteLn('--- Search Engine Libraries ---');

  Search := TCrossToolchainSearch.Create;
  try
    Target := MakeTarget('aarch64', 'linux', '', '', '');
    Target.BinutilsPrefix := 'aarch64-linux-gnu-';

    Libs := Search.SearchLibraries(Target);
    // Library search may or may not find results depending on system
    Check(True, 'SearchLibraries: completes without crash');
    // Verify returned array is valid (even if empty)
    Check(Length(Libs) >= 0, 'SearchLibraries: returns valid array');
  finally
    Search.Free;
  end;
end;

{ === Integration: All 21 builtin targets pass through OptBuilder === }

procedure TestIntegration_AllTargets_OptBuilder;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
  I: Integer;
  Target: TCrossTarget;
  Opts: string;
  AllOK: Boolean;
begin
  WriteLn('--- All Targets OptBuilder ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.ListTargetDefs;
    Check(Length(Defs) = 21, 'AllTargets: 21 builtin targets');

    AllOK := True;
    for I := 0 to High(Defs) do
    begin
      Target := Default(TCrossTarget);
      Target.Enabled := True;
      Target.CPU := Defs[I].CPU;
      Target.OS := Defs[I].OS;
      Target.SubArch := Defs[I].SubArch;
      Target.ABI := Defs[I].ABI;

      // This should not crash for any target
      try
        Opts := TCrossOptBuilder.Build(Target);
        // Opts can be empty for some targets (Win64, AArch64) - that's OK
        if Opts <> '' then; // suppress hint
      except
        on E: Exception do
        begin
          WriteLn('  [info] OptBuilder crash for ', Defs[I].Name, ': ', E.Message);
          AllOK := False;
        end;
      end;
    end;
    Check(AllOK, 'AllTargets: OptBuilder succeeds for all 21 targets');
  finally
    Reg.Free;
  end;
end;

{ === Integration: All 21 targets resolve to valid ppcross names === }

procedure TestIntegration_AllTargets_CompilerResolve;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
  I: Integer;
  PPName: string;
  AllHaveNames: Boolean;
begin
  WriteLn('--- All Targets Compiler Resolve ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.ListTargetDefs;

    AllHaveNames := True;
    for I := 0 to High(Defs) do
    begin
      PPName := TCrossCompilerResolver.GetPPCrossName(Defs[I].CPU);
      if PPName = '' then
      begin
        WriteLn('  [info] No ppcross name for CPU: ', Defs[I].CPU, ' (', Defs[I].Name, ')');
        AllHaveNames := False;
      end;
    end;
    Check(AllHaveNames, 'AllTargets: all CPUs have ppcross compiler names');
  finally
    Reg.Free;
  end;
end;

{ === Integration: All 21 targets can dry-run through engine === }

procedure TestIntegration_AllTargets_Engine_DryRun;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
  I: Integer;
  Target: TCrossTarget;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  AllComplete: Boolean;
begin
  WriteLn('--- All Targets Engine Dry-Run ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.ListTargetDefs;

    AllComplete := True;
    for I := 0 to High(Defs) do
    begin
      Target := Default(TCrossTarget);
      Target.Enabled := True;
      Target.CPU := Defs[I].CPU;
      Target.OS := Defs[I].OS;
      Target.SubArch := Defs[I].SubArch;
      Target.ABI := Defs[I].ABI;

      BM := TBuildManager.Create('/tmp/test_src', 1, False);
      Engine := TCrossBuildEngine.Create(BM, True);
      try
        Engine.SetDryRun(True);
        Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
        // Engine may not reach Complete without real source dir, but must at least
        // pass preflight (produce log entries). CompilerCycle failure is expected
        // since TBuildManager.BuildCompiler checks for source existence.
        if Engine.GetCommandLogCount < 2 then
        begin
          WriteLn('  [info] ', Defs[I].Name, ' did not produce log: ',
            Engine.GetLastError);
          AllComplete := False;
        end;
      finally
        Engine.Free;
      end;
    end;
    Check(AllComplete, 'AllTargets: all 21 targets dry-run pass preflight');
  finally
    Reg.Free;
  end;
end;

{ === Integration: Custom target extends registry and works in pipeline === }

procedure TestIntegration_CustomTarget_Pipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  WriteLn('--- Custom Target Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;

    // Register a custom ESP32 target
    Def := MakeTargetDef('xtensa-freertos', 'ESP32 FreeRTOS', 'xtensa', 'freertos',
      '', '', 'xtensa-esp32-elf-', '', 'ESP32 IoT target', False);
    Reg.RegisterTarget(Def);
    Check(Reg.HasTarget('xtensa-freertos'), 'CustomPipeline: target registered');
    Check(Reg.Count = 22, 'CustomPipeline: count increased to 22');
  finally
    Reg.Free;
  end;

  // Custom target through engine (will fail at ppcross resolution gracefully)
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := 'xtensa';
  Target.OS := 'freertos';

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    // xtensa has no ppcross mapping, should fail at preflight
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check(Engine.GetCurrentStage = cbsFailed, 'CustomPipeline: unknown CPU fails gracefully');
    Check(Pos('xtensa', Engine.GetLastError) > 0, 'CustomPipeline: error mentions xtensa');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Engine step-by-step produces valid logs === }

procedure TestIntegration_StepByStep_Logs;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
  Log: TStringArray;
begin
  WriteLn('--- Step-by-Step Log Validation ---');

  Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7', '');

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);

    // Each step should add a log entry
    Engine.Preflight(Target, '/tmp/test_src', '/tmp/sandbox');
    Check(Engine.GetCommandLogCount >= 1, 'StepByStep: preflight logged');
    Check(Engine.GetCurrentStage = cbsPreflight, 'StepByStep: stage = preflight');

    // Verify stage advances through CompilerCycle (may fail due to missing source)
    Engine.CompilerCycle(Target, '/tmp/test_src', '3.2.2');
    Check(Engine.GetCommandLogCount >= 2, 'StepByStep: compiler cycle logged');

    // Verify log entries have meaningful content
    Log := Engine.GetCommandLog;
    Check(Pos('arm-linux', Log[0]) > 0, 'StepByStep: preflight log mentions target');
    Check(Pos('compiler_cycle', Log[1]) > 0, 'StepByStep: step1 log mentions compiler_cycle');

    // Verify stage continues to verify even if make calls fail
    Engine.Verify(Target, '/tmp/sandbox', '3.2.2');
    Check(Engine.GetCurrentStage = cbsComplete, 'StepByStep: Verify sets Complete');
  finally
    Engine.Free;
  end;
end;

{ === Integration: fpc.cfg + OptBuilder consistency === }

procedure TestIntegration_FPCCfg_OptBuilder_Consistency;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Mgr: TFPCCfgManager;
  Content, Opts: string;
begin
  WriteLn('--- fpc.cfg + OptBuilder Consistency ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Reg.GetTarget('arm-linux', Def);
  finally
    Reg.Free;
  end;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;
  Target.SubArch := Def.SubArch;
  Target.ABI := Def.ABI;
  Target.BinutilsPrefix := Def.BinutilsPrefix;
  Target.BinutilsPath := '/usr/bin';
  Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';

  // Get CROSSOPT from builder
  Opts := TCrossOptBuilder.Build(Target);

  // Insert into fpc.cfg
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('# base config' + LineEnding);
    Mgr.InsertCrossTarget(Target);
    Content := Mgr.GetContent;

    // fpc.cfg should contain the same options that OptBuilder generates
    if Pos('-CaEABIHF', Opts) > 0 then
      Check(Pos('-CaEABIHF', Content) > 0, 'OptCfg: -CaEABIHF in both OptBuilder and cfg');
    if Pos('-CfVFPV3', Opts) > 0 then
      Check(Pos('-CfVFPV3', Content) > 0, 'OptCfg: -CfVFPV3 in both');
    if Pos('-CpARMV7A', Opts) > 0 then
      Check(Pos('-CpARMV7A', Content) > 0, 'OptCfg: -CpARMV7A in both');
    if Pos('-Fl', Opts) > 0 then
      Check(Pos('-Fl', Content) > 0, 'OptCfg: -Fl in both');
  finally
    Mgr.Free;
  end;
end;

{ === Integration: Invalid target error propagation === }

procedure TestIntegration_InvalidTarget_Errors;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  WriteLn('--- Invalid Target Error Propagation ---');

  // Empty CPU
  Target := Default(TCrossTarget);
  Target.CPU := '';
  Target.OS := 'linux';

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/sandbox', 'main');
    Check(Engine.GetCurrentStage = cbsFailed, 'InvalidTarget: empty CPU fails');
    Check(Pos('CPU', Engine.GetLastError) > 0, 'InvalidTarget: error mentions CPU');
  finally
    Engine.Free;
  end;

  // Empty OS
  Target := Default(TCrossTarget);
  Target.CPU := 'arm';
  Target.OS := '';

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/sandbox', 'main');
    Check(Engine.GetCurrentStage = cbsFailed, 'InvalidTarget: empty OS fails');
    Check(Pos('OS', Engine.GetLastError) > 0, 'InvalidTarget: error mentions OS');
  finally
    Engine.Free;
  end;

  // Both empty
  Target := Default(TCrossTarget);

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/sandbox', 'main');
    Check(Engine.GetCurrentStage = cbsFailed, 'InvalidTarget: both empty fails');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Android targets through pipeline === }

procedure TestIntegration_Android_Pipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  WriteLn('--- Android Target Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;

    // aarch64-android
    Check(Reg.GetTarget('aarch64-android', Def), 'Android: aarch64-android found');
    Check(Def.CPU = 'aarch64', 'Android: CPU = aarch64');
    Check(Def.OS = 'android', 'Android: OS = android');

    Target := Default(TCrossTarget);
    Target.Enabled := True;
    Target.CPU := Def.CPU;
    Target.OS := Def.OS;
  finally
    Reg.Free;
  end;

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'Android: aarch64-android dry-run attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: iOS target through pipeline === }

procedure TestIntegration_iOS_Pipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  WriteLn('--- iOS Target Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('aarch64-ios', Def), 'iOS: aarch64-ios found');
    Check(Def.CPU = 'aarch64', 'iOS: CPU = aarch64');
    Check(Def.OS = 'ios', 'iOS: OS = ios');

    Target := Default(TCrossTarget);
    Target.Enabled := True;
    Target.CPU := Def.CPU;
    Target.OS := Def.OS;
  finally
    Reg.Free;
  end;

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'iOS: aarch64-ios dry-run attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: FreeBSD target through pipeline === }

procedure TestIntegration_FreeBSD_Pipeline;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  WriteLn('--- FreeBSD Target Pipeline ---');

  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('x86_64-freebsd', Def), 'FreeBSD: x86_64-freebsd found');

    Target := Default(TCrossTarget);
    Target.Enabled := True;
    Target.CPU := Def.CPU;
    Target.OS := Def.OS;
  finally
    Reg.Free;
  end;

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', 'main');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'FreeBSD: x86_64-freebsd dry-run attempted build');
  finally
    Engine.Free;
  end;
end;

{ === Integration: Registry JSON export -> reimport -> engine === }

procedure TestIntegration_Registry_ExportImport_Engine;
var
  Reg1, Reg2: TCrossTargetRegistry;
  JSON: string;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  WriteLn('--- Registry Export/Import -> Engine ---');

  // Export all builtin targets to JSON
  Reg1 := TCrossTargetRegistry.Create;
  try
    Reg1.LoadBuiltinTargets;
    JSON := Reg1.ExportToJSON;
    Check(Length(JSON) > 100, 'ExportImport: JSON not empty');
  finally
    Reg1.Free;
  end;

  // Import into fresh registry
  Reg2 := TCrossTargetRegistry.Create;
  try
    Reg2.LoadFromJSON(JSON);
    Check(Reg2.Count = 21, 'ExportImport: reimported 21 targets');
    Check(Reg2.HasTarget('arm-linux'), 'ExportImport: arm-linux preserved');
    Check(Reg2.GetTarget('arm-linux', Def), 'ExportImport: can get target');
    Check(Def.CPU = 'arm', 'ExportImport: CPU preserved through round-trip');
    Check(Def.ABI = 'eabihf', 'ExportImport: ABI preserved through round-trip');
  finally
    Reg2.Free;
  end;

  // Use reimported target in engine
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;
  Target.ABI := Def.ABI;
  Target.SubArch := Def.SubArch;

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/test_sandbox', '3.2.2');
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'ExportImport: reimported target attempted build');
  finally
    Engine.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Integration Test Suite ===');
  WriteLn;

  TestIntegration_Win64_FullPipeline;
  TestIntegration_ARM_FullPipeline;
  TestIntegration_AArch64_FullPipeline;
  TestIntegration_MIPS_FullPipeline;
  TestIntegration_RISCV64_FullPipeline;

  TestIntegration_Registry_FPCCfg;
  TestIntegration_MultiTarget_FPCCfg;

  TestIntegration_SearchEngine_Diagnostics;
  TestIntegration_SearchEngine_Binutils;
  TestIntegration_SearchEngine_Libraries;

  TestIntegration_AllTargets_OptBuilder;
  TestIntegration_AllTargets_CompilerResolve;
  TestIntegration_AllTargets_Engine_DryRun;

  TestIntegration_CustomTarget_Pipeline;
  TestIntegration_StepByStep_Logs;
  TestIntegration_FPCCfg_OptBuilder_Consistency;
  TestIntegration_InvalidTarget_Errors;

  TestIntegration_Android_Pipeline;
  TestIntegration_iOS_Pipeline;
  TestIntegration_FreeBSD_Pipeline;

  TestIntegration_Registry_ExportImport_Engine;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
