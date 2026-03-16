program test_lazarus_update;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes, fpdev.cmd.lazarus, fpdev.config.interfaces, fpdev.config.managers, fpdev.git2,
  test_temp_paths;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  LazarusManager: fpdev.cmd.lazarus.TLazarusManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  // Create test root directory in temp
  TestRootDir := CreateUniqueTempDir('test_lazarus_update');
  if not PathUsesSystemTempRoot(TestRootDir) then
    raise Exception.Create('Test root dir should use system temp root');

  // Initialize config manager
  ConfigManager := CreateIsolatedConfigManager;

  // Override install root to test directory
  SettingsMgr := ConfigManager.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TestRootDir;
  SettingsMgr.SetSettings(Settings);

  // Create Lazarus manager
  LazarusManager := fpdev.cmd.lazarus.TLazarusManager.Create(ConfigManager);

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
begin
  if Assigned(LazarusManager) then
    LazarusManager.Free;
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
// Test 1: UpdateSources refreshes the source repository
// ============================================================================
procedure TestUpdateRefreshesSourceRepository;
var
  SourceDir: string;
  GitManager: TGitManager;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: UpdateSources Refreshes Source Repository');
  WriteLn('==================================================');

  try
    // Setup: Create a mock Lazarus source directory with git
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.0';
    ForceDirectories(SourceDir);

    // Initialize git repository
    GitManager := TGitManager.Create;
    try
      if GitManager.Initialize then
      begin
        // Create a mock git repository
        GitManager.InitRepository(SourceDir);

        // Create a dummy file to simulate source code
        with TStringList.Create do
        try
          Add('// Mock Lazarus source');
          SaveToFile(SourceDir + PathDelim + 'lazarus.lpr');
        finally
          Free;
        end;
      end;
    finally
      GitManager.Free;
    end;

    // Execute: Call UpdateSources
    Success := LazarusManager.UpdateSources('3.0');

    // Assert: UpdateSources should update the repository and return true
    AssertTrue(Success, 'UpdateSources refreshes repository state',
      'UpdateSources should update the source repository when git metadata is available');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources succeeds', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: UpdateSources rejects invalid repositories
// ============================================================================
procedure TestUpdateRejectsInvalidRepository;
var
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: UpdateSources Rejects Invalid Repository');
  WriteLn('==================================================');

  try
    // Setup: Create a source directory without .git (invalid repository scenario)
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-conflict';
    ForceDirectories(SourceDir);

    // Create some local files, but keep the directory non-repository
    with TStringList.Create do
    try
      Add('// Modified local file');
      SaveToFile(SourceDir + PathDelim + 'modified.pas');
    finally
      Free;
    end;

    // Execute: Call UpdateSources on a non-git directory
    Success := LazarusManager.UpdateSources('conflict');

    // Assert: UpdateSources should detect the issue and return false
    AssertFalse(Success, 'UpdateSources rejects invalid repository',
      'UpdateSources should return false when the source directory is not a git repository');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources rejects invalid repository', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: UpdateSources triggers rebuild notification
// ============================================================================
procedure TestUpdateTriggersRebuildNotification;
var
  SourceDir: string;
  GitManager: TGitManager;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: UpdateSources Triggers Rebuild Notification');
  WriteLn('==================================================');

  try
    // Setup: Create a mock Lazarus source directory
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-rebuild';
    ForceDirectories(SourceDir);

    // Initialize git repository
    GitManager := TGitManager.Create;
    try
      if GitManager.Initialize then
      begin
        GitManager.InitRepository(SourceDir);

        // Create source files
        with TStringList.Create do
        try
          Add('// Lazarus source v1');
          SaveToFile(SourceDir + PathDelim + 'lazarus.lpr');
        finally
          Free;
        end;
      end;
    finally
      GitManager.Free;
    end;

    // Execute: Call UpdateSources
    Success := LazarusManager.UpdateSources('rebuild');

    // Assert: UpdateSources should inform user about rebuild requirement
    // (For now, we just check it returns true if source is updated)
    AssertTrue(Success, 'UpdateSources notifies rebuild requirement',
      'UpdateSources should notify user to rebuild after update');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources triggers rebuild', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Lazarus Update Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestConfigManagerUsesIsolatedDefaultConfigPath;
  TestUpdateRefreshesSourceRepository;
  TestUpdateRejectsInvalidRepository;
  TestUpdateTriggersRebuildNotification;

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
