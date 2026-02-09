program test_cross_compiler_resolve;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.cross.compiler;

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

{ GetCPUSuffix tests }

procedure TestCPUSuffix_X86_64;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('x86_64') = 'x64',
    'CPUSuffix: x86_64 => x64');
end;

procedure TestCPUSuffix_I386;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('i386') = '386',
    'CPUSuffix: i386 => 386');
end;

procedure TestCPUSuffix_Arm;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('arm') = 'arm',
    'CPUSuffix: arm => arm');
end;

procedure TestCPUSuffix_Aarch64;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('aarch64') = 'a64',
    'CPUSuffix: aarch64 => a64');
end;

procedure TestCPUSuffix_Mipsel;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('mipsel') = 'mipsel',
    'CPUSuffix: mipsel => mipsel');
end;

procedure TestCPUSuffix_Mips;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('mips') = 'mips',
    'CPUSuffix: mips => mips');
end;

procedure TestCPUSuffix_PowerPC;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('powerpc') = 'ppc',
    'CPUSuffix: powerpc => ppc');
end;

procedure TestCPUSuffix_PowerPC64;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('powerpc64') = 'ppc64',
    'CPUSuffix: powerpc64 => ppc64');
end;

procedure TestCPUSuffix_Sparc;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('sparc') = 'sparc',
    'CPUSuffix: sparc => sparc');
end;

procedure TestCPUSuffix_RiscV32;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('riscv32') = 'rv32',
    'CPUSuffix: riscv32 => rv32');
end;

procedure TestCPUSuffix_RiscV64;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('riscv64') = 'rv64',
    'CPUSuffix: riscv64 => rv64');
end;

procedure TestCPUSuffix_Unknown;
begin
  Check(TCrossCompilerResolver.GetCPUSuffix('z80') = '',
    'CPUSuffix: unknown CPU => empty');
end;

{ GetPPCrossName tests }

procedure TestPPCrossName_X86_64;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('x86_64') = 'ppcrossx64',
    'PPCross: x86_64 => ppcrossx64');
end;

procedure TestPPCrossName_Arm;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('arm') = 'ppcrossarm',
    'PPCross: arm => ppcrossarm');
end;

procedure TestPPCrossName_Aarch64;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('aarch64') = 'ppcrossa64',
    'PPCross: aarch64 => ppcrossa64');
end;

procedure TestPPCrossName_I386;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('i386') = 'ppcross386',
    'PPCross: i386 => ppcross386');
end;

procedure TestPPCrossName_Unknown;
begin
  Check(TCrossCompilerResolver.GetPPCrossName('unknown') = '',
    'PPCross: unknown => empty');
end;

{ FindCrossCompiler tests (filesystem-dependent, test no-match case) }

procedure TestFindCrossCompiler_NotFound;
begin
  Check(TCrossCompilerResolver.FindCrossCompiler('arm', '/nonexistent/path') = '',
    'FindCrossCompiler: returns empty for nonexistent path');
end;

procedure TestFindCrossCompiler_UnknownCPU;
begin
  Check(TCrossCompilerResolver.FindCrossCompiler('z80', '/usr') = '',
    'FindCrossCompiler: returns empty for unknown CPU');
end;

{ ValidateCompiler tests }

procedure TestValidateCompiler_EmptyPath;
begin
  Check(TCrossCompilerResolver.ValidateCompiler('') = False,
    'ValidateCompiler: empty path => False');
end;

procedure TestValidateCompiler_NonexistentPath;
begin
  Check(TCrossCompilerResolver.ValidateCompiler('/nonexistent/ppcrossarm') = False,
    'ValidateCompiler: nonexistent file => False');
end;

procedure TestValidateCompiler_ExistingFile;
var
  TmpFile: string;
  F: TextFile;
begin
  TmpFile := GetTempDir + 'test_ppcross_validate.tmp';
  AssignFile(F, TmpFile);
  try
    Rewrite(F);
    WriteLn(F, 'dummy');
    CloseFile(F);
    Check(TCrossCompilerResolver.ValidateCompiler(TmpFile) = True,
      'ValidateCompiler: existing file => True');
  finally
    if FileExists(TmpFile) then
      DeleteFile(TmpFile);
  end;
end;

begin
  WriteLn('=== Cross-Compiler Resolver Tests ===');
  WriteLn;

  // CPU suffix mapping tests
  TestCPUSuffix_X86_64;
  TestCPUSuffix_I386;
  TestCPUSuffix_Arm;
  TestCPUSuffix_Aarch64;
  TestCPUSuffix_Mipsel;
  TestCPUSuffix_Mips;
  TestCPUSuffix_PowerPC;
  TestCPUSuffix_PowerPC64;
  TestCPUSuffix_Sparc;
  TestCPUSuffix_RiscV32;
  TestCPUSuffix_RiscV64;
  TestCPUSuffix_Unknown;

  // PPCross binary name tests
  TestPPCrossName_X86_64;
  TestPPCrossName_Arm;
  TestPPCrossName_Aarch64;
  TestPPCrossName_I386;
  TestPPCrossName_Unknown;

  // FindCrossCompiler tests
  TestFindCrossCompiler_NotFound;
  TestFindCrossCompiler_UnknownCPU;

  // ValidateCompiler tests
  TestValidateCompiler_EmptyPath;
  TestValidateCompiler_NonexistentPath;
  TestValidateCompiler_ExistingFile;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
