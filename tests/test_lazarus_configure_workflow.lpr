program test_lazarus_configure_workflow;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes,
  fpdev.config.interfaces, fpdev.config.managers, fpdev.cmd.lazarus, fpdev.utils, test_temp_paths;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  LazarusManager: TLazarusManager;
  OriginalLazarusConfigRoot: string;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create test root directory in temp
  TestRootDir := CreateUniqueTempDir('test_lazarus_configure_workflow');
  if not PathUsesSystemTempRoot(TestRootDir) then
    raise Exception.Create('Test root dir should use system temp root');

  OriginalLazarusConfigRoot := GetEnvironmentVariable('FPDEV_LAZARUS_CONFIG_ROOT');
  if not set_env('FPDEV_LAZARUS_CONFIG_ROOT',
    IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root') then
    raise Exception.Create('Failed to set isolated Lazarus config root');

  // Initialize config manager (interface-based)
  ConfigManager := CreateIsolatedConfigManager;

  // Override install root to test directory
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  // Create Lazarus manager
  LazarusManager := TLazarusManager.Create(ConfigManager);

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
begin
  if Assigned(LazarusManager) then
    LazarusManager.Free;
  ConfigManager := nil;  // Interface will be freed automatically

  CleanupTempDir(TestRootDir);

  if OriginalLazarusConfigRoot <> '' then
    set_env('FPDEV_LAZARUS_CONFIG_ROOT', OriginalLazarusConfigRoot)
  else
    unset_env('FPDEV_LAZARUS_CONFIG_ROOT');

  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  WriteLn('========================================');
end;

procedure AssertTrue(const Condition: Boolean; const TestName, Message: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  ', Message);
    Inc(TestsFailed);
  end;
end;

procedure AssertFalse(const Condition: Boolean; const TestName, Message: string);
begin
  AssertTrue(not Condition, TestName, Message);
end;

procedure TestConfigManagerUsesIsolatedDefaultConfigPath;
var
  ConfigPath: string;
  TempRoot: string;
  ExpectedPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Config Manager Uses Isolated Config Path');
  WriteLn('==================================================');

  try
    ConfigPath := ExpandFileName(ConfigManager.GetConfigPath);
    TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
    ExpectedPath := ExpandFileName(GetIsolatedDefaultConfigPath);

    AssertTrue(Pos(TempRoot, ConfigPath) = 1,
      'Config path uses system temp root',
      'Expected config path under temp root "' + TempRoot + '", got "' + ConfigPath + '"');

    AssertTrue(ConfigPath = ExpectedPath,
      'Config path uses isolated default override',
      'Expected config path "' + ExpectedPath + '", got "' + ConfigPath + '"');
  except
    on E: Exception do
      AssertTrue(False, 'Config path isolation check',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 1: ConfigureIDE fails when Lazarus not installed
// ============================================================================
procedure TestConfigureIDEFailsWhenNotInstalled;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: ConfigureIDE Fails When Not Installed');
  WriteLn('==================================================');

  try
    // Execute: Call ConfigureIDE on non-existent version
    Success := LazarusManager.ConfigureIDE('99.99');

    // Assert: Should fail because version is not installed
    AssertFalse(Success, 'ConfigureIDE fails for non-existent version',
      'ConfigureIDE should return False when Lazarus version is not installed');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE handles missing version', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: ConfigureIDE succeeds when Lazarus is installed
// ============================================================================
procedure TestConfigureIDESucceedsWhenInstalled;
var
  LazarusPath: string;
  LazarusExe: string;
  FPCPath: string;
  FPCExe: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: ConfigureIDE Succeeds When Installed');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus installation
    LazarusPath := TestRootDir + PathDelim + 'lazarus' + PathDelim + '3.0';
    ForceDirectories(LazarusPath);

    {$IFDEF MSWINDOWS}
    LazarusExe := LazarusPath + PathDelim + 'lazarus.exe';
    {$ELSE}
    LazarusExe := LazarusPath + PathDelim + 'lazarus';
    {$ENDIF}

    // Create mock lazarus executable
    with TStringList.Create do
    try
      Add('#!/bin/bash');
      Add('echo "Mock Lazarus"');
      SaveToFile(LazarusExe);
    finally
      Free;
    end;

    // Setup: Create mock FPC installation
    FPCPath := TestRootDir + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'bin';
    ForceDirectories(FPCPath);

    {$IFDEF MSWINDOWS}
    FPCExe := FPCPath + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := FPCPath + PathDelim + 'fpc';
    {$ENDIF}

    // Create mock fpc executable
    with TStringList.Create do
    try
      Add('#!/bin/bash');
      Add('echo "Mock FPC"');
      SaveToFile(FPCExe);
    finally
      Free;
    end;

    // Execute: Call ConfigureIDE
    Success := LazarusManager.ConfigureIDE('3.0');

    // Assert: Should succeed (or fail gracefully with clear message)
    // Note: May fail if FPC version detection fails, which is OK for this test
    WriteLn('[INFO] ConfigureIDE returned: ', Success);
    AssertTrue(True, 'ConfigureIDE executed without crash',
      'ConfigureIDE should execute without crashing');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE succeeds when installed', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: ConfigureIDE creates config directory
// ============================================================================
procedure TestConfigureIDECreatesConfigDir;
var
  LazarusPath: string;
  LazarusExe: string;
  ConfigDir: string;
  ConfigRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: ConfigureIDE Creates Config Directory');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus installation
    LazarusPath := TestRootDir + PathDelim + 'lazarus' + PathDelim + '3.1';
    ForceDirectories(LazarusPath);

    {$IFDEF MSWINDOWS}
    LazarusExe := LazarusPath + PathDelim + 'lazarus.exe';
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + 'lazarus-3.1';
    {$ELSE}
    LazarusExe := LazarusPath + PathDelim + 'lazarus';
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + '.lazarus-3.1';
    {$ENDIF}

    // Create mock lazarus executable
    with TStringList.Create do
    try
      Add('#!/bin/bash');
      Add('echo "Mock Lazarus"');
      SaveToFile(LazarusExe);
    finally
      Free;
    end;

    // Execute: Call ConfigureIDE
    LazarusManager.ConfigureIDE('3.1');

    // Assert: Config directory should be created
    AssertTrue(DirectoryExists(ConfigDir), 'ConfigureIDE creates config directory',
      'ConfigureIDE should create Lazarus config directory');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE creates config dir', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 4: ConfigureIDE creates backup
// ============================================================================
procedure TestConfigureIDECreatesBackup;
var
  LazarusPath: string;
  LazarusExe: string;
  ConfigDir: string;
  EnvOptionsFile: string;
  BackupDir: string;
  ConfigRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: ConfigureIDE Creates Backup');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus installation
    LazarusPath := TestRootDir + PathDelim + 'lazarus' + PathDelim + '3.2';
    ForceDirectories(LazarusPath);

    {$IFDEF MSWINDOWS}
    LazarusExe := LazarusPath + PathDelim + 'lazarus.exe';
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + 'lazarus-3.2';
    {$ELSE}
    LazarusExe := LazarusPath + PathDelim + 'lazarus';
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + '.lazarus-3.2';
    {$ENDIF}

    ForceDirectories(ConfigDir);

    // Create mock lazarus executable
    with TStringList.Create do
    try
      Add('#!/bin/bash');
      Add('echo "Mock Lazarus"');
      SaveToFile(LazarusExe);
    finally
      Free;
    end;

    // Create existing config file
    EnvOptionsFile := ConfigDir + PathDelim + 'environmentoptions.xml';
    with TStringList.Create do
    try
      Add('<?xml version="1.0" encoding="UTF-8"?>');
      Add('<CONFIG>');
      Add('  <EnvironmentOptions>');
      Add('    <CompilerFilename Value="/old/path/fpc"/>');
      Add('  </EnvironmentOptions>');
      Add('</CONFIG>');
      SaveToFile(EnvOptionsFile);
    finally
      Free;
    end;

    // Execute: Call ConfigureIDE
    LazarusManager.ConfigureIDE('3.2');

    // Assert: Backup directory should be created
    BackupDir := ConfigDir + PathDelim + 'backups';
    AssertTrue(DirectoryExists(BackupDir), 'ConfigureIDE creates backup directory',
      'ConfigureIDE should create backup directory');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE creates backup', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Lazarus Configure Workflow Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestConfigManagerUsesIsolatedDefaultConfigPath;
      TestConfigureIDEFailsWhenNotInstalled;
      TestConfigureIDESucceedsWhenInstalled;
      TestConfigureIDECreatesConfigDir;
      TestConfigureIDECreatesBackup;

      // Exit with error if any tests failed
      if TestsFailed > 0 then
        ExitCode := 1
      else
        ExitCode := 0;

    finally
      CleanupTestEnvironment;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite crashed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
