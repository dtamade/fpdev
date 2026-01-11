program test_fpc_verifier;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCVerifier
  
  Tests:
  - VerifyInstallation: Verifies FPC installation with version check and smoke test
  - RunSmokeTest: Compiles and runs a hello world program
  
  Note: These tests use a mock FPC executable to avoid dependency on real FPC installation.
}

uses
  SysUtils, Classes, fpdev.fpc.version, fpdev.fpc.verifier, fpdev.fpc.types, fpdev.config;

var
  TestInstallRoot: string;
  ConfigManager: TFPDevConfigManager;
  VersionManager: TFPCVersionManager;
  Verifier: TFPCVerifier;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create temporary install root directory
  TestInstallRoot := 'test_verifier_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  // Setup config manager to use test directory
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
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

function CreateMockFPC(const AVersion: string): Boolean;
var
  FPCDir, FPCExe: string;
  F: TextFile;
begin
  Result := False;
  
  // Create FPC install structure
  FPCDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'bin';
  ForceDirectories(FPCDir);

  {$IFDEF MSWINDOWS}
  FPCExe := FPCDir + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := FPCDir + PathDelim + 'fpc';
  {$ENDIF}

  // Create a simple batch file that acts as mock FPC
  // This is simpler than compiling a Pascal program
  {$IFDEF MSWINDOWS}
  try
    AssignFile(F, ChangeFileExt(FPCExe, '.bat'));
    Rewrite(F);
    WriteLn(F, '@echo off');
    WriteLn(F, 'if "%1"=="-iV" (');
    WriteLn(F, '  echo ' + AVersion);
    WriteLn(F, '  exit /b 0');
    WriteLn(F, ')');
    WriteLn(F, 'exit /b 1');
    CloseFile(F);
    
    // Create empty exe file to satisfy FileExists check
    AssignFile(F, FPCExe);
    Rewrite(F);
    CloseFile(F);
    
    Result := True;
    WriteLn('[Setup] Created mock FPC for version ', AVersion, ' at ', FPCExe);
  except
    on E: Exception do
    begin
      WriteLn('[Setup] Failed to create mock FPC: ', E.Message);
      Result := False;
    end;
  end;
  {$ELSE}
  try
    AssignFile(F, FPCExe);
    Rewrite(F);
    WriteLn(F, '#!/bin/sh');
    WriteLn(F, 'if [ "$1" = "-iV" ]; then');
    WriteLn(F, '  echo "' + AVersion + '"');
    WriteLn(F, '  exit 0');
    WriteLn(F, 'fi');
    WriteLn(F, 'exit 1');
    CloseFile(F);
    
    // Make executable
    FpChmod(FPCExe, &755);
    
    Result := True;
    WriteLn('[Setup] Created mock FPC for version ', AVersion, ' at ', FPCExe);
  except
    on E: Exception do
    begin
      WriteLn('[Setup] Failed to create mock FPC: ', E.Message);
      Result := False;
    end;
  end;
  {$ENDIF}
end;

{ Test: VerifyInstallation fails for non-existent version }
procedure TestVerifyNonExistent;
var
  VerifResult: TVerificationResult;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation - Non-existent version');
  WriteLn('==================================================');

  Success := Verifier.VerifyInstallation('9.9.9', VerifResult);

  AssertFalse(Success, 'Should return False for non-existent version');
  AssertFalse(VerifResult.Verified, 'Verified should be False');
  AssertFalse(VerifResult.ExecutableExists, 'ExecutableExists should be False');
  AssertTrue(Length(VerifResult.ErrorMessage) > 0, 'Should have error message');
end;

{ Test: VerifyInstallation detects executable exists }
procedure TestVerifyExecutableExists;
var
  VerifResult: TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerifyInstallation - Executable detection');
  WriteLn('==================================================');

  // Create mock FPC file (just the file, not a real executable)
  if not CreateMockFPC('3.2.2') then
  begin
    WriteLn('  SKIPPED: Could not create mock FPC file');
    Exit;
  end;

  // Note: VerifyInstallation will fail because the mock is not a real executable
  // But we can verify that it detects the file exists
  Verifier.VerifyInstallation('3.2.2', VerifResult);

  // The file exists, so ExecutableExists should be True
  AssertTrue(VerifResult.ExecutableExists, 'ExecutableExists should be True when file exists');
  
  // But verification will fail because it's not a real FPC
  AssertFalse(VerifResult.Verified, 'Verified should be False for mock file');
end;

{ Test: TestInstallation returns boolean }
procedure TestTestInstallation;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: TestInstallation');
  WriteLn('==================================================');

  // Test non-existent version
  Success := Verifier.TestInstallation('9.9.9');
  AssertFalse(Success, 'TestInstallation should return False for non-existent version');
end;

{ Test: Error message is set when executable not found }
procedure TestErrorMessageOnMissingExecutable;
var
  VerifResult: TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Error message on missing executable');
  WriteLn('==================================================');

  Verifier.VerifyInstallation('nonexistent_version', VerifResult);

  AssertTrue(Pos('not found', VerifResult.ErrorMessage) > 0, 
    'Error message should mention "not found"');
end;

{ Test: VerificationResult fields are properly initialized }
procedure TestVerificationResultInit;
var
  VerifResult: TVerificationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: VerificationResult initialization');
  WriteLn('==================================================');

  // Call verify on non-existent to check initialization
  Verifier.VerifyInstallation('nonexistent', VerifResult);

  AssertFalse(VerifResult.Verified, 'Verified should be False');
  AssertFalse(VerifResult.ExecutableExists, 'ExecutableExists should be False');
  AssertFalse(VerifResult.SmokeTestPassed, 'SmokeTestPassed should be False');
  AssertEqualsStr('', VerifResult.DetectedVersion, 'DetectedVersion should be empty');
  AssertTrue(Length(VerifResult.ErrorMessage) > 0, 'ErrorMessage should not be empty');
end;

{ Test: Verifier uses VersionManager for path resolution }
procedure TestVerifierUsesVersionManager;
var
  ExpectedPath, ActualPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Verifier uses VersionManager');
  WriteLn('==================================================');

  // Verify that Verifier's VersionManager is the same we passed
  AssertTrue(Verifier.VersionManager = VersionManager, 'Verifier should use provided VersionManager');

  // Check path resolution is consistent
  ExpectedPath := VersionManager.GetFPCExecutablePath('3.2.2');
  AssertTrue(Pos('3.2.2', ExpectedPath) > 0, 'Path should contain version');
  AssertTrue(Pos('fpc', ExpectedPath) > 0, 'Path should contain fpc');
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCVerifier Unit Test Suite');
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
        VersionManager := TFPCVersionManager.Create(ConfigManager);
        try
          // Create verifier
          Verifier := TFPCVerifier.Create(VersionManager);
          try
            // Run tests
            TestVerifyNonExistent;
            TestVerificationResultInit;
            TestVerifierUsesVersionManager;
            TestVerifyExecutableExists;
            TestTestInstallation;
            TestErrorMessageOnMissingExecutable;

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
            Verifier.Free;
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
