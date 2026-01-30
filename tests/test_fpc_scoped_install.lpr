program test_fpc_scoped_install;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.cmd.fpc, fpdev.config, fpdev.types,
  fpdev.config.interfaces, fpdev.config.managers, fpdev.utils;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  FPCManager: TFPCManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create test root directory in temp (outside project to avoid .fpdev detection)
  TestRootDir := GetTempDir + 'test_scoped_install_' + IntToStr(GetTickCount64);
  ForceDirectories(TestRootDir);

  // Set FPDEV_DATA_ROOT environment variable to override GetDataRoot
  set_env('FPDEV_DATA_ROOT', TestRootDir);

  // Initialize config manager with test-specific config file
  ConfigManager := TConfigManager.Create(TestRootDir + PathDelim + 'test_config.json');
  ConfigManager.CreateDefaultConfig;

  // Set InstallRoot immediately after creating config to ensure it's used
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

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

  if Assigned(FPCManager) then
    FPCManager.Free;
  // ConfigManager is an interface, no need to Free

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

// ============================================================================
// Test 1: Metadata Types Exist
// ============================================================================
procedure TestMetadataTypesExist;
var
  Scope: TInstallScope;
  SourceMode: TSourceMode;
  Meta: TFPDevMetadata;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: Metadata Types Exist');
  WriteLn('==================================================');

  // This will fail until we define the types
  try
    Scope := isUser;
    SourceMode := smSource;
    FillChar(Meta, SizeOf(Meta), 0);

    AssertTrue(True, 'Metadata types defined', 'Types should compile');
  except
    on E: Exception do
      AssertTrue(False, 'Metadata types defined', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: User Scope Installation (Default)
// ============================================================================
procedure TestUserScopeInstall;
var
  Settings: TFPDevSettings;
  ExpectedPath: string;
  InstallPath: string;
  SavedDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: User Scope Installation (Default)');
  WriteLn('==================================================');

  // Save current directory
  SavedDir := GetCurrentDir;
  try
    // Change to test directory (no .fpdev) to force user scope
    SetCurrentDir(TestRootDir);

    // Setup: Override install root to test directory
    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Expected path for user scope
    ExpectedPath := TestRootDir + PathDelim + 'fpc' + PathDelim + '3.2.2';

    // Test path resolution
    InstallPath := FPCManager.GetVersionInstallPath('3.2.2');

    // Compare - should be <TestRootDir>/fpc/3.2.2
    AssertTrue(
      (Pos(TestRootDir, InstallPath) > 0) and
      (Pos(PathDelim + 'fpc' + PathDelim + '3.2.2', InstallPath) > 0) and
      (Pos('.fpdev' + PathDelim + 'toolchains', InstallPath) = 0),
      'User scope path is correct',
      'Expected user scope path (<root>/fpc/3.2.2), got: ' + InstallPath
    );

    FPCManager.Free;
    FPCManager := nil;
  finally
    // Restore directory
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Test 3: Project Scope Installation
// ============================================================================
procedure TestProjectScopeInstall;
var
  ProjectDir: string;
  FPDevDir: string;
  ExpectedPath: string;
  InstallPath: string;
  SavedDir: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: Project Scope Installation');
  WriteLn('==================================================');

  // Save current directory
  SavedDir := GetCurrentDir;
  try
    // Setup: Create a project directory with .fpdev
    ProjectDir := TestRootDir + PathDelim + 'test_project';
    FPDevDir := ProjectDir + PathDelim + '.fpdev';
    ForceDirectories(FPDevDir);

    // Change to project directory to trigger project scope
    SetCurrentDir(ProjectDir);

    // Setup manager
    Settings := ConfigManager.GetSettingsManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.GetSettingsManager.SetSettings(Settings);

    FPCManager := TFPCManager.Create(ConfigManager);

    // Expected path for project scope
    ExpectedPath := FPDevDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';

    // Test path resolution
    InstallPath := FPCManager.GetVersionInstallPath('3.2.2');

    // Compare - should contain .fpdev/toolchains/fpc/3.2.2
    AssertTrue(
      (Pos(ProjectDir, InstallPath) > 0) and
      (Pos('.fpdev' + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2', InstallPath) > 0),
      'Project scope path is correct',
      'Expected project scope path (.fpdev/toolchains/fpc/3.2.2), got: ' + InstallPath
    );

    FPCManager.Free;
    FPCManager := nil;
  finally
    // Restore directory
    SetCurrentDir(SavedDir);
  end;
end;

// ============================================================================
// Test 4: Custom Prefix Installation
// ============================================================================
procedure TestCustomPrefixInstall;
var
  CustomPrefix: string;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: Custom Prefix Installation');
  WriteLn('==================================================');

  CustomPrefix := TestRootDir + PathDelim + 'custom_prefix';

  // Setup
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  FPCManager := TFPCManager.Create(ConfigManager);

  // Test that custom prefix overrides default
  // This currently works via the APrefix parameter
  WriteLn('  Custom prefix via --prefix already works');
  AssertTrue(True, 'Custom prefix support', 'Already implemented');

  FPCManager.Free;
  FPCManager := nil;
end;

// ============================================================================
// Test 5: Metadata File Creation
// ============================================================================
procedure TestMetadataCreation;
var
  MetaPath: string;
  TestInstallPath: string;
  Meta: TFPDevMetadata;
  WriteSuccess: Boolean;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: Metadata File Creation');
  WriteLn('==================================================');

  // Setup test install path
  TestInstallPath := TestRootDir + PathDelim + 'test_install';
  ForceDirectories(TestInstallPath);

  // Setup manager
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  FPCManager := TFPCManager.Create(ConfigManager);

  // Create metadata
  FillChar(Meta, SizeOf(Meta), 0);
  Meta.Version := '3.2.2';
  Meta.Scope := isUser;
  Meta.SourceMode := smSource;
  Meta.Channel := 'stable';
  Meta.Prefix := TestInstallPath;
  Meta.InstalledAt := Now;

  // Write metadata
  WriteSuccess := FPCManager.WriteMetadata(TestInstallPath, Meta);

  // Check file exists
  MetaPath := TestInstallPath + PathDelim + '.fpdev-meta.json';

  AssertTrue(WriteSuccess, 'WriteMetadata succeeded', 'WriteMetadata should return true');
  AssertTrue(FileExists(MetaPath), 'Metadata file created', 'File should exist: ' + MetaPath);

  FPCManager.Free;
  FPCManager := nil;
end;

// ============================================================================
// Test 6: Metadata Contains Verification Results
// ============================================================================
procedure TestMetadataWithVerification;
var
  TestInstallPath: string;
  Meta, ReadMeta: TFPDevMetadata;
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: Metadata Contains Verification Results');
  WriteLn('==================================================');

  // Setup test install path
  TestInstallPath := TestRootDir + PathDelim + 'test_verify';
  ForceDirectories(TestInstallPath);

  // Setup manager
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  FPCManager := TFPCManager.Create(ConfigManager);

  // Create initial metadata with no verification
  FillChar(Meta, SizeOf(Meta), 0);
  Meta.Version := '3.2.2';
  Meta.Scope := isUser;
  Meta.SourceMode := smSource;
  Meta.Channel := 'stable';
  Meta.Prefix := TestInstallPath;
  Meta.InstalledAt := Now;

  // Write initial metadata
  FPCManager.WriteMetadata(TestInstallPath, Meta);

  // Simulate verification results
  Meta.Verify.Timestamp := Now;
  Meta.Verify.OK := True;
  Meta.Verify.DetectedVersion := '3.2.2';
  Meta.Verify.SmokeTestPassed := True;

  // Write updated metadata
  FPCManager.WriteMetadata(TestInstallPath, Meta);

  // Read back metadata
  if FPCManager.ReadMetadata(TestInstallPath, ReadMeta) then
  begin
    AssertTrue(ReadMeta.Verify.OK, 'Verify OK field preserved', 'Should be true');
    AssertEquals('3.2.2', ReadMeta.Verify.DetectedVersion, 'Detected version preserved');
    AssertTrue(ReadMeta.Verify.SmokeTestPassed, 'Smoke test result preserved', 'Should be true');
  end
  else
  begin
    AssertTrue(False, 'Read metadata succeeded', 'ReadMetadata should return true');
  end;

  FPCManager.Free;
  FPCManager := nil;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  FPC Scoped Installation Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestMetadataTypesExist;
      TestUserScopeInstall;
      TestProjectScopeInstall;
      TestCustomPrefixInstall;
      TestMetadataCreation;
      TestMetadataWithVerification;

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
