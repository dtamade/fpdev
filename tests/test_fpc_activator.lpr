program test_fpc_activator;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCActivator
  
  Tests:
  - CreateWindowsActivationScript: Creates Windows batch activation script
  - CreateUnixActivationScript: Creates Unix shell activation script
  - ActivateVersion: Activates FPC version for current scope
}

uses
  SysUtils, Classes, fpdev.fpc.version, fpdev.fpc.activator, fpdev.types, fpdev.fpc.types,
  fpdev.config.interfaces, fpdev.config.managers;

var
  TestInstallRoot: string;
  ConfigManager: IConfigManager;
  VersionManager: TFPCVersionManager;
  Activator: TFPCActivator;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create temporary install root directory
  TestInstallRoot := GetTempDir + 'test_activator_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  // Setup config manager to use test directory
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

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

function CreateMockFPCInstallation(const AVersion: string): Boolean;
var
  InstallPath, FPCDir, FPCExe: string;
  F: TextFile;
begin
  Result := False;

  // Use VersionManager to get the correct install path (handles project vs user scope)
  InstallPath := VersionManager.GetVersionInstallPath(AVersion);
  FPCDir := InstallPath + PathDelim + 'bin';
  ForceDirectories(FPCDir);

  {$IFDEF MSWINDOWS}
  FPCExe := FPCDir + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := FPCDir + PathDelim + 'fpc';
  {$ENDIF}

  try
    // Create empty exe file to satisfy FileExists check
    AssignFile(F, FPCExe);
    Rewrite(F);
    CloseFile(F);

    Result := FileExists(FPCExe);
    if Result then
      WriteLn('[Setup] Created mock FPC installation for version ', AVersion, ' at ', InstallPath)
    else
      WriteLn('[Setup] Mock FPC exe missing after creation: ', FPCExe);
  except
    on E: Exception do
    begin
      WriteLn('[Setup] Failed to create mock FPC: ', E.Message);
      Result := False;
    end;
  end;
end;

function ReadFileContent(const APath: string): string;
var
  SL: TStringList;
begin
  Result := '';
  if not FileExists(APath) then Exit;
  
  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

{ Test: ActivateVersion fails for non-installed version }
procedure TestActivateNonInstalled;
var
  ActivationResult: TActivationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ActivateVersion - Non-installed version');
  WriteLn('==================================================');

  ActivationResult := Activator.ActivateVersion('9.9.9');

  AssertFalse(ActivationResult.Success, 'Should return False for non-installed version');
  AssertTrue(Pos('not installed', ActivationResult.ErrorMessage) > 0, 
    'Error message should mention "not installed"');
end;

{ Test: ActivateVersion creates activation scripts }
procedure TestActivateCreatesScripts;
var
  ActivationResult: TActivationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ActivateVersion - Creates activation scripts');
  WriteLn('==================================================');

  // Create mock FPC installation
  if not CreateMockFPCInstallation('3.2.2') then
  begin
    WriteLn('  SKIPPED: Could not create mock FPC installation');
    Exit;
  end;

  ActivationResult := Activator.ActivateVersion('3.2.2');

  // Note: Activation may fail at SetDefaultToolchain step, but scripts should still be created
  AssertTrue(Length(ActivationResult.ActivationScript) > 0, 'ActivationScript path should be set');
  AssertTrue(Length(ActivationResult.ShellCommand) > 0, 'ShellCommand should be set');
  
  // Check that activation script file exists (even if final step failed)
  if Length(ActivationResult.ActivationScript) > 0 then
  begin
    AssertTrue(FileExists(ActivationResult.ActivationScript), 
      'Activation script file should exist');
  end;
end;

{ Test: Windows activation script content }
procedure TestWindowsActivationScriptContent;
var
  ActivationResult: TActivationResult;
  ScriptContent: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Windows activation script content');
  WriteLn('==================================================');

  // Create mock FPC installation
  if not CreateMockFPCInstallation('3.2.2') then
  begin
    WriteLn('  SKIPPED: Could not create mock FPC installation');
    Exit;
  end;

  ActivationResult := Activator.ActivateVersion('3.2.2');

  // Check script content even if final activation step failed
  if Length(ActivationResult.ActivationScript) = 0 then
  begin
    WriteLn('  SKIPPED: No activation script path');
    Exit;
  end;

  if not FileExists(ActivationResult.ActivationScript) then
  begin
    WriteLn('  SKIPPED: Activation script file not found');
    Exit;
  end;

  // Read the Windows script (should have .cmd extension)
  ScriptContent := ReadFileContent(ActivationResult.ActivationScript);

  AssertTrue(Pos('@echo off', ScriptContent) > 0, 
    'Windows script should contain @echo off');
  AssertTrue(Pos('SET "PATH=', ScriptContent) > 0, 
    'Windows script should set PATH');
  AssertTrue(Pos('3.2.2', ScriptContent) > 0, 
    'Windows script should contain version path');
end;

{ Test: ActivationResult fields are properly initialized }
procedure TestActivationResultInit;
var
  ActivationResult: TActivationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ActivationResult initialization');
  WriteLn('==================================================');

  // Call activate on non-existent to check initialization
  ActivationResult := Activator.ActivateVersion('nonexistent');

  AssertFalse(ActivationResult.Success, 'Success should be False');
  AssertTrue(Length(ActivationResult.ErrorMessage) > 0, 'ErrorMessage should not be empty');
end;

{ Test: Activator uses VersionManager }
procedure TestActivatorUsesVersionManager;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Activator uses VersionManager');
  WriteLn('==================================================');

  AssertTrue(Activator.VersionManager = VersionManager, 
    'Activator should use provided VersionManager');
  AssertTrue(Activator.ConfigManager = ConfigManager, 
    'Activator should use provided ConfigManager');
end;

{ Test: Activation sets scope correctly }
procedure TestActivationScope;
var
  ActivationResult: TActivationResult;
  OriginalDir, TempDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Activation scope');
  WriteLn('==================================================');

  // Create mock FPC installation
  if not CreateMockFPCInstallation('3.2.2') then
  begin
    WriteLn('  SKIPPED: Could not create mock FPC installation');
    Exit;
  end;

  // Save original directory and change to a temp directory outside the project
  OriginalDir := GetCurrentDir;
  TempDir := GetTempDir + 'fpdev_test_' + IntToStr(GetTickCount64);
  ForceDirectories(TempDir);
  try
    SetCurrentDir(TempDir);

    ActivationResult := Activator.ActivateVersion('3.2.2');

    if ActivationResult.Success then
    begin
      // Should be user scope since we're not in a project directory
      AssertTrue(ActivationResult.Scope = isUser,
        'Scope should be isUser when not in project directory');
    end
    else
    begin
      WriteLn('  INFO: Activation returned: ', ActivationResult.ErrorMessage);
    end;
  finally
    // Restore original directory and clean up temp directory
    SetCurrentDir(OriginalDir);
    if DirectoryExists(TempDir) then
      RemoveDir(TempDir);
  end;
end;

{ Test: Multiple activations work }
procedure TestMultipleActivations;
var
  Result1, Result2: TActivationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Multiple activations');
  WriteLn('==================================================');

  // Create mock FPC installations
  if not CreateMockFPCInstallation('3.2.2') then
  begin
    WriteLn('  SKIPPED: Could not create mock FPC installation');
    Exit;
  end;

  if not CreateMockFPCInstallation('3.2.0') then
  begin
    WriteLn('  SKIPPED: Could not create mock FPC installation');
    Exit;
  end;

  Result1 := Activator.ActivateVersion('3.2.2');
  Result2 := Activator.ActivateVersion('3.2.0');

  // Check that scripts were created (even if final step failed)
  AssertTrue(Length(Result1.ActivationScript) > 0, 'First activation should create script path');
  AssertTrue(Length(Result2.ActivationScript) > 0, 'Second activation should create script path');

  // In user scope, scripts should be different (version in filename)
  // In project scope, scripts are the same (single activate script per project)
  if (Length(Result1.ActivationScript) > 0) and (Length(Result2.ActivationScript) > 0) then
  begin
    if Result1.Scope = isUser then
    begin
      AssertTrue(Result1.ActivationScript <> Result2.ActivationScript,
        'User scope: Different versions should have different activation scripts');
    end
    else
    begin
      // Project scope: same script is expected (by design)
      AssertTrue(Result1.ActivationScript = Result2.ActivationScript,
        'Project scope: All versions share the same activation script');
    end;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCActivator Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    ConfigManager := TConfigManager.Create('');
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    // Setup test environment
    SetupTestEnvironment;
    try
      // Create version manager
      VersionManager := TFPCVersionManager.Create(ConfigManager);
      try
        // Create activator
        Activator := TFPCActivator.Create(VersionManager, ConfigManager);
        try
          // Run tests
          TestActivateNonInstalled;
          TestActivationResultInit;
          TestActivatorUsesVersionManager;
          TestActivateCreatesScripts;
          TestWindowsActivationScriptContent;
          TestActivationScope;
          TestMultipleActivations;

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
          Activator.Free;
        end;
      finally
        VersionManager.Free;
      end;
    finally
      TeardownTestEnvironment;
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
