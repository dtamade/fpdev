program test_fpc_show;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCShowCommand

  Tests:
  - ShowVersionInfo: Displays version information for installed FPC
  - Execute: Runs show command with version parameter
}

uses
  SysUtils, test_config_isolation, Classes, fpdev.command.intf, fpdev.config.interfaces, fpdev.config.managers, fpdev.fpc.manager,
  test_temp_paths;

var
  TestInstallRoot: string;
  ConfigManager: IConfigManager;
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

procedure TestConfigManagerUsesIsolatedDefaultConfigPath;
var
  ConfigPath: string;
  TempRoot: string;
  ExpectedPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Config manager uses isolated config path');
  WriteLn('==================================================');

  ConfigPath := ExpandFileName(ConfigManager.GetConfigPath);
  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  ExpectedPath := ExpandFileName(GetIsolatedDefaultConfigPath);

  AssertTrue(Pos(TempRoot, ConfigPath) = 1,
    'Config path should live under system temp root');
  AssertTrue(ConfigPath = ExpectedPath,
    'Config path should use isolated default override');
end;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  TestInstallRoot := CreateUniqueTempDir('test_show_root');

  SettingsMgr := ConfigManager.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  SettingsMgr.SetSettings(Settings);

  WriteLn('[Setup] Created test directory: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
begin
  if DirectoryExists(TestInstallRoot) then
  begin
    CleanupTempDir(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
end;

{ Test: ShowVersionInfo returns false for non-existent version }
procedure TestShowNonExistentVersion;
var
  Manager: TFPCManager;
  Result: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ShowVersionInfo - Non-existent version');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    Result := Manager.ShowVersionInfo('9.9.9');
    AssertFalse(Result, 'ShowVersionInfo should return False for invalid version');
  finally
    Manager.Free;
  end;
end;

{ Test: ShowVersionInfo returns true for valid version }
procedure TestShowValidVersion;
var
  Manager: TFPCManager;
  Result: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ShowVersionInfo - Valid version');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    // 3.2.2 is a valid version in FPC_RELEASES
    Result := Manager.ShowVersionInfo('3.2.2');
    AssertTrue(Result, 'ShowVersionInfo should return True for valid version');
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

begin
  WriteLn('========================================');
  WriteLn('  TFPCShowCommand Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    ConfigManager := CreateIsolatedConfigManager;

    TestConfigManagerUsesIsolatedDefaultConfigPath;

    SetupTestEnvironment;
    try
      TestManagerCreation;
      TestShowNonExistentVersion;
      TestShowValidVersion;

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
