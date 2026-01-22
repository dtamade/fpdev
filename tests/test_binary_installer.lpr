program test_binary_installer;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.fpc.binary;

var
  Installer: TBinaryInstaller;
  TestsPassed, TestsFailed: Integer;
  UseCacheValue, OfflineModeValue, IsCachedValue: Boolean;
  ErrorMsg: string;

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

  WriteLn('=== Binary Installer Tests ===');
  WriteLn;

  Installer := TBinaryInstaller.Create;
  try
    // Test 1: Installer initializes
    Assert(Installer <> nil, 'Installer initializes');

    // Test 2: UseCache property works
    Installer.UseCache := False;
    UseCacheValue := Installer.UseCache;
    Assert(not UseCacheValue, 'Can disable cache');
    Installer.UseCache := True;
    UseCacheValue := Installer.UseCache;
    Assert(UseCacheValue, 'Can enable cache');

    // Test 3: OfflineMode property works
    Installer.OfflineMode := True;
    OfflineModeValue := Installer.OfflineMode;
    Assert(OfflineModeValue, 'Can enable offline mode');
    Installer.OfflineMode := False;
    OfflineModeValue := Installer.OfflineMode;
    Assert(not OfflineModeValue, 'Can disable offline mode');

    // Test 4: IsCached returns false for non-existent version
    IsCachedValue := Installer.IsCached('999.999.999');
    Assert(not IsCachedValue, 'Non-existent version not cached');

    // Test 5: Can get last error
    ErrorMsg := Installer.GetLastError;
    Assert(Length(ErrorMsg) >= 0, 'Can get last error');

  finally
    Installer.Free;
  end;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
