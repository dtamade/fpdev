program test_platform_detection;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils, fpdev.platform;

var
  Info: TPlatformInfo;
  TestsPassed, TestsFailed: Integer;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('=== Platform Detection Tests ===');
  WriteLn;

  // Test 1: DetectPlatform returns valid platform
  Info := DetectPlatform;
  Assert(Info.IsValid, 'DetectPlatform returns valid platform');

  // Test 2: OS is not unknown
  Assert(Info.OS <> posUnknown, 'OS is not unknown');

  // Test 3: CPU is not unknown
  Assert(Info.CPU <> pcUnknown, 'CPU is not unknown');

  // Test 4: Platform string format
  Assert(Length(Info.ToString) > 0, 'Platform string is not empty');
  Assert(Pos('-', Info.ToString) > 0, 'Platform string contains dash');

  // Test 5: PlatformToString with known values
  Info.OS := posLinux;
  Info.CPU := pcX86_64;
  Assert(PlatformToString(Info) = 'linux-x86_64', 'PlatformToString linux-x86_64');

  // Test 6: StringToPlatform Windows x64
  Info := StringToPlatform('windows-x86_64');
  Assert(Info.OS = posWindows, 'StringToPlatform Windows OS');
  Assert(Info.CPU = pcX86_64, 'StringToPlatform x86_64 CPU');

  // Test 7: StringToPlatform Linux x64
  Info := StringToPlatform('linux-x86_64');
  Assert(Info.OS = posLinux, 'StringToPlatform Linux OS');
  Assert(Info.CPU = pcX86_64, 'StringToPlatform x86_64 CPU');

  // Test 8: StringToPlatform Darwin ARM64
  Info := StringToPlatform('darwin-aarch64');
  Assert(Info.OS = posDarwin, 'StringToPlatform Darwin OS');
  Assert(Info.CPU = pcAArch64, 'StringToPlatform aarch64 CPU');

  // Test 9: StringToPlatform invalid
  Info := StringToPlatform('invalid-platform');
  Assert(not Info.IsValid, 'StringToPlatform invalid returns invalid');

  // Test 10: IsValid with valid platform
  Info.OS := posLinux;
  Info.CPU := pcX86_64;
  Assert(Info.IsValid, 'IsValid returns true for valid platform');

  // Test 11: IsValid with unknown OS
  Info.OS := posUnknown;
  Info.CPU := pcX86_64;
  Assert(not Info.IsValid, 'IsValid returns false for unknown OS');

  // Test 12: IsValid with unknown CPU
  Info.OS := posLinux;
  Info.CPU := pcUnknown;
  Assert(not Info.IsValid, 'IsValid returns false for unknown CPU');

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
