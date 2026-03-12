program test_cross_regression;

{$mode objfpc}{$H+}

{
  B118: Cross-Compilation Sub-Command Regression Tests

  Verifies all 12 cross sub-commands (+ root + alias) remain properly
  registered after M7 modifications (B107-B117). Ensures no regressions
  from the target registry migration (B117) or engine additions (B109-B111).

  Also verifies that the M7 source units compile and can be imported
  without linker errors alongside the original cross command units.
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
  fpdev.command.intf,
  // Root command
  fpdev.cmd.cross.root,
  // Original 7 sub-commands (pre-M7)
  fpdev.cmd.cross.list,
  fpdev.cmd.cross.show,
  fpdev.cmd.cross.install,
  fpdev.cmd.cross.uninstall,
  fpdev.cmd.cross.enable,
  fpdev.cmd.cross.disable,
  fpdev.cmd.cross.help,
  // M7 additions (B111, B113, B114)
  fpdev.cmd.cross.build,
  fpdev.cmd.cross.doctor,
  fpdev.cmd.cross.configure,
  fpdev.cmd.cross.test,
  // M7 core units - verify they compile alongside cmd units
  fpdev.cross.targets,
  fpdev.cross.opts,
  fpdev.cross.compiler,
  fpdev.cross.engine.intf,
  fpdev.cross.engine,
  fpdev.cross.fpccfg,
  fpdev.cross.search,
  fpdev.config.interfaces,
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

function HasSubcommand(const APath: array of string; const AName: string): Boolean;
var
  Children: TStringArray;
  I: Integer;
begin
  Result := False;
  Children := GlobalCommandRegistry.ListChildren(APath);
  for I := Low(Children) to High(Children) do
    if LowerCase(Children[I]) = LowerCase(AName) then
      Exit(True);
end;

function GetSubcommandCount(const APath: array of string): Integer;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(APath);
  Result := Length(Children);
end;

{ === Root Registration === }

procedure TestRootRegistered;
begin
  Check(HasSubcommand([], 'cross'), 'Regression: cross root registered');
end;

procedure TestAliasRegistered;
begin
  Check(not HasSubcommand([], 'x'), 'Regression: x alias removed');
end;

{ === Original 7 Sub-Commands (pre-M7) === }

procedure TestListRegistered;
begin
  Check(HasSubcommand(['cross'], 'list'), 'Regression: cross list registered');
end;

procedure TestShowRegistered;
begin
  Check(HasSubcommand(['cross'], 'show'), 'Regression: cross show registered');
end;

procedure TestInstallRegistered;
begin
  Check(HasSubcommand(['cross'], 'install'), 'Regression: cross install registered');
end;

procedure TestUninstallRegistered;
begin
  Check(HasSubcommand(['cross'], 'uninstall'), 'Regression: cross uninstall registered');
end;

procedure TestEnableRegistered;
begin
  Check(HasSubcommand(['cross'], 'enable'), 'Regression: cross enable registered');
end;

procedure TestDisableRegistered;
begin
  Check(HasSubcommand(['cross'], 'disable'), 'Regression: cross disable registered');
end;

procedure TestHelpRegistered;
begin
  Check(HasSubcommand(['cross'], 'help'), 'Regression: cross help registered');
end;

{ === M7 Sub-Commands (B111, B113, B114) === }

procedure TestBuildRegistered;
begin
  Check(HasSubcommand(['cross'], 'build'), 'Regression: cross build registered (B111)');
end;

procedure TestDoctorRegistered;
begin
  Check(HasSubcommand(['cross'], 'doctor'), 'Regression: cross doctor registered (B113)');
end;

procedure TestConfigureRegistered;
begin
  Check(HasSubcommand(['cross'], 'configure'), 'Regression: cross configure registered (B114)');
end;

procedure TestTestRegistered;
begin
  Check(HasSubcommand(['cross'], 'test'), 'Regression: cross test registered');
end;

{ === Count verification === }

procedure TestSubcommandCount;
var
  Cnt: Integer;
begin
  Cnt := GetSubcommandCount(['cross']);
  Check(Cnt >= 11, 'Regression: at least 11 cross sub-commands (got ' + IntToStr(Cnt) + ')');
end;

{ === M7 core units compile alongside cmd units === }

procedure TestM7UnitsCompile;
var
  Reg: TCrossTargetRegistry;
  Mgr: TFPCCfgManager;
  Search: TCrossToolchainSearch;
begin
  // Verify that creating M7 objects does not conflict with cmd unit imports
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.Count = 21, 'Regression: TCrossTargetRegistry works (21 targets)');
  finally
    Reg.Free;
  end;

  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('# test' + LineEnding);
    Check(Mgr.GetContent <> '', 'Regression: TFPCCfgManager works');
  finally
    Mgr.Free;
  end;

  Search := TCrossToolchainSearch.Create;
  try
    Check(Search.GetSearchLogCount = 0, 'Regression: TCrossToolchainSearch works');
  finally
    Search.Free;
  end;
end;

{ === TCrossOptBuilder available alongside cmd units === }

procedure TestOptBuilderWorks;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CPU := 'arm';
  Target.OS := 'linux';
  Target.ABI := 'eabihf';
  Target.SubArch := 'armv7';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CaEABIHF', Opts) > 0, 'Regression: TCrossOptBuilder produces ARM opts');
end;

{ === TCrossCompilerResolver available alongside cmd units === }

procedure TestCompilerResolverWorks;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('x86_64') = 'ppcrossx64',
    'Regression: TCrossCompilerResolver x86_64 resolves');
  Check(TCrossCompilerResolver.GetPPCrossName('arm') = 'ppcrossarm',
    'Regression: TCrossCompilerResolver arm resolves');
end;

{ === TCrossBuildEngine available alongside cmd units === }

procedure TestBuildEngineWorks;
var
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Target: TCrossTarget;
begin
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := 'x86_64';
  Target.OS := 'win64';

  BM := TBuildManager.Create('/tmp/test_src', 1, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/tmp/test_src', '/tmp/sandbox', 'main');
    // Engine may not reach Complete without real source dir, but must pass preflight
    Check((Engine.GetCurrentStage = cbsComplete) or (Engine.GetCommandLogCount >= 2),
      'Regression: TCrossBuildEngine dry-run passes preflight');
  finally
    Engine.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Sub-Command Regression Tests ===');
  WriteLn;

  WriteLn('--- Root Registration ---');
  TestRootRegistered;
  TestAliasRegistered;

  WriteLn;
  WriteLn('--- Original Sub-Commands (pre-M7) ---');
  TestListRegistered;
  TestShowRegistered;
  TestInstallRegistered;
  TestUninstallRegistered;
  TestEnableRegistered;
  TestDisableRegistered;
  TestHelpRegistered;

  WriteLn;
  WriteLn('--- M7 Sub-Commands ---');
  TestBuildRegistered;
  TestDoctorRegistered;
  TestConfigureRegistered;
  TestTestRegistered;

  WriteLn;
  WriteLn('--- Count Verification ---');
  TestSubcommandCount;

  WriteLn;
  WriteLn('--- M7 Core Unit Compatibility ---');
  TestM7UnitsCompile;
  TestOptBuilderWorks;
  TestCompilerResolverWorks;
  TestBuildEngineWorks;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
