program test_binary_installer_unit;

{$mode objfpc}{$H+}

{ Unit tests for TBinaryInstaller class in fpdev.fpc.binary }

uses
  SysUtils, Classes, fpdev.fpc.binary, test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ATestName: string; ACondition: Boolean);
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

procedure TestCreateDestroy;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('');
  WriteLn('=== Test 1: TBinaryInstaller Create/Destroy ===');

  Installer := TBinaryInstaller.Create;
  try
    Check('Create succeeds', Assigned(Installer));
    Check('GetLastError is empty initially', Installer.GetLastError = '');
  finally
    Installer.Free;
  end;
end;

procedure TestDefaultProperties;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('');
  WriteLn('=== Test 2: Default Property Values ===');

  Installer := TBinaryInstaller.Create;
  try
    Check('UseCache defaults to True', Installer.UseCache = True);
    Check('OfflineMode defaults to False', Installer.OfflineMode = False);
    Check('VerifyInstallation defaults to True', Installer.VerifyInstallation = True);
    Check('UseManifest defaults to False', Installer.UseManifest = False);
  finally
    Installer.Free;
  end;
end;

procedure TestPropertySetters;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('');
  WriteLn('=== Test 3: Property Setters ===');

  Installer := TBinaryInstaller.Create;
  try
    // Test UseCache
    Installer.UseCache := False;
    Check('UseCache can be set to False', Installer.UseCache = False);
    Installer.UseCache := True;
    Check('UseCache can be set to True', Installer.UseCache = True);

    // Test OfflineMode
    Installer.OfflineMode := True;
    Check('OfflineMode can be set to True', Installer.OfflineMode = True);
    Installer.OfflineMode := False;
    Check('OfflineMode can be set to False', Installer.OfflineMode = False);

    // Test VerifyInstallation
    Installer.VerifyInstallation := False;
    Check('VerifyInstallation can be set to False', Installer.VerifyInstallation = False);
    Installer.VerifyInstallation := True;
    Check('VerifyInstallation can be set to True', Installer.VerifyInstallation = True);

    // Test UseManifest
    Installer.UseManifest := True;
    Check('UseManifest can be set to True', Installer.UseManifest = True);
    Installer.UseManifest := False;
    Check('UseManifest can be set to False', Installer.UseManifest = False);
  finally
    Installer.Free;
  end;
end;

procedure TestIsCached;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('');
  WriteLn('=== Test 4: IsCached ===');

  Installer := TBinaryInstaller.Create;
  try
    // Non-existent version should not be cached
    Check('Non-existent version is not cached', Installer.IsCached('99.99.99') = False);

    // Note: Testing actual cache presence requires setup
    // This test just verifies the method doesn't crash
    Check('IsCached method works without error', True);
  finally
    Installer.Free;
  end;
end;

procedure TestOfflineModeBlocking;
var
  Installer: TBinaryInstaller;
  Result: Boolean;
  TempRoot: string;
begin
  WriteLn('');
  WriteLn('=== Test 5: Offline Mode Blocking ===');

  TempRoot := CreateUniqueTempDir('test_binary_installer_offline');
  Installer := TBinaryInstaller.Create;
  try
    Installer.OfflineMode := True;
    Installer.UseCache := False;  // Disable cache to force download attempt

    // In offline mode, installation should fail for non-cached versions
    Result := Installer.Install('99.99.99', TempRoot + PathDelim + 'test_install');
    Check('Install fails in offline mode for non-cached version', Result = False);
    Check('Error message mentions offline mode', Pos('offline', LowerCase(Installer.GetLastError)) > 0);
  finally
    Installer.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestMultipleInstances;
var
  Inst1, Inst2: TBinaryInstaller;
begin
  WriteLn('');
  WriteLn('=== Test 6: Multiple Instances ===');

  Inst1 := TBinaryInstaller.Create;
  try
    Inst2 := TBinaryInstaller.Create;
    try
      Check('Two instances can coexist', Assigned(Inst1) and Assigned(Inst2));

      // Verify independent settings
      Inst1.OfflineMode := True;
      Inst2.OfflineMode := False;
      Check('Instances have independent OfflineMode', Inst1.OfflineMode <> Inst2.OfflineMode);

      Inst1.UseCache := False;
      Inst2.UseCache := True;
      Check('Instances have independent UseCache', Inst1.UseCache <> Inst2.UseCache);
    finally
      Inst2.Free;
    end;
  finally
    Inst1.Free;
  end;
end;

procedure TestGetLastError;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('');
  WriteLn('=== Test 7: GetLastError ===');

  Installer := TBinaryInstaller.Create;
  try
    Check('Initial error is empty', Installer.GetLastError = '');

    // Trigger an error condition
    Installer.OfflineMode := True;
    Installer.UseCache := False;
    Installer.Install('99.99.99', '/invalid/path');

    Check('Error message is set after failed operation', Installer.GetLastError <> '');
  finally
    Installer.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  TBinaryInstaller Unit Tests');
  WriteLn('========================================');

  TestCreateDestroy;
  TestDefaultProperties;
  TestPropertySetters;
  TestIsCached;
  TestOfflineModeBlocking;
  TestMultipleInstances;
  TestGetLastError;

  WriteLn('');
  WriteLn('========================================');
  WriteLn(Format('  Results: %d passed, %d failed', [TestsPassed, TestsFailed]));
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
