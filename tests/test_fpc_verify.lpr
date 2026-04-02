program test_fpc_verify;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes, Process, fpdev.fpc.manager, fpdev.config,
  fpdev.types, fpdev.fpc.validator, fpdev.fpc.metadata, fpdev.fpc.types,
  fpdev.config.interfaces, fpdev.config.managers, fpdev.paths, test_temp_paths;

var
  TestInstallRoot: string;
  TestFPCInstallDir: string;
  ConfigManager: IConfigManager;
  FPCManager: TFPCManager;

procedure CompileMockFPCExecutable(const ATargetPath: string);
var
  MockFPCSource: string;
  CompileProcess: TProcess;
begin
  MockFPCSource := ExtractFileDir(ParamStr(0)) + PathDelim + '..' + PathDelim +
    'tests' + PathDelim + 'mock_fpc.pas';

  CompileProcess := TProcess.Create(nil);
  try
    CompileProcess.Executable := 'fpc';
    CompileProcess.Parameters.Add('-o' + ATargetPath);
    CompileProcess.Parameters.Add(MockFPCSource);
    CompileProcess.Options := CompileProcess.Options + [poWaitOnExit];
    CompileProcess.Execute;

    if CompileProcess.ExitStatus <> 0 then
      raise Exception.Create('Failed to compile mock FPC executable');
  finally
    CompileProcess.Free;
  end;
end;

procedure SetupTestEnvironment;
var
  TestFile: TextFile;
  Settings: TFPDevSettings;
  HelloPas: string;
  MockFPCTarget: string;
begin
  // Create temporary install root directory
  TestInstallRoot := CreateUniqueTempDir('test_install_root');

  // Setup config manager to use test directory
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  // Create FPC install structure: InstallRoot/toolchains/fpc/3.2.2/bin
  TestFPCInstallDir := BuildFPCInstallDirFromInstallRoot(TestInstallRoot, '3.2.2');
  ForceDirectories(TestFPCInstallDir + PathDelim + 'bin');
  ForceDirectories(TestFPCInstallDir + PathDelim + 'units');

  // Compile mock FPC executable
  WriteLn('[Setup] Compiling mock FPC executable...');
  {$IFDEF MSWINDOWS}
  MockFPCTarget := TestFPCInstallDir + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  MockFPCTarget := TestFPCInstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  CompileMockFPCExecutable(MockFPCTarget);

  // Create a hello.pas for smoke test
  HelloPas := TestInstallRoot + PathDelim + 'hello.pas';
  AssignFile(TestFile, HelloPas);
  Rewrite(TestFile);
  WriteLn(TestFile, 'program hello;');
  WriteLn(TestFile, 'begin');
  WriteLn(TestFile, '  WriteLn(''Hello, World!'');');
  WriteLn(TestFile, 'end.');
  CloseFile(TestFile);

  WriteLn('[Setup] Created test FPC installation: ', TestFPCInstallDir);
end;

procedure TestVerifyLegacyLayoutBackfillsMetadataAtLegacyPath;
var
  LegacyRoot: string;
  PreferredInstallDir: string;
  LegacyInstallDir: string;
  LegacyFPCExecutable: string;
  LocalConfigManager: IConfigManager;
  LocalSettingsMgr: ISettingsManager;
  LocalSettings: TFPDevSettings;
  LocalManager: TFPCManager;
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
  Meta: TFPDevMetadata;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation backfills metadata at legacy layout path');
  WriteLn('==================================================');

  LegacyRoot := CreateUniqueTempDir('test_verify_legacy_root');
  LocalConfigManager := CreateIsolatedConfigManager;
  LocalSettingsMgr := LocalConfigManager.GetSettingsManager;
  LocalSettings := LocalSettingsMgr.GetSettings;
  LocalSettings.InstallRoot := LegacyRoot;
  LocalSettingsMgr.SetSettings(LocalSettings);

  PreferredInstallDir := BuildFPCInstallDirFromInstallRoot(LegacyRoot, '3.2.2');
  LegacyInstallDir := LegacyRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';
  ForceDirectories(LegacyInstallDir + PathDelim + 'bin');
  ForceDirectories(LegacyInstallDir + PathDelim + 'units');
  {$IFDEF MSWINDOWS}
  LegacyFPCExecutable := LegacyInstallDir + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  LegacyFPCExecutable := LegacyInstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  CompileMockFPCExecutable(LegacyFPCExecutable);

  LocalManager := TFPCManager.Create(LocalConfigManager);
  try
    Success := LocalManager.VerifyInstallation('3.2.2', VerificationResult);
    if not Success then
    begin
      WriteLn('Failed: VerifyInstallation should succeed for legacy layout');
      WriteLn('Error: ', VerificationResult.ErrorMessage);
      Halt(1);
    end;

    if not FileExists(GetMetadataPath(LegacyInstallDir)) then
    begin
      WriteLn('Failed: VerifyInstallation should write metadata to legacy install path');
      Halt(1);
    end;

    if not ReadFPCMetadata(LegacyInstallDir, Meta) then
    begin
      WriteLn('Failed: ReadFPCMetadata should succeed for legacy install path');
      Halt(1);
    end;

    if not Meta.Verify.OK then
    begin
      WriteLn('Failed: Verify.OK should be true for legacy layout');
      Halt(1);
    end;

    if Meta.Verify.DetectedVersion <> '3.2.2' then
    begin
      WriteLn('Failed: DetectVersion should be 3.2.2 for legacy layout');
      Halt(1);
    end;

    if FileExists(GetMetadataPath(PreferredInstallDir)) then
    begin
      WriteLn('Failed: VerifyInstallation should not backfill metadata into preferred path when only legacy layout exists');
      Halt(1);
    end;
  finally
    LocalManager.Free;
    CleanupTempDir(LegacyRoot);
  end;

  WriteLn('Passed: VerifyInstallation backfills metadata at legacy install path');
end;

procedure TestVerifyConfiguredInstallPathBackfillsMetadataAtConfiguredPath;
var
  CustomRoot: string;
  PreferredInstallDir: string;
  ConfiguredInstallDir: string;
  ConfiguredFPCExecutable: string;
  LocalConfigManager: IConfigManager;
  LocalSettingsMgr: ISettingsManager;
  LocalSettings: TFPDevSettings;
  LocalToolchain: TToolchainInfo;
  LocalManager: TFPCManager;
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
  Meta: TFPDevMetadata;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation backfills metadata at configured install path');
  WriteLn('==================================================');

  CustomRoot := CreateUniqueTempDir('test_verify_configured_root');
  LocalConfigManager := CreateIsolatedConfigManager;
  LocalSettingsMgr := LocalConfigManager.GetSettingsManager;
  LocalSettings := LocalSettingsMgr.GetSettings;
  LocalSettings.InstallRoot := CustomRoot;
  LocalSettingsMgr.SetSettings(LocalSettings);

  PreferredInstallDir := BuildFPCInstallDirFromInstallRoot(CustomRoot, '3.2.2');
  ConfiguredInstallDir := CustomRoot + PathDelim + 'custom-toolchains' +
    PathDelim + 'fpc-3.2.2';
  ForceDirectories(ConfiguredInstallDir + PathDelim + 'bin');
  ForceDirectories(ConfiguredInstallDir + PathDelim + 'units');
  {$IFDEF MSWINDOWS}
  ConfiguredFPCExecutable := ConfiguredInstallDir + PathDelim + 'bin' +
    PathDelim + 'fpc.exe';
  {$ELSE}
  ConfiguredFPCExecutable := ConfiguredInstallDir + PathDelim + 'bin' +
    PathDelim + 'fpc';
  {$ENDIF}
  CompileMockFPCExecutable(ConfiguredFPCExecutable);

  LocalToolchain := Default(TToolchainInfo);
  LocalToolchain.Version := '3.2.2';
  LocalToolchain.InstallPath := ConfiguredInstallDir;
  LocalToolchain.Installed := True;
  LocalToolchain.InstallDate := Now;
  if not LocalConfigManager.GetToolchainManager.AddToolchain('fpc-3.2.2', LocalToolchain) then
  begin
    WriteLn('Failed: AddToolchain should succeed for configured install path');
    CleanupTempDir(CustomRoot);
    Halt(1);
  end;

  LocalManager := TFPCManager.Create(LocalConfigManager);
  try
    Success := LocalManager.VerifyInstallation('3.2.2', VerificationResult);
    if not Success then
    begin
      WriteLn('Failed: VerifyInstallation should succeed for configured install path');
      WriteLn('Error: ', VerificationResult.ErrorMessage);
      Halt(1);
    end;

    if not FileExists(GetMetadataPath(ConfiguredInstallDir)) then
    begin
      WriteLn('Failed: VerifyInstallation should write metadata to configured install path');
      Halt(1);
    end;

    if not ReadFPCMetadata(ConfiguredInstallDir, Meta) then
    begin
      WriteLn('Failed: ReadFPCMetadata should succeed for configured install path');
      Halt(1);
    end;

    if not Meta.Verify.OK then
    begin
      WriteLn('Failed: Verify.OK should be true for configured install path');
      Halt(1);
    end;

    if Meta.Verify.DetectedVersion <> '3.2.2' then
    begin
      WriteLn('Failed: DetectVersion should be 3.2.2 for configured install path');
      Halt(1);
    end;

    if ExpandFileName(Meta.Prefix) <> ExpandFileName(ConfiguredInstallDir) then
    begin
      WriteLn('Failed: Metadata prefix should be configured install path');
      Halt(1);
    end;

    if FileExists(GetMetadataPath(PreferredInstallDir)) then
    begin
      WriteLn('Failed: VerifyInstallation should not backfill metadata into default path when configured install path exists');
      Halt(1);
    end;
  finally
    LocalManager.Free;
    CleanupTempDir(CustomRoot);
  end;

  WriteLn('Passed: VerifyInstallation backfills metadata at configured install path');
end;

procedure TeardownTestEnvironment;
begin
  // Cleanup test install root directory
  if DirectoryExists(TestInstallRoot) then
  begin
    CleanupTempDir(TestInstallRoot);
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

procedure TestVerifyExistingInstallation;
var
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation checks existing FPC');
  WriteLn('==================================================');

  // Execute verification
  Success := FPCManager.VerifyInstallation('3.2.2', VerificationResult);

  if not Success then
  begin
    WriteLn('Failed: VerifyInstallation should return True for existing FPC');
    WriteLn('Error: ', VerificationResult.ErrorMessage);
    WriteLn('Executable exists: ', VerificationResult.ExecutableExists);
    Halt(1);
  end;

  // Assert: Executable should be found
  if not VerificationResult.ExecutableExists then
  begin
    WriteLn('Failed: FPC executable should be found');
    Halt(1);
  end;

  // Assert: Version should match
  if VerificationResult.DetectedVersion <> '3.2.2' then
  begin
    WriteLn('Failed: Version mismatch. Expected 3.2.2, got: ', VerificationResult.DetectedVersion);
    Halt(1);
  end;

  // Assert: Verification should be marked as successful
  if not VerificationResult.Verified then
  begin
    WriteLn('Failed: Verification should be marked as successful');
    Halt(1);
  end;

  WriteLn('Passed: Existing FPC installation verified successfully');
end;

procedure TestVerifyNonExistentInstallation;
var
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation handles non-existent FPC');
  WriteLn('==================================================');

  // Execute verification on non-existent version
  Success := FPCManager.VerifyInstallation('9.9.9', VerificationResult);

  if Success then
  begin
    WriteLn('Failed: VerifyInstallation should return False for non-existent FPC');
    Halt(1);
  end;

  // Assert: Executable should not be found
  if VerificationResult.ExecutableExists then
  begin
    WriteLn('Failed: FPC executable should not be found');
    Halt(1);
  end;

  // Assert: Verification should fail
  if VerificationResult.Verified then
  begin
    WriteLn('Failed: Verification should be marked as failed');
    Halt(1);
  end;

  WriteLn('Passed: Correctly handles non-existent FPC installation');
end;

procedure TestVerifySavesResults;
var
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation saves results to config');
  WriteLn('==================================================');

  // Execute verification
  Success := FPCManager.VerifyInstallation('3.2.2', VerificationResult);

  if not Success then
  begin
    WriteLn('Failed: VerifyInstallation should succeed');
    Halt(1);
  end;

  // Reload config to check if it was saved
  ConfigManager.LoadConfig;

  // Note: Config saving is optional for now
  // In future, we can add verification metadata to config
  WriteLn('Passed: Verification completed (config saving pending)');
end;

procedure TestVerifyBackfillsMissingMetadata;
var
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
  Meta: TFPDevMetadata;
  MetaPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation backfills missing metadata');
  WriteLn('==================================================');

  MetaPath := TestFPCInstallDir + PathDelim + '.fpdev-meta.json';
  if FileExists(MetaPath) then
    DeleteFile(MetaPath);

  Success := FPCManager.VerifyInstallation('3.2.2', VerificationResult);
  if not Success then
  begin
    WriteLn('Failed: VerifyInstallation should succeed');
    Halt(1);
  end;

  if not FileExists(MetaPath) then
  begin
    WriteLn('Failed: VerifyInstallation should create metadata file');
    Halt(1);
  end;

  if not ReadFPCMetadata(TestFPCInstallDir, Meta) then
  begin
    WriteLn('Failed: ReadFPCMetadata should succeed after verify');
    Halt(1);
  end;

  if not Meta.Verify.OK then
  begin
    WriteLn('Failed: Verify.OK should be true after successful verify');
    Halt(1);
  end;

  if Meta.Verify.DetectedVersion <> '3.2.2' then
  begin
    WriteLn('Failed: DetectVersion should be 3.2.2 after verify');
    Halt(1);
  end;

  if not Meta.Verify.SmokeTestPassed then
  begin
    WriteLn('Failed: SmokeTestPassed should be true after verify');
    Halt(1);
  end;

  WriteLn('Passed: VerifyInstallation backfills metadata with verification results');
end;

procedure TestVerifyPreservesInstallMetadataWhenUpdatingVerification;
var
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
  Meta, ReadMeta: TFPDevMetadata;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation preserves install metadata');
  WriteLn('==================================================');

  Meta := Default(TFPDevMetadata);
  Meta.Version := '3.2.2';
  Meta.Scope := isUser;
  Meta.SourceMode := smSource;
  Meta.Channel := 'stable';
  Meta.Prefix := TestFPCInstallDir;
  Meta.Origin.RepoURL := 'https://example.invalid/fpc.git';
  Meta.Origin.BuiltFromSource := True;
  Meta.InstalledAt := 45678.0;

  if not FPCManager.WriteMetadata(TestFPCInstallDir, Meta) then
  begin
    WriteLn('Failed: Seed metadata write should succeed');
    Halt(1);
  end;

  Success := FPCManager.VerifyInstallation('3.2.2', VerificationResult);
  if not Success then
  begin
    WriteLn('Failed: VerifyInstallation should succeed');
    Halt(1);
  end;

  if not ReadFPCMetadata(TestFPCInstallDir, ReadMeta) then
  begin
    WriteLn('Failed: ReadFPCMetadata should succeed after verify update');
    Halt(1);
  end;

  if ReadMeta.SourceMode <> smSource then
  begin
    WriteLn('Failed: SourceMode should be preserved');
    Halt(1);
  end;

  if ReadMeta.Channel <> 'stable' then
  begin
    WriteLn('Failed: Channel should be preserved');
    Halt(1);
  end;

  if ReadMeta.Prefix <> TestFPCInstallDir then
  begin
    WriteLn('Failed: Prefix should be preserved');
    Halt(1);
  end;

  if ReadMeta.Origin.RepoURL <> 'https://example.invalid/fpc.git' then
  begin
    WriteLn('Failed: Origin.RepoURL should be preserved');
    Halt(1);
  end;

  if not ReadMeta.Origin.BuiltFromSource then
  begin
    WriteLn('Failed: Origin.BuiltFromSource should be preserved');
    Halt(1);
  end;

  if ReadMeta.InstalledAt <> Meta.InstalledAt then
  begin
    WriteLn('Failed: InstalledAt should be preserved');
    Halt(1);
  end;

  if not ReadMeta.Verify.OK then
  begin
    WriteLn('Failed: Verify.OK should be updated to true');
    Halt(1);
  end;

  if ReadMeta.Verify.DetectedVersion <> '3.2.2' then
  begin
    WriteLn('Failed: Verify.DetectedVersion should be updated');
    Halt(1);
  end;

  if not ReadMeta.Verify.SmokeTestPassed then
  begin
    WriteLn('Failed: Verify.SmokeTestPassed should be updated');
    Halt(1);
  end;

  WriteLn('Passed: VerifyInstallation preserves install metadata while updating verify fields');
end;

procedure TestSmokeTestCompilation;
var
  Success: Boolean;
  VerificationResult: fpdev.fpc.validator.TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation runs smoke test');
  WriteLn('==================================================');

  // Execute verification with smoke test
  Success := FPCManager.VerifyInstallation('3.2.2', VerificationResult);

  if not Success then
  begin
    WriteLn('Failed: VerifyInstallation should succeed');
    Halt(1);
  end;

  // Assert: Smoke test should pass
  if not VerificationResult.SmokeTestPassed then
  begin
    WriteLn('Failed: Smoke test should pass');
    WriteLn('Note: This requires compiling and running a hello world program');
    Halt(1);
  end;

  WriteLn('Passed: Smoke test passed successfully');
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC Verify Functionality Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    ConfigManager := CreateIsolatedConfigManager;

    TestConfigManagerUsesIsolatedDefaultConfigPath;

    // Setup test environment (before creating FPCManager)
    SetupTestEnvironment;
    try
        // Create FPC manager (will use updated config)
        FPCManager := TFPCManager.Create(ConfigManager);
        try
          // Test 1: Verify existing installation
          TestVerifyExistingInstallation;

          // Test 2: Handle non-existent installation
          TestVerifyNonExistentInstallation;

          // Test 3: Save results to config
          TestVerifySavesResults;

          // Test 4: Verify metadata backfill
          TestVerifyBackfillsMissingMetadata;

          // Test 5: Verify metadata update preserves install metadata
          TestVerifyPreservesInstallMetadataWhenUpdatingVerification;

          // Test 6: Verify metadata backfill works for legacy layout
          TestVerifyLegacyLayoutBackfillsMetadataAtLegacyPath;

          // Test 7: Verify metadata backfill works for configured install path
          TestVerifyConfiguredInstallPathBackfillsMetadataAtConfiguredPath;

          // Test 8: Run smoke test
          TestSmokeTestCompilation;

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
