program test_fpc_current;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCCurrentCommand

  Tests:
  - GetCurrentVersion: Returns current active FPC version
  - Execute: Runs current command and displays version
}

uses
  SysUtils, Classes, test_temp_paths, fpdev.command.intf, fpdev.config.interfaces, fpdev.config.managers, fpdev.fpc.manager;

var
  TestInstallRoot: string;
  ConfigManager: IConfigManager;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function BuildTempRoot(const APrefix: string): string;
begin
  Result := CreateUniqueTempDir(APrefix);
end;

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

procedure TestTempPathsUseSystemTempRoot;
var
  TempRoot: string;
  ConfigPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: temp paths use system temp root');
  WriteLn('==================================================');

  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  ConfigPath := ExpandFileName(ConfigManager.GetConfigPath);
  AssertTrue(Pos(TempRoot, ExpandFileName(TestInstallRoot)) = 1,
    'Test install root should live under system temp');
  AssertTrue(Pos(TempRoot, ConfigPath) = 1,
    'Config path should live under system temp');
end;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  if TestInstallRoot = '' then
    TestInstallRoot := BuildTempRoot('test_current_root_');
  ForceDirectories(TestInstallRoot);

  SettingsMgr := ConfigManager.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  SettingsMgr.SetSettings(Settings);

  WriteLn('[Setup] Created test directory: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
begin
  if (TestInstallRoot <> '') and DirectoryExists(TestInstallRoot) then
  begin
    CleanupTempDir(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
    TestInstallRoot := '';
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

{ Test: uninstalling the default version clears current/default state }
procedure TestUninstallDefaultVersionClearsCurrentVersion;
var
  Manager: TFPCManager;
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
  FPCExe: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Uninstall default version clears current/default state');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    InstallPath := Manager.GetVersionInstallPath('3.2.2');
    ForceDirectories(InstallPath + PathDelim + 'bin');
    {$IFDEF MSWINDOWS}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}
    with TStringList.Create do
    try
      Add('mock fpc');
      SaveToFile(FPCExe);
    finally
      Free;
    end;

    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := InstallPath;
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;

    AssertTrue(ConfigManager.GetToolchainManager.AddToolchain('fpc-3.2.2', ToolchainInfo),
      'Should add installed toolchain before uninstall');
    AssertTrue(ConfigManager.GetToolchainManager.SetDefaultToolchain('fpc-3.2.2'),
      'Should set default toolchain before uninstall');
    AssertEqualsStr('3.2.2', Manager.GetCurrentVersion,
      'GetCurrentVersion should follow default toolchain before uninstall');

    AssertTrue(Manager.UninstallVersion('3.2.2'),
      'UninstallVersion should succeed for installed default version');
    AssertEqualsStr('', ConfigManager.GetToolchainManager.GetDefaultToolchain,
      'Default toolchain should clear after uninstall removes it');
    AssertEqualsStr('', Manager.GetCurrentVersion,
      'GetCurrentVersion should return empty after uninstalling default version');
    AssertFalse(DirectoryExists(InstallPath),
      'UninstallVersion should remove the installed version directory');
  finally
    Manager.Free;
  end;
end;

{ Test: loading config clears stale default toolchain when entry is missing }
procedure TestLoadConfigClearsMissingDefaultToolchain;
var
  ReloadedConfig: IConfigManager;
  Manager: TFPCManager;
  StaleConfigRoot: string;
  StaleConfigPath: string;
  ConfigText: TStringList;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: LoadConfig clears missing default toolchain');
  WriteLn('==================================================');

  StaleConfigRoot := BuildTempRoot('test_current_reload_');
  StaleConfigPath := IncludeTrailingPathDelimiter(StaleConfigRoot) + 'config.json';
  ConfigText := TStringList.Create;
  try
    ConfigText.Add('{');
    ConfigText.Add('  "version": "1.0",');
    ConfigText.Add('  "default_toolchain": "fpc-3.2.2",');
    ConfigText.Add('  "toolchains": {},');
    ConfigText.Add('  "lazarus": {');
    ConfigText.Add('    "default_version": "",');
    ConfigText.Add('    "versions": {}');
    ConfigText.Add('  },');
    ConfigText.Add('  "cross_targets": {},');
    ConfigText.Add('  "repositories": {');
    ConfigText.Add('    "official_fpc": "https://gitlab.com/freepascal.org/fpc/source.git",');
    ConfigText.Add('    "official_lazarus": "https://gitlab.com/freepascal.org/lazarus/lazarus.git"');
    ConfigText.Add('  },');
    ConfigText.Add('  "settings": {');
    ConfigText.Add('    "auto_update": false,');
    ConfigText.Add('    "parallel_jobs": 4,');
    ConfigText.Add('    "keep_sources": true,');
    ConfigText.Add('    "install_root": "' + StringReplace(
      IncludeTrailingPathDelimiter(StaleConfigRoot), '\', '\\', [rfReplaceAll]) + '",');
    ConfigText.Add('    "default_repo": "",');
    ConfigText.Add('    "mirror": "auto",');
    ConfigText.Add('    "custom_repo_url": ""');
    ConfigText.Add('  }');
    ConfigText.Add('}');
    ConfigText.SaveToFile(StaleConfigPath);

    ReloadedConfig := TConfigManager.Create(StaleConfigPath);
    AssertTrue(ReloadedConfig.LoadConfig, 'LoadConfig should succeed for stale default fixture');

    Manager := TFPCManager.Create(ReloadedConfig);
    try
      AssertEqualsStr('', ReloadedConfig.GetToolchainManager.GetDefaultToolchain,
        'LoadConfig should clear missing default toolchain');
      AssertEqualsStr('', Manager.GetCurrentVersion,
        'GetCurrentVersion should ignore stale default toolchain after reload');
    finally
      Manager.Free;
    end;
  finally
    ConfigText.Free;
    CleanupTempDir(StaleConfigRoot);
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
    // Use test-specific config file to avoid interference from user's config
    TestInstallRoot := BuildTempRoot('test_current_root_');
    ForceDirectories(TestInstallRoot);

    ConfigManager := TConfigManager.Create(TestInstallRoot + PathDelim + 'test_config.json');
    ConfigManager.CreateDefaultConfig;

    SetupTestEnvironment;
    try
      TestTempPathsUseSystemTempRoot;
      TestManagerCreation;
      TestGetCurrentVersionEmpty;
      TestUninstallDefaultVersionClearsCurrentVersion;
      TestLoadConfigClearsMissingDefaultToolchain;
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
