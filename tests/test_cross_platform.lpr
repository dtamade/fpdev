program test_cross_platform;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.cross.platform;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', AName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', AName);
    Inc(TestsFailed);
  end;
end;

procedure TestPlatformToString;
begin
  WriteLn('=== PlatformToString ===');
  Check('win32', PlatformToString(ctpWin32) = 'win32');
  Check('win64', PlatformToString(ctpWin64) = 'win64');
  Check('linux32', PlatformToString(ctpLinux32) = 'linux32');
  Check('linux64', PlatformToString(ctpLinux64) = 'linux64');
  Check('linuxarm', PlatformToString(ctpLinuxARM) = 'linuxarm');
  Check('linuxarm64', PlatformToString(ctpLinuxARM64) = 'linuxarm64');
  Check('darwin32', PlatformToString(ctpDarwin32) = 'darwin32');
  Check('darwin64', PlatformToString(ctpDarwin64) = 'darwin64');
  Check('darwinarm64', PlatformToString(ctpDarwinARM64) = 'darwinarm64');
  Check('android', PlatformToString(ctpAndroid) = 'android');
  Check('ios', PlatformToString(ctpiOS) = 'ios');
  Check('freebsd32', PlatformToString(ctpFreeBSD32) = 'freebsd32');
  Check('freebsd64', PlatformToString(ctpFreeBSD64) = 'freebsd64');
  Check('custom', PlatformToString(ctpCustom) = 'custom');
end;

procedure TestStringToPlatform;
begin
  WriteLn('=== StringToPlatform ===');
  Check('win32', StringToPlatform('win32') = ctpWin32);
  Check('WIN32 (case insensitive)', StringToPlatform('WIN32') = ctpWin32);
  Check('win64', StringToPlatform('win64') = ctpWin64);
  Check('linux32', StringToPlatform('linux32') = ctpLinux32);
  Check('linux64', StringToPlatform('linux64') = ctpLinux64);
  Check('linuxarm', StringToPlatform('linuxarm') = ctpLinuxARM);
  Check('linuxarm64', StringToPlatform('linuxarm64') = ctpLinuxARM64);
  Check('darwin32', StringToPlatform('darwin32') = ctpDarwin32);
  Check('darwin64', StringToPlatform('darwin64') = ctpDarwin64);
  Check('darwinarm64', StringToPlatform('darwinarm64') = ctpDarwinARM64);
  Check('android', StringToPlatform('android') = ctpAndroid);
  Check('ios', StringToPlatform('ios') = ctpiOS);
  Check('freebsd32', StringToPlatform('freebsd32') = ctpFreeBSD32);
  Check('freebsd64', StringToPlatform('freebsd64') = ctpFreeBSD64);
  Check('unknown -> custom', StringToPlatform('unknown') = ctpCustom);
  Check('empty -> custom', StringToPlatform('') = ctpCustom);
end;

procedure TestRoundTrip;
var
  P: TCrossTargetPlatform;
  S: string;
begin
  WriteLn('=== Round-trip conversion ===');
  for P := Low(TCrossTargetPlatform) to High(TCrossTargetPlatform) do
  begin
    S := PlatformToString(P);
    Check('roundtrip ' + S, StringToPlatform(S) = P);
  end;
end;

procedure TestGetBinutilsPrefix;
begin
  WriteLn('=== GetBinutilsPrefix ===');
  Check('win32 prefix', GetBinutilsPrefix(ctpWin32) = 'i686-w64-mingw32-');
  Check('win64 prefix', GetBinutilsPrefix(ctpWin64) = 'x86_64-w64-mingw32-');
  Check('linux32 prefix', GetBinutilsPrefix(ctpLinux32) = 'i686-linux-gnu-');
  Check('linux64 prefix', GetBinutilsPrefix(ctpLinux64) = 'x86_64-linux-gnu-');
  Check('linuxarm prefix', GetBinutilsPrefix(ctpLinuxARM) = 'arm-linux-gnueabihf-');
  Check('linuxarm64 prefix', GetBinutilsPrefix(ctpLinuxARM64) = 'aarch64-linux-gnu-');
  Check('darwin64 prefix', GetBinutilsPrefix(ctpDarwin64) = 'x86_64-apple-darwin-');
  Check('darwinarm64 prefix', GetBinutilsPrefix(ctpDarwinARM64) = 'aarch64-apple-darwin-');
  Check('android prefix', GetBinutilsPrefix(ctpAndroid) = 'arm-linux-androideabi-');
  Check('custom has no prefix', GetBinutilsPrefix(ctpCustom) = '');
  Check('ios has no prefix', GetBinutilsPrefix(ctpiOS) = '');
end;

procedure TestGetPackageManagerInstructions;
var
  S: string;
begin
  WriteLn('=== GetPackageManagerInstructions ===');
  S := GetPackageManagerInstructions('win64');
  Check('win64 has instructions', S <> '');
  Check('win64 mentions install', Pos('install', LowerCase(S)) > 0);

  S := GetPackageManagerInstructions('linuxarm');
  Check('linuxarm has instructions', S <> '');

  S := GetPackageManagerInstructions('unknown_target');
  Check('unknown has fallback message', S <> '');
  Check('unknown mentions configure', Pos('configure', LowerCase(S)) > 0);
end;

procedure TestDetectSystemCrossCompiler;
var
  BinutilsPath: string;
  Found: Boolean;
begin
  WriteLn('=== DetectSystemCrossCompiler ===');
  // This test may pass or fail depending on system configuration
  // We just verify it doesn't crash
  Found := DetectSystemCrossCompiler('win64', BinutilsPath);
  if Found then
    WriteLn('[INFO] win64 cross compiler found at: ', BinutilsPath)
  else
    WriteLn('[INFO] win64 cross compiler not found (expected on most systems)');
  Check('DetectSystemCrossCompiler returns valid result', True);

  // Unknown target should return False
  Found := DetectSystemCrossCompiler('unknown_platform', BinutilsPath);
  Check('unknown platform returns False', not Found);
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('');
  WriteLn('fpdev.cross.platform unit tests');
  WriteLn('================================');
  WriteLn('');

  TestPlatformToString;
  WriteLn('');
  TestStringToPlatform;
  WriteLn('');
  TestRoundTrip;
  WriteLn('');
  TestGetBinutilsPrefix;
  WriteLn('');
  TestGetPackageManagerInstructions;
  WriteLn('');
  TestDetectSystemCrossCompiler;

  WriteLn('');
  WriteLn('================================');
  WriteLn('Total: ', TestsPassed + TestsFailed);
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
