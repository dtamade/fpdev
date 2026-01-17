program test_fpc_show;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCShowCommand

  Tests:
  - ShowVersionInfo: Displays version information for installed FPC
  - Execute: Runs show command with version parameter
}

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config, fpdev.cmd.fpc;

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
  TestInstallRoot := 'test_show_root_' + IntToStr(GetTickCount64);
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

{ Test: ShowVersionInfo returns false for non-existent version }
procedure TestShowNonExistentVersion;
var
  Manager: TFPCManager;
  Result: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ShowVersionInfo - Non-existent version');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    Result := Manager.ShowVersionInfo('9.9.9');
    AssertFalse(Result, 'ShowVersionInfo should return False for invalid version');
  finally
    Manager.Free;
  end;
end;

{ Test: ShowVersionInfo returns true for valid version }
procedure TestShowValidVersion;
var
  Manager: TFPCManager;
  Result: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ShowVersionInfo - Valid version');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    // 3.2.2 is a valid version in FPC_RELEASES
    Result := Manager.ShowVersionInfo('3.2.2');
    AssertTrue(Result, 'ShowVersionInfo should return True for valid version');
  finally
    Manager.Free;
  end;
end;

{ Test: TFPCManager creation }
procedure TestManagerCreation;
var
  Manager: TFPCManager;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: TFPCManager creation');
  WriteLn('==================================================');

  Manager := TFPCManager.Create(ConfigManager);
  try
    AssertTrue(Manager <> nil, 'Manager should be created');
  finally
    Manager.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCShowCommand Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    ConfigManager := TFPDevConfigManager.Create;
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      SetupTestEnvironment;
      try
        TestManagerCreation;
        TestShowNonExistentVersion;
        TestShowValidVersion;

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
