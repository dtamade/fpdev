program test_fpc_builder;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCBuilder

  Tests:
  - DownloadSource: Downloads FPC source from Git repository
  - BuildFromSource: Builds FPC from source code
  - UpdateSources: Updates FPC source from remote repository
  - CleanSources: Cleans build artifacts from source directory

  Note: These tests use mock implementations for file system and process runner
  to avoid dependency on real Git and make commands.
}

uses
  SysUtils, Classes, fpdev.fpc.version, fpdev.fpc.builder, fpdev.fpc.builder.di,
  fpdev.fpc.types, fpdev.fpc.interfaces, fpdev.fpc.mocks, fpdev.config;

var
  TestInstallRoot: string;
  ConfigManager: TFPDevConfigManager;
  VersionManager: TFPCVersionManager;
  MockFileSystem: TMockFileSystem;
  MockProcessRunner: TMockProcessRunner;
  Builder: TFPCBuilder;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function BuildTempRoot(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + APrefix + IntToStr(GetTickCount64);
end;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create temporary install root directory
  if TestInstallRoot = '' then
    TestInstallRoot := BuildTempRoot('test_builder_root_');
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

procedure TestTempPathsUseSystemTempRoot;
var
  TempRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: temp paths use system temp root');
  WriteLn('==================================================');

  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  AssertTrue(Pos(TempRoot, ExpandFileName(TestInstallRoot)) = 1,
    'Test install root should live under system temp');
  AssertTrue(Pos(TempRoot, ExpandFileName(ConfigManager.ConfigPath)) = 1,
    'Config path should live under system temp');
end;

procedure ResetMocks;
begin
  MockFileSystem.Clear;
  MockProcessRunner.Clear;
end;

{ Test: DownloadSource succeeds with valid version }
procedure Test_DownloadSource_Success;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Success');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';

  // Setup mock: git clone succeeds
  MockProcessRunner.SetResult('git', 0, 'Cloning into...', '');

  Result := Builder.DownloadSource('3.2.2', TargetDir);

  AssertTrue(Result.Success, 'DownloadSource should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
  AssertTrue(MockFileSystem.DirectoryExists(TargetDir), 'Target directory should be created');
  AssertTrue(MockProcessRunner.GetExecutedCommands.Count > 0, 'Git command should be executed');
end;

{ Test: DownloadSource fails with invalid version }
procedure Test_DownloadSource_InvalidVersion;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Invalid Version');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-invalid';

  // Version 'invalid' should not have a valid Git tag
  Result := Builder.DownloadSource('invalid', TargetDir);

  AssertFalse(Result.Success, 'DownloadSource should fail for invalid version');
  AssertEquals(Ord(ecVersionNotFound), Ord(Result.ErrorCode), 'ErrorCode should be ecVersionNotFound');
end;

{ Test: DownloadSource fails when git clone fails }
procedure Test_DownloadSource_GitFailed;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Git Failed');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';

  // Setup mock: git clone fails
  MockProcessRunner.SetResult('git', 128, '', 'fatal: repository not found');

  Result := Builder.DownloadSource('3.2.2', TargetDir);

  AssertFalse(Result.Success, 'DownloadSource should fail when git fails');
  AssertEquals(Ord(ecDownloadFailed), Ord(Result.ErrorCode), 'ErrorCode should be ecDownloadFailed');
  AssertTrue(Pos('Git clone failed', Result.ErrorMessage) > 0, 'Error message should mention git clone');
end;

{ Test: BuildFromSource succeeds }
procedure Test_BuildFromSource_Success;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: BuildFromSource - Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Setup mock: source directory exists, make succeeds
  MockFileSystem.AddDirectory(SourceDir);
  MockProcessRunner.SetResult('make', 0, 'Build complete', '');

  Result := Builder.BuildFromSource(SourceDir, InstallDir);

  AssertTrue(Result.Success, 'BuildFromSource should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
  AssertTrue(MockFileSystem.DirectoryExists(InstallDir), 'Install directory should be created');
end;

{ Test: BuildFromSource fails when source directory does not exist }
procedure Test_BuildFromSource_SourceNotExist;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: BuildFromSource - Source Not Exist');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'nonexistent';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Source directory does not exist (not added to mock)

  Result := Builder.BuildFromSource(SourceDir, InstallDir);

  AssertFalse(Result.Success, 'BuildFromSource should fail when source does not exist');
  AssertEquals(Ord(ecBuildFailed), Ord(Result.ErrorCode), 'ErrorCode should be ecBuildFailed');
  AssertTrue(Pos('does not exist', Result.ErrorMessage) > 0, 'Error message should mention directory not exist');
end;

{ Test: BuildFromSource fails when make fails }
procedure Test_BuildFromSource_MakeFailed;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: BuildFromSource - Make Failed');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Setup mock: source directory exists, make fails
  MockFileSystem.AddDirectory(SourceDir);
  MockProcessRunner.SetResult('make', 2, '', 'Error: compilation failed');

  Result := Builder.BuildFromSource(SourceDir, InstallDir);

  AssertFalse(Result.Success, 'BuildFromSource should fail when make fails');
  AssertEquals(Ord(ecBuildFailed), Ord(Result.ErrorCode), 'ErrorCode should be ecBuildFailed');
  AssertTrue(Pos('Build failed', Result.ErrorMessage) > 0, 'Error message should mention build failed');
end;

{ Test: UpdateSources succeeds }
procedure Test_UpdateSources_Success;
var
  Result: TOperationResult;
  SourceDir, GitDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  GitDir := SourceDir + PathDelim + '.git';

  // Setup mock: source directory and .git exist, git commands succeed
  MockFileSystem.AddDirectory(SourceDir);
  MockFileSystem.AddDirectory(GitDir);
  MockProcessRunner.SetResult('git', 0, 'origin', '');  // git remote returns origin

  Result := Builder.UpdateSources('3.2.2');

  AssertTrue(Result.Success, 'UpdateSources should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

{ Test: UpdateSources fails when directory is not a git repo }
procedure Test_UpdateSources_NotGitRepo;
var
  Result: TOperationResult;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Not Git Repo');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';

  // Setup mock: source directory exists but no .git
  MockFileSystem.AddDirectory(SourceDir);
  // .git directory NOT added

  Result := Builder.UpdateSources('3.2.2');

  AssertFalse(Result.Success, 'UpdateSources should fail when not a git repo');
  AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode), 'ErrorCode should be ecFileSystemError');
  AssertTrue(Pos('not a git repository', Result.ErrorMessage) > 0, 'Error message should mention not a git repo');
end;

{ Test: CleanSources succeeds }
procedure Test_CleanSources_Success;
var
  Result: TOperationResult;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources - Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';

  // Setup mock: source directory exists
  MockFileSystem.AddDirectory(SourceDir);

  Result := Builder.CleanSources('3.2.2');

  AssertTrue(Result.Success, 'CleanSources should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

{ Test: CleanSources fails when directory does not exist }
procedure Test_CleanSources_DirNotExist;
var
  Result: TOperationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources - Dir Not Exist');
  WriteLn('==================================================');

  ResetMocks;
  // Source directory does not exist (not added to mock)

  Result := Builder.CleanSources('nonexistent');

  AssertFalse(Result.Success, 'CleanSources should fail when directory does not exist');
  AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode), 'ErrorCode should be ecFileSystemError');
  AssertTrue(Pos('does not exist', Result.ErrorMessage) > 0, 'Error message should mention directory not exist');
end;

{ Test: Builder uses injected dependencies }
procedure Test_Builder_UsesDependencies;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Builder uses injected dependencies');
  WriteLn('==================================================');

  AssertTrue(Builder.VersionManager = VersionManager, 'Builder should use provided VersionManager');
  AssertTrue(Builder.ConfigManager = ConfigManager, 'Builder should use provided ConfigManager');
  AssertTrue(Builder.FileSystem = IFileSystem(MockFileSystem), 'Builder should use provided FileSystem');
  AssertTrue(Builder.ProcessRunner = IProcessRunner(MockProcessRunner), 'Builder should use provided ProcessRunner');
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

  // Test ecVersionNotFound
  Result := Builder.DownloadSource('invalid_version_xyz', '/tmp/test');
  AssertEquals(Ord(ecVersionNotFound), Ord(Result.ErrorCode), 'Invalid version should return ecVersionNotFound');

  // Test ecBuildFailed for missing source
  Result := Builder.BuildFromSource('/nonexistent/path', '/tmp/install');
  AssertEquals(Ord(ecBuildFailed), Ord(Result.ErrorCode), 'Missing source should return ecBuildFailed');

  // Test ecFileSystemError for missing source in CleanSources
  Result := Builder.CleanSources('nonexistent_version');
  AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode), 'Missing source in CleanSources should return ecFileSystemError');
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCBuilder Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    TestInstallRoot := BuildTempRoot('test_builder_root_');
    ForceDirectories(TestInstallRoot);
    ConfigManager := TFPDevConfigManager.Create(IncludeTrailingPathDelimiter(TestInstallRoot) + 'config.json');
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      // Setup test environment
      SetupTestEnvironment;
      try
        TestTempPathsUseSystemTempRoot;
        // Create version manager
        VersionManager := TFPCVersionManager.Create(ConfigManager.AsConfigManager);
        try
          // Create mock dependencies
          MockFileSystem := TMockFileSystem.Create;
          MockProcessRunner := TMockProcessRunner.Create;

          // Create builder with mock dependencies
          Builder := TFPCBuilder.Create(VersionManager, ConfigManager,
            MockFileSystem, MockProcessRunner);
          try
            // Run tests
            Test_DownloadSource_Success;
            Test_DownloadSource_InvalidVersion;
            Test_DownloadSource_GitFailed;
            Test_BuildFromSource_Success;
            Test_BuildFromSource_SourceNotExist;
            Test_BuildFromSource_MakeFailed;
            Test_UpdateSources_Success;
            Test_UpdateSources_NotGitRepo;
            Test_CleanSources_Success;
            Test_CleanSources_DirNotExist;
            Test_Builder_UsesDependencies;
            Test_ErrorCodes;

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
            Builder.Free;
            // Note: MockFileSystem and MockProcessRunner are freed by Builder
            // since they are interface references
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
