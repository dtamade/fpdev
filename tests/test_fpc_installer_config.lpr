program test_fpc_installer_config;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.installer.config;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestName: string;

procedure StartTest(const AName: string);
begin
  TestName := AName;
  Write('  ', AName, '... ');
end;

procedure Pass;
begin
  WriteLn('PASSED');
  Inc(PassCount);
end;

procedure Fail(const AReason: string);
begin
  WriteLn('FAILED: ', AReason);
  Inc(FailCount);
end;

procedure TestGetFPCArchSuffix;
var
  Suffix: string;
begin
  StartTest('GetFPCArchSuffix returns non-empty string');
  Suffix := GetFPCArchSuffix;
  if Suffix <> '' then Pass
  else Fail('Expected non-empty suffix');

  StartTest('GetFPCArchSuffix contains hyphen separator');
  if Pos('-', Suffix) > 0 then Pass
  else Fail('Expected hyphen in suffix');

  StartTest('GetFPCArchSuffix contains platform name');
  // Should contain linux, win32, win64, darwin, or freebsd
  if (Pos('linux', Suffix) > 0) or (Pos('win', Suffix) > 0) or
     (Pos('darwin', Suffix) > 0) or (Pos('freebsd', Suffix) > 0) then Pass
  else Fail('Expected platform name in suffix');

  StartTest('GetFPCArchSuffix contains architecture');
  // Should contain x86_64, i386, or aarch64
  if (Pos('x86_64', Suffix) > 0) or (Pos('i386', Suffix) > 0) or
     (Pos('aarch64', Suffix) > 0) then Pass
  else Fail('Expected architecture in suffix');
end;

procedure TestGetNativeCompilerName;
var
  CompilerName: string;
begin
  StartTest('GetNativeCompilerName returns non-empty string');
  CompilerName := GetNativeCompilerName;
  if CompilerName <> '' then Pass
  else Fail('Expected non-empty compiler name');

  StartTest('GetNativeCompilerName starts with ppc');
  if Pos('ppc', CompilerName) = 1 then Pass
  else Fail('Expected name to start with ppc');

  StartTest('GetNativeCompilerName is valid compiler');
  // Should be ppcx64, ppc386, or ppca64
  if (CompilerName = 'ppcx64') or (CompilerName = 'ppc386') or
     (CompilerName = 'ppca64') then Pass
  else Fail('Expected ppcx64, ppc386, or ppca64, got ' + CompilerName);
end;

procedure TestTFPCConfigGeneratorCreate;
var
  Gen: TFPCConfigGenerator;
begin
  StartTest('TFPCConfigGenerator.Create with nil output');
  Gen := TFPCConfigGenerator.Create(nil);
  try
    if Gen <> nil then Pass
    else Fail('Expected non-nil generator');
  finally
    Gen.Free;
  end;
end;

procedure TestArchSuffixConsistency;
var
  Suffix: string;
  CompilerName: string;
begin
  StartTest('Architecture suffix matches compiler name');
  Suffix := GetFPCArchSuffix;
  CompilerName := GetNativeCompilerName;

  // x86_64 -> ppcx64, i386 -> ppc386, aarch64 -> ppca64
  if ((Pos('x86_64', Suffix) > 0) and (CompilerName = 'ppcx64')) or
     ((Pos('i386', Suffix) > 0) and (CompilerName = 'ppc386')) or
     ((Pos('aarch64', Suffix) > 0) and (CompilerName = 'ppca64')) then Pass
  else Fail('Suffix and compiler name mismatch');
end;

begin
  WriteLn('========================================');
  WriteLn('FPC Installer Config Unit Tests');
  WriteLn('========================================');
  WriteLn;

  WriteLn('[1] GetFPCArchSuffix Tests');
  TestGetFPCArchSuffix;
  WriteLn;

  WriteLn('[2] GetNativeCompilerName Tests');
  TestGetNativeCompilerName;
  WriteLn;

  WriteLn('[3] TFPCConfigGenerator Tests');
  TestTFPCConfigGeneratorCreate;
  WriteLn;

  WriteLn('[4] Consistency Tests');
  TestArchSuffixConsistency;
  WriteLn;

  WriteLn('========================================');
  WriteLn('Test Results Summary');
  WriteLn('========================================');
  WriteLn('Total:   ', PassCount + FailCount);
  WriteLn('Passed:  ', PassCount);
  WriteLn('Failed:  ', FailCount);
  WriteLn;

  if FailCount = 0 then
    WriteLn('All tests passed!')
  else
  begin
    WriteLn('Some tests failed!');
    Halt(1);
  end;
end.
