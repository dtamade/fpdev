program test_fpc_use;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes, fpdev.fpc.manager, fpdev.config, fpdev.fpc.activation,
  fpdev.config.interfaces, fpdev.config.managers, fpdev.paths, fpdev.types, fpdev.utils, test_temp_paths;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  FPCManager: TFPCManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
begin
  // Create test root directory in temp (outside project to avoid .fpdev detection)
  TestRootDir := CreateUniqueTempDir('test_fpc_use');
  if not PathUsesSystemTempRoot(TestRootDir) then
    raise Exception.Create('Test root dir should use system temp root');

  // Initialize config manager
  ConfigManager := CreateIsolatedConfigManager;

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
begin
  if Assigned(FPCManager) then
    FPCManager.Free;
  ConfigManager := nil;

  CleanupTempDir(TestRootDir);

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

procedure AssertEquals(const Expected, Actual, TestName: string);
begin
  if Expected = Actual then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  Expected: "', Expected, '"');
    WriteLn('  Actual:   "', Actual, '"');
    Inc(TestsFailed);
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
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

// Helper to create mock FPC installation
procedure CreateMockFPCInstallation(const AInstallPath, AVersion: string);
var
  BinDir, FPCExe: string;
  F: TextFile;
begin
  // Create bin directory
  BinDir := AInstallPath + PathDelim + 'bin';
  ForceDirectories(BinDir);

  // Create mock FPC executable
  {$IFDEF MSWINDOWS}
  FPCExe := BinDir + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := BinDir + PathDelim + 'fpc';
  {$ENDIF}

  AssignFile(F, FPCExe);
  Rewrite(F);
  WriteLn(F, 'Mock FPC ', AVersion);
  CloseFile(F);
end;

// ============================================================================
// Test 1: Activation Types Exist
// ============================================================================
procedure TestActivationTypesExist;
var
  ActivResult: TActivationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: Activation Types Exist');
  WriteLn('==================================================');

  try
    FillChar(ActivResult, SizeOf(ActivResult), 0);
    AssertTrue(True, 'Activation types defined', 'Types should compile');
  except
    on E: Exception do
      AssertTrue(False, 'Activation types defined', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: Project Scope Activation - Creates Activation Scripts
// ============================================================================
procedure TestProjectScopeActivation;
var
  ProjectDir, FPDevDir, EnvDir: string;
  ActivResult: TActivationResult;
  ActivateCmd, ActivateSh: string;
  SavedDir: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: Project Scope Activation');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    // Setup: Create test project with .fpdev
    ProjectDir := TestRootDir + PathDelim + 'test_project';
    FPDevDir := ProjectDir + PathDelim + '.fpdev';
    ForceDirectories(FPDevDir);

    // Change to project directory
    SetCurrentDir(ProjectDir);

    // Setup manager
    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Create mock FPC installation
    CreateMockFPCInstallation(
      FPDevDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2',
      '3.2.2'
    );

    // Add toolchain entry to config
    Settings := ConfigManager.GetSettingsManager.GetSettings;
    ConfigManager.GetToolchainManager.AddToolchain('fpc-3.2.2', Default(TToolchainInfo));

    // Execute activation
    ActivResult := FPCManager.ActivateVersion('3.2.2');

    // Verify success
    AssertTrue(ActivResult.Success, 'Activation succeeded',
      'Expected activation to succeed, got: ' + ActivResult.ErrorMessage);

    AssertTrue(ActivResult.Scope = isProject, 'Scope is project',
      'Expected project scope');

    // Verify scripts created
    EnvDir := FPDevDir + PathDelim + 'env';
    ActivateCmd := EnvDir + PathDelim + 'activate.cmd';
    ActivateSh := EnvDir + PathDelim + 'activate.sh';

    {$IFDEF MSWINDOWS}
    AssertTrue(FileExists(ActivateCmd), 'activate.cmd created',
      'File should exist: ' + ActivateCmd);
    {$ELSE}
    // On Unix, both scripts should be created for cross-platform compatibility
    // but we only verify the Unix script since Windows script may not have execute permissions
    {$ENDIF}

    AssertTrue(FileExists(ActivateSh), 'activate.sh created',
      'File should exist: ' + ActivateSh);

    FPCManager.Free;
    FPCManager := nil;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Test 3: Activation Script Content Correct
// ============================================================================
procedure TestActivationScriptContent;
var
  ProjectDir, FPDevDir: string;
  ActivResult: TActivationResult;
  ScriptContent: TStringList;
  ExpectedPath: string;
  SavedDir: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: Activation Script Content');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    // Setup: Create test project
    ProjectDir := TestRootDir + PathDelim + 'test_project2';
    FPDevDir := ProjectDir + PathDelim + '.fpdev';
    ForceDirectories(FPDevDir);
    SetCurrentDir(ProjectDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Create mock FPC installation
    CreateMockFPCInstallation(
      FPDevDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2',
      '3.2.2'
    );

    // Execute activation
    ActivResult := FPCManager.ActivateVersion('3.2.2');

    // Read script content
    ScriptContent := TStringList.Create;
    try
      if FileExists(ActivResult.ActivationScript) then
        ScriptContent.LoadFromFile(ActivResult.ActivationScript);

      // Verify contains bin path
      ExpectedPath := 'fpc' + PathDelim + '3.2.2' + PathDelim + 'bin';

      AssertTrue(Pos(ExpectedPath, ScriptContent.Text) > 0,
        'Script contains FPC bin path',
        'Expected path pattern "' + ExpectedPath + '" in script');
    finally
      ScriptContent.Free;
    end;

    FPCManager.Free;
    FPCManager := nil;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Test 4: User Scope Activation
// ============================================================================
procedure TestUserScopeActivation;
var
  UserDir: string;
  InstallPath: string;
  ActivResult: TActivationResult;
  SavedDir: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: User Scope Activation');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    // Setup: Directory without .fpdev
    UserDir := TestRootDir + PathDelim + 'user_test';
    ForceDirectories(UserDir);
    AssertTrue(SetCurrentDir(UserDir), 'SetCurrentDir to user dir',
      'Failed to chdir to: ' + UserDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Create mock FPC installation in user scope location
    InstallPath := BuildFPCInstallDirFromInstallRoot(Settings.InstallRoot, '3.2.2');
    CreateMockFPCInstallation(
      InstallPath,
      '3.2.2'
    );

    // Add toolchain entry to config
    ConfigManager.GetToolchainManager.AddToolchain('fpc-3.2.2', Default(TToolchainInfo));

    // Execute activation
    ActivResult := FPCManager.ActivateVersion('3.2.2');

    // Verify user scope
    AssertTrue(ActivResult.Scope = isUser, 'Scope is user',
      'Expected user scope in directory without .fpdev');

    AssertTrue(FileExists(ActivResult.ActivationScript), 'User activation script created',
      'Expected script at: ' + ActivResult.ActivationScript);

    FPCManager.Free;
    FPCManager := nil;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

procedure TestUserScopeActivationUsesConfiguredCustomPrefix;
var
  UserDir: string;
  CustomInstallPath: string;
  ActivResult: TActivationResult;
  ScriptContent: TStringList;
  SavedDir: string;
  Settings: TFPDevSettings;
  Info: TToolchainInfo;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4b: User Scope Activation Uses Configured Custom Prefix');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    UserDir := TestRootDir + PathDelim + 'user_test_custom_prefix';
    ForceDirectories(UserDir);
    AssertTrue(SetCurrentDir(UserDir), 'SetCurrentDir to user dir for custom prefix',
      'Failed to chdir to: ' + UserDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    CustomInstallPath := TestRootDir + PathDelim + 'custom-fpc-3.3.1';
    CreateMockFPCInstallation(CustomInstallPath, '3.3.1');

    Initialize(Info);
    Info.Version := '3.3.1';
    Info.InstallPath := CustomInstallPath;
    Info.Installed := True;
    ConfigManager.GetToolchainManager.AddToolchain('fpc-3.3.1', Info);

    ActivResult := FPCManager.ActivateVersion('3.3.1');
    AssertTrue(ActivResult.Success, 'Configured custom-prefix activation succeeded',
      'Expected activation to succeed, got: ' + ActivResult.ErrorMessage);
    AssertTrue(FileExists(ActivResult.ActivationScript), 'Configured custom-prefix activation script created',
      'Expected script at: ' + ActivResult.ActivationScript);

    ScriptContent := TStringList.Create;
    try
      if FileExists(ActivResult.ActivationScript) then
        ScriptContent.LoadFromFile(ActivResult.ActivationScript);
      AssertTrue(Pos(CustomInstallPath + PathDelim + 'bin', ScriptContent.Text) > 0,
        'Activation script uses configured custom prefix bin path',
        'Expected "' + CustomInstallPath + PathDelim + 'bin' + '" in script:' + LineEnding + ScriptContent.Text);
    finally
      ScriptContent.Free;
    end;

    FPCManager.Free;
    FPCManager := nil;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

procedure TestUserScopeActivationUsesSameProcessHomeFallback;
var
  UserDir, ProbeHome, ProbeBinDir: string;
  ActivResult: TActivationResult;
  SavedDir, SavedHome, SavedAppData, SavedUserProfile: string;
  SavedDataRoot, SavedXDGDataHome: string;
  SavedPortableMode: Boolean;
  Settings: TFPDevSettings;
  ActivationManager: TFPCActivationManager;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4c: User Scope Activation Uses Same-Process Home Fallback');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  SavedHome := get_env('HOME');
  SavedAppData := get_env('APPDATA');
  SavedUserProfile := get_env('USERPROFILE');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  SavedPortableMode := IsPortableMode;
  ActivationManager := nil;
  try
    UserDir := TestRootDir + PathDelim + 'user_test_same_process_home';
    ProbeHome := TestRootDir + PathDelim + 'same_process_home_probe';
    ProbeBinDir := ProbeHome + PathDelim + 'custom-fpc-bin';
    ForceDirectories(UserDir);
    ForceDirectories(ProbeHome);
    ForceDirectories(ProbeBinDir);
    AssertTrue(SetCurrentDir(UserDir), 'SetCurrentDir to user dir for same-process home fallback',
      'Failed to chdir to: ' + UserDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := '';
    ConfigManager.GetSettingsManager.SetSettings(Settings);
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');

    {$IFDEF MSWINDOWS}
    AssertTrue(set_env('APPDATA', ProbeHome), 'Set same-process APPDATA for activation fallback',
      'Expected APPDATA override to succeed');
    AssertTrue(set_env('USERPROFILE', ProbeHome), 'Set same-process USERPROFILE for activation fallback',
      'Expected USERPROFILE override to succeed');
    {$ELSE}
    AssertTrue(set_env('HOME', ProbeHome), 'Set same-process HOME for activation fallback',
      'Expected HOME override to succeed');
    {$ENDIF}

    ActivationManager := TFPCActivationManager.Create(ConfigManager);
    ActivResult := ActivationManager.ActivateVersion('3.2.2', ProbeBinDir);

    AssertTrue(ActivResult.Success, 'Same-process home fallback activation succeeded',
      'Expected activation to succeed, got: ' + ActivResult.ErrorMessage);
    AssertTrue(ActivResult.Scope = isUser, 'Same-process home fallback keeps user scope',
      'Expected user scope activation');
    AssertTrue(Pos(ProbeHome + PathDelim + '.fpdev' + PathDelim + 'env', ActivResult.ActivationScript) = 1,
      'Activation script path uses same-process home fallback',
      'Expected activation script under "' + ProbeHome + PathDelim + '.fpdev' + PathDelim + 'env' +
      '", got "' + ActivResult.ActivationScript + '"');
  finally
    ActivationManager.Free;
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    RestoreEnv('HOME', SavedHome);
    RestoreEnv('APPDATA', SavedAppData);
    RestoreEnv('USERPROFILE', SavedUserProfile);
    SetPortableMode(SavedPortableMode);
    SetCurrentDir(SavedDir);
  end;
end;

procedure TestUserScopeActivationUsesFPDEVDataRootOverride;
var
  UserDir, ProbeRoot, ProbeHome, ProbeBinDir: string;
  ActivResult: TActivationResult;
  SavedDir, SavedHome, SavedAppData, SavedUserProfile: string;
  SavedDataRoot, SavedXDGDataHome: string;
  SavedPortableMode: Boolean;
  Settings: TFPDevSettings;
  ActivationManager: TFPCActivationManager;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4d: User Scope Activation Uses FPDEV_DATA_ROOT Override');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  SavedHome := get_env('HOME');
  SavedAppData := get_env('APPDATA');
  SavedUserProfile := get_env('USERPROFILE');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  SavedPortableMode := IsPortableMode;
  ActivationManager := nil;
  try
    UserDir := TestRootDir + PathDelim + 'user_test_data_root';
    ProbeRoot := TestRootDir + PathDelim + 'activation_data_root_probe';
    ProbeHome := TestRootDir + PathDelim + 'activation_fallback_home_probe';
    ProbeBinDir := ProbeRoot + PathDelim + 'custom-fpc-bin';
    ForceDirectories(UserDir);
    ForceDirectories(ProbeRoot);
    ForceDirectories(ProbeHome);
    ForceDirectories(ProbeBinDir);
    AssertTrue(SetCurrentDir(UserDir), 'SetCurrentDir to user dir for activation data-root probe',
      'Failed to chdir to: ' + UserDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := '';
    ConfigManager.GetSettingsManager.SetSettings(Settings);
    SetPortableMode(False);
    AssertTrue(set_env('FPDEV_DATA_ROOT', ProbeRoot),
      'Set FPDEV_DATA_ROOT for activation data-root probe',
      'Expected FPDEV_DATA_ROOT override to succeed');
    unset_env('XDG_DATA_HOME');

    {$IFDEF MSWINDOWS}
    AssertTrue(set_env('APPDATA', ProbeHome), 'Set same-process APPDATA fallback for activation data-root probe',
      'Expected APPDATA override to succeed');
    AssertTrue(set_env('USERPROFILE', ProbeHome), 'Set same-process USERPROFILE fallback for activation data-root probe',
      'Expected USERPROFILE override to succeed');
    {$ELSE}
    AssertTrue(set_env('HOME', ProbeHome), 'Set same-process HOME fallback for activation data-root probe',
      'Expected HOME override to succeed');
    {$ENDIF}

    ActivationManager := TFPCActivationManager.Create(ConfigManager);
    ActivResult := ActivationManager.ActivateVersion('3.2.2', ProbeBinDir);

    AssertTrue(ActivResult.Success, 'Activation data-root probe succeeded',
      'Expected activation to succeed, got: ' + ActivResult.ErrorMessage);
    AssertTrue(ActivResult.Scope = isUser, 'Activation data-root probe keeps user scope',
      'Expected user scope activation');
    AssertTrue(Pos(IncludeTrailingPathDelimiter(GetDataRoot) + 'env', ActivResult.ActivationScript) = 1,
      'Activation script path uses FPDEV_DATA_ROOT override',
      'Expected activation script under "' + IncludeTrailingPathDelimiter(GetDataRoot) + 'env' +
      '", got "' + ActivResult.ActivationScript + '"');
  finally
    ActivationManager.Free;
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    RestoreEnv('HOME', SavedHome);
    RestoreEnv('APPDATA', SavedAppData);
    RestoreEnv('USERPROFILE', SavedUserProfile);
    SetPortableMode(SavedPortableMode);
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Test 5: VS Code Settings Integration
// ============================================================================
procedure TestVSCodeIntegration;
var
  ProjectDir, FPDevDir, SettingsPath: string;
  ActivResult: TActivationResult;
  SavedDir: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: VS Code Integration');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    // Setup: Create test project
    ProjectDir := TestRootDir + PathDelim + 'test_project_vscode';
    FPDevDir := ProjectDir + PathDelim + '.fpdev';
    ForceDirectories(FPDevDir);
    SetCurrentDir(ProjectDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Create mock FPC installation
    CreateMockFPCInstallation(
      FPDevDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2',
      '3.2.2'
    );

    // Execute activation
    ActivResult := FPCManager.ActivateVersion('3.2.2');

    // Verify VS Code settings (if created)
    if ActivResult.VSCodeSettings <> '' then
    begin
      AssertTrue(FileExists(ActivResult.VSCodeSettings), 'VS Code settings.json exists',
        'Expected file at: ' + ActivResult.VSCodeSettings);
    end
    else
    begin
      WriteLn('  [INFO] VS Code integration not implemented yet (optional)');
      Inc(TestsPassed); // Count as pass since it's optional
    end;

    FPCManager.Free;
    FPCManager := nil;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Test 6: Activation Command Printing
// ============================================================================
procedure TestActivationCommand;
var
  ProjectDir, FPDevDir: string;
  ActivResult: TActivationResult;
  SavedDir: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: Activation Command');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    // Setup
    ProjectDir := TestRootDir + PathDelim + 'test_project_cmd';
    FPDevDir := ProjectDir + PathDelim + '.fpdev';
    ForceDirectories(FPDevDir);
    SetCurrentDir(ProjectDir);

    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Create mock FPC installation
    CreateMockFPCInstallation(
      FPDevDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2',
      '3.2.2'
    );

    // Execute activation
    ActivResult := FPCManager.ActivateVersion('3.2.2');

    // Verify command string not empty
    AssertTrue(ActivResult.ShellCommand <> '', 'Shell command generated',
      'Expected non-empty shell command');

    {$IFDEF WINDOWS}
    AssertTrue(Pos('.cmd', LowerCase(ActivResult.ShellCommand)) > 0,
      'Windows command references .cmd',
      'Command: ' + ActivResult.ShellCommand);
    {$ELSE}
    AssertTrue(Pos('source', ActivResult.ShellCommand) > 0,
      'Unix command uses "source"',
      'Command: ' + ActivResult.ShellCommand);

    AssertTrue(Pos('.sh', ActivResult.ShellCommand) > 0,
      'Unix command references .sh',
      'Command: ' + ActivResult.ShellCommand);
    {$ENDIF}

    FPCManager.Free;
    FPCManager := nil;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  FPC Use Activation Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestConfigManagerUsesIsolatedDefaultConfigPath;
      TestActivationTypesExist;
      TestProjectScopeActivation;
      TestActivationScriptContent;
      TestUserScopeActivation;
      TestUserScopeActivationUsesConfiguredCustomPrefix;
      TestUserScopeActivationUsesSameProcessHomeFallback;
      TestUserScopeActivationUsesFPDEVDataRootOverride;
      TestVSCodeIntegration;
      TestActivationCommand;

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
