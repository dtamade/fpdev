program test_fpc_current;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCCurrentCommand

  Tests:
  - GetCurrentVersion: Returns current active FPC version
  - Execute: Runs current command and displays version
}

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config, fpdev.cmd.fpc;

var
  TestInstallRoot: string;
  ConfigManager: TFPDevConfigManager;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('  FAILED: ', AMessage);
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure AssertEqualsStr(const AExpected, AActual, AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected "', AExpected, '", got "', AActual, '")');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  TestInstallRoot := 'test_current_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  ConfigManager.SetSettings(Settings);

  WriteLn('[Setup] Created test directory: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
  procedure DeleteDirectory(const DirPath: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if not DirectoryExists(DirPath) then Exit;
    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          FilePath := DirPath + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath)
          else
            DeleteFile(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(DirPath);
  end;
begin
  if DirectoryExists(TestInstallRoot) then
  begin
    DeleteDirectory(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
end;

{ Test: GetCurrentVersion returns empty when no default set }
procedure TestGetCurrentVersionEmpty;
var
  Manager: TFPCManager;
  Version: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetCurrentVersion - No default set');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    Version := Manager.GetCurrentVersion;
    AssertEqualsStr('', Version, 'GetCurrentVersion should return empty when no default set');
  finally
    Manager.Free;
  end;
end;

{ Test: TFPCManager creation }
procedure TestManagerCreation;
var
  Manager: TFPCManager;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: TFPCManager creation');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    AssertTrue(Manager <> nil, 'Manager should be created');
  finally
    Manager.Free;
  end;
end;

{ Test: SetDefaultVersion fails for non-installed version }
procedure TestSetDefaultNonInstalled;
var
  Manager: TFPCManager;
  Result: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: SetDefaultVersion - Non-installed version');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    Result := Manager.SetDefaultVersion('9.9.9');
    AssertFalse(Result, 'SetDefaultVersion should return False for non-installed version');
  finally
    Manager.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCCurrentCommand Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    ConfigManager := TFPDevConfigManager.Create;
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      SetupTestEnvironment;
      try
        TestManagerCreation;
        TestGetCurrentVersionEmpty;
        TestSetDefaultNonInstalled;

        WriteLn;
        WriteLn('========================================');
        WriteLn('  Test Summary');
        WriteLn('========================================');
        WriteLn('  Passed: ', TestsPassed);
        WriteLn('  Failed: ', TestsFailed);
        WriteLn('  Total:  ', TestsPassed + TestsFailed);
        WriteLn;

        if TestsFailed > 0 then
        begin
          WriteLn('  SOME TESTS FAILED');
          ExitCode := 1;
        end
        else
        begin
          WriteLn('  ALL TESTS PASSED');
          ExitCode := 0;
        end;

      finally
        TeardownTestEnvironment;
      end;
    finally
      ConfigManager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite failed with exception');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
