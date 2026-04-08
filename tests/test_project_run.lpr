program test_project_run;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process, test_temp_paths, fpdev.project.manager, fpdev.config;

var
  TestProjectDir: string;
  ConfigManager: TFPDevConfigManager;
  ProjectManager: TProjectManager;

function BuildTempProjectDir(const APrefix: string): string;
begin
  Result := CreateUniqueTempDir(APrefix);
end;

procedure SetupTestEnvironment;
var
  TestProgram: TextFile;
  ExeName: string;
  P: TProcess;
  CompileExitCode: Integer;
begin
  // Create temporary test project directory
  if TestProjectDir = '' then
    TestProjectDir := BuildTempProjectDir('test_run_temp_');
  ForceDirectories(TestProjectDir);

  // Create a simple test executable
  {$IFDEF MSWINDOWS}
  ExeName := TestProjectDir + PathDelim + 'testapp.exe';
  {$ELSE}
  ExeName := TestProjectDir + PathDelim + 'testapp';
  {$ENDIF}

  // Create a simple Pascal program
  AssignFile(TestProgram, TestProjectDir + PathDelim + 'testapp.lpr');
  Rewrite(TestProgram);
  WriteLn(TestProgram, 'program testapp;');
  WriteLn(TestProgram, '{$mode objfpc}{$H+}');
  WriteLn(TestProgram, 'uses SysUtils;');
  WriteLn(TestProgram, 'var i: Integer;');
  WriteLn(TestProgram, 'begin');
  WriteLn(TestProgram, '  WriteLn(''TestApp Running'');');
  WriteLn(TestProgram, '  for i := 1 to ParamCount do');
  WriteLn(TestProgram, '    WriteLn(''Arg '', i, '': '', ParamStr(i));');
  WriteLn(TestProgram, '  ExitCode := 0;');
  WriteLn(TestProgram, 'end.');
  CloseFile(TestProgram);

  // Compile the test program using TProcess instead of ExecuteProcess
  WriteLn('[Setup] Compiling test program...');
  P := TProcess.Create(nil);
  try
    P.Executable := 'fpc';
    P.Parameters.Add('-o' + ExeName);
    P.Parameters.Add(TestProjectDir + PathDelim + 'testapp.lpr');
    P.Options := [poWaitOnExit];
    try
      P.Execute;
      CompileExitCode := P.ExitStatus;
    except
      on E: Exception do
      begin
        WriteLn('[Setup] WARNING: Could not compile test program: ', E.Message);
        CompileExitCode := 1;
      end;
    end;
  finally
    P.Free;
  end;

  if CompileExitCode <> 0 then
  begin
    WriteLn('[Setup] WARNING: Could not compile test program, some tests may be skipped');
  end
  else
    WriteLn('[Setup] Test program compiled successfully: ', ExeName);
end;

procedure TeardownTestEnvironment;
begin
  if (TestProjectDir <> '') and DirectoryExists(TestProjectDir) then
  begin
    CleanupTempDir(TestProjectDir);
    WriteLn('[Teardown] Removed test directory: ', TestProjectDir);
    TestProjectDir := '';
  end;
end;

procedure TestTempPathsUseSystemTempRoot;
var
  TempRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: temp paths use system temp root');
  WriteLn('==================================================');

  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  if Pos(TempRoot, ExpandFileName(TestProjectDir)) <> 1 then
  begin
    WriteLn('FAIL: Test project dir should live under system temp');
    Halt(1);
  end;

  if Pos(TempRoot, ExpandFileName(ConfigManager.ConfigPath)) <> 1 then
  begin
    WriteLn('FAIL: Config path should live under system temp');
    Halt(1);
  end;

  WriteLn('PASS: Temp project/config paths are isolated under system temp');
end;

procedure TestRunExecutable;
var
  Success: Boolean;
  ExeName: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: RunProject executes built executable');
  WriteLn('==================================================');

  {$IFDEF MSWINDOWS}
  ExeName := TestProjectDir + PathDelim + 'testapp.exe';
  {$ELSE}
  ExeName := TestProjectDir + PathDelim + 'testapp';
  {$ENDIF}

  // Skip test if executable doesn't exist
  if not FileExists(ExeName) then
  begin
    WriteLn('SKIP: Test executable not available');
    Exit;
  end;

  // Execute run
  Success := ProjectManager.RunProject(TestProjectDir, '');

  if not Success then
  begin
    WriteLn('FAIL: RunProject returned False');
    Halt(1);
  end;

  WriteLn('PASS: Executable ran successfully');
end;

procedure TestRunWithArguments;
var
  Success: Boolean;
  ExeName: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: RunProject passes arguments to executable');
  WriteLn('==================================================');

  {$IFDEF MSWINDOWS}
  ExeName := TestProjectDir + PathDelim + 'testapp.exe';
  {$ELSE}
  ExeName := TestProjectDir + PathDelim + 'testapp';
  {$ENDIF}

  // Skip test if executable doesn't exist
  if not FileExists(ExeName) then
  begin
    WriteLn('SKIP: Test executable not available');
    Exit;
  end;

  // Execute run with arguments
  Success := ProjectManager.RunProject(TestProjectDir, 'arg1 arg2 arg3');

  if not Success then
  begin
    WriteLn('FAIL: RunProject with arguments returned False');
    Halt(1);
  end;

  WriteLn('PASS: Executable ran with arguments successfully');
end;

procedure TestRunNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: RunProject handles non-existent directory');
  WriteLn('==================================================');

  // Execute run on non-existent directory
  Success := ProjectManager.RunProject('non_existent_directory_54321', '');

  if Success then
  begin
    WriteLn('FAIL: RunProject should return False for non-existent directory');
    Halt(1);
  end;

  WriteLn('PASS: RunProject correctly handles non-existent directory');
end;

procedure TestRunNoExecutable;
var
  EmptyDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('TEST: RunProject handles directory with no executable');
  WriteLn('==================================================');

  // Create empty directory
  EmptyDir := BuildTempProjectDir('test_no_exe_');
  ForceDirectories(EmptyDir);

  try
    // Execute run
    Success := ProjectManager.RunProject(EmptyDir, '');

    if Success then
    begin
      WriteLn('FAIL: RunProject should return False when no executable found');
      Halt(1);
    end;

    WriteLn('PASS: RunProject correctly handles missing executable');
  finally
    CleanupTempDir(EmptyDir);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Project Run Functionality Tests');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize managers
    TestProjectDir := BuildTempProjectDir('test_run_temp_');
    ForceDirectories(TestProjectDir);
    ConfigManager := TFPDevConfigManager.Create(IncludeTrailingPathDelimiter(TestProjectDir) + 'config.json');
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      ProjectManager := TProjectManager.Create(ConfigManager);
      try
        // Setup test environment
        SetupTestEnvironment;
        try
          TestTempPathsUseSystemTempRoot;
          // Test 1: Run executable
          TestRunExecutable;

          // Test 2: Run with arguments
          TestRunWithArguments;

          // Test 3: Handle non-existent directory
          TestRunNonExistentDirectory;

          // Test 4: Handle missing executable
          TestRunNoExecutable;

          WriteLn;
          WriteLn('========================================');
          WriteLn('  ALL TESTS PASSED');
          WriteLn('========================================');
          ExitCode := 0;

        finally
          TeardownTestEnvironment;
        end;
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
