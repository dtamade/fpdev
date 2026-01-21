program test_lazarus_update;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.cmd.lazarus, fpdev.config.interfaces, fpdev.config.managers, fpdev.git2;

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
  TestRootDir := GetTempDir + 'test_lazarus_update_' + IntToStr(GetTickCount64);
  ForceDirectories(TestRootDir);

  // Initialize config manager
  ConfigManager := TConfigManager.Create('');
  ConfigManager.LoadConfig;

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
  if DirectoryExists(TestRootDir) then
    DeleteDirectory(TestRootDir);

  if Assigned(LazarusManager) then
    LazarusManager.Free;

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

// ============================================================================
// Test 1: UpdateSources pulls latest source code
// ============================================================================
procedure TestUpdatePullsLatestSource;
var
  SourceDir: string;
  GitManager: TGitManager;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: UpdateSources Pulls Latest Source Code');
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

    // Assert: UpdateSources should execute git pull and return true
    AssertTrue(Success, 'UpdateSources executes git pull',
      'UpdateSources should pull latest source code from git repository');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources succeeds', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: UpdateSources handles git conflicts gracefully
// ============================================================================
procedure TestUpdateHandlesConflicts;
var
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: UpdateSources Handles Git Conflicts');
  WriteLn('==================================================');

  try
    // Setup: Create a source directory without .git (simulating conflict scenario)
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-conflict';
    ForceDirectories(SourceDir);

    // Create some modified files that would conflict
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
    AssertFalse(Success, 'UpdateSources detects conflict',
      'UpdateSources should return false when git repository is invalid');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources handles conflicts', 'Exception: ' + E.Message);
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
      TestUpdatePullsLatestSource;
      TestUpdateHandlesConflicts;
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
