program test_lazarus_clean;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes, fpdev.lazarus.manager, fpdev.config.interfaces, fpdev.config.managers,
  test_temp_paths
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF};

var
  TestRootDir: string;
  TestSourceDir: string;
  ConfigManager: IConfigManager;
  LazarusManager: fpdev.lazarus.manager.TLazarusManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  // Create test root directory in temp
  TestRootDir := CreateUniqueTempDir('test_lazarus_clean');
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
  LazarusManager := fpdev.lazarus.manager.TLazarusManager.Create(ConfigManager);

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
// Test 1: CleanSources removes build artifacts
// ============================================================================
procedure TestCleanRemovesBuildArtifacts;
var
  ComponentsDir, LCLDir: string;
  TestFile: TextFile;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: CleanSources Removes Build Artifacts');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus source directory structure
    TestSourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.0';
    ForceDirectories(TestSourceDir);

    // Create typical Lazarus directory structure
    ComponentsDir := TestSourceDir + PathDelim + 'components';
    LCLDir := TestSourceDir + PathDelim + 'lcl';
    ForceDirectories(ComponentsDir);
    ForceDirectories(LCLDir);
    ForceDirectories(TestSourceDir + PathDelim + 'ide');
    ForceDirectories(TestSourceDir + PathDelim + 'packager');
    ForceDirectories(TestSourceDir + PathDelim + 'debugger');

    // Create build artifacts that should be deleted
    // Object files (.o)
    AssignFile(TestFile, ComponentsDir + PathDelim + 'component1.o');
    Rewrite(TestFile);
    WriteLn(TestFile, 'dummy object file');
    CloseFile(TestFile);

    // Unit files (.ppu)
    AssignFile(TestFile, LCLDir + PathDelim + 'forms.ppu');
    Rewrite(TestFile);
    WriteLn(TestFile, 'dummy unit file');
    CloseFile(TestFile);

    // Compiled marker files (.compiled)
    AssignFile(TestFile, ComponentsDir + PathDelim + 'component1.compiled');
    Rewrite(TestFile);
    WriteLn(TestFile, '<?xml version="1.0"?>');
    CloseFile(TestFile);

    // Resource string files (.rst, .rsj)
    AssignFile(TestFile, LCLDir + PathDelim + 'forms.rst');
    Rewrite(TestFile);
    WriteLn(TestFile, 'dummy resource string');
    CloseFile(TestFile);

    AssignFile(TestFile, LCLDir + PathDelim + 'forms.rsj');
    Rewrite(TestFile);
    WriteLn(TestFile, '{}');
    CloseFile(TestFile);

    // Executable (platform-specific)
    {$IFDEF MSWINDOWS}
    AssignFile(TestFile, TestSourceDir + PathDelim + 'lazarus.exe');
    Rewrite(TestFile);
    WriteLn(TestFile, 'dummy executable');
    CloseFile(TestFile);
    {$ELSE}
    AssignFile(TestFile, TestSourceDir + PathDelim + 'lazarus');
    Rewrite(TestFile);
    WriteLn(TestFile, 'dummy executable');
    CloseFile(TestFile);
    // Set execute permission on Unix
    FpChmod(TestSourceDir + PathDelim + 'lazarus', &755);
    {$ENDIF}

    // Create source files that should be preserved
    // Pascal source files (.pas)
    AssignFile(TestFile, ComponentsDir + PathDelim + 'component1.pas');
    Rewrite(TestFile);
    WriteLn(TestFile, 'unit component1; interface implementation end.');
    CloseFile(TestFile);

    // Lazarus form files (.lfm)
    AssignFile(TestFile, LCLDir + PathDelim + 'forms.lfm');
    Rewrite(TestFile);
    WriteLn(TestFile, 'object Form1: TForm1');
    CloseFile(TestFile);

    // Lazarus program file (.lpr)
    AssignFile(TestFile, TestSourceDir + PathDelim + 'lazarus.lpr');
    Rewrite(TestFile);
    WriteLn(TestFile, 'program lazarus; begin end.');
    CloseFile(TestFile);

    // Lazarus project file (.lpi)
    AssignFile(TestFile, TestSourceDir + PathDelim + 'lazarus.lpi');
    Rewrite(TestFile);
    WriteLn(TestFile, '<?xml version="1.0"?><CONFIG></CONFIG>');
    CloseFile(TestFile);

    // Makefile
    AssignFile(TestFile, TestSourceDir + PathDelim + 'Makefile');
    Rewrite(TestFile);
    WriteLn(TestFile, 'all:');
    WriteLn(TestFile, #9'@echo "Building Lazarus"');
    CloseFile(TestFile);

    // Execute: Call CleanSources
    Success := LazarusManager.CleanSources('3.0');

    // Assert: CleanSources should execute successfully
    AssertTrue(Success, 'CleanSources returns true',
      'CleanSources should return true on successful cleanup');

    // Assert: Build artifacts should be deleted
    AssertFalse(FileExists(ComponentsDir + PathDelim + 'component1.o'),
      'Object file (.o) deleted',
      'Object files should be removed by CleanSources');

    AssertFalse(FileExists(LCLDir + PathDelim + 'forms.ppu'),
      'Unit file (.ppu) deleted',
      'Unit files should be removed by CleanSources');

    AssertFalse(FileExists(ComponentsDir + PathDelim + 'component1.compiled'),
      'Compiled marker (.compiled) deleted',
      'Compiled marker files should be removed by CleanSources');

    AssertFalse(FileExists(LCLDir + PathDelim + 'forms.rst'),
      'Resource string file (.rst) deleted',
      'Resource string files should be removed by CleanSources');

    AssertFalse(FileExists(LCLDir + PathDelim + 'forms.rsj'),
      'Resource JSON file (.rsj) deleted',
      'Resource JSON files should be removed by CleanSources');

    {$IFDEF MSWINDOWS}
    AssertFalse(FileExists(TestSourceDir + PathDelim + 'lazarus.exe'),
      'Executable (.exe) deleted',
      'Executables should be removed by CleanSources');
    {$ELSE}
    AssertFalse(FileExists(TestSourceDir + PathDelim + 'lazarus'),
      'Executable deleted',
      'Executables should be removed by CleanSources');
    {$ENDIF}

    // Assert: Source files should be preserved
    AssertTrue(FileExists(ComponentsDir + PathDelim + 'component1.pas'),
      'Pascal source file (.pas) preserved',
      'Pascal source files should not be removed by CleanSources');

    AssertTrue(FileExists(LCLDir + PathDelim + 'forms.lfm'),
      'Lazarus form file (.lfm) preserved',
      'Lazarus form files should not be removed by CleanSources');

    AssertTrue(FileExists(TestSourceDir + PathDelim + 'lazarus.lpr'),
      'Lazarus program file (.lpr) preserved',
      'Lazarus program files should not be removed by CleanSources');

    AssertTrue(FileExists(TestSourceDir + PathDelim + 'lazarus.lpi'),
      'Lazarus project file (.lpi) preserved',
      'Lazarus project files should not be removed by CleanSources');

    AssertTrue(FileExists(TestSourceDir + PathDelim + 'Makefile'),
      'Makefile preserved',
      'Makefile should not be removed by CleanSources');

  except
    on E: Exception do
      AssertTrue(False, 'Test completes without exception', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: CleanSources handles non-existent directory
// ============================================================================
procedure TestCleanHandlesNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: CleanSources Handles Non-Existent Directory');
  WriteLn('==================================================');

  try
    // Execute: Call CleanSources on non-existent version
    Success := LazarusManager.CleanSources('nonexistent-999');

    // Assert: CleanSources should return false for non-existent directory
    AssertFalse(Success, 'CleanSources returns false for non-existent directory',
      'CleanSources should gracefully handle non-existent directories');

  except
    on E: Exception do
      AssertTrue(False, 'Test handles non-existent directory', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: CleanSources rejects invalid source directory
// ============================================================================
procedure TestCleanRejectsInvalidSourceDirectory;
var
  EmptySourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: CleanSources Rejects Invalid Source Directory');
  WriteLn('==================================================');

  try
    // Setup: Create empty Lazarus source directory without ide/lcl/packager
    EmptySourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-empty';
    ForceDirectories(EmptySourceDir);

    // Execute: Call CleanSources on invalid directory
    Success := LazarusManager.CleanSources('empty');

    // Assert: CleanSources should reject invalid directory
    AssertFalse(Success, 'CleanSources rejects invalid source directory',
      'CleanSources should fail for directory without ide/lcl/packager');

    // Assert: Directory should still exist (not deleted)
    AssertTrue(DirectoryExists(EmptySourceDir),
      'Invalid directory still exists after rejected clean',
      'CleanSources should not delete the source directory itself on rejection');

  except
    on E: Exception do
      AssertTrue(False, 'Test rejects invalid source directory', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Lazarus Clean Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestConfigManagerUsesIsolatedDefaultConfigPath;
      TestCleanRemovesBuildArtifacts;
      TestCleanHandlesNonExistentDirectory;
      TestCleanRejectsInvalidSourceDirectory;

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
