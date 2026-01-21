program test_fpc_installer;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCInstaller
  
  Tests:
  - InstallVersion: Installs FPC version from source or binary
  - UninstallVersion: Uninstalls FPC version
  - GetBinaryDownloadURL: Generates platform-specific download URL
  
  Note: These tests use mock implementations for file system and process runner
  to avoid dependency on real network and file system operations.
}

uses
  SysUtils, Classes, fpdev.fpc.version, fpdev.fpc.installer, fpdev.fpc.builder,
  fpdev.fpc.types, fpdev.fpc.interfaces, fpdev.fpc.mocks, fpdev.config;

var
  TestInstallRoot: string;
  ConfigManager: TFPDevConfigManager;
  VersionManager: TFPCVersionManager;
  MockFileSystem: TMockFileSystem;
  MockProcessRunner: TMockProcessRunner;
  Builder: TFPCBuilder;
  Installer: TFPCInstaller;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create temporary install root directory
  TestInstallRoot := 'test_installer_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  // Setup config manager to use test directory
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  Settings.ParallelJobs := 4;
  ConfigManager.SetSettings(Settings);

  WriteLn('[Setup] Created test directory: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
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
  if DirectoryExists(TestInstallRoot) then
  begin
    DeleteDirectory(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
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

procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected ', AExpected, ', got ', AActual, ')');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
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

procedure ResetMocks;
begin
  MockFileSystem.Clear;
  MockProcessRunner.Clear;
end;

{ Test: InstallVersion from source succeeds }
procedure Test_InstallVersion_FromSource_Success;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: InstallVersion - From Source Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Setup mock: git clone succeeds, make succeeds
  MockProcessRunner.SetResult('git', 0, 'Cloning into...', '');
  MockProcessRunner.SetResult('make', 0, 'Build complete', '');
  MockFileSystem.AddDirectory(SourceDir);
  // Note: Don't add InstallDir - it should be created by the installer

  Result := Installer.InstallVersion('3.2.2', True);

  AssertTrue(Result.Success, 'InstallVersion from source should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

{ Test: InstallVersion fails when already installed }
procedure Test_InstallVersion_AlreadyInstalled;
var
  Result: TOperationResult;
  InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: InstallVersion - Already Installed');
  WriteLn('==================================================');

  ResetMocks;
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';
  
  // Setup mock: version is already installed
  MockFileSystem.AddDirectory(InstallDir);
  // Simulate installed version by adding to config
  // Note: This test may need adjustment based on how IsVersionInstalled works
  
  // First install
  MockProcessRunner.SetResult('git', 0, 'Cloning into...', '');
  MockProcessRunner.SetResult('make', 0, 'Build complete', '');
  Installer.InstallVersion('3.2.2', True);
  
  // Second install should fail
  Result := Installer.InstallVersion('3.2.2', True);

  AssertFalse(Result.Success, 'InstallVersion should fail when already installed');
  AssertEquals(Ord(ecVersionAlreadyInstalled), Ord(Result.ErrorCode), 'ErrorCode should be ecVersionAlreadyInstalled');
end;

{ Test: InstallVersion fails with invalid version }
procedure Test_InstallVersion_InvalidVersion;
var
  Result: TOperationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: InstallVersion - Invalid Version');
  WriteLn('==================================================');

  ResetMocks;
  
  Result := Installer.InstallVersion('invalid_version_xyz', True);

  AssertFalse(Result.Success, 'InstallVersion should fail for invalid version');
  AssertEquals(Ord(ecVersionInvalid), Ord(Result.ErrorCode), 'ErrorCode should be ecVersionInvalid');
end;

{ Test: UninstallVersion succeeds }
procedure Test_UninstallVersion_Success;
var
  Result: TOperationResult;
  InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UninstallVersion - Success');
  WriteLn('==================================================');

  ResetMocks;
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';
  
  // Setup mock: version is installed
  MockFileSystem.AddDirectory(InstallDir);
  MockProcessRunner.SetResult('git', 0, 'Cloning into...', '');
  MockProcessRunner.SetResult('make', 0, 'Build complete', '');
  {$IFDEF MSWINDOWS}
  MockProcessRunner.SetResult('cmd', 0, '', '');
  {$ELSE}
  MockProcessRunner.SetResult('rm', 0, '', '');
  {$ENDIF}
  
  // First install
  Installer.InstallVersion('3.2.2', True);
  
  // Then uninstall
  Result := Installer.UninstallVersion('3.2.2');

  AssertTrue(Result.Success, 'UninstallVersion should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

{ Test: UninstallVersion succeeds when not installed }
procedure Test_UninstallVersion_NotInstalled;
var
  Result: TOperationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UninstallVersion - Not Installed');
  WriteLn('==================================================');

  ResetMocks;
  
  // Version is not installed
  Result := Installer.UninstallVersion('9.9.9');

  // Should succeed (nothing to uninstall)
  AssertTrue(Result.Success, 'UninstallVersion should succeed when not installed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

{ Test: GetBinaryDownloadURL generates correct URL }
procedure Test_GetBinaryDownloadURL;
var
  URL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetBinaryDownloadURL');
  WriteLn('==================================================');

  URL := Installer.GetBinaryDownloadURL('3.2.2');

  // URL should contain version
  AssertTrue(Pos('3.2.2', URL) > 0, 'URL should contain version');
  
  // URL should be from sourceforge
  AssertTrue(Pos('sourceforge.net', URL) > 0, 'URL should be from sourceforge');
  
  // URL should contain platform info
  {$IFDEF MSWINDOWS}
  AssertTrue((Pos('Win64', URL) > 0) or (Pos('Win32', URL) > 0), 'URL should contain Windows platform');
  {$ENDIF}
  {$IFDEF LINUX}
  AssertTrue(Pos('Linux', URL) > 0, 'URL should contain Linux platform');
  {$ENDIF}
  {$IFDEF DARWIN}
  AssertTrue(Pos('macOS', URL) > 0, 'URL should contain macOS platform');
  {$ENDIF}
end;

{ Test: Installer uses injected dependencies }
procedure Test_Installer_UsesDependencies;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Installer uses injected dependencies');
  WriteLn('==================================================');

  AssertTrue(Installer.VersionManager = VersionManager, 'Installer should use provided VersionManager');
  AssertTrue(Installer.ConfigManager = ConfigManager, 'Installer should use provided ConfigManager');
  AssertTrue(Installer.Builder = Builder, 'Installer should use provided Builder');
  AssertTrue(Installer.FileSystem = IFileSystem(MockFileSystem), 'Installer should use provided FileSystem');
  AssertTrue(Installer.ProcessRunner = IProcessRunner(MockProcessRunner), 'Installer should use provided ProcessRunner');
end;

{ Test: Error codes are correct }
procedure Test_ErrorCodes;
var
  Result: TOperationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Error codes are correct');
  WriteLn('==================================================');

  ResetMocks;
  
  // Test ecVersionInvalid
  Result := Installer.InstallVersion('invalid_version_xyz', True);
  AssertEquals(Ord(ecVersionInvalid), Ord(Result.ErrorCode), 'Invalid version should return ecVersionInvalid');
end;

{ Test: InstallVersion with Ensure flag }
procedure Test_InstallVersion_WithEnsure;
var
  Result: TOperationResult;
  InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: InstallVersion - With Ensure Flag');
  WriteLn('==================================================');

  ResetMocks;
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';
  
  // Setup mock
  MockFileSystem.AddDirectory(InstallDir);
  MockProcessRunner.SetResult('git', 0, 'Cloning into...', '');
  MockProcessRunner.SetResult('make', 0, 'Build complete', '');
  
  // First install
  Installer.InstallVersion('3.2.2', True);
  
  // Second install with Ensure=True should succeed (not fail)
  Result := Installer.InstallVersion('3.2.2', True, '', True);

  AssertTrue(Result.Success, 'InstallVersion with Ensure should succeed when already installed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCInstaller Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    ConfigManager := TFPDevConfigManager.Create;
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      // Setup test environment
      SetupTestEnvironment;
      try
        // Create version manager
        VersionManager := TFPCVersionManager.Create(ConfigManager.AsConfigManager);
        try
          // Create mock dependencies
          MockFileSystem := TMockFileSystem.Create;
          MockProcessRunner := TMockProcessRunner.Create;

          // Create builder with mock dependencies
          Builder := TFPCBuilder.Create(VersionManager, ConfigManager,
            MockFileSystem, MockProcessRunner);

          // Create installer with mock dependencies
          Installer := TFPCInstaller.Create(VersionManager, ConfigManager,
            Builder, MockFileSystem, MockProcessRunner);
          try
            // Run tests
            Test_InstallVersion_FromSource_Success;
            Test_InstallVersion_AlreadyInstalled;
            Test_InstallVersion_InvalidVersion;
            Test_UninstallVersion_Success;
            Test_UninstallVersion_NotInstalled;
            Test_GetBinaryDownloadURL;
            Test_Installer_UsesDependencies;
            Test_ErrorCodes;
            Test_InstallVersion_WithEnsure;

            // Summary
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
            Installer.Free;
            // Note: Builder is freed by Installer if FOwnsBuilder is True
            // But we passed FOwnsBuilder=False, so we need to free it
            Builder.Free;
          end;
        finally
          VersionManager.Free;
        end;
      finally
        TeardownTestEnvironment;
      end;
    finally
      ConfigManager.Free;
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
