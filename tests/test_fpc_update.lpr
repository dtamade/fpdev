program test_fpc_update;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes, fpdev.fpc.manager, fpdev.config.interfaces, fpdev.config.managers, Process;

var
  TestInstallRoot: string;
  TestSourceDir: string;
  ConfigManager: IConfigManager;
  FPCManager: TFPCManager;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  // Create temporary install root directory
  TestInstallRoot := IncludeTrailingPathDelimiter(GetTempDir(False))
    + 'test_install_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  // Set configuration manager to use test directory
  SettingsMgr := ConfigManager.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  SettingsMgr.SetSettings(Settings);

  WriteLn('[Setup] Created test install root: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
var
  SR: TSearchRec;

  procedure DeleteDirectory(const DirPath: string);
  var
    SR2: TSearchRec;
    FilePath2: string;
  begin
    if not DirectoryExists(DirPath) then Exit;

    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR2) = 0 then
    begin
      repeat
        if (SR2.Name <> '.') and (SR2.Name <> '..') then
        begin
          FilePath2 := DirPath + PathDelim + SR2.Name;
          if (SR2.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath2)
          else
            DeleteFile(FilePath2);
        end;
      until FindNext(SR2) <> 0;
      FindClose(SR2);
    end;
    RemoveDir(DirPath);
  end;

begin
  // Clean up test install root directory (including all subdirectories)
  if DirectoryExists(TestInstallRoot) then
  begin
    DeleteDirectory(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
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

  if Pos(TempRoot, ConfigPath) <> 1 then
  begin
    WriteLn('Failed: Expected config path under temp root ', TempRoot);
    WriteLn('Actual: ', ConfigPath);
    Halt(1);
  end;

  if ConfigPath <> ExpectedPath then
  begin
    WriteLn('Failed: Expected isolated config path ', ExpectedPath);
    WriteLn('Actual: ', ConfigPath);
    Halt(1);
  end;

  WriteLn('Passed: Config manager uses isolated temp config path');
end;

procedure TestUpdateNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources handles non-existent directory');
  WriteLn('==================================================');

  // Execute update on non-existent version
  Success := FPCManager.UpdateSources('nonexistent-version-999');

  if Success then
  begin
    WriteLn('Failed: UpdateSources should return False for non-existent version');
    Halt(1);
  end;

  WriteLn('Passed: Correctly handles non-existent version');
end;

procedure TestUpdateNonGitDirectory;
var
  EmptySourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources handles non-git directory');
  WriteLn('==================================================');

  // Create empty source directory (in correct location)
  EmptySourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-empty';
  ForceDirectories(EmptySourceDir);

  try
    // Execute update on non-git directory
    Success := FPCManager.UpdateSources('empty');

    if Success then
    begin
      WriteLn('Failed: UpdateSources should return False for non-git directory');
      Halt(1);
    end;

    WriteLn('Passed: Correctly handles non-git directory');
  finally
    RemoveDir(EmptySourceDir);
  end;
end;

procedure TestUpdateValidGitRepository;
var
  TestSourceDir: string;
  GitDir: string;
  Process: TProcess;
  TestFile: TextFile;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources updates valid git repository');
  WriteLn('==================================================');

  // Create FPC source directory structure: InstallRoot/sources/fpc/fpc-testver
  TestSourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-testver';
  ForceDirectories(TestSourceDir);

  try
    // Initialize a local git repository for testing
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('init');
      Process.CurrentDirectory := TestSourceDir;
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;

      if Process.ExitStatus <> 0 then
      begin
        WriteLn('Failed: Could not initialize git repository for testing');
        Halt(1);
      end;
    finally
      Process.Free;
    end;

    // Create a test file and commit it
    AssignFile(TestFile, TestSourceDir + PathDelim + 'test.txt');
    Rewrite(TestFile);
    WriteLn(TestFile, 'Initial version');
    CloseFile(TestFile);

    // Configure git user (required for commits)
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('config');
      Process.Parameters.Add('user.email');
      Process.Parameters.Add('test@example.com');
      Process.CurrentDirectory := TestSourceDir;
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;
    finally
      Process.Free;
    end;

    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('config');
      Process.Parameters.Add('user.name');
      Process.Parameters.Add('Test User');
      Process.CurrentDirectory := TestSourceDir;
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;
    finally
      Process.Free;
    end;

    // Add and commit the file
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('add');
      Process.Parameters.Add('.');
      Process.CurrentDirectory := TestSourceDir;
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;
    finally
      Process.Free;
    end;

    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('commit');
      Process.Parameters.Add('-m');
      Process.Parameters.Add('Initial commit');
      Process.CurrentDirectory := TestSourceDir;
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;

      if Process.ExitStatus <> 0 then
      begin
        WriteLn('Failed: Could not create initial commit for testing');
        Halt(1);
      end;
    finally
      Process.Free;
    end;

    // Now test UpdateSources - should succeed (no-op since no remote configured)
    Success := FPCManager.UpdateSources('testver');

    if not Success then
    begin
      WriteLn('Failed: UpdateSources should return True for valid git repository');
      Halt(1);
    end;

    WriteLn('Passed: UpdateSources works with valid git repository');

  finally
    // Cleanup is handled by TeardownTestEnvironment
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC Update Functionality Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize configuration manager
    ConfigManager := CreateIsolatedConfigManager;

    TestConfigManagerUsesIsolatedDefaultConfigPath;

    // Setup test environment (before creating FPCManager)
    SetupTestEnvironment;
    try
      // Create FPC manager (will use updated configuration)
      FPCManager := TFPCManager.Create(ConfigManager);
      try
        // Test 1: Handle non-existent directory
        TestUpdateNonExistentDirectory;

        // Test 2: Handle non-git directory
        TestUpdateNonGitDirectory;

        // Test 3: Update valid git repository
        TestUpdateValidGitRepository;

        WriteLn;
        WriteLn('========================================');
        WriteLn('  All tests passed');
        WriteLn('========================================');
        ExitCode := 0;

      finally
        FPCManager.Free;
      end;
    finally
      TeardownTestEnvironment;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite failed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
