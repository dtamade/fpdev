program test_cmd_params;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  fpdev.cmd.params;

var
  Passed, Failed: Integer;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('PASS: ', AMsg);
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL: ', AMsg);
  end;
end;

procedure CheckStr(const AExpected, AActual, AMsg: string);
begin
  if AExpected = AActual then
  begin
    Inc(Passed);
    WriteLn('PASS: ', AMsg);
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL: ', AMsg, ' (expected "', AExpected, '", got "', AActual, '")');
  end;
end;

procedure CheckInt(AExpected, AActual: Integer; const AMsg: string);
begin
  if AExpected = AActual then
  begin
    Inc(Passed);
    WriteLn('PASS: ', AMsg);
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL: ', AMsg, ' (expected ', AExpected, ', got ', AActual, ')');
  end;
end;

// ---- HasFlag tests ----

procedure TestHasFlag_DoubleDash;
begin
  WriteLn('-- TestHasFlag_DoubleDash --');
  Check(HasFlag(['--verbose'], 'verbose'), 'HasFlag --verbose');
  Check(HasFlag(['--all', '--verbose'], 'verbose'), 'HasFlag --verbose in multi');
  Check(HasFlag(['--force'], 'force'), 'HasFlag --force');
end;

procedure TestHasFlag_SingleDash;
begin
  WriteLn('-- TestHasFlag_SingleDash --');
  Check(HasFlag(['-verbose'], 'verbose'), 'HasFlag -verbose');
  Check(HasFlag(['-all', '-force'], 'force'), 'HasFlag -force in multi');
end;

procedure TestHasFlag_CaseInsensitive;
begin
  WriteLn('-- TestHasFlag_CaseInsensitive --');
  Check(HasFlag(['--VERBOSE'], 'verbose'), 'HasFlag case-insensitive upper');
  Check(HasFlag(['--Verbose'], 'verbose'), 'HasFlag case-insensitive mixed');
end;

procedure TestHasFlag_NotFound;
begin
  WriteLn('-- TestHasFlag_NotFound --');
  Check(not HasFlag(['--verbose'], 'force'), 'HasFlag not found');
  Check(not HasFlag([], 'verbose'), 'HasFlag empty params');
end;

procedure TestHasFlag_WithValueParam;
begin
  WriteLn('-- TestHasFlag_WithValueParam --');
  Check(not HasFlag(['--jobs=4'], 'jobs'), 'HasFlag should not match key=value');
end;

// ---- GetFlagValue tests ----

procedure TestGetFlagValue_Found;
var
  V: string;
begin
  WriteLn('-- TestGetFlagValue_Found --');
  Check(GetFlagValue(['--jobs=4'], 'jobs', V), 'GetFlagValue --jobs=4 found');
  CheckStr('4', V, 'GetFlagValue --jobs=4 value');

  Check(GetFlagValue(['--prefix=/usr/local'], 'prefix', V), 'GetFlagValue --prefix found');
  CheckStr('/usr/local', V, 'GetFlagValue --prefix value');
end;

procedure TestGetFlagValue_InMulti;
var
  V: string;
begin
  WriteLn('-- TestGetFlagValue_InMulti --');
  Check(GetFlagValue(['--verbose', '--jobs=8', 'arg1'], 'jobs', V), 'GetFlagValue in multi found');
  CheckStr('8', V, 'GetFlagValue in multi value');
end;

procedure TestGetFlagValue_EmptyValue;
var
  V: string;
begin
  WriteLn('-- TestGetFlagValue_EmptyValue --');
  Check(GetFlagValue(['--prefix='], 'prefix', V), 'GetFlagValue empty value found');
  CheckStr('', V, 'GetFlagValue empty value is empty');
end;

procedure TestGetFlagValue_NotFound;
var
  V: string;
begin
  WriteLn('-- TestGetFlagValue_NotFound --');
  Check(not GetFlagValue(['--verbose'], 'jobs', V), 'GetFlagValue not found');
  Check(not GetFlagValue([], 'jobs', V), 'GetFlagValue empty params');
end;

procedure TestGetFlagValue_ValueWithEquals;
var
  V: string;
begin
  WriteLn('-- TestGetFlagValue_ValueWithEquals --');
  Check(GetFlagValue(['--config=path=val'], 'config', V), 'GetFlagValue value with equals');
  CheckStr('path=val', V, 'GetFlagValue preserves inner equals');
end;

// ---- GetPositionalParam tests ----

procedure TestGetPositionalParam_Basic;
var
  V: string;
begin
  WriteLn('-- TestGetPositionalParam_Basic --');
  Check(GetPositionalParam(['install', '3.2.2'], 0, V), 'GetPositional index 0');
  CheckStr('install', V, 'GetPositional index 0 value');

  Check(GetPositionalParam(['install', '3.2.2'], 1, V), 'GetPositional index 1');
  CheckStr('3.2.2', V, 'GetPositional index 1 value');
end;

procedure TestGetPositionalParam_SkipsFlags;
var
  V: string;
begin
  WriteLn('-- TestGetPositionalParam_SkipsFlags --');
  Check(GetPositionalParam(['--verbose', 'install', '--force', '3.2.2'], 0, V), 'GetPositional skips flags idx 0');
  CheckStr('install', V, 'GetPositional skips --verbose');

  Check(GetPositionalParam(['--verbose', 'install', '--force', '3.2.2'], 1, V), 'GetPositional skips flags idx 1');
  CheckStr('3.2.2', V, 'GetPositional skips --force');
end;

procedure TestGetPositionalParam_OutOfRange;
var
  V: string;
begin
  WriteLn('-- TestGetPositionalParam_OutOfRange --');
  Check(not GetPositionalParam(['install'], 1, V), 'GetPositional out of range');
  Check(not GetPositionalParam([], 0, V), 'GetPositional empty params');
end;

// ---- CountPositionalParams tests ----

procedure TestCountPositionalParams_Basic;
begin
  WriteLn('-- TestCountPositionalParams_Basic --');
  CheckInt(0, CountPositionalParams([]), 'Count empty');
  CheckInt(1, CountPositionalParams(['install']), 'Count 1');
  CheckInt(2, CountPositionalParams(['install', '3.2.2']), 'Count 2');
end;

procedure TestCountPositionalParams_SkipsFlags;
begin
  WriteLn('-- TestCountPositionalParams_SkipsFlags --');
  CheckInt(0, CountPositionalParams(['--verbose', '--force']), 'Count all flags = 0');
  CheckInt(1, CountPositionalParams(['--verbose', 'install', '--force']), 'Count 1 among flags');
  CheckInt(2, CountPositionalParams(['--verbose', 'install', '--force', '3.2.2']), 'Count 2 among flags');
end;

begin
  Passed := 0;
  Failed := 0;

  WriteLn('');
  WriteLn('=== fpdev.cmd.params Test Suite ===');
  WriteLn('');

  TestHasFlag_DoubleDash;
  TestHasFlag_SingleDash;
  TestHasFlag_CaseInsensitive;
  TestHasFlag_NotFound;
  TestHasFlag_WithValueParam;
  TestGetFlagValue_Found;
  TestGetFlagValue_InMulti;
  TestGetFlagValue_EmptyValue;
  TestGetFlagValue_NotFound;
  TestGetFlagValue_ValueWithEquals;
  TestGetPositionalParam_Basic;
  TestGetPositionalParam_SkipsFlags;
  TestGetPositionalParam_OutOfRange;
  TestCountPositionalParams_Basic;
  TestCountPositionalParams_SkipsFlags;

  WriteLn('');
  WriteLn('=== Results ===');
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  WriteLn('Total:  ', Passed + Failed);

  if Failed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
