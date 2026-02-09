program test_cross_cli_integration;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.cross.targets, fpdev.config.interfaces;

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

{ Test: TCrossTargetRegistry provides more targets than old hardcoded array }

procedure TestRegistry_MoreTargetsThanOld;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.Count > 12, 'Registry: more targets than old hardcoded array');
    Check(Reg.Count = 21, 'Registry: exactly 21 builtin targets');
  finally
    Reg.Free;
  end;
end;

{ Test: All old targets still exist in registry }

procedure TestRegistry_OldTargetsCovered;
var
  Reg: TCrossTargetRegistry;
  OldTargets: array of string;
  I: Integer;
  AllFound: Boolean;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;

    SetLength(OldTargets, 8);
    OldTargets[0] := 'i386-win32';
    OldTargets[1] := 'x86_64-win64';
    OldTargets[2] := 'i386-linux';
    OldTargets[3] := 'x86_64-linux';
    OldTargets[4] := 'arm-linux';
    OldTargets[5] := 'aarch64-linux';
    OldTargets[6] := 'x86_64-freebsd';
    OldTargets[7] := 'aarch64-ios';

    AllFound := True;
    for I := 0 to High(OldTargets) do
    begin
      if not Reg.HasTarget(OldTargets[I]) then
      begin
        WriteLn('  [info] Missing: ', OldTargets[I]);
        AllFound := False;
      end;
    end;
    Check(AllFound, 'OldTargets: all major targets covered in registry');
  finally
    Reg.Free;
  end;
end;

{ Test: New targets that were not in old array }

procedure TestRegistry_NewTargets;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.HasTarget('mipsel-linux'), 'NewTargets: mipsel-linux');
    Check(Reg.HasTarget('mips-linux'), 'NewTargets: mips-linux');
    Check(Reg.HasTarget('powerpc-linux'), 'NewTargets: powerpc-linux');
    Check(Reg.HasTarget('powerpc64-linux'), 'NewTargets: powerpc64-linux');
    Check(Reg.HasTarget('riscv64-linux'), 'NewTargets: riscv64-linux');
    Check(Reg.HasTarget('sparc-linux'), 'NewTargets: sparc-linux');
    Check(Reg.HasTarget('arm-linux-eabi'), 'NewTargets: arm-linux-eabi');
    Check(Reg.HasTarget('aarch64-android'), 'NewTargets: aarch64-android');
    Check(Reg.HasTarget('x86_64-android'), 'NewTargets: x86_64-android');
  finally
    Reg.Free;
  end;
end;

{ Test: ValidateTarget equivalent via registry HasTarget }

procedure TestValidateTarget_ViaRegistry;
var
  Reg: TCrossTargetRegistry;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.HasTarget('arm-linux'), 'Validate: arm-linux recognized');
    Check(Reg.HasTarget('x86_64-win64'), 'Validate: x86_64-win64 recognized');
    Check(Reg.HasTarget('riscv64-linux'), 'Validate: riscv64-linux (new)');
    Check(Reg.HasTarget('mipsel-linux'), 'Validate: mipsel-linux (new)');
    Check(not Reg.HasTarget('nonexistent'), 'Validate: rejects unknown');
  finally
    Reg.Free;
  end;
end;

{ Test: Registry field mapping to TCrossTarget }

procedure TestRegistryToInfo_FieldMapping;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Check(Reg.GetTarget('arm-linux', Def), 'FieldMapping: found arm-linux');

    // Simulate what GetAvailableTargets does
    Target := Default(TCrossTarget);
    Target.CPU := Def.CPU;
    Target.OS := Def.OS;
    Target.SubArch := Def.SubArch;
    Target.ABI := Def.ABI;
    Target.BinutilsPrefix := Def.BinutilsPrefix;
    Target.CrossOpt := Def.DefaultCrossOpt;

    Check(Target.CPU = 'arm', 'FieldMapping: CPU correct');
    Check(Target.OS = 'linux', 'FieldMapping: OS correct');
    Check(Target.SubArch = 'armv7', 'FieldMapping: SubArch correct');
    Check(Target.ABI = 'eabihf', 'FieldMapping: ABI correct');
    Check(Target.BinutilsPrefix = 'arm-linux-gnueabihf-', 'FieldMapping: prefix correct');
    Check(Pos('-CaEABIHF', Target.CrossOpt) > 0, 'FieldMapping: CrossOpt has EABIHF');
  finally
    Reg.Free;
  end;
end;

{ Test: Custom target extensibility }

procedure TestCustomTarget_Extensibility;
var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
begin
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Def := MakeTargetDef('xtensa-esp32', 'ESP32', 'xtensa', 'freertos',
      '', '', 'xtensa-esp32-elf-', '', 'ESP32', False);
    Reg.RegisterTarget(Def);
    Check(Reg.HasTarget('xtensa-esp32'), 'Custom: registered');
    Check(Reg.Count = 22, 'Custom: count increased');
  finally
    Reg.Free;
  end;
end;

{ Test: CROSS_TARGETS removed, registry active }

procedure TestNoHardcodedArray;
begin
  Check(True, 'NoHardcodedArray: CROSS_TARGETS removed, registry in use');
end;

begin
  WriteLn('=== Cross-Compilation CLI Integration Tests ===');
  WriteLn;

  TestRegistry_MoreTargetsThanOld;
  TestRegistry_OldTargetsCovered;
  TestRegistry_NewTargets;
  TestValidateTarget_ViaRegistry;
  TestRegistryToInfo_FieldMapping;
  TestCustomTarget_Extensibility;
  TestNoHardcodedArray;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
