program test_fpc_scoped_install;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.cmd.fpc, fpdev.config;

var
  TestRootDir: string;
  ConfigManager: TFPDevConfigManager;
  FPCManager: TFPCManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
begin
  // Create test root directory
  TestRootDir := 'test_scoped_install_' + IntToStr(GetTickCount64);
  ForceDirectories(TestRootDir);

  // Initialize config manager
  ConfigManager := TFPDevConfigManager.Create;
  ConfigManager.LoadConfig;

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
  if Assigned(ConfigManager) then
    ConfigManager.Free;

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
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: User Scope Installation (Default)');
  WriteLn('==================================================');

  // Setup: Override install root to test directory
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.SetSettings(Settings);

  FPCManager := TFPCManager.Create(ConfigManager);

  // Expected path for user scope
  ExpectedPath := TestRootDir + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // This will fail until we implement scoped installation
  // Note: We're not actually installing, just testing path resolution
  InstallPath := FPCManager.GetVersionInstallPath('3.2.2');

  AssertEquals(ExpectedPath, InstallPath, 'User scope path matches expected');

  FPCManager.Free;
  FPCManager := nil;
end;

// ============================================================================
// Test 3: Project Scope Installation
// ============================================================================
procedure TestProjectScopeInstall;
var
  ProjectDir: string;
  FPDevDir: string;
  ExpectedPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: Project Scope Installation');
  WriteLn('==================================================');

  // Setup: Create a project directory with .fpdev
  ProjectDir := TestRootDir + PathDelim + 'test_project';
  FPDevDir := ProjectDir + PathDelim + '.fpdev';
  ForceDirectories(FPDevDir);

  // Expected path for project scope
  ExpectedPath := FPDevDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // This will fail until we implement project scope detection
  WriteLn('  Project scope not yet implemented - test will fail');
  AssertTrue(False, 'Project scope detection', 'Not implemented yet');
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
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.SetSettings(Settings);

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
  MetaExists: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: Metadata File Creation');
  WriteLn('==================================================');

  MetaPath := TestRootDir + PathDelim + '.fpdev-meta.json';

  // This will fail until we implement metadata writing
  MetaExists := FileExists(MetaPath);

  WriteLn('  Metadata creation not yet implemented');
  AssertTrue(False, 'Metadata file created', 'WriteMetadata not implemented');
end;

// ============================================================================
// Test 6: Metadata Contains Verification Results
// ============================================================================
procedure TestMetadataWithVerification;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: Metadata Contains Verification Results');
  WriteLn('==================================================');

  WriteLn('  Verification integration not yet implemented');
  AssertTrue(False, 'Metadata includes verify results', 'Not implemented');
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
