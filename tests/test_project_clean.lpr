program test_project_clean;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.cmd.project, fpdev.config;

var
  TestProjectDir: string;
  TestFilesCreated: Integer;
  ConfigManager: TFPDevConfigManager;
  ProjectManager: TProjectManager;

procedure SetupTestEnvironment;
var
  TestFile: TextFile;
begin
  // Create temporary test project directory
  TestProjectDir := 'test_project_temp_' + IntToStr(GetTickCount64);
  ForceDirectories(TestProjectDir);

  // Create build artifacts that should be cleaned
  TestFilesCreated := 0;

  // Object files (.o)
  AssignFile(TestFile, TestProjectDir + PathDelim + 'main.o');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy object file');
  CloseFile(TestFile);
  Inc(TestFilesCreated);

  AssignFile(TestFile, TestProjectDir + PathDelim + 'unit1.o');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy object file');
  CloseFile(TestFile);
  Inc(TestFilesCreated);

  // Unit files (.ppu)
  AssignFile(TestFile, TestProjectDir + PathDelim + 'unit1.ppu');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy unit file');
  CloseFile(TestFile);
  Inc(TestFilesCreated);

  // Executable (.exe on Windows, no extension on Unix)
  {$IFDEF MSWINDOWS}
  AssignFile(TestFile, TestProjectDir + PathDelim + 'myapp.exe');
  {$ELSE}
  AssignFile(TestFile, TestProjectDir + PathDelim + 'myapp');
  {$ENDIF}
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy executable');
  CloseFile(TestFile);
  Inc(TestFilesCreated);

  // Source files that should NOT be cleaned
  AssignFile(TestFile, TestProjectDir + PathDelim + 'main.pas');
  Rewrite(TestFile);
  WriteLn(TestFile, 'program main; begin WriteLn(''Hello''); end.');
  CloseFile(TestFile);

  AssignFile(TestFile, TestProjectDir + PathDelim + 'unit1.pas');
  Rewrite(TestFile);
  WriteLn(TestFile, 'unit unit1; interface implementation end.');
  CloseFile(TestFile);

  AssignFile(TestFile, TestProjectDir + PathDelim + 'myapp.lpr');
  Rewrite(TestFile);
  WriteLn(TestFile, 'program myapp; begin WriteLn(''Hello''); end.');
  CloseFile(TestFile);

  WriteLn('[Setup] Created test project directory: ', TestProjectDir);
  WriteLn('[Setup] Created ', TestFilesCreated, ' build artifacts');
end;

procedure TeardownTestEnvironment;
var
  SR: TSearchRec;
  FilePath: string;
begin
  // Clean up test directory
  if DirectoryExists(TestProjectDir) then
  begin
    if FindFirst(TestProjectDir + PathDelim + '*.*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          FilePath := TestProjectDir + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) = 0 then
            DeleteFile(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(TestProjectDir);
    WriteLn('[Teardown] Removed test directory: ', TestProjectDir);
  end;
end;

procedure TestCleanRemovesBuildArtifacts;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: CleanProject removes build artifacts');
  WriteLn('==================================================');

  // Execute clean
  Success := ProjectManager.CleanProject(TestProjectDir);

  if not Success then
  begin
    WriteLn('FAIL: CleanProject returned False');
    Halt(1);
  end;

  // Assert: Build artifacts should be removed
  if FileExists(TestProjectDir + PathDelim + 'main.o') then
  begin
    WriteLn('FAIL: Object file main.o was not removed');
    Halt(1);
  end;

  if FileExists(TestProjectDir + PathDelim + 'unit1.o') then
  begin
    WriteLn('FAIL: Object file unit1.o was not removed');
    Halt(1);
  end;

  if FileExists(TestProjectDir + PathDelim + 'unit1.ppu') then
  begin
    WriteLn('FAIL: Unit file unit1.ppu was not removed');
    Halt(1);
  end;

  {$IFDEF MSWINDOWS}
  if FileExists(TestProjectDir + PathDelim + 'myapp.exe') then
  begin
    WriteLn('FAIL: Executable myapp.exe was not removed');
    Halt(1);
  end;
  {$ELSE}
  if FileExists(TestProjectDir + PathDelim + 'myapp') then
  begin
    WriteLn('FAIL: Executable myapp was not removed');
    Halt(1);
  end;
  {$ENDIF}

  // Assert: Source files should be preserved
  if not FileExists(TestProjectDir + PathDelim + 'main.pas') then
  begin
    WriteLn('FAIL: Source file main.pas was removed (should be preserved)');
    Halt(1);
  end;

  if not FileExists(TestProjectDir + PathDelim + 'unit1.pas') then
  begin
    WriteLn('FAIL: Source file unit1.pas was removed (should be preserved)');
    Halt(1);
  end;

  if not FileExists(TestProjectDir + PathDelim + 'myapp.lpr') then
  begin
    WriteLn('FAIL: Source file myapp.lpr was removed (should be preserved)');
    Halt(1);
  end;

  WriteLn('PASS: All build artifacts removed, source files preserved');
end;

procedure TestCleanNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: CleanProject handles non-existent directory');
  WriteLn('==================================================');

  // Execute clean on non-existent directory
  Success := ProjectManager.CleanProject('non_existent_directory_12345');

  if Success then
  begin
    WriteLn('FAIL: CleanProject should return False for non-existent directory');
    Halt(1);
  end;

  WriteLn('PASS: CleanProject correctly handles non-existent directory');
end;

procedure TestCleanEmptyDirectory;
var
  EmptyDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: CleanProject handles empty directory');
  WriteLn('==================================================');

  // Create empty directory
  EmptyDir := 'test_empty_' + IntToStr(GetTickCount64);
  ForceDirectories(EmptyDir);

  try
    // Execute clean
    Success := ProjectManager.CleanProject(EmptyDir);

    if not Success then
    begin
      WriteLn('FAIL: CleanProject should return True for empty directory');
      Halt(1);
    end;

    // Directory should still exist
    if not DirectoryExists(EmptyDir) then
    begin
      WriteLn('FAIL: CleanProject should not remove the directory itself');
      Halt(1);
    end;

    WriteLn('PASS: CleanProject correctly handles empty directory');
  finally
    RemoveDir(EmptyDir);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Project Clean Functionality Tests');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize managers
    ConfigManager := TFPDevConfigManager.Create;
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      ProjectManager := TProjectManager.Create(ConfigManager);
      try
        // Test 1: Clean removes build artifacts
        SetupTestEnvironment;
        try
          TestCleanRemovesBuildArtifacts;
        finally
          TeardownTestEnvironment;
        end;

        // Test 2: Handle non-existent directory
        TestCleanNonExistentDirectory;

        // Test 3: Handle empty directory
        TestCleanEmptyDirectory;

        WriteLn;
        WriteLn('========================================');
        WriteLn('  ALL TESTS PASSED');
        WriteLn('========================================');
        ExitCode := 0;

      finally
        ProjectManager.Free;
      end;
    finally
      ConfigManager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  TEST SUITE FAILED');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
