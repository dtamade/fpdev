program test_cross_opts;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.cross.opts;

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

{ GetABIOption tests }

procedure TestABIOption_ArmEabihf;
begin
  Check(TCrossOptBuilder.GetABIOption('arm', 'eabihf') = '-CaEABIHF',
    'ABI: arm+eabihf => -CaEABIHF');
end;

procedure TestABIOption_ArmEabi;
begin
  Check(TCrossOptBuilder.GetABIOption('arm', 'eabi') = '-CaEABI',
    'ABI: arm+eabi => -CaEABI');
end;

procedure TestABIOption_ArmDefault;
begin
  Check(TCrossOptBuilder.GetABIOption('arm', '') = '-CaEABI',
    'ABI: arm+empty => -CaEABI (default)');
end;

procedure TestABIOption_Aarch64;
begin
  Check(TCrossOptBuilder.GetABIOption('aarch64', '') = '',
    'ABI: aarch64 => empty (no ABI needed)');
end;

procedure TestABIOption_MipselO32;
begin
  Check(TCrossOptBuilder.GetABIOption('mipsel', 'o32') = '-CaO32',
    'ABI: mipsel+o32 => -CaO32');
end;

procedure TestABIOption_X86_64;
begin
  Check(TCrossOptBuilder.GetABIOption('x86_64', '') = '',
    'ABI: x86_64 => empty');
end;

{ GetFPUOption tests }

procedure TestFPUOption_ArmEabihf;
begin
  Check(TCrossOptBuilder.GetFPUOption('arm', 'eabihf') = '-CfVFPV3',
    'FPU: arm+eabihf => -CfVFPV3');
end;

procedure TestFPUOption_ArmSoft;
begin
  Check(TCrossOptBuilder.GetFPUOption('arm', 'eabi') = '-CfSOFT',
    'FPU: arm+eabi => -CfSOFT');
end;

procedure TestFPUOption_Mipsel;
begin
  Check(TCrossOptBuilder.GetFPUOption('mipsel', '') = '-CfSOFT',
    'FPU: mipsel => -CfSOFT');
end;

procedure TestFPUOption_Mips;
begin
  Check(TCrossOptBuilder.GetFPUOption('mips', '') = '-CfSOFT',
    'FPU: mips => -CfSOFT');
end;

procedure TestFPUOption_X86_64;
begin
  Check(TCrossOptBuilder.GetFPUOption('x86_64', '') = '',
    'FPU: x86_64 => empty');
end;

procedure TestFPUOption_Aarch64;
begin
  Check(TCrossOptBuilder.GetFPUOption('aarch64', '') = '',
    'FPU: aarch64 => empty');
end;

{ GetSubArchOption tests }

procedure TestSubArch_Armv7;
begin
  Check(TCrossOptBuilder.GetSubArchOption('arm', 'armv7') = '-CpARMV7A',
    'SubArch: arm+armv7 => -CpARMV7A');
end;

procedure TestSubArch_Armv7a;
begin
  Check(TCrossOptBuilder.GetSubArchOption('arm', 'armv7a') = '-CpARMV7A',
    'SubArch: arm+armv7a => -CpARMV7A');
end;

procedure TestSubArch_Armv6;
begin
  Check(TCrossOptBuilder.GetSubArchOption('arm', 'armv6') = '-CpARMV6',
    'SubArch: arm+armv6 => -CpARMV6');
end;

procedure TestSubArch_Armv5;
begin
  Check(TCrossOptBuilder.GetSubArchOption('arm', 'armv5') = '-CpARMV5TE',
    'SubArch: arm+armv5 => -CpARMV5TE');
end;

procedure TestSubArch_Armv8;
begin
  Check(TCrossOptBuilder.GetSubArchOption('arm', 'armv8') = '-CpARMV7A',
    'SubArch: arm+armv8 => -CpARMV7A (32-bit v7a profile)');
end;

procedure TestSubArch_NonArm;
begin
  Check(TCrossOptBuilder.GetSubArchOption('x86_64', 'armv7') = '',
    'SubArch: non-arm CPU => empty');
end;

procedure TestSubArch_EmptySubArch;
begin
  Check(TCrossOptBuilder.GetSubArchOption('arm', '') = '',
    'SubArch: arm+empty => empty');
end;

{ GetLibraryOption tests }

procedure TestLibraryOption_WithPath;
begin
  Check(TCrossOptBuilder.GetLibraryOption('/usr/arm-linux-gnueabihf/lib') = '-Fl/usr/arm-linux-gnueabihf/lib',
    'Library: path => -Fl<path>');
end;

procedure TestLibraryOption_Empty;
begin
  Check(TCrossOptBuilder.GetLibraryOption('') = '',
    'Library: empty => empty');
end;

{ Build (integration) tests }

procedure TestBuild_ArmEabihf;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CPU := 'arm';
  Target.OS := 'linux';
  Target.ABI := 'eabihf';
  Target.SubArch := 'armv7';
  Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CaEABIHF', Opts) > 0, 'Build ARM eabihf: contains -CaEABIHF');
  Check(Pos('-CfVFPV3', Opts) > 0, 'Build ARM eabihf: contains -CfVFPV3');
  Check(Pos('-CpARMV7A', Opts) > 0, 'Build ARM eabihf: contains -CpARMV7A');
  Check(Pos('-Fl/usr/arm-linux-gnueabihf/lib', Opts) > 0, 'Build ARM eabihf: contains -Fl<path>');
end;

procedure TestBuild_Win64;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CPU := 'x86_64';
  Target.OS := 'win64';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '', 'Build Win64: empty options (no special opts needed)');
end;

procedure TestBuild_MipsSoft;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CPU := 'mipsel';
  Target.OS := 'linux';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CfSOFT', Opts) > 0, 'Build MIPS: contains -CfSOFT');
end;

procedure TestBuild_ExplicitCrossOpt;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CPU := 'arm';
  Target.OS := 'linux';
  Target.CrossOpt := '-CaEABIHF -CfVFPV3 -CpARMV7A';
  Target.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Pos('-CaEABIHF -CfVFPV3 -CpARMV7A', Opts) > 0,
    'Build explicit CrossOpt: uses explicit value');
  Check(Pos('-Fl/usr/arm-linux-gnueabihf/lib', Opts) > 0,
    'Build explicit CrossOpt: appends library path');
end;

procedure TestBuild_ExplicitCrossOptWithFl;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CrossOpt := '-CaEABIHF -Fl/custom/lib';
  Target.LibrariesPath := '/usr/lib';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '-CaEABIHF -Fl/custom/lib',
    'Build explicit CrossOpt with -Fl: does not duplicate -Fl');
end;

procedure TestBuild_Aarch64_NoSpecialOpts;
var
  Target: TCrossTarget;
  Opts: string;
begin
  Target := Default(TCrossTarget);
  Target.CPU := 'aarch64';
  Target.OS := 'linux';
  Opts := TCrossOptBuilder.Build(Target);
  Check(Opts = '', 'Build aarch64: empty (no special opts needed)');
end;

begin
  WriteLn('=== Cross-Compilation CROSSOPT Builder Tests ===');
  WriteLn;

  // ABI option tests
  TestABIOption_ArmEabihf;
  TestABIOption_ArmEabi;
  TestABIOption_ArmDefault;
  TestABIOption_Aarch64;
  TestABIOption_MipselO32;
  TestABIOption_X86_64;

  // FPU option tests
  TestFPUOption_ArmEabihf;
  TestFPUOption_ArmSoft;
  TestFPUOption_Mipsel;
  TestFPUOption_Mips;
  TestFPUOption_X86_64;
  TestFPUOption_Aarch64;

  // SubArch option tests
  TestSubArch_Armv7;
  TestSubArch_Armv7a;
  TestSubArch_Armv6;
  TestSubArch_Armv5;
  TestSubArch_Armv8;
  TestSubArch_NonArm;
  TestSubArch_EmptySubArch;

  // Library option tests
  TestLibraryOption_WithPath;
  TestLibraryOption_Empty;

  // Build integration tests
  TestBuild_ArmEabihf;
  TestBuild_Win64;
  TestBuild_MipsSoft;
  TestBuild_ExplicitCrossOpt;
  TestBuild_ExplicitCrossOptWithFl;
  TestBuild_Aarch64_NoSpecialOpts;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
