program test_cross_targets;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, jsonparser,
  fpdev.cross.targets, test_temp_paths;

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

{ === Tests: Constructor and basics === }

procedure TestCreate_EmptyByDefault;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Check(Reg.Count = 0, 'Create: empty by default');
  finally
    Reg.Free;
  end;
end;

procedure TestLoadBuiltinTargets_NonEmpty;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.Count = 21, 'LoadBuiltin: 21 targets loaded');
  finally
    Reg.Free;
  end;
end;

procedure TestLoadBuiltinTargets_Idempotent;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Reg.LoadBuiltinTargets;
    Check(Reg.Count = 21, 'LoadBuiltin: idempotent (still 21)');
  finally
    Reg.Free;
  end;
end;

{ === Tests: GetTarget === }

procedure TestGetTarget_Win64;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('x86_64-win64', Def), 'GetTarget: x86_64-win64 found');
    Check(Def.CPU = 'x86_64', 'GetTarget Win64: CPU correct');
    Check(Def.OS = 'win64', 'GetTarget Win64: OS correct');
    Check(Def.BinutilsPrefix = 'x86_64-w64-mingw32-', 'GetTarget Win64: prefix correct');
    Check(Def.Builtin = True, 'GetTarget Win64: is builtin');
  finally
    Reg.Free;
  end;
end;

procedure TestGetTarget_ARM_Linux;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('arm-linux', Def), 'GetTarget: arm-linux found');
    Check(Def.CPU = 'arm', 'GetTarget ARM: CPU correct');
    Check(Def.OS = 'linux', 'GetTarget ARM: OS correct');
    Check(Def.SubArch = 'armv7', 'GetTarget ARM: SubArch correct');
    Check(Def.ABI = 'eabihf', 'GetTarget ARM: ABI correct');
    Check(Pos('-CaEABIHF', Def.DefaultCrossOpt) > 0, 'GetTarget ARM: CROSSOPT has EABIHF');
  finally
    Reg.Free;
  end;
end;

procedure TestGetTarget_NotFound;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(not Reg.GetTarget('zzz-fake', Def), 'GetTarget: non-existent returns False');
  finally
    Reg.Free;
  end;
end;

procedure TestGetTarget_CaseInsensitive;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('X86_64-Win64', Def), 'GetTarget: case-insensitive lookup');
    Check(Def.CPU = 'x86_64', 'GetTarget case: CPU still correct');
  finally
    Reg.Free;
  end;
end;

{ === Tests: HasTarget === }

procedure TestHasTarget;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.HasTarget('aarch64-linux'), 'HasTarget: aarch64-linux exists');
    Check(Reg.HasTarget('mipsel-linux'), 'HasTarget: mipsel-linux exists');
    Check(not Reg.HasTarget('nonexistent'), 'HasTarget: nonexistent returns False');
  finally
    Reg.Free;
  end;
end;

{ === Tests: ListTargets === }

procedure TestListTargets;
var
  Reg: TCrossTargetRegistry;
  Names: TStringArray;
  I: Integer;
  HasWin64, HasARM: Boolean;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Names := Reg.ListTargets;
    Check(Length(Names) = 21, 'ListTargets: 21 names');

    HasWin64 := False;
    HasARM := False;
    for I := 0 to High(Names) do
    begin
      if Names[I] = 'x86_64-win64' then HasWin64 := True;
      if Names[I] = 'arm-linux' then HasARM := True;
    end;
    Check(HasWin64, 'ListTargets: contains x86_64-win64');
    Check(HasARM, 'ListTargets: contains arm-linux');
  finally
    Reg.Free;
  end;
end;

{ === Tests: RegisterTarget (custom) === }

procedure TestRegisterCustomTarget;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Def := MakeTargetDef('xtensa-esp32', 'ESP32 (Xtensa)', 'xtensa', 'freertos',
      '', '', 'xtensa-esp32-elf-', '', 'ESP32 microcontroller', False);
    Reg.RegisterTarget(Def);
    Check(Reg.Count = 22, 'RegisterCustom: count is 22');
    Check(Reg.HasTarget('xtensa-esp32'), 'RegisterCustom: custom target found');
    Check(Reg.GetTarget('xtensa-esp32', Def), 'RegisterCustom: GetTarget works');
    Check(Def.CPU = 'xtensa', 'RegisterCustom: CPU correct');
    Check(Def.Builtin = False, 'RegisterCustom: not builtin');
  finally
    Reg.Free;
  end;
end;

procedure TestRegisterOverwrite;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Def := MakeTargetDef('arm-linux', 'My Custom ARM', 'arm', 'linux',
      'armv8', 'eabihf', 'my-arm-', '-CpARMV8A', 'Custom override', False);
    Reg.RegisterTarget(Def);
    Check(Reg.Count = 21, 'RegisterOverwrite: count unchanged');
    Reg.GetTarget('arm-linux', Def);
    Check(Def.DisplayName = 'My Custom ARM', 'RegisterOverwrite: overwritten');
    Check(Def.Builtin = False, 'RegisterOverwrite: now custom');
  finally
    Reg.Free;
  end;
end;

{ === Tests: RemoveTarget === }

procedure TestRemoveTarget;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.RemoveTarget('sparc-linux'), 'RemoveTarget: returns True');
    Check(Reg.Count = 20, 'RemoveTarget: count decreased');
    Check(not Reg.HasTarget('sparc-linux'), 'RemoveTarget: target gone');
  finally
    Reg.Free;
  end;
end;

procedure TestRemoveTarget_NotFound;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(not Reg.RemoveTarget('nonexistent'), 'RemoveNotFound: returns False');
    Check(Reg.Count = 21, 'RemoveNotFound: count unchanged');
  finally
    Reg.Free;
  end;
end;

{ === Tests: FindByCPU / FindByOS === }

procedure TestFindByCPU;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.FindByCPU('arm');
    Check(Length(Defs) >= 2, 'FindByCPU arm: at least 2 targets');
    Defs := Reg.FindByCPU('aarch64');
    Check(Length(Defs) >= 3, 'FindByCPU aarch64: at least 3 targets');
    Defs := Reg.FindByCPU('zzz');
    Check(Length(Defs) = 0, 'FindByCPU zzz: empty result');
  finally
    Reg.Free;
  end;
end;

procedure TestFindByOS;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.FindByOS('linux');
    Check(Length(Defs) >= 8, 'FindByOS linux: at least 8 targets');
    Defs := Reg.FindByOS('android');
    Check(Length(Defs) = 3, 'FindByOS android: 3 targets');
    Defs := Reg.FindByOS('win64');
    Check(Length(Defs) = 1, 'FindByOS win64: 1 target');
  finally
    Reg.Free;
  end;
end;

{ === Tests: JSON round-trip === }

procedure TestExportToJSON;
var
  Reg: TCrossTargetRegistry;
  JSON: string;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    JSON := Reg.ExportToJSON;
    Check(Length(JSON) > 100, 'ExportToJSON: non-trivial output');
    Check(Pos('"arm-linux"', JSON) > 0, 'ExportToJSON: contains arm-linux');
    Check(Pos('"cpu"', JSON) > 0, 'ExportToJSON: contains cpu field');
  finally
    Reg.Free;
  end;
end;

procedure TestLoadFromJSON;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  JSON: string;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    JSON := '[{"name":"custom-test","displayName":"Test Target",' +
      '"cpu":"testcpu","os":"testos","binutilsPrefix":"test-"}]';
    Reg.LoadFromJSON(JSON);
    Check(Reg.Count = 1, 'LoadFromJSON: 1 target loaded');
    Check(Reg.GetTarget('custom-test', Def), 'LoadFromJSON: target found');
    Check(Def.CPU = 'testcpu', 'LoadFromJSON: CPU correct');
    Check(Def.Builtin = False, 'LoadFromJSON: not builtin');
  finally
    Reg.Free;
  end;
end;

procedure TestLoadFromJSON_Empty;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadFromJSON('');
    Check(Reg.Count = 0, 'LoadFromJSON empty: no crash');
    Reg.LoadFromJSON('[]');
    Check(Reg.Count = 0, 'LoadFromJSON []: no targets');
  finally
    Reg.Free;
  end;
end;

procedure TestLoadFromJSON_InvalidSkipped;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    // Entry without 'name' should be skipped
    Reg.LoadFromJSON('[{"cpu":"arm"},{"name":"valid","cpu":"arm","os":"linux"}]');
    Check(Reg.Count = 1, 'LoadFromJSON invalid: skipped entry without name');
  finally
    Reg.Free;
  end;
end;

procedure TestJSONRoundTrip;
var
  Reg1, Reg2: TCrossTargetRegistry;
  JSON: string;
  Def1, Def2: TCrossTargetDef;
begin
  Reg1 := TCrossTargetRegistry.Create;
  Reg2 := TCrossTargetRegistry.Create;
  try
    Reg1.LoadBuiltinTargets;
    JSON := Reg1.ExportToJSON;
    Reg2.LoadFromJSON(JSON);
    Check(Reg2.Count = Reg1.Count, 'RoundTrip: same count');
    Reg1.GetTarget('arm-linux', Def1);
    Check(Reg2.GetTarget('arm-linux', Def2), 'RoundTrip: arm-linux exists');
    Check(Def2.CPU = Def1.CPU, 'RoundTrip: CPU preserved');
    Check(Def2.ABI = Def1.ABI, 'RoundTrip: ABI preserved');
    Check(Def2.DefaultCrossOpt = Def1.DefaultCrossOpt, 'RoundTrip: CrossOpt preserved');
  finally
    Reg1.Free;
    Reg2.Free;
  end;
end;

{ === Tests: LoadFromFile === }

procedure TestLoadFromFile;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  TempDir, TmpFile: string;
  SL: TStringList;
begin
  TempDir := CreateUniqueTempDir('fpdev_test_targets');
  Reg := TCrossTargetRegistry.Create;
  try
    TmpFile := TempDir + PathDelim + 'targets.json';
    SL := TStringList.Create;
    try
      SL.Add('[{"name":"file-target","displayName":"From File",' +
        '"cpu":"avr","os":"embedded","binutilsPrefix":"avr-"}]');
      SL.SaveToFile(TmpFile);
    finally
      SL.Free;
    end;

    Reg.LoadFromFile(TmpFile);
    Check(Reg.Count = 1, 'LoadFromFile: 1 target');
    Check(Reg.GetTarget('file-target', Def), 'LoadFromFile: target found');
    Check(Def.CPU = 'avr', 'LoadFromFile: CPU correct');

  finally
    Reg.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestLoadFromFile_NotExists;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadFromFile('/nonexistent/path/targets.json');
    Check(Reg.Count = 0, 'LoadFromFile nonexistent: no crash');
  finally
    Reg.Free;
  end;
end;

{ === Tests: MakeTargetDef helper === }

procedure TestMakeTargetDef;
var
  Def: TCrossTargetDef;
begin
  Def := MakeTargetDef('test', 'Test', 'arm', 'linux', 'armv7', 'eabihf',
    'arm-', '-Ca', 'desc', False);
  Check(Def.Name = 'test', 'MakeTargetDef: Name');
  Check(Def.CPU = 'arm', 'MakeTargetDef: CPU');
  Check(Def.SubArch = 'armv7', 'MakeTargetDef: SubArch');
  Check(Def.Builtin = False, 'MakeTargetDef: Builtin');
end;

{ === Tests: Specific builtin targets have correct definitions === }

procedure TestBuiltin_AArch64_Darwin;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('aarch64-darwin', Def), 'Builtin: aarch64-darwin exists');
    Check(Def.CPU = 'aarch64', 'Builtin aarch64-darwin: CPU');
    Check(Def.OS = 'darwin', 'Builtin aarch64-darwin: OS');
    Check(Pos('apple', Def.BinutilsPrefix) > 0, 'Builtin aarch64-darwin: prefix has apple');
  finally
    Reg.Free;
  end;
end;

procedure TestBuiltin_RISCV64;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('riscv64-linux', Def), 'Builtin: riscv64-linux exists');
    Check(Def.CPU = 'riscv64', 'Builtin riscv64: CPU');
    Check(Pos('riscv64', Def.BinutilsPrefix) > 0, 'Builtin riscv64: prefix');
  finally
    Reg.Free;
  end;
end;

procedure TestBuiltin_Android_Targets;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
  I: Integer;
  HasARM, HasAArch64, HasX64: Boolean;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.FindByOS('android');
    HasARM := False;
    HasAArch64 := False;
    HasX64 := False;
    for I := 0 to High(Defs) do
    begin
      if Defs[I].CPU = 'arm' then HasARM := True;
      if Defs[I].CPU = 'aarch64' then HasAArch64 := True;
      if Defs[I].CPU = 'x86_64' then HasX64 := True;
    end;
    Check(HasARM, 'Android targets: has ARM');
    Check(HasAArch64, 'Android targets: has AArch64');
    Check(HasX64, 'Android targets: has x86_64');
  finally
    Reg.Free;
  end;
end;

procedure TestBuiltin_AllHaveCPUAndOS;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
  I: Integer;
  AllOK: Boolean;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.ListTargetDefs;
    AllOK := True;
    for I := 0 to High(Defs) do
    begin
      if (Defs[I].CPU = '') or (Defs[I].OS = '') then
      begin
        WriteLn('  [info] Missing CPU/OS for: ', Defs[I].Name);
        AllOK := False;
      end;
    end;
    Check(AllOK, 'AllBuiltins: every target has CPU and OS');
  finally
    Reg.Free;
  end;
end;

procedure TestBuiltin_AllHaveBinutilsPrefix;
var
  Reg: TCrossTargetRegistry;
  Defs: TCrossTargetDefArray;
  I: Integer;
  AllOK: Boolean;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Defs := Reg.ListTargetDefs;
    AllOK := True;
    for I := 0 to High(Defs) do
    begin
      if Defs[I].BinutilsPrefix = '' then
      begin
        WriteLn('  [info] Missing BinutilsPrefix for: ', Defs[I].Name);
        AllOK := False;
      end;
    end;
    Check(AllOK, 'AllBuiltins: every target has BinutilsPrefix');
  finally
    Reg.Free;
  end;
end;

{ === Tests: Custom + Builtin merge === }

procedure TestCustomPlusBuiltin;
var
  Reg: TCrossTargetRegistry;
  JSON: string;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    JSON := '[{"name":"my-custom","cpu":"custom","os":"custom"}]';
    Reg.LoadFromJSON(JSON);
    Check(Reg.Count = 22, 'CustomPlusBuiltin: 22 targets');
    Check(Reg.HasTarget('arm-linux'), 'CustomPlusBuiltin: builtin still there');
    Check(Reg.HasTarget('my-custom'), 'CustomPlusBuiltin: custom added');
  finally
    Reg.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Target Registry Tests ===');
  WriteLn;

  // Constructor and basics
  TestCreate_EmptyByDefault;
  TestLoadBuiltinTargets_NonEmpty;
  TestLoadBuiltinTargets_Idempotent;

  // GetTarget
  TestGetTarget_Win64;
  TestGetTarget_ARM_Linux;
  TestGetTarget_NotFound;
  TestGetTarget_CaseInsensitive;

  // HasTarget
  TestHasTarget;

  // ListTargets
  TestListTargets;

  // RegisterTarget
  TestRegisterCustomTarget;
  TestRegisterOverwrite;

  // RemoveTarget
  TestRemoveTarget;
  TestRemoveTarget_NotFound;

  // FindByCPU / FindByOS
  TestFindByCPU;
  TestFindByOS;

  // JSON
  TestExportToJSON;
  TestLoadFromJSON;
  TestLoadFromJSON_Empty;
  TestLoadFromJSON_InvalidSkipped;
  TestJSONRoundTrip;

  // File
  TestLoadFromFile;
  TestLoadFromFile_NotExists;

  // MakeTargetDef
  TestMakeTargetDef;

  // Builtin target validation
  TestBuiltin_AArch64_Darwin;
  TestBuiltin_RISCV64;
  TestBuiltin_Android_Targets;
  TestBuiltin_AllHaveCPUAndOS;
  TestBuiltin_AllHaveBinutilsPrefix;

  // Custom + Builtin
  TestCustomPlusBuiltin;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
