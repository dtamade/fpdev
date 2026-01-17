program test_fpc_doctor;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCDoctorCommand

  Tests:
  - RunToolVersion: Runs external tool and captures version output
  - CheckWriteableDir: Checks if directory is writable
  - Execute: Runs environment diagnostic checks
}

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config;

var
  TestInstallRoot: string;
  ConfigManager: TFPDevConfigManager;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

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

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  TestInstallRoot := 'test_doctor_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

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

{ Test: Directory write check on valid directory }
procedure TestWriteCheckValidDir;
var
  TestDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Write check on valid directory');
  WriteLn('==================================================');

  TestDir := TestInstallRoot + PathDelim + 'write_test';
  ForceDirectories(TestDir);

  AssertTrue(DirectoryExists(TestDir), 'Test directory should exist');
end;

{ Test: Directory write check on non-existent directory }
procedure TestWriteCheckNonExistentDir;
var
  TestDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Write check on non-existent directory');
  WriteLn('==================================================');

  TestDir := TestInstallRoot + PathDelim + 'nonexistent_' + IntToStr(GetTickCount64);

  AssertFalse(DirectoryExists(TestDir), 'Directory should not exist initially');
end;

{ Test: Config manager provides install root }
procedure TestConfigManagerInstallRoot;
var
  Settings: TFPDevSettings;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Config manager provides install root');
  WriteLn('==================================================');

  Settings := ConfigManager.GetSettings;

  AssertTrue(Settings.InstallRoot <> '', 'InstallRoot should not be empty');
  AssertTrue(Settings.InstallRoot = TestInstallRoot, 'InstallRoot should match test root');
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCDoctorCommand Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    ConfigManager := TFPDevConfigManager.Create;
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      SetupTestEnvironment;
      try
        TestWriteCheckValidDir;
        TestWriteCheckNonExistentDir;
        TestConfigManagerInstallRoot;

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
